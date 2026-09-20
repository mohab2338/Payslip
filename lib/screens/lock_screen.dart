import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../theme.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _bioService = BiometricService();
  final _authService = AuthService();
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    setState(() => _authenticating = true);
    final ok = await _bioService.authenticate(reason: 'Unlock Salary Tracker');
    setState(() => _authenticating = false);
    if (ok) widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(Icons.fingerprint, color: AppColors.primary, size: 44),
              ),
              const SizedBox(height: 24),
              const Text('Salary Tracker is locked',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('Use your fingerprint to continue',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _authenticating ? null : _authenticate,
                icon: const Icon(Icons.fingerprint),
                label: Text(_authenticating ? 'Verifying...' : 'Try again'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  await _authService.signOut();
                },
                child: const Text('Sign out instead'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
