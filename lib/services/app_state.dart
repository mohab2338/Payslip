import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/month_data.dart';
import '../models/expense_item.dart';
import '../models/external_saving.dart';
import '../models/note_item.dart';
import '../models/saving_goal.dart';
import '../models/spending_category.dart';
import '../models/purchase_group.dart';
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

    await _applyCompletedCycleContributions(periodStart);

    var month = await _firestore.getMonth(_uid, id);
    if (month == null) {
      // Carry over previous salary/saving goal as defaults if not provided.
      double defaultSalary = salary ?? 0;
      double defaultSaving = savingGoal ?? 0;
      var defaultCategories = <SpendingCategory>[];
      if (salary == null) {
        final prevMonths = await _firestore.getAllMonths(_uid);
        if (prevMonths.isNotEmpty) {
          defaultSalary = prevMonths.first.salary;
          defaultSaving = prevMonths.first.savingGoal;
          defaultCategories = prevMonths.first.categories;
        }
      }
      month = MonthData(
        id: id,
        periodStart: periodStart,
        salary: defaultSalary,
        savingGoal: defaultSaving,
        categories: defaultCategories,
      );
      await _firestore.upsertMonth(_uid, month);
    } else if (salary != null || savingGoal != null) {
      month = month.copyWith(salary: salary, savingGoal: savingGoal);
      await _firestore.upsertMonth(_uid, month);
    }

    currentMonth = month;
    notifyListeners();
  }

  Future<void> _applyCompletedCycleContributions(DateTime currentPeriodStart) async {
    final months = await _firestore.getAllMonths(_uid);
    final goals = await _firestore.getAllGoals(_uid);
    if (goals.isEmpty) return;

    // Oldest first, so skipped cycles are reconciled in their actual order.
    for (final month in months.reversed) {
      final cycleEnd = _calculator.nextCycleStart(month.periodStart);
      if (cycleEnd.isAfter(currentPeriodStart)) continue;

      final overspend = (month.totalSpent - month.allowedToSpend).clamp(0, double.infinity);
      var availableSavings = (month.savingGoal - overspend).clamp(0, double.infinity).toDouble();

      for (final goal in goals) {
        if (goal.createdAt.isAfter(cycleEnd) || goal.processedCycleIds.contains(month.id)) continue;

        final credited = await _firestore.applyCycleGoalContribution(
          _uid,
          goal.id,
          month.id,
          availableSavings,
        );
        availableSavings = (availableSavings - credited).clamp(0, double.infinity).toDouble();
      }
    }
  }

  Future<void> updateSalaryAndSaving({double? salary, double? savingGoal}) async {
    if (currentMonth == null) return;
    currentMonth = currentMonth!.copyWith(salary: salary, savingGoal: savingGoal);
    await _firestore.upsertMonth(_uid, currentMonth!);
    notifyListeners();
  }

  Future<void> addExpenseItem(
    String title,
    double amount, {
    String note = '',
    String? categoryId,
  }) async {
    if (currentMonth == null) return;
    final item = ExpenseItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      amount: amount,
      date: DateTime.now(),
      note: note,
      categoryId: categoryId,
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

  Future<void> updateExpenseItem(ExpenseItem item) async {
    if (currentMonth == null) return;
    await _firestore.updateItem(_uid, currentMonth!.id, item);
    final index = currentMonth!.items.indexWhere((existing) => existing.id == item.id);
    if (index >= 0) currentMonth!.items[index] = item;
    notifyListeners();
  }

  Future<void> addSpendingCategory(String name, double budgetAmount) async {
    final month = currentMonth;
    if (month == null) return;
    final category = SpendingCategory(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      budgetAmount: budgetAmount,
    );
    currentMonth = month.copyWith(categories: [...month.categories, category]);
    await _firestore.upsertMonth(_uid, currentMonth!);
    notifyListeners();
  }

  Future<void> updateSpendingCategory(SpendingCategory updatedCategory) async {
    final month = currentMonth;
    if (month == null) return;
    currentMonth = month.copyWith(
      categories: month.categories
          .map((category) => category.id == updatedCategory.id ? updatedCategory : category)
          .toList(),
    );
    await _firestore.upsertMonth(_uid, currentMonth!);
    notifyListeners();
  }

  Future<void> removeSpendingCategory(String categoryId) async {
    final month = currentMonth;
    if (month == null) return;
    final updatedItems = month.items
        .map((item) => item.categoryId == categoryId
            ? item.copyWith(clearCategory: true)
            : item)
        .toList();
    currentMonth = month.copyWith(
      items: updatedItems,
      categories: month.categories.where((category) => category.id != categoryId).toList(),
    );
    await _firestore.upsertMonth(_uid, currentMonth!);
    notifyListeners();
  }

  Future<void> createPurchaseGroup(String name, Set<String> itemIds) async {
    final month = currentMonth;
    if (month == null || itemIds.isEmpty) return;
    final existingItemIds = month.items
        .where((item) => itemIds.contains(item.id))
        .map((item) => item.id)
        .toSet();
    if (existingItemIds.isEmpty) return;
    final group = PurchaseGroup(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
    );
    final updatedItems = month.items
        .map((item) => existingItemIds.contains(item.id)
            ? item.copyWith(groupId: group.id)
            : item)
        .toList();
    currentMonth = month.copyWith(
      items: updatedItems,
      purchaseGroups: [...month.purchaseGroups, group],
    );
    await _firestore.upsertMonth(_uid, currentMonth!);
    notifyListeners();
  }

  Future<void> removePurchaseGroup(String groupId) async {
    final month = currentMonth;
    if (month == null) return;
    final updatedItems = month.items
        .map((item) => item.groupId == groupId ? item.copyWith(clearGroup: true) : item)
        .toList();
    currentMonth = month.copyWith(
      items: updatedItems,
      purchaseGroups: month.purchaseGroups.where((group) => group.id != groupId).toList(),
    );
    await _firestore.upsertMonth(_uid, currentMonth!);
    notifyListeners();
  }

  Stream<List<MonthData>> watchHistory() => _firestore.watchAllMonths(_uid);

  // ---------- external (manually added) savings, e.g. gold, cash kept outside the app ----------

  Stream<List<ExternalSaving>> watchExternalSavings() => _firestore.watchExternalSavings(_uid);

  Future<void> addExternalSaving(String title, double amount) async {
    final item = ExternalSaving(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      amount: amount,
      date: DateTime.now(),
    );
    await _firestore.addExternalSaving(_uid, item);
  }

  Future<void> removeExternalSaving(ExternalSaving item) async {
    await _firestore.removeExternalSaving(_uid, item.id);
  }

  Stream<List<NoteItem>> watchNotes() => _firestore.watchNotes(_uid);

  Future<void> saveNote(NoteItem note) async {
    await _firestore.saveNote(_uid, note);
  }

  Future<void> removeNote(String noteId) async {
    await _firestore.removeNote(_uid, noteId);
  }

  Stream<List<SavingGoal>> watchSavingGoals() => _firestore.watchGoals(_uid);

  Stream<double> watchTotalGoalWithdrawals() => _firestore.watchTotalGoalWithdrawals(_uid);

  Future<void> saveSavingGoal(SavingGoal goal) async {
    await _firestore.saveGoal(_uid, goal);
  }

  Future<void> removeSavingGoal(String goalId) async {
    await _firestore.removeGoal(_uid, goalId);
  }

  Future<void> markSavingGoalAchieved(String goalId) async {
    await _firestore.markGoalAchieved(_uid, goalId);
  }

  Future<double> addManualGoalContribution(String goalId, double amount) =>
      _firestore.addManualGoalContribution(_uid, goalId, amount);

  Future<double> withdrawFromGoal(String goalId, double amount) =>
      _firestore.withdrawFromGoal(_uid, goalId, amount);

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
