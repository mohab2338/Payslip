import 'package:flutter_test/flutter_test.dart';
import 'package:salary_tracker/models/expense_item.dart';
import 'package:salary_tracker/models/extra_income.dart';
import 'package:salary_tracker/models/month_data.dart';

void main() {
  group('MonthData actualSaved', () {
    MonthData monthWithSpent(double spent) => MonthData(
          id: '2026-09-01',
          periodStart: DateTime(2026, 9),
          salary: 1000,
          savingGoal: 200,
          items: [
            ExpenseItem(
              id: 'purchase',
              title: 'Purchase',
              amount: spent,
              date: DateTime(2026, 9, 2),
            ),
          ],
        );

    test('includes unspent allowance in actual savings', () {
      expect(monthWithSpent(500).actualSaved, 500);
    });

    test('reflects savings below the goal after overspending', () {
      expect(monthWithSpent(900).actualSaved, 100);
    });

    test('can be negative when spending exceeds salary', () {
      expect(monthWithSpent(1100).actualSaved, -100);
    });
  });

  group('MonthData extra income', () {
    final month = MonthData(
      id: '2026-09-01',
      periodStart: DateTime(2026, 9),
      salary: 1000,
      savingGoal: 200,
      items: [
        ExpenseItem(
          id: 'purchase',
          title: 'Purchase',
          amount: 500,
          date: DateTime(2026, 9, 2),
        ),
      ],
      extraIncomes: [
        ExtraIncome(
          id: 'bonus',
          amount: 150,
          date: DateTime(2026, 9, 5),
          description: 'One-time bonus',
        ),
        ExtraIncome(
          id: 'refund',
          amount: 50,
          date: DateTime(2026, 9, 8),
        ),
      ],
    );

    test('adds extra income to cycle salary and allowance calculations', () {
      expect(month.totalExtraIncome, 200);
      expect(month.totalCycleSalary, 1200);
      expect(month.allowedToSpend, 1000);
      expect(month.remaining, 500);
      expect(month.actualSaved, 700);
    });

    test('round trips extra incomes through map serialization', () {
      final restored = MonthData.fromMap(month.toMap());
      expect(restored.extraIncomes, hasLength(2));
      expect(restored.extraIncomes.first.description, 'One-time bonus');
      expect(restored.totalCycleSalary, 1200);
    });

    test('loads older cycle data without extra incomes', () {
      final oldData = month.toMap()..remove('extraIncomes');
      final restored = MonthData.fromMap(oldData);
      expect(restored.extraIncomes, isEmpty);
      expect(restored.totalCycleSalary, restored.salary);
    });
  });
}
