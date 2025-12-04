import 'package:supabase_flutter/supabase_flutter.dart';
import '../notifications/notification_manager.dart';

final _supabase = Supabase.instance.client;

class OtpActivationService {
  static final supabase = Supabase.instance.client;

  static Future<Map<String, dynamic>> sendActivationOtp({
    required String email,
  }) async {
    try {
      final userProfile = await supabase
          .from('user_profiles')
          .select('custom_user_id, account_disable')
          .eq('email', email)
          .maybeSingle();

      if (userProfile != null && userProfile['account_disable'] == true) {
        final disableLog = await supabase
            .from('account_status_logs')
            .select('performed_by_custom_id')
            .eq('target_custom_id', userProfile['custom_user_id'])
            .eq('action_type', 'account_disabled')
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (disableLog != null &&
            disableLog['performed_by_custom_id'] !=
                userProfile['custom_user_id']) {
          return {
            'ok': false,
            'error':
                'Your account has been disabled by an admin/agent. Please use the "Request Access" option.',
          };
        }
      }

      await _attemptOtp(email, true);
      return {'ok': true, 'message': 'OTP sent successfully to $email'};
    } catch (_) {
      try {
        await _attemptOtp(email, false);
        return {'ok': true, 'message': 'OTP sent successfully to $email'};
      } catch (e2) {
        print('Both attempts failed: $e2');
        String errorMessage = e2.toString();
        if (errorMessage.contains('timeout') || errorMessage.contains('504')) {
          errorMessage =
              'Server timeout - please check your internet connection and try again';
        } else if (errorMessage.contains('otp_disabled')) {
          errorMessage = 'OTP is disabled in Supabase settings';
        } else if (errorMessage.contains('rate_limit')) {
          errorMessage =
              'Too many requests - please wait a moment and try again';
        }
        return {'ok': false, 'error': errorMessage};
      }
    }
  }

  static Future<void> _attemptOtp(String email, bool shouldCreate) async {
    await supabase.auth
        .signInWithOtp(email: email, shouldCreateUser: shouldCreate)
        .timeout(const Duration(seconds: 15));
  }

  static Future<Map<String, dynamic>> verifyOtpAndActivate({
    required String email,
    required String otpCode,
    required String customUserId,
  }) async {
    try {
      final response = await supabase.auth.verifyOTP(
        email: email,
        token: otpCode,
        type: OtpType.email,
      );

      if (response.user == null)
        return {'ok': false, 'error': 'Invalid OTP code'};

      final profile = await supabase
          .from('user_profiles')
          .select('account_disable')
          .eq('custom_user_id', customUserId)
          .maybeSingle();

      if (profile?['account_disable'] == true) {
        final disableLog = await supabase
            .from('account_status_logs')
            .select('performed_by_custom_id')
            .eq('target_custom_id', customUserId)
            .eq('action_type', 'account_disabled')
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (disableLog != null &&
            disableLog['performed_by_custom_id'] != customUserId) {
          return {
            'ok': false,
            'error':
                'This account was disabled by an admin/agent and cannot be reactivated via OTP. Please use the "Request Access" option.',
          };
        }
      }

      await supabase
          .from('user_profiles')
          .update({
            'account_disable': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('custom_user_id', customUserId);

      await supabase.from('account_status_logs').insert({
        'target_custom_id': customUserId,
        'performed_by_custom_id': customUserId,
        'action_type': 'account_enabled',
        'reason': 'self_activation_via_otp',
        'metadata': {
          'activation_method': 'email_otp',
          'timestamp': DateTime.now().toIso8601String(),
          'email_used': email,
        },
        'created_at': DateTime.now().toIso8601String(),
      });

      await _notifyOwnerAboutAccountActivation(customUserId);

      return {
        'ok': true,
        'message': 'Account activated successfully',
        'user_id': customUserId,
      };
    } catch (e) {
      return {'ok': false, 'error': 'Verification failed: $e'};
    }
  }

  static Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
    } catch (_) {}
  }

  static Future<void> _notifyOwnerAboutAccountActivation(
    String customUserId,
  ) async {
    try {
      final relation = await supabase
          .from('driver_relation')
          .select('*')
          .eq('driver_custom_id', customUserId)
          .maybeSingle();

      if (relation == null) return;

      final ownerId =
          relation['owner_custom_id'] ??
          relation['agent_custom_id'] ??
          relation['truck_owner_custom_id'];

      if (ownerId == null) return;

      final driver = await supabase
          .from('user_profiles')
          .select('name')
          .eq('custom_user_id', customUserId)
          .single();

      await NotificationManager().createNotification(
        userId: ownerId,
        title: 'Driver Account Activated',
        message: '${driver['name'] ?? 'Driver'} has activated their account.',
        type: 'account_status',
        sourceType: 'account_management',
        sourceId: customUserId,
      );
    } catch (_) {}
  }
}

Future<void> toggleAccountStatusRpc({
  required String customUserId,
  required bool disabled,
  required String changedBy,
  required String changedByRole,
}) async {
  try {
    String performer = customUserId;

    final currentUser = _supabase.auth.currentUser;
    if (currentUser != null) {
      final profile = await _supabase
          .from('user_profiles')
          .select('custom_user_id')
          .eq('user_id', currentUser.id)
          .maybeSingle();
      performer = profile?['custom_user_id'] ?? performer;
    }

    final isAdminAction = performer != customUserId;

    await _supabase
        .from('user_profiles')
        .update({
          'account_disable': disabled,
          'disabled_by_admin': isAdminAction && disabled,
          'account_disabled_by_role': disabled ? changedByRole : null,
          'last_changed_by': performer,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('custom_user_id', customUserId);

    await _supabase.from('account_status_logs').insert({
      'target_custom_id': customUserId,
      'performed_by_custom_id': performer,
      'action_type': disabled ? 'account_disabled' : 'account_enabled',
      'reason': disabled
          ? 'Account disabled by $changedByRole'
          : 'Account enabled by $changedByRole',
      'metadata': {
        'changed_by': changedBy,
        'changed_by_role': changedByRole,
        'timestamp': DateTime.now().toIso8601String(),
      },
      'created_at': DateTime.now().toIso8601String(),
    });
  } catch (e) {
    rethrow;
  }
}
