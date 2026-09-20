import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/spend_ring.dart';
import '../widgets/stat_card.dart';
import 'add_item_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final month = state.currentMonth;

    if (month == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salary Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddItemScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add purchase'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => state.loadForCurrentUser(),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Cycle starting ${DateFormat.yMMMd().format(month.periodStart)}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Center(child: SpendRing(percentage: month.spentPercentage)),
              const SizedBox(height: 24),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.25,
                children: [
                  StatCard(
                    label: 'Salary',
                    value: _currency.format(month.salary),
                    icon: Icons.payments_outlined,
                  ),
                  StatCard(
                    label: 'Saving goal',
                    value: _currency.format(month.savingGoal),
                    icon: Icons.flag_outlined,
                  ),
                  StatCard(
                    label: 'Allowed to spend',
                    value: _currency.format(month.allowedToSpend),
                    icon: Icons.wallet_outlined,
                  ),
                  StatCard(
                    label: 'Remaining',
                    value: _currency.format(month.remaining),
                    valueColor: month.remaining < 0 ? AppColors.danger : AppColors.accent,
                    icon: Icons.trending_down_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  const Text('Purchases this cycle',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    _currency.format(month.totalSpent),
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (month.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No purchases yet. Tap "Add purchase" to log one.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              else
                ...month.items.reversed.map((item) => Dismissible(
                      key: ValueKey(item.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => state.removeExpenseItem(item),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete_outline, color: AppColors.danger),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.shopping_bag_outlined,
                                  color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title,
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(
                                    DateFormat.yMMMd().add_jm().format(item.date),
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _currency.format(item.amount),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    )),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
