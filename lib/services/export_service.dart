import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/month_data.dart';

class ExportService {
  Future<File> buildCsv(MonthData month) async {
    final dateFmt = DateFormat('yyyy-MM-dd');
    final rows = <List<dynamic>>[
      ['Salary Tracker Export'],
      ['Period start', dateFmt.format(month.periodStart)],
      ['Salary', month.salary],
      ['Saving goal', month.savingGoal],
      ['Allowed to spend', month.allowedToSpend],
      ['Total spent', month.totalSpent],
      ['Remaining', month.remaining],
      ['Spent percentage', '${month.spentPercentage.toStringAsFixed(1)}%'],
      [],
      ['Item', 'Amount', 'Date'],
      ...month.items.map((e) => [e.title, e.amount, dateFmt.format(e.date)]),
    ];

    final csvData = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/salary_export_${month.id}.csv');
    await file.writeAsString(csvData);
    return file;
  }

  Future<void> shareMonth(MonthData month) async {
    final file = await buildCsv(month);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Salary export for period starting ${month.id}',
    );
  }
}
