import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logistics_toolkit/features/disable/otp_activation_service.dart';
import '../notifications/notification_service.dart';

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _roleFilter = 'All';
  late Future<List<Map<String, dynamic>>> _usersFuture;
  late TabController _tabController;

  final List<String> _roles = [
    'All',
    'shipper',
    'truckowner',
    'driver',
    'agent',
  ];

  @override
  void initState() {
    super.initState();
    _usersFuture = _fetchUsers();
    _tabController = TabController(length: 1, vsync: this);
  }
  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    // If the selected role is "driver", fetch all users so we can filter locally
    final roleForQuery = _roleFilter == 'driver' ? 'All' : _roleFilter;

    final response = await Supabase.instance.client.rpc(
      'get_all_users_for_admin',
      params: {'search_query': _searchQuery, 'role_filter': roleForQuery},
    );

    final List<Map<String, dynamic>> allUsers =
    response == null ? [] : List<Map<String, dynamic>>.from(response);

    // Local filter: remove admin + combine both driver roles
    final filteredUsers = allUsers.where((user) {
      final role = (user['role'] ?? '').toLowerCase();
      if (role == 'admin') return false; // hide admin always
      if (_roleFilter == 'All') return true;
      if (_roleFilter == 'driver') {
        // combine both driver roles
        return role == 'driver_individual' || role == 'driver_company';
      }

      return role == _roleFilter.toLowerCase();
    }).toList();

    return filteredUsers;
  }

  Future<void> _refresh() async {
    setState(() {
      _usersFuture = _fetchUsers();
    });
  }

  Future<void> _toggleUserStatus(Map<String, dynamic> user) async {
    final isCurrentlyDisabled = user['account_disable'] ?? false;
    final action = isCurrentlyDisabled ? 'enable'.tr() : 'disable'.tr();
    bool isProcessing = false;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('$action ${'user_account'.tr()}'),
              content: Text(
                'confirm_user_action'.tr(
                  namedArgs: {
                    'action': action,
                    'name': user['name'] ?? 'Unknown',
                  },
                ),
              ),
              actions: [
                if (!isProcessing)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('cancel'.tr()),
                  ),
                if (!isProcessing)
                  ElevatedButton(
                    onPressed: () async {
                      setState(() => isProcessing = true);
                      try {
                        final currentAdmin =
                            Supabase.instance.client.auth.currentUser;
                        final adminEmail =
                            currentAdmin?.email ?? 'unknown_admin';

                        await toggleAccountStatusRpc(
                          customUserId:
                          user['custom_user_id'],
                          disabled:
                          !isCurrentlyDisabled,
                          changedBy: adminEmail,
                          changedByRole: 'admin',
                        );

                        // --- UPDATED NOTIFICATION LOGIC ---
                        if (!isCurrentlyDisabled) {
                          // This means the user was just DISABLED
                          final String disabledUserCustomId = user['custom_user_id'] ?? '';
                          final String? adminCustomId = await NotificationService.getCurrentCustomUserId();
                          final String disabledUserName = user['name'] ?? 'the user';

                          // 1. Notify the user who was disabled
                          NotificationService.sendPushNotificationToUser(
                            recipientId: disabledUserCustomId,
                            title: 'Account Disabled'.tr(),
                            message: 'Your account has been disabled by an administrator.'.tr(),
                            data: {'type': 'account_status'},
                          );

                          // 2. Notify the admin (self-notification)
                          if (adminCustomId != null) {
                            NotificationService.sendPushNotificationToUser(
                              recipientId: adminCustomId,
                              title: 'Action Confirmation'.tr(),
                              message: 'You have successfully disabled the account for'.tr() + ' $disabledUserName.',
                              data: {'type': 'admin_log'},
                            );
                          }
                        } else {
                          // This means the user was just ENABLED
                          final String enabledUserCustomId = user['custom_user_id'] ?? '';
                          final String? adminCustomId = await NotificationService.getCurrentCustomUserId();
                          final String enabledUserName = user['name'] ?? 'the user';

                          // 1. Notify the user who was enabled
                          NotificationService.sendPushNotificationToUser(
                            recipientId: enabledUserCustomId,
                            title: 'Account Enabled'.tr(),
                            message: 'Your account has been re-enabled by an administrator.'.tr(),
                            data: {'type': 'account_status'},
                          );

                          // 2. Notify the admin (self-notification)
                          if (adminCustomId != null) {
                            NotificationService.sendPushNotificationToUser(
                              recipientId: adminCustomId,
                              title: 'Action Confirmation'.tr(),
                              message: 'You have successfully enabled the account for'.tr() + ' $enabledUserName.',
                              data: {'type': 'admin_log'},
                            );
                          }
                        }
                        Navigator.pop(ctx, true);
                      } catch (e) {
                        setState(() => isProcessing = false);
                        Navigator.pop(ctx, false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: Text(action.toUpperCase()),
                  ),
                if (isProcessing)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );

    if (confirm == true) {
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'user_account_success'.tr(namedArgs: {'action': action}),
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showEditDialog(Map<String, dynamic> user) {
    final nameController = TextEditingController(text: user['name'] ?? '');
    final emailController = TextEditingController(text: user['email'] ?? '');
    String selectedRole = user['role'] ?? '';

    List<String> dropdownRoles = _roles.where((r) => r != 'All').toList();
    if (selectedRole.isNotEmpty && !dropdownRoles.contains(selectedRole)) {
      dropdownRoles.add(selectedRole);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('edit_user_profile'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'name'.tr()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'email'.tr()),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedRole.isNotEmpty ? selectedRole : null,
              items: dropdownRoles
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (val) => setState(() => selectedRole = val ?? ''),
              decoration: InputDecoration(labelText: 'role'.tr()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              await Supabase.instance.client.rpc(
                'admin_update_user',
                params: {
                  'target_user_id': user['user_id'],
                  'new_name': nameController.text,
                  'new_email': emailController.text,
                  'new_role': selectedRole,
                },
              );
              Navigator.pop(context);
              _refresh();
            },
            child: Text('save'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('manage_users'.tr()),
        /*backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,*/
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [Tab(icon: Icon(Icons.people), text: 'all_users'.tr())],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildUserListTab()],
      ),
    );
  }

  Widget _buildUserListTab() {
    return Column(
      children: [
        // Header info
        Container(
          color: Theme.of(context).cardColor,
          padding: const EdgeInsets.all(16),
          //color: Colors.blue[50],
          child: Row(
            children: [
              Icon(Icons.info, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _usersFuture,
                  builder: (context, snapshot) {
                    final count = snapshot.hasData ? snapshot.data!.length : 0;
                    return Text(
                      'total_users'.tr(namedArgs: {'count': count.toString()}),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    );
                  },
                ),
              ),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
            ],
          ),
        ),

        // Search & Filters
        _buildSearchBar(),
        _buildFilterChips(),

        // User List
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }
              final allUsers = snapshot.data ?? [];
              // Filter out admin users completely
              final users = allUsers
                  .where((u) => (u['role'] ?? '').toLowerCase() != 'admin')
                  .toList();

              if (users.isEmpty) {
                return Center(child: Text("no_users_found".tr()));
              }
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final bool isDisabled = user['account_disable'] ?? false;
                    return Card(
                      color: Theme.of(context).cardColor,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getRoleColor(user['role']),
                          child: Text(
                            user['role']?.substring(0, 1).toUpperCase() ?? '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          user['name'] ?? 'No Name',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDisabled ? Colors.grey : null,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ID: ${user['custom_user_id']}'),
                            Text('Email: ${user['email'] ?? 'N/A'}'),
                            Text('Role: ${user['role']}'),
                            if (isDisabled)
                              Text(
                                'account_disabled'.tr(),
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (user['role'] == 'admin')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'admin'.tr(),
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                isDisabled ? Icons.toggle_off : Icons.toggle_on,
                                color: isDisabled ? Colors.grey : Colors.green,
                              ),
                              onPressed: () => _toggleUserStatus(user),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: 'search_user'.tr(),
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
              _refresh();
            },
          ),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
        onSubmitted: (_) => _refresh(),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
      child: Wrap(
        spacing: 8.0,
        children: _roles.map((role) {
          return FilterChip(
            label: Text(role),
            selected: _roleFilter == role,
            onSelected: (selected) {
              setState(() => _roleFilter = role);
              _refresh();
            },
          );
        }).toList(),
      ),
    );
  }

  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'agent':
        return Colors.blue;
      case 'truckowner':
        return Colors.green;
      case 'driver_individual':
      case 'driver_company':
      case 'driver':
        return Colors.orange;
      case 'shipper':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
final _supabase = Supabase.instance.client;
Future<void> toggleAccountStatusRpc({
  required String customUserId,
  required bool disabled,
  required String changedBy,
  required String changedByRole,
}) async {
  try {
    await _supabase
        .from('user_profiles')
        .update({
      'account_disable': disabled,
      'updated_at': DateTime.now().toIso8601String(),
    })
        .eq('custom_user_id', customUserId);
    try {
      await _supabase.from('account_status_log').insert({
        'custom_user_id': customUserId,
        'disabled': disabled,
        'changed_by': changedBy,
        'changed_by_role': changedByRole,
        'changed_at': DateTime.now().toIso8601String(),
      });
    } catch (logError) {
      print('Note: Could not log status change: $logError');
    }
  } catch (e) {
    rethrow;
  }
}