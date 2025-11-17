import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart' as ptr;

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({Key? key}) : super(key: key);

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  final supabase = Supabase.instance.client;
  bool showReadNotifications = false;
  bool isLoading = false;
  List<Map<String, dynamic>> notifications = [];
  final ptr.RefreshController _refreshController = ptr.RefreshController(
    initialRefresh: false,
  );

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }


  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      if (mounted) {
        setState(() {
          isLoading = false;
          notifications = [];
        });
        _refreshController.refreshFailed();
        debugPrint("❌ No user logged in. Cannot fetch notifications.");
      }
      return;
    }

    try {
      final response = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          notifications = List<Map<String, dynamic>>.from(response);
          isLoading = false;
        });
        _refreshController.refreshCompleted();
      }
    } catch (e) {
      debugPrint("❌ Error loading notifications: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
      _refreshController.refreshFailed();
    }
  }

  void toggleShowReadNotifications() {
    setState(() {
      showReadNotifications = !showReadNotifications;
    });
  }

  Future<void> markAllAsRead() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final unreadIds = notifications
        .where((n) => n['read'] != true)
        .map((n) => n['id'] as String)
        .toList();

    if (unreadIds.isEmpty) return;

    try {
      await supabase
          .from('notifications')
          .update({'read': true})
          .eq('user_id', userId)
          .inFilter('id', unreadIds);

      if (mounted) {
        setState(() {
          for (var notification in notifications) {
            if (unreadIds.contains(notification['id'])) {
              notification['read'] = true;
            }
          }
        });
      }
    }catch (e) {
      debugPrint("❌ Error marking all as read: $e");
    }
  }


  String _formatTimeAgo(String timeString) {
    try {
      final createdAt = DateTime.parse(timeString);
      final localCreatedAt = createdAt.toLocal();
      final difference = DateTime.now().difference(localCreatedAt);

      if (difference.inSeconds < 60) {
        return 'just_now'.tr();
      }
      if (difference.inMinutes < 60) {
        final minutes = difference.inMinutes;
        return "$minutes ${'minutes_ago'.tr().replaceAll('{0}', '').trim()}";
      }
      if (difference.inHours < 24) {
        final hours = difference.inHours;
        return "$hours ${'hours_ago'.tr().replaceAll('{0}', '').trim()}";
      }
      if (difference.inDays < 30) {
        final days = difference.inDays;
        return "$days ${'days_ago'.tr().replaceAll('{0}', '').trim()}";
      }
      if (difference.inDays < 365) {
        final months = (difference.inDays / 30).floor();
        return "$months ${'months_ago'.tr().replaceAll('{0}', '').trim()}";
      }
      final years = (difference.inDays / 365).floor();
      return "$years ${'years_ago'.tr().replaceAll('{0}', '').trim()}";

    } catch (e) {
      debugPrint("❌ Error formatting time: $e");
      return timeString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotifications = showReadNotifications
        ? notifications
        : notifications.where((n) => n['read'] != true).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('notifications'.tr()),
        actions: [
          IconButton(
            icon: Icon(
              showReadNotifications ? Icons.visibility_off : Icons.visibility,
            ),
            tooltip: showReadNotifications ? 'hide_read'.tr() : 'show_all'.tr(),
            onPressed: toggleShowReadNotifications,
          ),
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'mark_all_as_read'.tr(),
            onPressed: markAllAsRead,
          ),
        ],
      ),
      body: ptr.SmartRefresher(
        controller: _refreshController,
        onRefresh: _loadNotifications,
        enablePullDown: true,
        enablePullUp: false,
        header: const ptr.WaterDropHeader(),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : filteredNotifications.isEmpty
            ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.notifications_off,
                size: 70,
                color: Colors.grey,
              ),
              const SizedBox(height: 10),
              Text(
                showReadNotifications
                    ? 'no_notifications_found'.tr()
                    : 'all_caught_up'.tr(),
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: toggleShowReadNotifications,
                child: Text('show_read_notifications'.tr()),
              ),
            ],
          ),
        )
            : ListView.builder(
          itemCount: filteredNotifications.length,
          itemBuilder: (context, index) {
            final notification = filteredNotifications[index];
            final isRead =  notification['read'] == true;
            final timestamp = DateTime.parse(notification['created_at']);
            final timeAgo = _formatTimeAgo(notification['created_at']);

            return Card(
              color: isRead
                  ? Theme.of(context).colorScheme.surface
                  : Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.notifications),
                title: Text(notification['title'] ?? ''),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification['message'] ?? ''),
                    const SizedBox(height: 4),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                trailing: isRead
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.mark_email_read),
                  onPressed: () async {
                    try {
                      await supabase
                          .from('notifications')
                          .update({'read': true})
                          .eq('id', notification['id']);
                      setState(() {
                        notification['read'] = true;
                      });
                    } catch (e) {
                      debugPrint("❌ Error marking as read: $e");
                    }
                  },
                ),
                onTap: () => _showNotificationDetails(notification),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (context) {
        final shipmentDetails = notification['shipment_details'] ?? {};
        return AlertDialog(
          title: Text(notification['title'] ?? 'details'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notification['message'] ?? ''),
              const SizedBox(height: 8),
              if (shipmentDetails.isNotEmpty) ...[
                const Divider(),
                Text('Status: ${shipmentDetails['status']}'.tr()),
                Text('ID: ${shipmentDetails['id']}'.tr()),
                Text('From: ${shipmentDetails['from']}'.tr()),
                Text('To: ${shipmentDetails['to']}'.tr()),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('close'.tr()),
            ),
          ],
        );
      },
    );
  }
}