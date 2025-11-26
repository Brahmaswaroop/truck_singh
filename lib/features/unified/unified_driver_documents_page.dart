import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:logistics_toolkit/config/theme.dart';
import 'package:intl/intl.dart';
import '../../config/document_types_config.dart';
import '../../services/user_data_service.dart';

enum UserRole { agent, truckOwner, driver }

class UnifiedDriverDocumentsPage extends StatefulWidget {
  const UnifiedDriverDocumentsPage({super.key});

  @override
  State<UnifiedDriverDocumentsPage> createState() =>
      _UnifiedDriverDocumentsPageState();
}

class _UnifiedDriverDocumentsPageState extends State<UnifiedDriverDocumentsPage>
    with TickerProviderStateMixin {
  final SupabaseClient supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _uploadingDriverId;
  String? _uploadingDocType;
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _filteredDrivers = [];
  String? _loggedInUserId;
  UserRole? _userRole;
  late final AnimationController _animationController;
  String _selectedStatusFilter = 'All';
  final List<String> _statusFilters = ['All', 'Pending', 'Approved', 'Rejected'];

  Map<String, Map<String, dynamic>> get _documentTypes =>
      DocumentTypes.allDocuments;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _initializePage();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializePage() async {
    try {
      final userId = await UserDataService.getCustomUserId();
      if (!mounted) return;

      if (userId == null) {
        _showErrorSnackBar('auth_required'.tr());
        setState(() => _isLoading = false);
        return;
      }

      _loggedInUserId = userId;
      await _detectUserRole();

      debugPrint('Detected role for user $_loggedInUserId: $_userRole');
      await _fetchDriversWithDocStatus();

      _animationController.forward();
    } catch (e) {
      _showErrorSnackBar('Failed to initialize page: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _detectUserRole() async {
    if (_loggedInUserId == null) return;
    try {
      final userProfileCheck = await supabase
          .from('user_profiles')
          .select('role')
          .eq('custom_user_id', _loggedInUserId!)
          .limit(1);

      if (userProfileCheck.isNotEmpty) {
        final role = userProfileCheck.first['role'];
        if (role == 'driver') {
          _userRole = UserRole.driver;
          return;
        } else if (role == 'truck_owner' ||
            role.toString().toLowerCase().contains('truck')) {
          _userRole = UserRole.truckOwner;
          return;
        } else if (role == 'agent' ||
            role.toString().toLowerCase().contains('agent')) {
          _userRole = UserRole.agent;
          return;
        }
      }

      final agentRelations = await supabase
          .from('driver_relation')
          .select('owner_custom_id')
          .eq('owner_custom_id', _loggedInUserId!)
          .limit(1);

      if (agentRelations.isNotEmpty) {
        _userRole = UserRole.agent;
        return;
      }

      final truckOwnerRelations = await supabase
          .from('truck_owner_driver_relation')
          .select('truck_owner_custom_id')
          .eq('truck_owner_custom_id', _loggedInUserId!)
          .limit(1);

      if (truckOwnerRelations.isNotEmpty) {
        _userRole = UserRole.truckOwner;
        return;
      }

      _userRole = UserRole.driver;
      debugPrint(
          'Warning: Could not determine user role for $_loggedInUserId, defaulting to driver');
    } catch (e) {
      _userRole = UserRole.driver;
      debugPrint('Error detecting user role: $e, defaulting to driver');
    }
  }

  Future<void> _fetchDriversWithDocStatus() async {
    if (_loggedInUserId == null || _userRole == null) return;

    try {
      List<dynamic> relations;

      if (_userRole == UserRole.agent || _userRole == UserRole.truckOwner) {
        relations = await supabase
            .from('driver_relation')
            .select('driver_custom_id')
            .eq('owner_custom_id', _loggedInUserId!);
      } else if (_userRole == UserRole.driver) {
        final driverOwnerRelation = await supabase
            .from('driver_relation')
            .select('owner_custom_id')
            .eq('driver_custom_id', _loggedInUserId!);

        if (driverOwnerRelation.isNotEmpty) {
          final ownerId = driverOwnerRelation.first['owner_custom_id'];
          relations = await supabase
              .from('driver_relation')
              .select('driver_custom_id')
              .eq('owner_custom_id', ownerId);
        } else {
          relations = [
            {'driver_custom_id': _loggedInUserId},
          ];
        }
      } else {
        relations = [];
      }

      if (relations.isEmpty) {
        if (mounted) setState(() => _drivers = []);
        return;
      }

      final driverIds = relations
          .map((r) => r['driver_custom_id'] as String)
          .where((id) => id.isNotEmpty)
          .toList();

      if (driverIds.isEmpty) {
        if (mounted) setState(() => _drivers = []);
        return;
      }

      final driverProfiles = await supabase
          .from('user_profiles')
          .select('custom_user_id, name, email, mobile_number')
          .inFilter('custom_user_id', driverIds);

      final uploadedDocs = await supabase
          .from('driver_documents')
          .select(
        'driver_custom_id, document_type, updated_at, file_url, status, file_path, rejection_reason, submitted_at, reviewed_at, reviewed_by, uploaded_by_role, owner_custom_id, truck_owner_id, document_category',
      )
          .inFilter('driver_custom_id', driverIds);

      final driversWithStatus = driverProfiles
          .map((driver) {
        final driverId = driver['custom_user_id'];
        if (driverId == null || driverId.isEmpty) return null;

        final docsForThisDriver = uploadedDocs
            .where((doc) => doc['driver_custom_id'] == driverId)
            .toList();

        final docStatus = <String, Map<String, dynamic>>{};
        for (var type in _documentTypes.keys) {
          final doc = docsForThisDriver.firstWhere(
                (d) => d['document_type'] == type,
            orElse: () => {},
          );
          docStatus[type] = {
            'uploaded': doc.isNotEmpty,
            'status': doc['status'] ?? 'Not Uploaded',
            'uploadedAt': doc['updated_at'],
            'file_path': doc['file_path'],
            'file_url': doc['file_url'],
            'uploaded_by_role': doc['uploaded_by_role'],
            'owner_custom_id': doc['owner_custom_id'],
            'truck_owner_id': doc['truck_owner_id'],
            'document_category': doc['document_category'],
            'rejection_reason': doc['rejection_reason'],
            'submitted_at': doc['submitted_at'],
            'reviewed_at': doc['reviewed_at'],
            'reviewed_by': doc['reviewed_by'],
          };
        }

        return {
          ...driver,
          'doc_status': docStatus,
          'total_docs':
          docStatus.values.where((doc) => doc['uploaded']).length,
          'completion_percentage':
          (docStatus.values.where((doc) => doc['uploaded']).length /
              _documentTypes.length *
              100)
              .round(),
        };
      })
          .whereType<Map<String, dynamic>>()
          .toList();

      if (mounted) {
        setState(() {
          _drivers = driversWithStatus;
          _applyStatusFilter();
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error loading driver data: ${e.toString()}');
    }
  }

  void _applyStatusFilter() {
    if (_selectedStatusFilter == 'All') {
      _filteredDrivers = List.from(_drivers);
    } else {
      _filteredDrivers = _drivers.where((driver) {
        final docStatus = driver['doc_status'] as Map<String, dynamic>;
        return docStatus.values.any(
              (doc) =>
          doc['status'].toString().toLowerCase() ==
              _selectedStatusFilter.toLowerCase(),
        );
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Vault'),
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : const Center(
        child: Text(
          'Unified Driver Documents Loaded Successfully!',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}