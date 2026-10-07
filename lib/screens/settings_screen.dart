import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  final _bioService = BiometricService();
  bool _bioEnabled = false;
  bool _bioSupported = false;

  late TextEditingController _salaryCtrl;
  late TextEditingController _savingCtrl;
  late int _startDay;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final month = state.currentMonth;
    _salaryCtrl = TextEditingController(text: month?.salary.toStringAsFixed(2) ?? '0');
    _savingCtrl = TextEditingController(text: month?.savingGoal.toStringAsFixed(2) ?? '0');
    _startDay = state.monthStartDay;
    _loadBio();
  }

  Future<void> _loadBio() async {
    final supported = await _bioService.isDeviceSupported();
    final enabled = await _bioService.isBiometricEnabled();
    setState(() {
      _bioSupported = supported;
      _bioEnabled = enabled;
    });
  }

  Future<void> _saveSalaryAndSaving() async {
    final salary = double.tryParse(_salaryCtrl.text);
    final saving = double.tryParse(_savingCtrl.text);
    if (salary == null || saving == null) return;
    await context.read<AppState>().updateSalaryAndSaving(salary: salary, savingGoal: saving);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Updated for this cycle')),
      );
    }
  }

  Future<void> _saveStartDay(int day) async {
    setState(() => _startDay = day);
    await context.read<AppState>().updateMonthStartDay(day);
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? errorMessage;
    var saving = false;

    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Change password'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Current password'),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Enter your current password'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'New password'),
                    validator: (value) => value == null || value.length < 6
                        ? 'Use at least 6 characters'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirm new password'),
                    validator: (value) => value != newController.text
                        ? 'Passwords do not match'
                        : null,
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(errorMessage!, style: const TextStyle(color: AppColors.danger)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        saving = true;
                        errorMessage = null;
                      });
                      try {
                        await _authService.changePassword(
                          currentPassword: currentController.text,
                          newPassword: newController.text,
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                      } catch (error) {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            errorMessage = _authService.passwordChangeError(error);
                            saving = false;
                          });
                        }
                      }
                    },
              child: Text(saving ? 'Updating…' : 'Update password'),
            ),
          ],
        ),
      ),
    );

    currentController.dispose();
    newController.dispose();
    confirmController.dispose();
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('This cycle', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: _salaryCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Salary', prefixText: 'E£ '),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _savingCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Saving goal', prefixIcon: Icon(Icons.flag_outlined)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _saveSalaryAndSaving, child: const Text('Save changes')),
            ),
            const SizedBox(height: 28),
            const Text('Month start day', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 6),
            const Text(
              'Changing this affects which cycle new purchases fall into going forward.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _startDay,
                  isExpanded: true,
                  items: List.generate(31, (i) => i + 1)
                      .map((d) => DropdownMenuItem(value: d, child: Text('Day $d')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) _saveStartDay(v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text('Security', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 6),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_reset_outlined),
              title: const Text('Change password'),
              subtitle: const Text('Verify your current password first'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _changePassword,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _bioEnabled,
              onChanged: _bioSupported
                  ? (v) async {
                      if (v) {
                        final ok = await _bioService.authenticate(reason: 'Confirm to enable fingerprint login');
                        if (!ok) return;
                      }
                      await _bioService.setBiometricEnabled(v);
                      setState(() => _bioEnabled = v);
                    }
                  : null,
              title: const Text('Fingerprint login'),
              subtitle: Text(_bioSupported
                  ? 'Use your fingerprint or face to unlock the app'
                  : 'Not supported on this device'),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _authService.signOut(),
                icon: const Icon(Icons.logout, color: AppColors.danger),
                label: const Text('Sign out', style: TextStyle(color: AppColors.danger)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
