import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:logistics_toolkit/services/user_data_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logistics_toolkit/features/disable/otp_activation_service.dart';
import '../notifications/notification_service.dart';

class AddDriverPage extends StatefulWidget {
  const AddDriverPage({super.key});
  @override
  _AddDriverPageState createState() => _AddDriverPageState();
}

class _AddDriverPageState extends State<AddDriverPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController inputController = TextEditingController();
  bool _pageIsLoading = true;
  bool _actionIsLoading = false;
  List<Map<String, dynamic>> addedDrivers = [];
  String? loggedInOwnerCustomId;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    final ownerId = await UserDataService.getCustomUserId();
    if (!mounted) return;

    if (ownerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('could_not_identify_user'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _pageIsLoading = false);
      return;
    }

    loggedInOwnerCustomId = ownerId;
    await fetchAddedDrivers();
    if (mounted) setState(() => _pageIsLoading = false);
  }

  Future<void> addDriver() async {
    final input = inputController.text.trim();

    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('please_enter_driver_id_or_mobile'.tr())),
      );
      return;
    }

    if (loggedInOwnerCustomId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('owner_info_not_loaded'.tr())));
      return;
    }

    setState(() => _actionIsLoading = true);

    try {
      Map<String, dynamic>? userResponse;

      if (RegExp(r'^\d{10}$').hasMatch(input)) {
        final result = await supabase
            .from('user_profiles')
            .select()
            .eq('mobile_number', input)
            .limit(1);
        if (result.isEmpty) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('no_driver_with_mobile'.tr())));
          setState(() => _actionIsLoading = false);
          return;
        }
        userResponse = result.first;
      } else {
        final result = await supabase
            .from('user_profiles')
            .select()
            .eq('custom_user_id', input)
            .limit(1);
        if (result.isEmpty) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('driver_not_found_id'.tr())));
          setState(() => _actionIsLoading = false);
          return;
        }
        userResponse = result.first;
      }

      final driverCustomId = userResponse['custom_user_id'];

      if (driverCustomId == loggedInOwnerCustomId) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('cannot_add_self_driver'.tr())));
        setState(() => _actionIsLoading = false);
        return;
      }

      if (!driverCustomId.toString().startsWith("DRV")) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('cannot_add_non_driver'.tr())));
        setState(() => _actionIsLoading = false);
        return;
      }

      final existingRelation = await supabase
          .from('driver_relation')
          .select()
          .eq('owner_custom_id', loggedInOwnerCustomId!)
          .eq('driver_custom_id', driverCustomId)
          .maybeSingle();

      if (existingRelation != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('driver_already_added'.tr())));
        setState(() => _actionIsLoading = false);
        return;
      }

      await supabase.from('driver_relation').insert({
        'owner_custom_id': loggedInOwnerCustomId,
        'driver_custom_id': driverCustomId,
      });

      await fetchAddedDrivers();
      inputController.clear();

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('driver_linked_success'.tr())));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _actionIsLoading = false);
    }
  }

  Future<void> fetchAddedDrivers() async {
    if (loggedInOwnerCustomId == null) return;

    try {
      final relation = await supabase
          .from('driver_relation')
          .select('driver_custom_id')
          .eq('owner_custom_id', loggedInOwnerCustomId!);

      if (relation.isEmpty) {
        setState(() => addedDrivers = []);
        return;
      }

      final driverIds = relation
          .map((item) => item['driver_custom_id'].toString())
          .toList();
      final drivers = await supabase
          .from('user_profiles')
          .select()
          .inFilter('custom_user_id', driverIds);

      setState(() {
        addedDrivers = List<Map<String, dynamic>>.from(drivers);
      });
    } catch (e) {
      setState(() => addedDrivers = []);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('error_fetch_driver_list'.tr())));
    }
  }

  Future<void> deleteDriver(String driverId) async {
    if (loggedInOwnerCustomId == null) return;

    try {
      await supabase
          .from('driver_relation')
          .delete()
          .eq('owner_custom_id', loggedInOwnerCustomId!)
          .eq('driver_custom_id', driverId);

      setState(() =>
          addedDrivers.removeWhere((d) => d['custom_user_id'] == driverId));

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('driver_removed'.tr())));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _toggleDriverAccountStatus(Map<String, dynamic> driver) async {
    final isDisabled = driver['account_disable'] ?? false;
    final shouldDisable = !isDisabled;
    final action = shouldDisable ? 'disable' : 'enable';

    try {
      final current = supabase.auth.currentUser;
      if (current == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("No authenticated user found")));
        return;
      }

      String role = 'agent';
      String email = current.email ?? '';

      final userRole = await supabase
          .from('user_profiles')
          .select('role')
          .eq('user_id', current.id)
          .maybeSingle();

      if (userRole?['role'] != null) {
        role = userRole!['role'];
      }

      await toggleAccountStatusRpc(
        customUserId: driver['custom_user_id'],
        disabled: shouldDisable,
        changedBy: email,
        changedByRole: role,
      );

      if (shouldDisable) {
        NotificationService.sendPushNotificationToUser(
          recipientId: driver['custom_user_id'],
          title: 'Account Disabled'.tr(),
          message: 'Your account has been disabled by your owner.'.tr(),
          data: {'type': 'account_status'},
        );
      } else {
        NotificationService.sendPushNotificationToUser(
          recipientId: driver['custom_user_id'],
          title: 'Account Enabled'.tr(),
          message: 'Your account has been enabled by your owner.'.tr(),
          data: {'type': 'account_status'},
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Driver account ${action}d successfully"),
          backgroundColor: Colors.green,
        ),
      );

      await fetchAddedDrivers();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Widget driverCard(Map<String, dynamic> driver) {
    final isDisabled = driver['account_disable'] ?? false;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.only(left: 24, right: 16, top: 16, bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  child: Icon(Icons.person, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    driver['name'] ?? 'No Name',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "ID: ${driver['custom_user_id']}",
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              "Contact: ${driver['mobile_number'] ?? 'N/A'}",
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              "Status: ${isDisabled ? 'Disabled' : 'Enabled'}",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDisabled ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('confirm_action'.tr()),
                        content: Text(
                          isDisabled
                              ? 'confirm_enable'.tr()
                              : 'confirm_disable'.tr(),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('cancel'.tr()),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(
                              isDisabled ? 'enable'.tr() : 'disable'.tr(),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await _toggleDriverAccountStatus(driver);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDisabled ? Colors.green : Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                  ),
                  child: Text(isDisabled ? 'Enable' : 'Disable'),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 15),
                  child: IconButton(
                    icon: const Icon(
                      Icons.delete_forever,
                      size: 32,
                      color: Colors.red,
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('confirm_deletion'.tr()),
                          content: Text('confirm_remove_driver'.tr()),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('cancel'.tr()),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(
                                'delete'.tr(),
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await deleteDriver(driver['custom_user_id']);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('manage_drivers'.tr())),
      body: _pageIsLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: inputController,
                    decoration: InputDecoration(
                      labelText: 'enter_driver_id_mobile'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _actionIsLoading ? null : addDriver,
                    icon: _actionIsLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                  ))
                        : const Icon(Icons.person_add_alt_1),
                    label: Text('add_driver'.tr()),
                  ),

                  const SizedBox(height: 18),
            Text('your_added_drivers'.tr(),
                style: Theme.of(context).textTheme.titleLarge),
                  const Divider(),
                  Expanded(
                    child: addedDrivers.isEmpty
                        ? Center(child: Text('no_drivers_added'.tr()))
                        : RefreshIndicator(
                            onRefresh: fetchAddedDrivers,
                            child: ListView.builder(
                              itemCount: addedDrivers.length,
                              itemBuilder: (context, index) =>
                                  driverCard(addedDrivers[index]),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
