import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../notifications/notification_service.dart';

enum FilePickerSource { camera, gallery }

class TruckDocsScreen extends StatefulWidget {
  const TruckDocsScreen({super.key});

  @override
  State createState() => _TruckDocsScreenState();
}

class _TruckDocsScreenState extends State<TruckDocsScreen>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final uuid = const Uuid();
  final RefreshController _refreshController =
  RefreshController(initialRefresh: false);

  List<Map<String, dynamic>> truckData = [];
  bool isLoading = true;
  Map<int, Map<String, Map<String, dynamic>>> truckDocs = {};
  String? _uploadingTruckId;
  String? _uploadingDocType;
  Map<int, bool> _expandedTrucks = {};
  String? _loggedInUserName;

  late AnimationController _animationController;

  final Map<String, Map<String, dynamic>> _documentTypes = {
    'Permit': {
      'icon': Icons.assignment,
      'description': 'Valid truck permit',
      'color': Colors.blue,
    },
    'Insurance': {
      'icon': Icons.shield,
      'description': 'Active truck insurance',
      'color': Colors.orange,
    },
    'Other': {
      'icon': Icons.insert_drive_file,
      'description': 'Additional document',
      'color': Colors.green,
    },
  };
  bool isSearching = false;
  String searchQuery = '';
  bool showOnlyPending = false;
  final TextEditingController _searchController = TextEditingController();
  Future getOrCreateTempUserId() async {
    final prefs = await SharedPreferences.getInstance();
    var tempUserId = prefs.getString('temp_user_id');
    if (tempUserId == null) {
      tempUserId = uuid.v4();
      await prefs.setString('temp_user_id', tempUserId);
    }
    return tempUserId;
  }

  Future getCustomUserId() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      try {
        final profileRes = await supabase
            .from('user_profiles')
            .select('custom_user_id')
            .eq('user_id', userId)
            .single();
        return profileRes['custom_user_id'] ?? 'TEMP_$userId';
      } catch (e) {
        return 'TEMP_$userId';
      }
    }
    return await getOrCreateTempUserId();
  }

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _searchController.addListener(() {
      setState(() {
        searchQuery = _searchController.text.toLowerCase();
      });
    });
    _fetchTrucks();
  }
  Future<List<String>> _getDriversForTruck(String truckNumber) async {
    try {
      final response = await supabase
          .from('shipment')
          .select('assigned_driver')
          .eq('assigned_truck', truckNumber)
          .not('booking_status', 'in', '("Completed", "cancelled")');

      if (response.isEmpty) {
        return [];
      }
      final driverIds = <String>{};
      for (var row in response) {
        if (row['assigned_driver'] != null) {
          driverIds.add(row['assigned_driver'] as String);
        }
      }
      return driverIds.toList();
    } catch (e) {
      print('Error finding drivers for truck $truckNumber: $e');
      return [];
    }
  }

  Future _fetchTrucks() async {
    setState(() => isLoading = true);
    try {
      final userId = await getCustomUserId();
      final profileResponse = await supabase
          .from('user_profiles')
          .select('name')
          .eq('custom_user_id', userId)
          .maybeSingle();
      if(profileResponse != null) {
        _loggedInUserName = profileResponse['name'];
      }
      final response =
      await supabase.from('trucks').select().eq('truck_admin', userId);
      final fetchedTrucks = List<Map<String, dynamic>>.from(response);
      setState(() {
        truckData = fetchedTrucks;
        _expandedTrucks = {for (var truck in truckData) truck['id']: true}; // Initialize all trucks as expanded
      });

      if (truckData.isNotEmpty) {
        await Future.wait(
          truckData.map((truck) => _fetchDocs(truck['id'] as int)),
        );
      }
      _animationController.forward();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching trucks: $e')),
      );
    } finally {
      setState(() => isLoading = false);
      _refreshController.refreshCompleted();
    }
  }

  Future _fetchDocs(int truckId) async {
    try {
      final res = await supabase
          .from('truck_documents')
          .select()
          .eq('truck_id', truckId);
      final docList = List<Map<String, dynamic>>.from(res);
      final docStatus = <String, Map<String, dynamic>>{};

      for (var type in _documentTypes.keys) {
        final doc = docList.firstWhere(
              (d) => d['doc_type'] == type,
          orElse: () => {},
        );
        docStatus[type] = {
          'uploaded': doc.isNotEmpty,
          'uploadedAt': doc['uploaded_at'],
          'filePath': doc['file_path'],
          'fileName': doc['file_name'],
          'docId': doc['id'],
        };
      }
      setState(() {
        truckDocs[truckId] = docStatus;
      });
    } catch (e) {
      debugPrint('Could not fetch docs for truck $truckId: $e');
    }
  }

  // Show camera tips dialog
  Future<void> _showCameraTipsDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Warning'),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.yellow),
                    SizedBox(width: 8),
                    Expanded(child: Text('Ensure the image is taken in proper lighting to capture clear details.')),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.pan_tool, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(child: Text('Hold the camera steady to avoid blurry images.')),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.flash_on, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(child: Text('Use flash when necessary, especially in low-light conditions.')),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.crop, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(child: Text('Position the document flat and fill the frame for best readability.')),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.visibility_off, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(child: Text('Avoid shadows or glare on the document.')),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Okay'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future _pickAndUploadFile(int truckId, String docType) async {
    String? userId = supabase.auth.currentUser?.id; // This must be a UUID or null
    String? customUserId;

    if (userId == null) {
      // User not logged in, generate temp user id (non UUID)
      customUserId = await getOrCreateTempUserId();
    } else {
      // Try to get proper UUID user_id from user_profiles
      try {
        final profileRes = await supabase
            .from('user_profiles').select('user_id')
            .eq('user_id', userId)
            .single();
        userId = profileRes['user_id'] as String;
      } catch (e) {
        // On failure fallback store original userId as customUserId
        customUserId = userId;
        userId = null;
      }
    }

    // Prompt user to choose source: Camera or Gallery (centered dialog)
    final FilePickerSource? source = await showDialog<FilePickerSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, FilePickerSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, FilePickerSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return; // User cancelled selection

    File? file;
    String? fileName;

    if (source == FilePickerSource.camera) {
      // Show camera tips before opening the camera
      await _showCameraTipsDialog();

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);
      if (pickedFile == null) return;

      file = File(pickedFile.path);
      fileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
    } else {
      // Use FilePicker for gallery
      final result = await FilePicker.platform.pickFiles(allowMultiple: false);
      if (result == null || result.files.isEmpty) return;

      file = File(result.files.single.path!);
      fileName = '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
    }

    final filePath = '${userId ?? customUserId}/$truckId/$fileName';

    setState(() {
      _uploadingTruckId = truckId.toString();
      _uploadingDocType = docType;
    });

    try {
      await supabase.storage.from('truck-docs').upload(filePath, file);
      await supabase.from('truck_documents').upsert({
        'truck_id': truckId,
        'user_id': userId,             // UUID or null here
        'custom_user_id': customUserId, // Put fallback string here
        'doc_type': docType,
        'file_name': fileName,
        'file_path': filePath,
        'uploaded_at': DateTime.now().toIso8601String(),
      }, onConflict: 'truck_id,doc_type');

      // --- START NOTIFICATION LOGIC ---
      if (customUserId != null) {
        final uploaderName = _loggedInUserName ?? customUserId;
        final truck = truckData.firstWhere((t) => t['id'] == truckId);
        final truckNumber = truck['truck_number'] ?? 'your truck';

        // 1. Notify self (Agent or Truck Owner)
        NotificationService.sendPushNotificationToUser(
          recipientId: customUserId,
          title: 'Document Uploaded'.tr(),
          message: 'You have successfully uploaded $docType for truck $truckNumber.'.tr(),
          data: {'type': 'truck_document_upload', 'truck_number': truckNumber},
        );

        // 2. Find and notify assigned drivers
        final driverIds = await _getDriversForTruck(truckNumber);
        for (final driverId in driverIds) {
          NotificationService.sendPushNotificationToUser(
            recipientId: driverId,
            title: 'Truck Document Updated'.tr(),
            message: '$uploaderName has uploaded a new document ($docType) for your assigned truck $truckNumber.'.tr(),
            data: {'type': 'truck_document_update', 'truck_number': truckNumber},
          );
        }
      }
      // --- END NOTIFICATION LOGIC ---

      await _fetchDocs(truckId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$docType uploaded successfully!'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error uploading $docType: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() {
        _uploadingTruckId = null;
        _uploadingDocType = null;
      });
    }
  }


  Widget _buildDocumentRow(int truckId, String docType, Map docInfo) {
    final hasDoc = docInfo['uploaded'] ?? false;
    final typeInfo = _documentTypes[docType]!;
    final isUploading = _uploadingTruckId == truckId.toString() &&
        _uploadingDocType == docType;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      //color: Theme.of(context).cardColor,
      decoration: BoxDecoration(
        //color: hasDoc ? Colors.green.shade50 : null ,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasDoc ? Colors.green.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(typeInfo['icon'], color: typeInfo['color']),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(docType,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text(typeInfo['description'],
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                if (hasDoc && docInfo['uploadedAt'] != null)
                  Text(
                    'Uploaded: ${docInfo['uploadedAt']}',
                    style: TextStyle(fontSize: 10, color: Colors.green.shade600),
                  ),
              ],
            ),
          ),
          if (isUploading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            ElevatedButton(
              onPressed: () => _pickAndUploadFile(truckId, docType),
              child: Text(hasDoc ? 'Update' : 'Upload'),
            ),
        ],
      ),
    );
  }

  void _onRefresh() => _fetchTrucks();

  List<Map<String, dynamic>> _getFilteredTrucks() {
    return truckData.where((truck) {
      final truckId = truck['id'] as int;
      final docsStatus = truckDocs[truckId] ?? {};
      final uploadedCount = docsStatus.values.where((d) => d['uploaded'] == true).length;
      final totalDocs = _documentTypes.length;

      final matchesSearch = searchQuery.isEmpty ||
          (truck['truck_number']?.toString().toLowerCase().contains(searchQuery) ?? false);

      final matchesPendingFilter = !showOnlyPending || uploadedCount < totalDocs;

      return matchesSearch && matchesPendingFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredTrucks = _getFilteredTrucks();

    return Scaffold(
      appBar: AppBar(
        title: isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search by truck number...',
            border: InputBorder.none,
            //hintStyle: TextStyle(color: Colors.white70),
          ),
          //style: const TextStyle(color: Colors.white),
        )
            : const Text('Truck Documents'),
        backgroundColor: Colors.blue.shade600,
        //foregroundColor: Colors.white,
        actions: [
          if (isSearching)
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: () {
                setState(() {
                  isSearching = false;
                  _searchController.clear();
                });
              },
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  isSearching = true;
                });
              },
            ),
            IconButton(
              icon: Icon(
                Icons.filter_list,
                color: showOnlyPending ? Colors.blueAccent : null,
              ),
              onPressed: () {
                setState(() {
                  showOnlyPending = !showOnlyPending;
                });
              },
            ),
          ],
        ],
      ),
      body: SmartRefresher(
        controller: _refreshController,
        onRefresh: _onRefresh,
        header: const WaterDropHeader(),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : filteredTrucks.isEmpty
            ? const Center(child: Text('No trucks found'))
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredTrucks.length,
          itemBuilder: (context, index) {
            final truck = filteredTrucks[index];
            final truckId = truck['id'] as int;
            final docsStatus = truckDocs[truckId] ?? {};
            final totalDocs = _documentTypes.length;
            final uploadedCount = docsStatus.values
                .where((d) => d['uploaded'] == true)
                .length;
            final isExpanded = _expandedTrucks[truckId] ?? true;

            return AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return SlideTransition(
                  position: Tween(
                      begin: const Offset(1, 0), end: Offset.zero)
                      .animate(CurvedAnimation(
                    parent: _animationController,
                    curve: Interval(index * 0.1, 1.0,
                        curve: Curves.easeOutBack),
                  )),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      // color: Colors.white,
                      color: Theme.of(context).cardColor,

                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.blue.shade100,
                                child: const Icon(
                                    Icons.local_shipping,
                                    color: Colors.blue),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  truck['truck_number'] ??
                                      'Unnamed Truck',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  isExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _expandedTrucks[truckId] =
                                    !isExpanded;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: uploadedCount == totalDocs
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: uploadedCount == totalDocs
                                    ? Colors.green.shade200
                                    : Colors.orange.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  uploadedCount == totalDocs
                                      ? Icons.check_circle
                                      : Icons.pending,
                                  color: uploadedCount == totalDocs
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$uploadedCount / $totalDocs documents uploaded',
                                  style: TextStyle(
                                    color: uploadedCount == totalDocs
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isExpanded) ...[
                            const SizedBox(height: 16),
                            ..._documentTypes.keys.map((docType) {
                              final docInfo =
                                  docsStatus[docType] ?? {'uploaded': false};
                              return _buildDocumentRow(
                                  truckId, docType, docInfo);
                            }).toList(),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}