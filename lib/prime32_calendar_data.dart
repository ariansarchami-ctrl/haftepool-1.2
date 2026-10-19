
import 'package:flutter/foundation.dart';

@immutable
class Prime32CalendarEntry {
  final String id;
  final DateTime date;
  final String kind;
  final int amount;
  final String category;
  final String note;

  const Prime32CalendarEntry({
    required this.id,
    required this.date,
    required this.kind,
    required this.amount,
    required this.category,
    required this.note,
  });
}

@immutable
class Prime32DaySummary {
  final DateTime date;
  final int expense;
  final int income;
  final int transactionCount;

  const Prime32DaySummary({
    required this.date,
    required this.expense,
    required this.income,
    required this.transactionCount,
  });

  int get balance => income - expense;
}

class Prime32CalendarData {
  static DateTime normalize(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static List<Prime32CalendarEntry> entriesOn(
    DateTime date,
    Iterable<Prime32CalendarEntry> entries,
  ) {
    final target = normalize(date);
    return entries.where(
      (entry) => normalize(entry.date) == target,
    ).toList();
  }

  static Prime32DaySummary summary(
    DateTime date,
    Iterable<Prime32CalendarEntry> entries,
  ) {
    final daily = entriesOn(date, entries);

    return Prime32DaySummary(
      date: normalize(date),
      expense: daily
          .where((entry) => entry.kind == 'expense')
          .fold<int>(0, (sum, entry) => sum + entry.amount),
      income: daily
          .where((entry) => entry.kind == 'income')
          .fold<int>(0, (sum, entry) => sum + entry.amount),
      transactionCount: daily.length,
    );
  }
}
