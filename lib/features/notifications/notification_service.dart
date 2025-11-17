import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final SupabaseClient _client = Supabase.instance.client;
  static String? _currentUserCustomId;
  static Future<String?> getCurrentCustomUserId() async {
    if (_currentUserCustomId != null) {
      return _currentUserCustomId;
    }

    final user = _client.auth.currentUser;
    if (user == null) {
      if (kDebugMode) {
        print('NotificationService: No authenticated user found.');
      }
      return null;
    }

    try {
      final response = await _client
          .from('user_profiles')
          .select('custom_user_id')
          .eq('user_id', user.id)
          .single();

      _currentUserCustomId = response['custom_user_id'] as String?;
      return _currentUserCustomId;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching current user custom_user_id: $e');
      }
      return null;
    }
  }
  static Future<void> sendPushNotificationToUser({
    required String recipientId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    if (recipientId.isEmpty) {
      if (kDebugMode) {
        print('Skipping notification: recipientId is empty.');
      }
      return;
    }

    try {
      await _client.functions.invoke(
        'send-user-notification',
        body: {
          'recipient_id': recipientId,
          'title': title,
          'message': message,
          'data': data ?? {},
        },
      );
      if (kDebugMode) {
        print('Notification sent successfully to $recipientId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to send user notification to $recipientId: $e');
      }
    }
  }
}