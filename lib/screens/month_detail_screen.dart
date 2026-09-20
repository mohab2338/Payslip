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
          padding: const EdgeInsets.all(20),
          children: [
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
                  label: 'Total spent',
                  value: _currency.format(month.totalSpent),
                  icon: Icons.trending_down_outlined,
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text('Purchases', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (month.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No purchases recorded.')),
              )
            else
              ...month.items.map((item) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
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
                              Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                DateFormat.yMMMd().add_jm().format(item.date),
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Text(_currency.format(item.amount),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
