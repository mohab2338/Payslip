import 'expense_item.dart';

/// Represents one salary cycle (from the user-chosen start day to the day
/// before the next cycle's start day). The document id in Firestore is
/// derived from [periodStart] so cycles never collide, even if the user
/// changes their "month start day" setting later.
class MonthData {
  final String id; // e.g. "2026-09-18"
  final DateTime periodStart;
  final double salary;
  final double savingGoal;
  final List<ExpenseItem> items;

  MonthData({
    required this.id,
    required this.periodStart,
    required this.salary,
    required this.savingGoal,
    List<ExpenseItem>? items,
  }) : items = items ?? [];

  double get totalSpent => items.fold(0.0, (sum, e) => sum + e.amount);

  double get allowedToSpend => salary - savingGoal;

  double get remaining => allowedToSpend - totalSpent;

  double get spentPercentage {
    if (allowedToSpend <= 0) return 0;
    final pct = (totalSpent / allowedToSpend) * 100;
    return pct.clamp(0, 999);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'periodStart': periodStart.toIso8601String(),
      'salary': salary,
      'savingGoal': savingGoal,
      'items': items.map((e) => e.toMap()).toList(),
    };
  }

  factory MonthData.fromMap(Map<String, dynamic> map) {
    return MonthData(
      id: map['id'] as String,
      periodStart: DateTime.parse(map['periodStart'] as String),
      salary: (map['salary'] as num).toDouble(),
      savingGoal: (map['savingGoal'] as num).toDouble(),
      items: (map['items'] as List<dynamic>? ?? [])
          .map((e) => ExpenseItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  MonthData copyWith({
    double? salary,
    double? savingGoal,
    List<ExpenseItem>? items,
  }) {
    return MonthData(
      id: id,
      periodStart: periodStart,
      salary: salary ?? this.salary,
      savingGoal: savingGoal ?? this.savingGoal,
      items: items ?? this.items,
    );
  }
}
