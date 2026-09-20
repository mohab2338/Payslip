/// Computes salary-cycle boundaries based on a user-chosen "month start day"
/// (1-31). This lets a cycle run e.g. the 25th of one month to the 24th of
/// the next, instead of a fixed calendar month.
class CycleCalculator {
  final int startDay;

  CycleCalculator(this.startDay);

  /// Returns the start date of the cycle that contains [date].
  DateTime cycleStartFor(DateTime date) {
    final daysInMonth = DateTime(date.year, date.month + 1, 0).day;
    final effectiveStartDay = startDay > daysInMonth ? daysInMonth : startDay;

    if (date.day >= effectiveStartDay) {
      return DateTime(date.year, date.month, effectiveStartDay);
    } else {
      final prevMonth = DateTime(date.year, date.month - 1, 1);
      final daysInPrevMonth = DateTime(prevMonth.year, prevMonth.month + 1, 0).day;
      final prevEffectiveDay = startDay > daysInPrevMonth ? daysInPrevMonth : startDay;
      return DateTime(prevMonth.year, prevMonth.month, prevEffectiveDay);
    }
  }

  /// Returns the start date of the cycle right after [periodStart].
  DateTime nextCycleStart(DateTime periodStart) {
    final next = DateTime(periodStart.year, periodStart.month + 1, 1);
    final daysInNext = DateTime(next.year, next.month + 1, 0).day;
    final effectiveDay = startDay > daysInNext ? daysInNext : startDay;
    return DateTime(next.year, next.month, effectiveDay);
  }

  /// Document id used in Firestore for the cycle containing [date].
  String idFor(DateTime date) {
    final start = cycleStartFor(date);
    return '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
  }
}
