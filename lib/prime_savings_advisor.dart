/// Explainable savings suggestions based on completed weeks.
/// Pure Dart; no external service, UI, or persistent side effects.
class PrimeWeekSnapshot {
  final int income;
  final int expenses;
  final int saved;
  final int plannedSaving;
   PrimeWeekSnapshot({required this.income, required this.expenses,
    required this.saved, required this.plannedSaving}) {
    if (income < 0 || expenses < 0 || saved < 0 || plannedSaving < 0) {
      throw ArgumentError('Weekly values must be non-negative');
    }
  }
  int get surplusBeforeSaving => income - expenses;
  bool get withinIncome => expenses + saved <= income;
}

class PrimeSavingAdvice {
  final int? suggestedAmount;
  final int? dailySpendingBudget;
  final int? differenceFromCurrent;
  final int sampleWeeks;
  final String explanation;
  const PrimeSavingAdvice({required this.suggestedAmount,
    required this.dailySpendingBudget, required this.differenceFromCurrent,
    required this.sampleWeeks, required this.explanation});
  bool get hasEnoughData => suggestedAmount != null;
}

/// Uses up to the last 12 completed weeks; 4 weeks are required for a
/// personalized suggestion. A conservative suggestion is bounded by both
/// the median of historically saved amounts and the median available surplus.
/// It never recommends more than the user's upcoming income after fixed costs.
PrimeSavingAdvice recommendNextWeekSavings({
  required List<PrimeWeekSnapshot> completedWeeks,
  required int upcomingIncome,
  required int upcomingFixedCosts,
  required int currentSavingTarget,
}) {
  if (upcomingIncome < 0 || upcomingFixedCosts < 0 || currentSavingTarget < 0) {
    throw ArgumentError('Amounts must be non-negative');
  }
  final recent = completedWeeks.length <= 12
      ? completedWeeks
      : completedWeeks.sublist(completedWeeks.length - 12);
  if (recent.length < 4) {
    return PrimeSavingAdvice(suggestedAmount: null, dailySpendingBudget: null,
      differenceFromCurrent: null, sampleWeeks: recent.length,
      explanation: 'برای پیشنهاد شخصی‌سازی‌شده حداقل ۴ هفته کامل اطلاعات لازم است.');
  }
  int median(List<int> values) {
    final sorted = [...values]..sort();
    final n = sorted.length;
    return n.isOdd ? sorted[n ~/ 2] :
      (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) ~/ 2;
  }
  final observedSavings = median(recent.map((w) => w.saved).toList());
  final historicalSurplus = median(recent
      .map((w) => w.surplusBeforeSaving < 0 ? 0 : w.surplusBeforeSaving)
      .toList());
  final available = upcomingIncome > upcomingFixedCosts
      ? upcomingIncome - upcomingFixedCosts : 0;
  final suggestion = [observedSavings, historicalSurplus, available]
      .reduce((a, b) => a < b ? a : b);
  final spendable = available - suggestion;
  return PrimeSavingAdvice(suggestedAmount: suggestion,
    dailySpendingBudget: spendable ~/ 7,
    differenceFromCurrent: suggestion - currentSavingTarget,
    sampleWeeks: recent.length,
    explanation: 'پیشنهاد بر پایه میانه پس‌انداز واقعی و مازاد درآمد '
      'در ${recent.length} هفته کامل است و از پول قابل‌دسترس '
      'پس از هزینه‌های ثابت هفته آینده بیشتر نمی‌شود. '
      'سهم روزانه نمایش‌داده‌شده تقریبی است؛ باقی‌مانده تقسیم باید '
      'در تخصیص دقیق هفت‌روزه منظور شود.');
}
