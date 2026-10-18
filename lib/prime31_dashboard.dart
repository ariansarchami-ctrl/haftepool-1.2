
import 'dart:math' as math;
import 'package:flutter/material.dart';

class Prime31Colors {
  static const emerald = Color(0xFF087F75);
  static const navy = Color(0xFF123B43);
  static const mint = Color(0xFFEAF6F2);
  static const background = Color(0xFFF1F5F9);
  static const warning = Color(0xFFEA8B35);
  static const danger = Color(0xFFE65B65);
}

class Prime31BudgetRing extends StatelessWidget {
  final int budget;
  final int spent;

  const Prime31BudgetRing({
    super.key,
    required this.budget,
    required this.spent,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = budget > 0 ? spent / budget * 100 : 0.0;
    final progress = budget > 0
        ? (spent / budget).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final color = percentage >= 100
        ? Prime31Colors.danger
        : percentage >= 75
            ? Prime31Colors.warning
            : Prime31Colors.emerald;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 164,
                height: 164,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 15,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Prime31Colors.mint,
                  color: color,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    budget > 0
                        ? '${percentage.toStringAsFixed(1)}٪'
                        : '—',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Prime31Colors.navy,
                    ),
                  ),
                  const Text(
                    'بودجه مصرف‌شده',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class Prime31WeeklyChart extends StatelessWidget {
  final List<int> dailyExpenses;
  final int todayIndex;
  final List<String> dayLabels;

  const Prime31WeeklyChart({
    super.key,
    required this.dailyExpenses,
    required this.todayIndex,
    this.dayLabels = const [
      'ش',
      'ی',
      'د',
      'س',
      'چ',
      'پ',
      'ج',
    ],
  });

  @override
  Widget build(BuildContext context) {
    final values = List<int>.generate(
      7,
      (i) => i < dailyExpenses.length
          ? math.max(0, dailyExpenses[i])
          : 0,
    );

    final maximum = values.reduce(math.max);
    final scale = math.max(1, maximum);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'نمودار هزینه‌های هفته',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 160,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final ratio = values[i] / scale;
              final isToday = i == todayIndex;

              return Expanded(
                child: Tooltip(
                  message: '${values[i]} تومان',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0,
                            end: ratio,
                          ),
                          duration: const Duration(
                            milliseconds: 700,
                          ),
                          builder: (context, height, child) {
                            return Container(
                              height: 110 * height + 4,
                              decoration: BoxDecoration(
                                color: isToday
                                    ? Prime31Colors.emerald
                                    : const Color(0xFFB9DAD2),
                                borderRadius:
                                    BorderRadius.circular(9),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        Text(
                          dayLabels[i],
                          style: TextStyle(
                            fontWeight: isToday
                                ? FontWeight.w900
                                : FontWeight.normal,
                            color: isToday
                                ? Prime31Colors.emerald
                                : Prime31Colors.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class Prime31SavingsCard extends StatelessWidget {
  final String title;
  final int target;
  final int saved;
  final String Function(int) formatMoney;

  const Prime31SavingsCard({
    super.key,
    required this.title,
    required this.target,
    required this.saved,
    required this.formatMoney,
  });

  @override
  Widget build(BuildContext context) {
    final progress = target > 0
        ? (saved / target).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Prime31Colors.navy,
            Prime31Colors.emerald,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.savings_outlined,
                color: Colors.white,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            formatMoney(saved),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'از هدف ${formatMoney(target)}',
            style: const TextStyle(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              color: const Color(0xFF8CE8B7),
              backgroundColor: Colors.white24,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            target > 0
                ? '${(progress * 100).toStringAsFixed(0)}٪ تکمیل شده'
                : 'هنوز هدفی تعیین نشده',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class Prime31BudgetAlert extends StatelessWidget {
  final int budget;
  final int spent;

  const Prime31BudgetAlert({
    super.key,
    required this.budget,
    required this.spent,
  });

  @override
  Widget build(BuildContext context) {
    if (budget <= 0) {
      return const SizedBox.shrink();
    }

    final percentage = spent / budget * 100;

    if (percentage < 75) {
      return const SizedBox.shrink();
    }

    final isDanger = percentage >= 90;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDanger
            ? const Color(0xFFFFEBED)
            : const Color(0xFFFFF3E4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: isDanger
                ? Prime31Colors.danger
                : Prime31Colors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isDanger
                  ? 'هشدار: ${percentage.toStringAsFixed(0)}٪ بودجه مصرف شده است.'
                  : 'توجه: بیش از ۷۵٪ بودجه مصرف شده است.',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Prime31Colors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
