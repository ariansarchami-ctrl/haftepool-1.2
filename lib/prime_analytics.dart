/// Read-only financial chart and transaction search data for PRIME 3.0.
/// Amounts are non-negative integer tomans; no UI or storage side effects.
class PrimeRecord {
  final String id;
  final DateTime date;
  final int amount;
  final bool isExpense;
  final String category;
  final String note;

  PrimeRecord({required this.id, required this.date, required this.amount,
    required this.isExpense, required this.category, this.note = ''}) {
    if (id.trim().isEmpty || amount < 0 || category.trim().isEmpty) {
      throw ArgumentError('تراکنش نامعتبر');
    }
  }
}

class PrimeDailyTotals {
  final DateTime date;
  final int income;
  final int expense;
  final int budget;
  const PrimeDailyTotals(this.date, this.income, this.expense, this.budget);
  int get remaining => budget - expense;
}

class PrimeCategoryTotal {
  final String category;
  final int amount;
  const PrimeCategoryTotal(this.category, this.amount);
}

class PrimeAnalytics {
  static DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Exactly one point per day, including days without transactions.
  /// Budgets are keyed by midnight local dates.
  static List<PrimeDailyTotals> dailyChart({
    required List<PrimeRecord> records,
    required DateTime from,
    required DateTime through,
    Map<DateTime, int> dailyBudgets = const {},
    int maxDays = 366,
  }) {
    final start = day(from);
    final end = day(through);
    final length = end.difference(start).inDays + 1;
    if (length <= 0 || length > maxDays || maxDays < 1) {
      throw ArgumentError('بازه نمودار نامعتبر');
    }
    final incomes = <DateTime, int>{};
    final expenses = <DateTime, int>{};
    for (final record in records) {
      final date = day(record.date);
      if (date.isBefore(start) || date.isAfter(end)) continue;
      final totals = record.isExpense ? expenses : incomes;
      totals[date] = (totals[date] ?? 0) + record.amount;
    }
    final budgets = <DateTime, int>{};
    for (final entry in dailyBudgets.entries) {
      if (entry.value < 0) throw ArgumentError('بودجه منفی');
      budgets[day(entry.key)] = entry.value;
    }
    return List.unmodifiable(List.generate(length, (i) {
      // Construct calendar dates instead of adding 24h to avoid DST drift.
      final date = DateTime(start.year, start.month, start.day + i);
      return PrimeDailyTotals(date, incomes[date] ?? 0,
          expenses[date] ?? 0, budgets[date] ?? 0);
    }));
  }

  static List<PrimeCategoryTotal> expenseCategories({
    required List<PrimeRecord> records,
    required DateTime from,
    required DateTime through,
  }) {
    final start = day(from);
    final end = day(through);
    if (end.isBefore(start)) throw ArgumentError('بازه نامعتبر');
    final totals = <String, int>{};
    for (final record in records) {
      final date = day(record.date);
      if (!record.isExpense || date.isBefore(start) || date.isAfter(end)) continue;
      totals[record.category] = (totals[record.category] ?? 0) + record.amount;
    }
    final result = totals.entries
        .map((e) => PrimeCategoryTotal(e.key, e.value)).toList()
      ..sort((a, b) {
        final byAmount = b.amount.compareTo(a.amount);
        return byAmount != 0 ? byAmount : a.category.compareTo(b.category);
      });
    return List.unmodifiable(result);
  }

  static List<PrimeRecord> search({
    required List<PrimeRecord> records,
    String query = '',
    String? category,
    bool? isExpense,
    DateTime? from,
    DateTime? through,
  }) {
    final normalized = query.trim().toLowerCase();
    final start = from == null ? null : day(from);
    final end = through == null ? null : day(through);
    if (start != null && end != null && end.isBefore(start)) {
      throw ArgumentError('بازه نامعتبر');
    }
    final result = records.where((record) {
      final date = day(record.date);
      if (start != null && date.isBefore(start)) return false;
      if (end != null && date.isAfter(end)) return false;
      if (category != null && record.category != category) return false;
      if (isExpense != null && record.isExpense != isExpense) return false;
      return normalized.isEmpty || record.note.toLowerCase().contains(normalized) ||
          record.category.toLowerCase().contains(normalized);
    }).toList()
      ..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });
    return List.unmodifiable(result);
  }
}
