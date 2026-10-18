/// PRIME 3.0 finance calculation core.
/// Pure Dart: independent of Flutter UI and persistent storage.
/// Monetary amounts are integer tomans; callers must validate inputs.
import 'dart:math' as math;

class PrimeMoney {
  /// Allocates every toman; tie-breaks by weekday order (Saturday first).
  static List<int> allocate(int amount, List<int> weights) {
    if (amount < 0 || weights.length != 7 || weights.any((w) => w < 0)) {
      throw ArgumentError('Invalid amount or weekday weights');
    }
    final sum = weights.fold<int>(0, (a, b) => a + b);
    if (sum == 0) throw ArgumentError('At least one weight is required');
    final base = weights.map((w) => amount * w ~/ sum).toList();
    final remainders = List<int>.generate(7, (i) => (amount * weights[i]) % sum);
    final indices = List<int>.generate(7, (i) => i)
      ..sort((a, b) {
        final comparison = remainders[b].compareTo(remainders[a]);
        return comparison != 0 ? comparison : a.compareTo(b);
      });
    final leftover = amount - base.fold<int>(0, (a, b) => a + b);
    for (var i = 0; i < leftover; i++) { base[indices[i]]++; }
    return base;
  }

  static int checkedSubtract(int balance, int amount) {
    if (amount <= 0 || balance < amount) {
      throw StateError('موجودی کافی نیست یا مبلغ نامعتبر است');
    }
    return balance - amount;
  }
}

enum FundingSource { savings, remainingDaysEqual, selectedDay, none }

/// A proposed transfer has no side effects until explicitly confirmed.
class OverspendProposal {
  final int shortfall;
  final FundingSource source;
  final Map<int, int> weekdayDeductions;
  final int savingsDeduction;
  final bool feasible;
  final String reason;
  const OverspendProposal(this.shortfall, this.source, this.weekdayDeductions,
      this.savingsDeduction, this.feasible, this.reason);
}

class PrimeOverspend {
  /// `remaining` is the amount still unspent in each weekday (7 elements).
  /// `currentDay` is Saturday=0 ... Friday=6.
  static OverspendProposal propose({
    required int shortfall,
    required FundingSource source,
    required List<int> remaining,
    required int currentDay,
    required int savingsBalance,
    int? selectedDay,
  }) {
    if (shortfall <= 0 || remaining.length != 7 || currentDay < 0 || currentDay > 6 ||
        remaining.any((v) => v < 0) || savingsBalance < 0) {
      throw ArgumentError('Invalid overspend request');
    }
    if (source == FundingSource.none) {
      return OverspendProposal(shortfall, source, const {}, 0, true, 'بدون انتقال؛ اضافه‌خرج ثبت می‌شود');
    }
    if (source == FundingSource.savings) {
      final ok = savingsBalance >= shortfall;
      return OverspendProposal(shortfall, source, const {}, ok ? shortfall : 0,
          ok, ok ? 'برداشت از پس‌انداز' : 'موجودی پس‌انداز کافی نیست');
    }
    final eligible = source == FundingSource.selectedDay
        ? [selectedDay ?? -1]
        : List<int>.generate(6 - currentDay, (i) => currentDay + i + 1);
    if (eligible.isEmpty || eligible.any((i) => i <= currentDay || i > 6)) {
      return OverspendProposal(shortfall, source, const {}, 0, false, 'روز آینده معتبری انتخاب نشده');
    }
    final capacity = eligible.fold<int>(0, (a, i) => a + remaining[i]);
    if (capacity < shortfall) {
      return OverspendProposal(shortfall, source, const {}, 0, false, 'مانده روزهای انتخاب‌شده کافی نیست');
    }
    final result = <int, int>{for (final i in eligible) i: 0};
    var pending = shortfall;
    // Water-filling: distribute as evenly as possible while respecting each day's balance.
    while (pending > 0) {
      final active = eligible.where((i) => remaining[i] > result[i]!).toList();
      if (active.isEmpty) throw StateError('Allocation capacity exhausted');
      final shares = PrimeMoney.allocate(pending, [for (var i = 0; i < 7; i++) active.contains(i) ? 1 : 0]);
      var moved = 0;
      for (final i in active) {
        final take = math.min(shares[i], remaining[i] - result[i]!);
        result[i] = result[i]! + take;
        moved += take;
      }
      if (moved == 0) throw StateError('No progress in allocation');
      pending -= moved;
    }
    return OverspendProposal(shortfall, source, result, 0, true, 'منتظر تأیید کاربر');
  }
}

