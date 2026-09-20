import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/month_data.dart';
import '../services/export_service.dart';
import '../theme.dart';
import '../widgets/spend_ring.dart';
import '../widgets/stat_card.dart';

class MonthDetailScreen extends StatefulWidget {
  final MonthData month;
  const MonthDetailScreen({super.key, required this.month});

  @override
  State<MonthDetailScreen> createState() => _MonthDetailScreenState();
}

class _MonthDetailScreenState extends State<MonthDetailScreen> {
  static final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final _exportService = ExportService();
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await _exportService.shareMonth(widget.month);
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

  @override
  Widget build(BuildContext context) {
    final month = widget.month;
    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat.yMMMd().format(month.periodStart)),
        actions: [
          IconButton(
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
            tooltip: 'Export this month',
            onPressed: _exporting ? null : _export,
          ),
        ],
      ),
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
                  SpendRing(percentage: month.spentPercentage, size: 84, onDark: true),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Allowed to spend',
                          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _currency.format(month.allowedToSpend),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'total spent',
                          style: TextStyle(color: AppColors.primaryLight, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
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
                    label: 'Saved',
                    value: _currency.format(month.savingGoal),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            StatCard(
              label: 'Total spent',
              value: _currency.format(month.totalSpent),
              row: true,
            ),
            const SizedBox(height: 24),
            const Text('Purchases', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            if (month.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No purchases recorded.')),
              )
            else
              ...month.items.map((item) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat.yMMMd().add_jm().format(item.date),
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Text(_currency.format(item.amount),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
