import 'package:fl_chart/fl_chart.dart';
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
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final maxAmount = entries
                    .map((entry) => entry.total)
                    .reduce((a, b) => a > b ? a : b);
                final chartMax = maxAmount * 1.28;
                final groupWidth =
                    (constraints.maxWidth - 48) / entries.length;
                final barWidth =
                    (groupWidth * 0.48).clamp(8.0, 24.0).toDouble();
                return SizedBox(
                  width: constraints.maxWidth,
                  height: 246,
                  child: BarChart(
                    BarChartData(
                      minY: 0,
                      maxY: chartMax,
                      alignment: BarChartAlignment.spaceAround,
                      groupsSpace: 4,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: chartMax / 4,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: AppColors.divider.withOpacity(0.7),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(
                        handleBuiltInTouches: false,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => AppColors.primary,
                          tooltipRoundedRadius: 10,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                              BarTooltipItem(
                            _axisCurrency.format(rod.toY),
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 48,
                            interval: chartMax / 4,
                            getTitlesWidget: (value, meta) {
                              if (value <= 0 || value > maxAmount) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text(
                                  _axisCurrency.format(value),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: AppColors.textSecondary,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= entries.length) {
                                return const SizedBox.shrink();
                              }
                              final name = entries[index].name;
                              return SizedBox(
                                width: groupWidth,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    name,
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      height: 1.1,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: entries.asMap().entries.map((entry) {
                        final index = entry.key;
                        final category = entry.value;
                        return BarChartGroupData(
                          x: index,
                          showingTooltipIndicators: const [0],
                          barRods: [
                            BarChartRodData(
                              toY: category.total,
                              width: barWidth,
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  category.color.withOpacity(0.72),
                                  category.color,
                                ],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
