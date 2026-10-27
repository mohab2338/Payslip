import 'package:flutter_test/flutter_test.dart';
import 'package:salary_tracker/models/expense_item.dart';
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
}
