/// Read-only liquidity forecast for PRIME 3.0. No payments or transfers occur.
import 'prime_planning_engine.dart';

class PrimeCashflowPoint {
  final DateTime day;
  final int incoming;
  final int outgoing;
  final int closingBalance;
  final bool belowReserve;
  const PrimeCashflowPoint(this.day, this.incoming, this.outgoing,
      this.closingBalance, this.belowReserve);
}

class PrimeCashflowForecast {
  final List<PrimeCashflowPoint> days;
  final DateTime? firstShortfall;
  final int lowestBalance;
  final int requiredBuffer;
  const PrimeCashflowForecast(this.days, this.firstShortfall,
      this.lowestBalance, this.requiredBuffer);
}

class PrimeCashflowRisk {
  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Forecasts calendar-day closing balances. Reserve is a protected threshold,
  /// not an expense. Events occurring on the same day are netted together.
  /// A negative balance is a projected shortfall, never an automatic overdraft.
  static PrimeCashflowForecast forecast({
    required int openingBalance,
    required int protectedReserve,
    required DateTime from,
    required DateTime through,
    required List<PrimeScheduledOccurrence> occurrences,
    int maxDays = 366,
  }) {
    if (openingBalance < 0 || protectedReserve < 0 || maxDays < 1) {
      throw ArgumentError('Invalid opening balance or reserve');
    }
    final start = _day(from);
    final end = _day(through);
    final days = end.difference(start).inDays + 1;
    if (days < 1 || days > maxDays) throw ArgumentError('Invalid forecast horizon');
    final totals = <DateTime, List<int>>{};
    for (final event in occurrences) {
      final date = _day(event.due);
      if (date.isBefore(start) || date.isAfter(end)) continue;
      final values = totals.putIfAbsent(date, () => [0, 0]);
      if (event.signedAmount >= 0) {
        values[0] += event.signedAmount;
      } else {
        values[1] += -event.signedAmount;
      }
    }
    var balance = openingBalance;
    var minimum = balance;
    DateTime? firstShortfall;
    final result = <PrimeCashflowPoint>[];
    for (var i = 0; i < days; i++) {
      final date = start.add(Duration(days: i));
      final amounts = totals[date] ?? [0, 0];
      balance += amounts[0] - amounts[1];
      if (balance < minimum) minimum = balance;
      final short = balance < protectedReserve;
      if (short && firstShortfall == null) firstShortfall = date;
      result.add(PrimeCashflowPoint(date, amounts[0], amounts[1], balance, short));
    }
    final buffer = minimum < protectedReserve ? protectedReserve - minimum : 0;
    return PrimeCashflowForecast(List.unmodifiable(result), firstShortfall,
        minimum, buffer);
  }
}
