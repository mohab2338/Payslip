import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../models/month_data.dart';
import 'csv_delivery/csv_delivery.dart';

class ExportService {
  String buildCsvString(MonthData month) {
    final dateFmt = DateFormat('yyyy-MM-dd');
    final rows = <List<dynamic>>[
      ['Our Life Export'],
      ['Period start', dateFmt.format(month.periodStart)],
      ['Base salary', month.salary],
      ['Extra income', month.totalExtraIncome],
      ['Total cycle salary', month.totalCycleSalary],
      ['Saving goal', month.savingGoal],
      ['Allowed to spend', month.allowedToSpend],
      ['Total spent', month.totalSpent],
      ['Remaining', month.remaining],
      ['Spent percentage', '${month.spentPercentage.toStringAsFixed(1)}%'],
      [],
      ['Item', 'Amount', 'Date'],
      ...month.items.map((e) => [e.title, e.amount, dateFmt.format(e.date)]),
      [],
      ['Extra income', 'Amount', 'Date', 'Description'],
      ...month.extraIncomes.map((income) => [
            'Extra income',
            income.amount,
            dateFmt.format(income.date),
            income.description,
          ]),
    ];
    return const ListToCsvConverter().convert(rows);
  }

  /// On mobile (Android/iOS) this opens the native share sheet with the CSV
  /// file. On web (no filesystem, no share sheet) it triggers a normal
  /// browser file download instead. Same CSV content either way.
  Future<void> shareMonth(MonthData month) async {
    final csvData = buildCsvString(month);
    await deliverCsv(
      csvData,
      'salary_export_${month.id}.csv',
      'Salary export for period starting ${month.id}',
    );
  }
}
