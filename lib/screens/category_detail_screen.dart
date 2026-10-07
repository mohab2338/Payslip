import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense_item.dart';
import '../models/month_data.dart';
import '../models/spending_category.dart';
import '../theme.dart';
import '../widgets/stat_card.dart';

class CategoryDetailScreen extends StatelessWidget {
  const CategoryDetailScreen({super.key, required this.month, required this.category});

  final MonthData month;
  final SpendingCategory category;

  static final _currency = NumberFormat.currency(symbol: 'E£', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    final items = month.items.where((item) => item.categoryId == category.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final spent = items.fold(0.0, (sum, item) => sum + item.amount);
    final remaining = category.budgetAmount - spent;

    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: StatCard(label: 'Allowed', value: _currency.format(category.budgetAmount), fillColor: AppColors.accent)),
                  const SizedBox(width: 10),
                  Expanded(child: StatCard(label: 'Spent', value: _currency.format(spent))),
                ],
              ),
            ),
            const SizedBox(height: 10),
            StatCard(
              label: 'Left',
              value: _currency.format(remaining),
              valueColor: remaining < 0 ? AppColors.danger : AppColors.textPrimary,
              row: true,
            ),
            const SizedBox(height: 24),
            Text('Purchases (${items.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('No purchases in this category yet.', style: TextStyle(color: AppColors.textSecondary))),
              )
            else
              ...items.map((item) => _PurchaseRow(item: item)),
          ],
        ),
      ),
    );
  }
}

class _PurchaseRow extends StatelessWidget {
  const _PurchaseRow({required this.item});
  final ExpenseItem item;
  static final _currency = NumberFormat.currency(symbol: 'E£', decimalDigits: 2);

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(DateFormat.yMMMd().add_jm().format(item.date), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ]),
            ),
            Text(_currency.format(item.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
