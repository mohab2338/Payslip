import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _authService = AuthService();
  final _bioService = BiometricService();

  bool _isSignUp = false;
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    _prefillAndCheckBiometrics();
  }

  Future<void> _prefillAndCheckBiometrics() async {
    final lastEmail = await _bioService.getLastEmail();
    final bioEnabled = await _bioService.isBiometricEnabled();
    final supported = await _bioService.isDeviceSupported();
    if (lastEmail != null) _emailCtrl.text = lastEmail;
    setState(() => _bioAvailable = supported && bioEnabled && lastEmail != null);
    if (_bioAvailable) {
      // Offer biometric unlock immediately.
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometricLogin());
    }
  }

  Future<void> _tryBiometricLogin() async {
    // Biometric unlock only works because Firebase Auth already persists the
    // session on-device; fingerprint just re-confirms it's the same person.
    if (_authService.currentUser == null) return;
    final ok = await _bioService.authenticate(reason: 'Unlock Salary Tracker');
    if (ok && mounted) {
      // AuthGate listens to authStateChanges and will navigate automatically.
      setState(() {});
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isSignUp) {
        await _authService.signUp(email: _emailCtrl.text, password: _passCtrl.text);
      } else {
        await _authService.signIn(email: _emailCtrl.text, password: _passCtrl.text);
      }
      await _bioService.saveLastEmail(_emailCtrl.text.trim());

      if (_isSignUp) {
        final supported = await _bioService.isDeviceSupported();
        if (supported && mounted) {
          final enable = await _askEnableBiometrics();
          await _bioService.setBiometricEnabled(enable);
        }
      }
    } catch (e) {
      setState(() => _error = _authService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _askEnableBiometrics() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Enable fingerprint login?'),
        content: const Text('Use your fingerprint or face to unlock the app next time instead of typing your password.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enable')),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 32),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isSignUp ? 'Create your account' : 'Welcome back',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Track your salary, savings and spending.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'At least 6 characters' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isSignUp ? 'Sign up' : 'Log in'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() {
                        _isSignUp = !_isSignUp;
                        _error = null;
                      }),
                      child: Text(_isSignUp
                          ? 'Already have an account? Log in'
                          : "Don't have an account? Sign up"),
                    ),
                  ),
                  if (!_isSignUp && _bioAvailable)
                    Center(
                      child: TextButton.icon(
                        onPressed: _tryBiometricLogin,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Use fingerprint'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
