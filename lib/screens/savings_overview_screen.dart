import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/month_data.dart';
import '../models/external_saving.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/stat_card.dart';

class SavingsOverviewScreen extends StatelessWidget {
  const SavingsOverviewScreen({super.key});

  static final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  Future<void> _addExternalSaving(BuildContext context) async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Add external saving'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'What is it?',
                  hintText: 'e.g. Gold, cash kept at home...',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Value'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      await context.read<AppState>().addExternalSaving(
            titleCtrl.text.trim(),
            double.parse(amountCtrl.text),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Savings overview')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addExternalSaving(context),
        icon: const Icon(Icons.add),
        label: const Text('Add external saving'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<MonthData>>(
          stream: state.watchHistory(),
          builder: (context, monthsSnap) {
            if (!monthsSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final months = monthsSnap.data!;
            // Overspending in a cycle comes out of what would have been
            // saved, so each cycle's real contribution to savings is its
            // goal minus however much it went over the allowed spend —
            // not just the raw saving goal.
            double excessFor(MonthData m) =>
                m.totalSpent > m.allowedToSpend ? m.totalSpent - m.allowedToSpend : 0.0;
            double netSavedFor(MonthData m) => m.savingGoal - excessFor(m);
            final totalFromCycles = months.fold(0.0, (sum, m) => sum + netSavedFor(m));

            return StreamBuilder<List<ExternalSaving>>(
              stream: state.watchExternalSavings(),
              builder: (context, externalSnap) {
                final externalItems = externalSnap.data ?? [];
                final totalExternal =
                    externalItems.fold(0.0, (sum, e) => sum + e.amount);
                final grandTotal = totalFromCycles + totalExternal;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  children: [
                    // Hero: grand total saved, across everything.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total saved (all sources)',
                            style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currency.format(grandTotal),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'From salary cycles',
                              value: _currency.format(totalFromCycles),
                              fillColor: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              label: 'External savings',
                              value: _currency.format(totalExternal),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),
                    const Text('All cycles',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),

                    if (months.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('No cycles recorded yet.',
                            style: TextStyle(color: AppColors.textSecondary)),
                      )
                    else
                      ...months.map((m) {
                        final excess = excessFor(m);
                        final netSaved = netSavedFor(m);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat.yMMMd().format(m.periodStart),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _MiniStat(label: 'Saving goal', value: _currency.format(m.savingGoal)),
                                  ),
                                  Expanded(
                                    child: _MiniStat(label: 'Spent', value: _currency.format(m.totalSpent)),
                                  ),
                                  Expanded(
                                    child: _MiniStat(
                                      label: 'Over budget',
                                      value: excess > 0 ? _currency.format(excess) : '—',
                                      valueColor: excess > 0 ? AppColors.danger : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              if (excess > 0) ...[
                                const SizedBox(height: 10),
                                Container(height: 1, color: AppColors.divider),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Net saved this cycle',
                                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    Text(
                                      _currency.format(netSaved),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: netSaved < 0 ? AppColors.danger : AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      }),

                    const SizedBox(height: 28),
                    const Text('External savings',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    const Text(
                      'Money or valuables you keep track of outside this app — gold, cash at home, etc.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 10),

                    if (externalItems.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Nothing added yet. Use the button below to add one.',
                            style: TextStyle(color: AppColors.textSecondary)),
                      )
                    else
                      ...externalItems.map((item) => Dismissible(
                            key: ValueKey(item.id),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) => confirmDelete(context, itemLabel: item.title),
                            onDismissed: (_) => state.removeExternalSaving(item),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.delete_outline, color: AppColors.danger),
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.title,
                                            style: const TextStyle(
                                                fontSize: 14, fontWeight: FontWeight.w500)),
                                        const SizedBox(height: 2),
                                        Text(
                                          DateFormat.yMMMd().format(item.date),
                                          style: const TextStyle(
                                              fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _currency.format(item.amount),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          )),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _MiniStat({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
