import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/month_data.dart';
import '../models/expense_item.dart';
import 'firestore_service.dart';
import 'cycle_calculator.dart';

class AppState extends ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();

  int monthStartDay = 1;
  bool setupDone = false;
  MonthData? currentMonth;
  bool loading = true;

  String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('No signed-in user');
    return uid;
  }

  CycleCalculator get _calculator => CycleCalculator(monthStartDay);

  Future<void> loadForCurrentUser() async {
    loading = true;
    notifyListeners();

    final settings = await _firestore.getUserSettings(_uid);
    if (settings != null && settings['setupDone'] == true) {
      monthStartDay = settings['monthStartDay'] as int? ?? 1;
      setupDone = true;
      await _loadOrCreateCurrentMonth(salary: null, savingGoal: null);
    } else {
      setupDone = false;
    }

    loading = false;
    notifyListeners();
  }

  Future<void> completeSetup({
    required int startDay,
    required double salary,
    required double savingGoal,
  }) async {
    monthStartDay = startDay;
    await _firestore.saveUserSettings(_uid, monthStartDay: startDay);
    await _loadOrCreateCurrentMonth(salary: salary, savingGoal: savingGoal);
    setupDone = true;
    notifyListeners();
  }

  Future<void> _loadOrCreateCurrentMonth({
    double? salary,
    double? savingGoal,
  }) async {
    final now = DateTime.now();
    final id = _calculator.idFor(now);
    final periodStart = _calculator.cycleStartFor(now);

    var month = await _firestore.getMonth(_uid, id);
    if (month == null) {
      // Carry over previous salary/saving goal as defaults if not provided.
      double defaultSalary = salary ?? 0;
      double defaultSaving = savingGoal ?? 0;
      if (salary == null) {
        final prevMonths = await _firestore.getAllMonths(_uid);
        if (prevMonths.isNotEmpty) {
          defaultSalary = prevMonths.first.salary;
          defaultSaving = prevMonths.first.savingGoal;
        }
      }
      month = MonthData(
        id: id,
        periodStart: periodStart,
        salary: defaultSalary,
        savingGoal: defaultSaving,
      );
      await _firestore.upsertMonth(_uid, month);
    } else if (salary != null || savingGoal != null) {
      month = month.copyWith(salary: salary, savingGoal: savingGoal);
      await _firestore.upsertMonth(_uid, month);
    }

    currentMonth = month;
    notifyListeners();
  }

  Future<void> updateSalaryAndSaving({double? salary, double? savingGoal}) async {
    if (currentMonth == null) return;
    currentMonth = currentMonth!.copyWith(salary: salary, savingGoal: savingGoal);
    await _firestore.upsertMonth(_uid, currentMonth!);
    notifyListeners();
  }

  Future<void> addExpenseItem(String title, double amount) async {
    if (currentMonth == null) return;
    final item = ExpenseItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      amount: amount,
      date: DateTime.now(),
    );
    await _firestore.addItem(_uid, currentMonth!.id, item);
    currentMonth!.items.add(item);
    notifyListeners();
  }

  Future<void> removeExpenseItem(ExpenseItem item) async {
    if (currentMonth == null) return;
    await _firestore.removeItem(_uid, currentMonth!.id, item);
    currentMonth!.items.removeWhere((e) => e.id == item.id);
    notifyListeners();
  }

  Stream<List<MonthData>> watchHistory() => _firestore.watchAllMonths(_uid);

  Future<void> updateMonthStartDay(int newStartDay) async {
    monthStartDay = newStartDay;
    await _firestore.saveUserSettings(_uid, monthStartDay: newStartDay);
    await _loadOrCreateCurrentMonth();
    notifyListeners();
  }

  void reset() {
    monthStartDay = 1;
    setupDone = false;
    currentMonth = null;
    loading = true;
  }
}
