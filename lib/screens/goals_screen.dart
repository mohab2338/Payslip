import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/saving_goal.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/confirm_dialog.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  static final _currency = NumberFormat.currency(symbol: 'E£', decimalDigits: 2);

  Future<void> _editGoal(BuildContext context, SavingGoal? goal) async {
    final nameController = TextEditingController(text: goal?.name ?? '');
    final targetController = TextEditingController(
      text: goal?.targetAmount.toStringAsFixed(2) ?? '',
    );
    final cycleController = TextEditingController(
      text: goal?.contributionPerCycle.toStringAsFixed(2) ?? '',
    );
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<(String, double, double)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(goal == null ? 'Add a goal' : 'Edit goal'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Goal name',
                    hintText: 'e.g. New laptop',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Enter a name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: targetController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Total cost',
                    prefixText: 'E£ ',
                  ),
                  validator: (value) => _validatePositiveAmount(value, 'Enter a valid total cost'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: cycleController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Planned amount per saving cycle',
                    prefixText: 'E£ ',
                  ),
                  validator: (value) =>
                      _validatePositiveAmount(value, 'Enter a valid cycle contribution'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(
                  dialogContext,
                  (
                    nameController.text.trim(),
                    double.parse(targetController.text.trim()),
                    double.parse(cycleController.text.trim()),
                  ),
                );
              }
            },
            child: Text(goal == null ? 'Create goal' : 'Save changes'),
          ),
        ],
      ),
    );

    nameController.dispose();
    targetController.dispose();
    cycleController.dispose();
    if (result == null || !context.mounted) return;

    final savedAmount = goal == null
        ? 0.0
        : (goal.savedAmount > result.$2 ? result.$2 : goal.savedAmount);
    final savedGoal = goal == null
        ? SavingGoal(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: result.$1,
            targetAmount: result.$2,
            contributionPerCycle: result.$3,
            savedAmount: 0,
            createdAt: DateTime.now(),
          )
        : goal.copyWith(
            name: result.$1,
            targetAmount: result.$2,
            contributionPerCycle: result.$3,
            savedAmount: savedAmount,
          );
    await context.read<AppState>().saveSavingGoal(savedGoal);
  }

  Future<void> _addMoney(BuildContext context, SavingGoal goal) async {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Add money to ${goal.name}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: amountController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount', prefixText: 'E£ '),
            validator: (value) => _validatePositiveAmount(value, 'Enter a valid amount'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, double.parse(amountController.text.trim()));
              }
            },
            child: const Text('Add money'),
          ),
        ],
      ),
    );
    amountController.dispose();
    if (amount == null || !context.mounted) return;

    final credited = await context.read<AppState>().addManualGoalContribution(goal.id, amount);
    if (context.mounted && credited < amount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${_currency.format(credited)}; this goal is now fully funded.')),
      );
    }
  }

  Future<void> _takeMoney(BuildContext context, SavingGoal goal) async {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Take money from ${goal.name}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Available: ${_currency.format(goal.savedAmount)}'),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount', prefixText: 'E£ '),
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  if (parsed == null || parsed <= 0) return 'Enter a valid amount';
                  if (parsed > goal.savedAmount) return 'Cannot take more than is saved for this goal';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, double.parse(amountController.text.trim()));
              }
            },
            child: const Text('Take money'),
          ),
        ],
      ),
    );
    amountController.dispose();
    if (amount == null || !context.mounted) return;

    final withdrawn = await context.read<AppState>().withdrawFromGoal(goal.id, amount);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_currency.format(withdrawn)} taken from ${goal.name}.')),
      );
    }
  }

  Future<void> _deleteGoal(BuildContext context, SavingGoal goal) async {
    if (await confirmDelete(context, itemLabel: goal.name) && context.mounted) {
      await context.read<AppState>().removeSavingGoal(goal.id);
    }
  }

  static String? _validatePositiveAmount(String? value, String message) {
    final amount = double.tryParse(value?.trim() ?? '');
    return amount == null || amount <= 0 ? message : null;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Our goals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editGoal(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Add goal'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<SavingGoal>>(
          stream: state.watchSavingGoals(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Could not load goals. Please try again.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final goals = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: AppColors.accent),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'At the end of a saving cycle, a goal only gets its planned contribution if that full amount was actually saved. You can add or take money manually anytime. Taking money lowers the overall saved total only; source totals stay unchanged.',
                          style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (goals.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48, horizontal: 12),
                    child: Column(
                      children: [
                        Icon(Icons.flag_outlined, size: 42, color: AppColors.textSecondary),
                        SizedBox(height: 12),
                        Text(
                          'No goals yet. Add something you are saving for.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                else
                  ...goals.map((goal) => _GoalCard(
                        goal: goal,
                        onAddMoney: () => _addMoney(context, goal),
                    onTakeMoney: () => _takeMoney(context, goal),
                        onEdit: () => _editGoal(context, goal),
                        onDelete: () => _deleteGoal(context, goal),
                      )),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.onAddMoney,
    required this.onTakeMoney,
    required this.onEdit,
    required this.onDelete,
  });

  static final _currency = NumberFormat.currency(symbol: 'E£', decimalDigits: 2);
  final SavingGoal goal;
  final VoidCallback onAddMoney;
  final VoidCallback onTakeMoney;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final complete = goal.savedAmount >= goal.targetAmount;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(goal.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              if (complete)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.check_circle, color: AppColors.accent, size: 21),
                ),
              IconButton(tooltip: 'Edit goal', onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 20)),
              IconButton(
                tooltip: 'Delete goal',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 8,
              backgroundColor: AppColors.background,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_currency.format(goal.savedAmount)} of ${_currency.format(goal.targetAmount)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text('${(goal.progress * 100).round()}%',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            complete
                ? 'Goal reached'
                : '${_currency.format(goal.contributionPerCycle)} planned each cycle · ${_currency.format(goal.remainingAmount)} to go',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (!complete || goal.savedAmount > 0) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!complete)
                  OutlinedButton.icon(
                    onPressed: onAddMoney,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add money now'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (goal.savedAmount > 0)
                  OutlinedButton.icon(
                    onPressed: onTakeMoney,
                    icon: const Icon(Icons.south_west, size: 18),
                    label: const Text('Take money'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
