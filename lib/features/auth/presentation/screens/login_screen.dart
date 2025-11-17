import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'reset_password_screen.dart';
import 'role_selection_page.dart';
import 'dashboard_router.dart';
import '../../utils/user_role.dart';
import '../../../disable/unable_account_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with WidgetsBindingObserver {
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _obscureText = true;
  bool _loading = false;
  bool _oauthInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      print('🔄 App resumed, checking for OAuth completion...');
      _checkForOAuthCompletion();
    }
  }

  void _checkForOAuthCompletion() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null && mounted) {
      print('🎉 CACHED OAUTH DETECTED ON APP RESUME!');
      _handleSuccessfulLogin(currentUser);
    }
  }

  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final email = emailCtrl.text.trim();
    final password = passCtrl.text.trim();

    try {
      final AuthResponse res = await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);

      if (res.user != null) {
        print('✅ Email login successful for user: ${res.user!.email}');
        print('✅ User ID: ${res.user!.id}');

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Login successful!')));
        }
        await Future.delayed(const Duration(milliseconds: 500));
        final currentUser = Supabase.instance.client.auth.currentUser;
        print('🔍 Current user after login: ${currentUser?.email}');

        if (currentUser != null && mounted) {
          print(
            '✅ User authentication confirmed, checking profile and redirecting',
          );
          await _handleSuccessfulLogin(currentUser);
        }
      } else {
        print('❌ Login failed: No user returned');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("login_failed".tr())));
        }
      }
    } on AuthException catch (e) {
      print('❌ Login AuthException: ${e.message}');
      if (e.message.contains('Invalid login credentials') ||
          e.message.contains('Email not confirmed')) {
        await _handlePossibleOAuthUser(email);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    } catch (e) {
      print('❌ Login Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("login_failed".tr())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithProvider(OAuthProvider provider) async {
    if (_oauthInProgress) {
      print('  OAuth already in progress, ignoring duplicate request');
      return;
    }

    print(' 🚀 Starting OAuth flow for provider: $provider');
    setState(() {
      _loading = true;
      _oauthInProgress = true;
    });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: 'com.login.app://login-callback',
      );
      print('🔐 OAuth flow initiated successfully');
      await Future.delayed(const Duration(milliseconds: 500));
      final immediateUser = Supabase.instance.client.auth.currentUser;

      if (immediateUser != null) {
        print('🎯 CACHED OAUTH DETECTED: User session returned immediately');
        if (mounted) {
          setState(() {
            _loading = false;
            _oauthInProgress = false;
          });
          await _handleSuccessfulLogin(immediateUser);
        }
        return;
      }

      print(
        '🔐 OAuth requires user interaction, starting callback detection...',
      );
      _startOAuthCallbackDetection();
    } catch (e) {
      print('❌ OAuth Error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _oauthInProgress = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Social login failed: ${e.toString()}")),
        );
      }
    }
  }

  void _startOAuthCallbackDetection() {
    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      final currentUser = Supabase.instance.client.auth.currentUser;

      if (currentUser != null) {
        print(
          '🎉 OAuth callback completed! User authenticated: ${currentUser.email}',
        );
        timer.cancel();

        if (mounted) {
          setState(() {
            _loading = false;
            _oauthInProgress = false;
          });
          _handleSuccessfulLogin(currentUser);
        }
      } else if (timer.tick > 150) {
        print('⏰ OAuth callback timeout - stopping detection');
        timer.cancel();
        if (mounted) {
          setState(() {
            _loading = false;
            _oauthInProgress = false;
          });
        }
      }
    });
  }

  Future<void> _handleSuccessfulLogin(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_id', user.id);
      print('✅ Saved current_user_id to SharedPreferences for background service.');
    } catch (e) {
      print('❌ Failed to save user_id to SharedPreferences: $e');
    }

    try {
      print(
        '🔍 Checking user profile after successful login for: ${user.email}',
      );

      final userProfile = await Supabase.instance.client
          .from('user_profiles')
          .select(
        'role, account_disable, profile_completed, custom_user_id',
      )
          .eq('user_id', user.id)
          .maybeSingle();

      if (userProfile == null) {
        print('🆕 No profile found, redirecting to role selection');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const RoleSelectionPage()),
          );
        }
      } else {
        final isDisabled = userProfile['account_disable'] as bool? ?? false;
        if (isDisabled) {
          print('🚫 Account disabled, redirecting to unable account page');
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) =>
                    UnableAccountPage(userProfile: userProfile),
              ),
            );
          }
          return;
        }
        final isProfileCompleted =
            userProfile['profile_completed'] as bool? ?? false;
        final role = userProfile['role'];
        final customUserId = userProfile['custom_user_id'] as String?;
        print('🔍 Fetched Custom User ID: $customUserId');
        if (!isProfileCompleted || role == null) {
          print('⚠️ Incomplete profile, redirecting to role selection');
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const RoleSelectionPage(),
              ),
            );
          }
        } else {
          print('✅ Complete profile found, redirecting to dashboard');

          // --- ONESIGNAL LOGIN LOGIC ---
          if (customUserId != null) {
            OneSignal.login(customUserId);
            print('✅ OneSignal user logged in with external ID: $customUserId');
          } else {
            print('❌ OneSignal login skipped: custom_user_id is null');
          }
          // --- END OF LOGIC ---

          final userRole = UserRoleExtension.fromDbValue(role);
          if (userRole != null && mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => DashboardRouter(role: userRole),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('❌ Error handling successful login: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Login successful but navigation failed. Please restart the app.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _handlePossibleOAuthUser(String email) async {
    try {
      final existingUser = await Supabase.instance.client
          .from('user_profiles')
          .select('email, user_id')
          .eq('email', email)
          .maybeSingle();

      if (existingUser != null) {
        print('👤 Email found in database - likely OAuth user');
        _showOAuthRequiredDialog();
      } else {
        print('❌ Email not found in database - invalid credentials');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Invalid email or password")));
        }
      }
    } catch (e) {
      print('❌ Error checking OAuth user: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("login_failed".tr())));
      }
    }
  }

  void _showOAuthRequiredDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Use Google Sign-In"),
        content: const Text(
          "This email is linked to Google sign-in. "
              "Please use 'Continue with Google' to access your account.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _signInWithProvider(OAuthProvider.google);
            },
            child: const Text("Sign in with Google"),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData prefixIcon) {
    return InputDecoration(
      filled: true,
      labelText: label,
      prefixIcon: Icon(prefixIcon, color: Colors.teal.shade700),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.teal.shade700, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('chooseLanguage'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('English'.tr()),
              onTap: () {
                context.setLocale(const Locale('en'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text("हिंदी".tr()),
              onTap: () {
                context.setLocale(const Locale('hi'));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF009688), Color(0xFF26D0CE), Color(0xFF00675b)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          alignment: Alignment.center,
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  child: Material(
                    elevation: 12,
                    borderRadius: BorderRadius.circular(28),
                    shadowColor: Colors.black26,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 38,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 8),
                            Image.asset(
                              'assets/TruckSinghbgr.png',
                              width: 110,
                              height: 110,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "welcome_back".tr(),
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF00796B),
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "sign_in_to_continue".tr(),
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(
                                  context,
                                ).textTheme.headlineMedium?.color,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 32),
                            TextFormField(
                              controller: emailCtrl,
                              enabled: !_loading,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _inputDecoration(
                                "email".tr(),
                                Icons.email_outlined,
                              ),
                              validator: (val) =>
                              val == null || !val.contains('@')
                                  ? 'enter_valid_email'.tr()
                                  : null,
                            ),
                            const SizedBox(height: 22),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: passCtrl,
                                  enabled: !_loading,
                                  obscureText: _obscureText,
                                  style: const TextStyle(
                                    fontSize: 16,
                                  ),
                                  decoration:
                                  _inputDecoration(
                                    "password".tr(),
                                    Icons.lock_outline,
                                  ).copyWith(
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureText
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        color: Colors.teal.shade700,
                                      ),
                                      onPressed: () => setState(
                                            () => _obscureText = !_obscureText,
                                      ),
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.isEmpty) {
                                      return 'please_enter_password'.tr();
                                    }
                                    if (val.length < 8) {
                                      return 'min_password'.tr();
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                          const ResetPasswordRequestPage(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      "forgot_password".tr(),
                                      style: TextStyle(
                                        color: Colors.teal,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF00796B),
                                  foregroundColor: Colors.white,
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: _loading ? null : _loginUser,
                                child: _loading
                                    ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                    : Text("log_in".tr()),
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                    const RoleSelectionPage(),
                                  ),
                                );
                              },
                              child: Text(
                                "dont_have_account".tr(),
                                style: TextStyle(
                                  color: Colors.teal.shade800,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    thickness: 1,
                                    color: Colors.teal.shade400,
                                    endIndent: 12,
                                  ),
                                ),
                                Text(
                                  "or_continue_with".tr(),
                                  style: TextStyle(
                                    color: Colors.teal.shade600,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    thickness: 1,
                                    color: Colors.teal.shade400,
                                    indent: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      side: BorderSide(
                                        color: Colors.grey.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    onPressed: _loading
                                        ? null
                                        : () => _signInWithProvider(
                                      OAuthProvider.google,
                                    ),
                                    child: const Icon(
                                      Icons.g_mobiledata,
                                      size: 32,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 28),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 100,
                right: 60,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(
                      Icons.translate_outlined,
                      size: 28,
                    ),
                    onPressed: () => _showLanguageDialog(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}