class WeekSnapshot {
  final DateTime start;
  final int budget, income, expense, saved;
  final List<int> dailyExpenses;
  final Map<String, int> categoryExpenses;
  WeekSnapshot({required this.start, required this.budget, required this.income,
    required this.expense, required this.saved, required this.dailyExpenses,
    required this.categoryExpenses}) {
    if (dailyExpenses.length != 7) throw ArgumentError('Expected 7 weekdays');
  }
  int get remaining => budget + income - expense;
  double get adherence => budget + income <= 0 ? 0 :
      ((budget + income - math.max(0, expense - budget - income)) / (budget + income)).clamp(0.0, 1.0).toDouble();
}

class PrimeInsight {
  final int weeksAnalyzed;
  final double averageWeeklyExpense, averageWeeklySaving;
  final int highestSpendDay;
  final String? highestSpendCategory;
  final double budgetAdherenceRate;
  const PrimeInsight(this.weeksAnalyzed, this.averageWeeklyExpense,
      this.averageWeeklySaving, this.highestSpendDay,
      this.highestSpendCategory, this.budgetAdherenceRate);

  static PrimeInsight analyze(List<WeekSnapshot> all, {int lookback = 8}) {
    if (![4, 8, 12].contains(lookback)) throw ArgumentError('Use 4, 8 or 12 weeks');
    final sorted = [...all]..sort((a, b) => b.start.compareTo(a.start));
    final weeks = sorted.take(lookback).toList();
    if (weeks.isEmpty) return const PrimeInsight(0, 0, 0, 0, null, 0);
    final byDay = List<int>.filled(7, 0);
    final byCategory = <String, int>{};
    var expenses = 0, savings = 0, adherent = 0;
    for (final week in weeks) {
      expenses += week.expense;
      savings += week.saved;
      if (week.expense <= week.budget + week.income) adherent++;
      for (var i = 0; i < 7; i++) { byDay[i] += week.dailyExpenses[i]; }
      for (final item in week.categoryExpenses.entries) {
        byCategory.update(item.key, (v) => v + item.value, ifAbsent: () => item.value);
      }
    }
    final busiestDay = List<int>.generate(7, (i) => i)
      ..sort((a, b) => byDay[b].compareTo(byDay[a]));
    final categories = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return PrimeInsight(weeks.length, expenses / weeks.length, savings / weeks.length,
        busiestDay.first, categories.isEmpty ? null : categories.first.key,
        adherent / weeks.length);
  }
}

class GoalForecast {
  final int remaining, weeklyRequired;
  final DateTime? expectedCompletion;
  final bool? achievableByDeadline;
  final String explanation;
  const GoalForecast(this.remaining, this.weeklyRequired,
      this.expectedCompletion, this.achievableByDeadline, this.explanation);

  static GoalForecast calculate({required int target, required int saved,
      required DateTime today, required DateTime deadline,
      required double sustainableWeeklySaving, required int historyWeeks}) {
    if (target <= 0 || saved < 0 || sustainableWeeklySaving < 0) {
      throw ArgumentError('Invalid goal inputs');
    }
    final remaining = math.max(0, target - saved);
    final days = deadline.difference(today).inDays;
    final weeks = math.max(1, (days / 7).ceil());
    final required = (remaining / weeks).ceil();
    if (remaining == 0) return GoalForecast(0, 0, today, true, 'هدف تکمیل شده است');
    if (historyWeeks < 4 || sustainableWeeklySaving <= 0) {
      return GoalForecast(remaining, required, null, null,
          'برای پیش‌بینی قابل اتکا حداقل چهار هفته سابقه پس‌انداز لازم است');
    }
    final projectedWeeks = (remaining / sustainableWeeklySaving).ceil();
    final completion = today.add(Duration(days:projectedWeeks * 7));
    return GoalForecast(remaining, required, completion,
        !completion.isAfter(deadline), 'برآورد بر پایه میانگین پس‌انداز ثبت‌شده است، نه تضمین');
  }
}

class PrimeHealthScore {
  final int score;
  final String explanation;
  const PrimeHealthScore(this.score, this.explanation);
  static PrimeHealthScore calculate({required List<WeekSnapshot> history}) {
    if (history.length < 4) return const PrimeHealthScore(0, 'داده کافی نیست؛ حداقل چهار هفته لازم است');
    final recent = ([...history]..sort((a, b) => b.start.compareTo(a.start))).take(8).toList();
    final within = recent.where((w) => w.expense <= w.budget + w.income).length / recent.length;
    final savings = recent.where((w) => w.saved > 0).length / recent.length;
    final positive = recent.where((w) => w.remaining >= 0).length / recent.length;
    final score = (100 * (0.5 * within + 0.3 * savings + 0.2 * positive)).round();
    return PrimeHealthScore(score.clamp(0, 100),
        '۵۰٪ پایبندی به بودجه، ۳۰٪ استمرار پس‌انداز، ۲۰٪ مانده غیرمنفی');
  }
}
