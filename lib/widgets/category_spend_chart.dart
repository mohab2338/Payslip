import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/month_data.dart';
import '../theme.dart';

class CategorySpendChart extends StatelessWidget {
  final MonthData month;
  final String title;

  const CategorySpendChart({
    super.key,
    required this.month,
    this.title = 'Spend by part',
  });

  static const _colors = [
    Color(0xFF7B1E3A),
    Color(0xFFB7791F),
    Color(0xFF0D6A48),
    Color(0xFF124FA3),
    Color(0xFF1E2A78),
    Color(0xFF9E1A4C),
    Color(0xFF5B39A6),
  ];

  static final _currency = NumberFormat.currency(symbol: 'E£', decimalDigits: 2);
  static final _axisCurrency =
      NumberFormat.compactCurrency(symbol: 'E£', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final categoriesById = {
      for (final category in month.categories) category.id: category,
    };
    final totals = <String?, double>{};
    for (final item in month.items) {
      final categoryId = categoriesById.containsKey(item.categoryId)
          ? item.categoryId
          : null;
      totals.update(
        categoryId,
        (total) => total + item.amount,
        ifAbsent: () => item.amount,
      );
    }

    final entries = <({String name, double total, Color color})>[];
    for (var index = 0; index < month.categories.length; index++) {
      final category = month.categories[index];
      final total = totals[category.id] ?? 0;
      if (total > 0) {
        entries.add((
          name: category.name,
          total: total,
          color: _colors[index % _colors.length],
        ));
      }
    }
    final uncategorized = totals[null] ?? 0;
    if (uncategorized > 0) {
      entries.add((
        name: 'Uncategorized',
        total: uncategorized,
        color: const Color(0xFF9AA0A6),
      ));
    }
    entries.sort((a, b) => b.total.compareTo(a.total));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider.withOpacity(0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            '${_currency.format(month.totalSpent)} total',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
          ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('No spending data for this cycle yet.')),
            )
          else ...[
            const SizedBox(height: 14),
            ..._buildAmountBars(entries),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildAmountBars(
    List<({String name, double total, Color color})> entries,
  ) {
    final maxAmount =
        entries.map((entry) => entry.total).reduce((a, b) => a > b ? a : b);
    return [
      for (final entry in entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 13),
          child: Row(
            children: [
              SizedBox(
                width: 68,
                child: Text(
                  entry.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SizedBox(
                    height: 22,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Positioned.fill(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(
                              5,
                              (_) => Container(
                                width: 1,
                                color: AppColors.divider.withOpacity(0.8),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: constraints.maxWidth * entry.total / maxAmount,
                          height: 14,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                entry.color.withOpacity(0.72),
                                entry.color,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(7),
                            boxShadow: [
                              BoxShadow(
                                color: entry.color.withOpacity(0.18),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 78,
                child: Text(
                  _currency.format(entry.total),
                  maxLines: 1,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(left: 76, right: 86),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            5,
            (index) => Text(
              _axisCurrency.format(maxAmount * index / 4),
              style: const TextStyle(
                fontSize: 8,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    ];
  }
}
