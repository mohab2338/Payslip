import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'theme.dart';
import 'services/app_state.dart';
import 'services/biometric_service.dart';
import 'screens/auth_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SalaryTrackerApp());
}

class SalaryTrackerApp extends StatelessWidget {
  const SalaryTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'Salary Tracker',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const AuthGate(),
      ),
    );
  }
}

/// Routes between: signed-out -> AuthScreen, signed-in-but-locked ->
/// LockScreen (fingerprint), signed-in-and-unlocked -> Setup or Home.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _bioService = BiometricService();
  bool _unlockedThisSession = false;
  String? _lastUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snapshot.data;
        if (user == null) {
          _unlockedThisSession = false;
          _lastUid = null;
          return const AuthScreen();
        }

        // Reset unlock flag when a different user signs in.
        if (_lastUid != user.uid) {
          _lastUid = user.uid;
          _unlockedThisSession = false;
        }

        return FutureBuilder<bool>(
          future: _bioService.isBiometricEnabled(),
          builder: (context, bioSnap) {
            if (!bioSnap.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final bioRequired = bioSnap.data!;
            if (bioRequired && !_unlockedThisSession) {
              return LockScreen(
                onUnlocked: () => setState(() => _unlockedThisSession = true),
              );
            }
            return const _AppBody();
          },
        );
      },
    );
  }
}

class _AppBody extends StatefulWidget {
  const _AppBody();

  @override
  State<_AppBody> createState() => _AppBodyState();
}

class _AppBodyState extends State<_AppBody> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    context.read<AppState>().loadForCurrentUser().then((_) {
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final state = context.watch<AppState>();
    if (!state.setupDone) return const SetupScreen();
    return const HomeScreen();
  }
}
