/// PRIME 3.0 goal scenarios and spending challenges.
/// Pure calculations; no financial records are modified by these previews.
import 'dart:math' as math;

class PrimeGoalScenario {
  final int remaining;
  final int weeksAvailable;
  final int requiredWeeklySaving;
  final int weeklySavingGap;
  final DateTime? currentPaceCompletion;
  final int? daysRelativeToDeadline;
  final bool enoughHistory;
  const PrimeGoalScenario({required this.remaining, required this.weeksAvailable,
    required this.requiredWeeklySaving, required this.weeklySavingGap,
    required this.currentPaceCompletion, required this.daysRelativeToDeadline,
    required this.enoughHistory});
}

class PrimeGoalScenarios {
  /// Uses complete weeks as a conservative planning unit. The estimated
  /// completion is indicative, not a guarantee or a probability estimate.
  static PrimeGoalScenario compare({required int target, required int saved,
    required DateTime today, required DateTime deadline,
    required int averageWeeklySaving, required int completedHistoryWeeks}) {
    if (target <= 0 || saved < 0 || averageWeeklySaving < 0 ||
        completedHistoryWeeks < 0) {
      throw ArgumentError('Invalid goal inputs');
    }
    final remaining = math.max(0, target - saved);
    final days = math.max(0, deadline.difference(today).inDays);
    final weeks = math.max(1, (days / 7).ceil());
    final required = (remaining / weeks).ceil();
    final sufficient = completedHistoryWeeks >= 4;
    if (remaining == 0) {
      return PrimeGoalScenario(remaining: 0, weeksAvailable: weeks,
        requiredWeeklySaving: 0, weeklySavingGap: 0,
        currentPaceCompletion: today, daysRelativeToDeadline: today.difference(deadline).inDays,
        enoughHistory: sufficient);
    }
    if (!sufficient || averageWeeklySaving == 0) {
      return PrimeGoalScenario(remaining: remaining, weeksAvailable: weeks,
        requiredWeeklySaving: required,
        weeklySavingGap: math.max(0, required - averageWeeklySaving),
        currentPaceCompletion: null, daysRelativeToDeadline: null,
        enoughHistory: sufficient);
    }
    final weeksAtPace = (remaining / averageWeeklySaving).ceil();
    final projected = today.add(Duration(days: weeksAtPace * 7));
    return PrimeGoalScenario(remaining: remaining, weeksAvailable: weeks,
      requiredWeeklySaving: required,
      weeklySavingGap: math.max(0, required - averageWeeklySaving),
      currentPaceCompletion: projected,
      daysRelativeToDeadline: projected.difference(deadline).inDays,
      enoughHistory: true);
  }
}

enum PrimeChallengeKind { noSpendDays, categoryReduction, budgetAdherence }

class PrimeChallengeProgress {
  final int achieved;
  final int target;
  final bool completed;
  final int verifiedSavings;
  const PrimeChallengeProgress(this.achieved, this.target, this.completed, this.verifiedSavings);
}

class PrimeChallengeEngine {
  /// Only actual recorded zero-spend days count; missing days are not treated
  /// as success. `dailyExpense` must contain every observed day.
  static PrimeChallengeProgress noSpendDays({required List<int> dailyExpense,
    required int targetDays}) {
    if (targetDays <= 0 || dailyExpense.any((v) => v < 0)) {
      throw ArgumentError('Invalid no-spend challenge');
    }
    final achieved = dailyExpense.where((v) => v == 0).length;
    return PrimeChallengeProgress(achieved, targetDays, achieved >= targetDays, 0);
  }

  /// Savings are the nonnegative reduction against an explicit historical
  /// comparison amount. No hypothetical savings are presented as verified.
  static PrimeChallengeProgress categoryReduction({required int baselineExpense,
    required int actualExpense, required int reductionTarget}) {
    if (baselineExpense < 0 || actualExpense < 0 || reductionTarget <= 0) {
      throw ArgumentError('Invalid reduction challenge');
    }
    final saved = math.max(0, baselineExpense - actualExpense);
    return PrimeChallengeProgress(saved, reductionTarget,
      saved >= reductionTarget, saved);
  }

  static PrimeChallengeProgress budgetAdherence({required List<int> dailyBudget,
    required List<int> dailyExpense, required int targetDays}) {
    if (targetDays <= 0 || dailyBudget.length != dailyExpense.length ||
        dailyBudget.any((v) => v < 0) || dailyExpense.any((v) => v < 0)) {
      throw ArgumentError('Invalid adherence challenge');
    }
    var achieved = 0;
    for (var i = 0; i < dailyBudget.length; i++) {
      if (dailyExpense[i] <= dailyBudget[i]) achieved++;
    }
    return PrimeChallengeProgress(achieved, targetDays,
      achieved >= targetDays, 0);
  }
}
