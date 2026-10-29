import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/expense_item.dart';
import '../models/month_data.dart';
import '../services/app_state.dart';
import '../services/export_service.dart';
import '../theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/category_spend_chart.dart';
import '../widgets/spend_ring.dart';
import '../widgets/stat_card.dart';
import 'add_item_screen.dart';

class _CategorySpend {
  final String? categoryId;
  final String name;
  final double total;
  final Color color;

  const _CategorySpend({
    required this.categoryId,
    required this.name,
    required this.total,
    required this.color,
  });
}

class MonthDetailScreen extends StatefulWidget {
  final MonthData month;
  const MonthDetailScreen({super.key, required this.month});

  @override
  State<MonthDetailScreen> createState() => _MonthDetailScreenState();
}

class _MonthDetailScreenState extends State<MonthDetailScreen> {
  static final _currency = NumberFormat.currency(symbol: 'E£', decimalDigits: 2);
  static const List<Color> _chartColors = [
    Color(0xFF7B1E3A),
    Color(0xFFB7791F),
    Color(0xFF0D6A48),
    Color(0xFF124FA3),
    Color(0xFF1E2A78),
    Color(0xFF9E1A4C),
    Color(0xFF5B39A6),
  ];

  final _exportService = ExportService();
  bool _exporting = false;
  bool _editing = false;

  Future<void> _export(MonthData month) async {
    setState(() => _exporting = true);
    try {
      await _exportService.shareMonth(month);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _deleteItem(MonthData month, ExpenseItem item) async {
    if (await confirmDelete(context, itemLabel: item.title)) {
      await context.read<AppState>().removeExpenseItemFromMonth(month.id, item);
    }
  }

  List<_CategorySpend> _buildCategoryBreakdown(MonthData month) {
    final categoriesById = {
      for (final category in month.categories) category.id: category,
    };
    final totalsByCategory = <String?, double>{};
    for (final item in month.items) {
      final categoryId = categoriesById.containsKey(item.categoryId)
          ? item.categoryId
          : null;
      totalsByCategory.update(
        categoryId,
        (total) => total + item.amount,
        ifAbsent: () => item.amount,
      );
    }

    final categoryEntries = <_CategorySpend>[];
    for (int i = 0; i < month.categories.length; i++) {
      final category = month.categories[i];
      final total = totalsByCategory[category.id] ?? 0;
      if (total > 0) {
        categoryEntries.add(_CategorySpend(
          categoryId: category.id,
          name: category.name,
          total: total,
          color: _chartColors[i % _chartColors.length],
        ));
      }
    }

    final uncategorizedTotal = totalsByCategory[null] ?? 0;
    if (uncategorizedTotal > 0) {
      categoryEntries.add(_CategorySpend(
        categoryId: null,
        name: 'Uncategorized',
        total: uncategorizedTotal,
        color: const Color(0xFF9AA0A6),
      ));
    }

    categoryEntries.sort((a, b) => b.total.compareTo(a.total));
    return categoryEntries;
  }

  Widget _buildSpendingCharts(MonthData month) {
    final breakdown = _buildCategoryBreakdown(month);
    final pieSections = breakdown.map((bucket) {
      final pct = (bucket.total / month.totalSpent) * 100;
      return PieChartSectionData(
        color: bucket.color,
        value: bucket.total,
        title: pct >= 8 ? '${pct.round()}%' : '',
        radius: 64,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spending by part',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 34,
                      sections: pieSections,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: breakdown.map((bucket) {
                    final pct = (bucket.total / month.totalSpent) * 100;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: bucket.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${bucket.name} (${pct.toStringAsFixed(0)}%)',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MonthData?>(
      stream: context.read<AppState>().watchMonth(widget.month.id),
      builder: (context, snapshot) {
        final month = snapshot.data ?? widget.month;
        final itemsByDay = <DateTime, List<ExpenseItem>>{};
        for (final item in month.items) {
          final day = DateUtils.dateOnly(item.date);
          itemsByDay.putIfAbsent(day, () => []).add(item);
        }
        final purchaseDays = itemsByDay.keys.toList()
          ..sort((a, b) => b.compareTo(a));
        return Scaffold(
          appBar: AppBar(
            title: Text(DateFormat.yMMMd().format(month.periodStart)),
            actions: [
              IconButton(
                icon: Icon(_editing ? Icons.done : Icons.edit_note_outlined),
                tooltip: _editing ? 'Finish editing' : 'Edit purchases',
                onPressed: () => setState(() => _editing = !_editing),
              ),
              IconButton(
                icon: _exporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share),
                tooltip: 'Export this month',
                onPressed: _exporting ? null : () => _export(month),
              ),
            ],
          ),
          floatingActionButton: _editing
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddItemScreen(month: month),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add purchase'),
                )
              : null,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      SpendRing(
                        percentage: month.spentPercentage,
                        size: 84,
                        onDark: true,
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Allowed to spend',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currency.format(month.allowedToSpend),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_currency.format(month.totalSpent)} total spent',
                              style: TextStyle(
                                color: AppColors.primaryLight,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
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
                          label: 'Salary',
                          value: _currency.format(month.salary),
                          fillColor: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: 'Saving goal',
                          value: _currency.format(month.savingGoal),
                          fillColor: AppColors.accentLight,
                          labelColor: AppColors.accent,
                          valueColor: AppColors.accent,
                        ),
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
                          label: 'Actual saved',
                          value: _currency.format(month.actualSaved),
                          fillColor: month.actualSaved < 0
                              ? AppColors.danger
                              : AppColors.accent,
                          labelColor: Colors.white.withOpacity(0.8),
                          valueColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: 'Total spent',
                          value: _currency.format(month.totalSpent),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _buildSpendingCharts(month),
                const SizedBox(height: 10),
                CategorySpendChart(
                  month: month,
                  title: 'Cycle spend by part',
                ),
                const SizedBox(height: 24),
                const Text(
                  'Purchases',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                if (month.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No purchases recorded.')),
                  )
                else
                  ...purchaseDays.expand((day) {
                    final dayItems = itemsByDay[day]!
                      ..sort((a, b) => b.date.compareTo(a.date));
                    final dayTotal =
                        dayItems.fold<double>(0, (total, item) => total + item.amount);
                    return [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                DateFormat.yMMMMEEEEd().format(day),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              _currency.format(dayTotal),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...dayItems.map((item) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat.yMMMd()
                                            .add_jm()
                                            .format(item.date),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      if (item.note.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          item.note,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Text(
                                  _currency.format(item.amount),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (_editing) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'Edit purchase',
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 19),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AddItemScreen(
                                          month: month,
                                          item: item,
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete purchase',
                                    icon: const Icon(Icons.delete_outline,
                                        size: 19),
                                    onPressed: () => _deleteItem(month, item),
                                  ),
                                ],
                              ],
                            ),
                          )),
                    ];
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}
