import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:logistics_toolkit/config/theme.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/presentation/screens/dashboard_router.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/role_selection_page.dart';
import 'features/auth/utils/user_role.dart';
import 'features/disable/unable_account_page.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('supabaseUrl', dotenv.env['SUPABASE_URL']!);
  await prefs.setString('supabaseAnonKey', dotenv.env['SUPABASE_ANON_KEY']!);

  OneSignal.initialize(dotenv.env['ONESIGNAL_APP_ID']!);
  OneSignal.Notifications.requestPermission(true);

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('hi')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: ChangeNotifierProvider(
        create: (_) => ThemeNotifier(),
        child: const MyApp(),
      ),
    ),
  );
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, notifier, _) {
        return MaterialApp(
          title: 'Logistics Toolkit',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: notifier.themeMode,
          home: const RootPage(),
          debugShowCheckedModeBanner: false,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
        );
      },
    );
  }
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  bool _loading = true;
  Widget? _screen;
  late StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _handleInitialSession();
    _authSubscription = supabase.auth.onAuthStateChange.listen(
      _handleAuthEvent,
    );
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _handleInitialSession() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _setScreen(const LoginPage());
    } else {
      await _routeUser(user);
    }
  }

  Future<void> _handleAuthEvent(AuthState event) async {
    final user = event.session?.user;

    if (event.event == AuthChangeEvent.signedOut || user == null) {
      return _setScreen(const LoginPage());
    }

    await _routeUser(user);
  }

  Future<void> _routeUser(User user) async {
    try {
      final profile = await supabase
          .from('user_profiles')
          .select('role, account_disable, profile_completed')
          .eq('user_id', user.id)
          .maybeSingle();

      if (profile == null) return _setScreen(const RoleSelectionPage());

      if (profile['account_disable'] == true) {
        return _setScreen(UnableAccountPage(userProfile: profile));
      }

      if (!(profile['profile_completed'] ?? false)) {
        return _setScreen(const RoleSelectionPage());
      }

      final role = UserRoleExtension.fromDbValue(profile['role']);
      if (role == null) return _setScreen(const RoleSelectionPage());

      _setScreen(DashboardRouter(role: role));
    } catch (e) {
      debugPrint("Routing error: $e");
      _setScreen(const LoginPage());
    }
  }

  void _setScreen(Widget page) {
    if (!mounted) return;
    setState(() {
      _screen = page;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : _screen!;
  }
}
