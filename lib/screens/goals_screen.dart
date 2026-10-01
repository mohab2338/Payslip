import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/saving_goal.dart';
import '../services/app_state.dart';
import '../theme.dart';

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

    if (goal?.status == SavingGoalStatus.achieved) return;

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
    final isPending = goal.status == SavingGoalStatus.pending;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${goal.name}?'),
        content: Text(isPending
            ? 'The ${_currency.format(goal.savedAmount)} currently assigned to this pending goal will return to your general saved total.'
            : 'This goal is achieved. Its money will not be returned to your general saved total.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (shouldDelete == true && context.mounted) {
      await context.read<AppState>().removeSavingGoal(goal.id);
    }
  }

  Future<void> _markAchieved(BuildContext context, SavingGoal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark goal as achieved?'),
        content: Text(
          'The ${_currency.format(goal.savedAmount)} assigned to this goal will be considered spent and will not return to your general saved total. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Mark achieved'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AppState>().markSavingGoalAchieved(goal.id);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.celebration_outlined, color: AppColors.accent, size: 42),
          title: const Text('مبروك!'),
          content: const Text(
            'نفعكم الله بها و بارك لكم في بيتكم ❤️',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, height: 1.7),
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('آمين'),
              ),
            ),
          ],
        ),
      );
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
            final pending = goals
                .where((goal) => goal.status == SavingGoalStatus.pending)
                .toList();
            final achieved = goals
                .where((goal) => goal.status == SavingGoalStatus.achieved)
                .toList();

            return DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                    child: Container(
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
                              'Pending goals can be funded or withdrawn from. Mark a goal achieved when its money is spent; it will not return to your saved total. Deleting a pending goal returns its remaining balance to the total.',
                              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TabBar(
                    tabs: [
                      Tab(text: 'Pending (${pending.length})'),
                      Tab(text: 'Achieved (${achieved.length})'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildGoalList(context, pending, emptyMessage: 'No pending goals.'),
                        _buildGoalList(context, achieved, emptyMessage: 'No achieved goals yet.'),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGoalList(
    BuildContext context,
    List<SavingGoal> goals, {
    required String emptyMessage,
  }) {
    if (goals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      itemCount: goals.length,
      itemBuilder: (context, index) {
        final goal = goals[index];
        return _GoalCard(
          goal: goal,
          onAddMoney: () => _addMoney(context, goal),
          onTakeMoney: () => _takeMoney(context, goal),
          onEdit: () => _editGoal(context, goal),
          onDelete: () => _deleteGoal(context, goal),
          onMarkAchieved: () => _markAchieved(context, goal),
        );
      },
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
    required this.onMarkAchieved,
  });

  static final _currency = NumberFormat.currency(symbol: 'E£', decimalDigits: 2);
  final SavingGoal goal;
  final VoidCallback onAddMoney;
  final VoidCallback onTakeMoney;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMarkAchieved;

  @override
  Widget build(BuildContext context) {
    final complete = goal.savedAmount >= goal.targetAmount;
    final isPending = goal.status == SavingGoalStatus.pending;
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
              if (goal.status == SavingGoalStatus.achieved)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.check_circle, color: AppColors.accent, size: 21),
                ),
              if (isPending)
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
            goal.status == SavingGoalStatus.achieved
              ? 'Achieved · funds will not return to general savings'
              : '${_currency.format(goal.contributionPerCycle)} planned each cycle · ${_currency.format(goal.remainingAmount)} to go',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (isPending) ...[
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
                OutlinedButton.icon(
                  onPressed: onMarkAchieved,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Mark achieved'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
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
