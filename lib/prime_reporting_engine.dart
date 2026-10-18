/// Read-only reports and purchase simulations for PRIME 3.0.
/// All amounts are integer tomans. No persistence or UI side effects.
import 'dart:math' as math;

class PrimeReportEntry {
  final DateTime date;
  final int amount;
  final String category;
  final bool isExpense;
  const PrimeReportEntry({required this.date, required this.amount,
    required this.category, required this.isExpense});
}

class PrimePeriodReport {
  final int income;
  final int expenses;
  final Map<String, int> categoryExpenses;
  final List<int> dailyExpenses;
  const PrimePeriodReport(this.income, this.expenses,
      this.categoryExpenses, this.dailyExpenses);
  int get netCashFlow => income - expenses;
}

class PrimeReports {
  /// A Saturday-based local calendar week, independent of device locale.
  static DateTime weekStart(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: (day.weekday + 1) % 7));
  }

  static PrimePeriodReport weekly(List<PrimeReportEntry> entries, DateTime anchor) {
    final start = weekStart(anchor);
    final end = start.add(const Duration(days: 7));
    return period(entries, start: start, endExclusive: end, daily: true);
  }

  static PrimePeriodReport monthly(List<PrimeReportEntry> entries, int year, int month) {
    if (month < 1 || month > 12) throw ArgumentError('Invalid month');
    return period(entries, start: DateTime(year, month),
        endExclusive: DateTime(year, month + 1));
  }

  static PrimePeriodReport period(List<PrimeReportEntry> entries, {
    required DateTime start, required DateTime endExclusive, bool daily = false,
  }) {
    if (!start.isBefore(endExclusive)) throw ArgumentError('Invalid report interval');
    var income = 0, expense = 0;
    final categories = <String, int>{};
    final dailyExpenses = List<int>.filled(7, 0);
    for (final entry in entries) {
      if (entry.amount < 0) throw ArgumentError('Negative transaction amount');
      if (entry.date.isBefore(start) || !entry.date.isBefore(endExclusive)) continue;
      if (!entry.isExpense) {
        income += entry.amount;
      } else {
        expense += entry.amount;
        final category = entry.category.trim().isEmpty ? 'سایر' : entry.category.trim();
        categories.update(category, (value) => value + entry.amount,
            ifAbsent: () => entry.amount);
        if (daily) {
          final day = (entry.date.weekday + 1) % 7;
          dailyExpenses[day] += entry.amount;
        }
      }
    }
    return PrimePeriodReport(income, expense,
        Map.unmodifiable(categories), List.unmodifiable(dailyExpenses));
  }
}

class PrimePurchaseSimulation {
  final int balanceAfterPurchase;
  final int dailyBudgetAfterPurchase;
  final int savingsShortfall;
  final bool affordable;
  const PrimePurchaseSimulation(this.balanceAfterPurchase,
      this.dailyBudgetAfterPurchase, this.savingsShortfall, this.affordable);
}

class PrimeForecastSimulator {
  /// Preview only; never registers a transaction or withdraws savings.
  /// `available` excludes protected emergency and goal balances.
  static PrimePurchaseSimulation purchase({required int available,
      required int purchasePrice, required int remainingDays,
      required int plannedSaving}) {
    if (available < 0 || purchasePrice < 0 || remainingDays < 1 || plannedSaving < 0) {
      throw ArgumentError('Invalid simulation inputs');
    }
    final after = available - purchasePrice;
    final spendableAfterSavings = after - plannedSaving;
    return PrimePurchaseSimulation(after,
        math.max(0, spendableAfterSavings ~/ remainingDays),
        math.max(0, plannedSaving - math.max(0, after)),
        purchasePrice <= available && spendableAfterSavings >= 0);
  }
}

class PrimeWeeklyReview {
  final int expenseChange;
  final double? expenseChangePercent;
  final String busiestCategory;
  final int netCashFlow;
  final List<String> suggestions;
  const PrimeWeeklyReview(this.expenseChange, this.expenseChangePercent,
      this.busiestCategory, this.netCashFlow, this.suggestions);

  static PrimeWeeklyReview compare(PrimePeriodReport current,
      PrimePeriodReport previous, {required int weeklyBudget}) {
    if (weeklyBudget < 0) throw ArgumentError('Invalid budget');
    final delta = current.expenses - previous.expenses;
    final percent = previous.expenses == 0 ? null : delta * 100 / previous.expenses;
    final ranked = current.categoryExpenses.entries.toList()
      ..sort((a, b) {
        final byAmount = b.value.compareTo(a.value);
        return byAmount != 0 ? byAmount : a.key.compareTo(b.key);
      });
    final largest = ranked.isEmpty ? 'بدون هزینه' : ranked.first.key;
    final suggestions = <String>[];
    if (current.expenses > weeklyBudget) {
      suggestions.add('هزینه این هفته از بودجه تعیین‌شده بیشتر بوده است.');
    }
    if (delta > 0) {
      suggestions.add('هزینه‌ها نسبت به هفته قبل افزایش یافته‌اند؛ دسته $largest را بررسی کنید.');
    } else if (delta < 0) {
      suggestions.add('هزینه‌ها نسبت به هفته قبل کاهش یافته‌اند.');
    }
    if (current.netCashFlow < 0) {
      suggestions.add('هزینه این هفته از درآمد ثبت‌شده بیشتر است.');
    }
    if (suggestions.isEmpty) {
      suggestions.add('بودجه و روند هزینه را برای هفته آینده بازبینی کنید.');
    }
    return PrimeWeeklyReview(delta, percent, largest,
        current.netCashFlow, List.unmodifiable(suggestions));
  }
}
