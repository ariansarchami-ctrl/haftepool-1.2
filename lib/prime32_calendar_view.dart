
import 'package:flutter/material.dart';
import 'prime32_calendar_data.dart';

class Prime32Jalali {
  static const months = [
    'فروردین', 'اردیبهشت', 'خرداد',
    'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر',
    'دی', 'بهمن', 'اسفند',
  ];

  static const weekdays = [
    'ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج',
  ];

  static List<int> fromGregorian(DateTime date) {
    var gy = date.year;
    final gm = date.month;
    final gd = date.day;

    final gdm = [
      0, 31, 59, 90, 120, 151,
      181, 212, 243, 273, 304, 334,
    ];

    final gy2 = gm > 2 ? gy + 1 : gy;
    var days = 355666 +
        365 * gy +
        (gy2 + 3) ~/ 4 -
        (gy2 + 99) ~/ 100 +
        (gy2 + 399) ~/ 400 +
        gd +
        gdm[gm - 1];

    var jy = -1595 + 33 * (days ~/ 12053);
    days %= 12053;

    jy += 4 * (days ~/ 1461);
    days %= 1461;

    if (days > 365) {
      jy += (days - 1) ~/ 365;
      days = (days - 1) % 365;
    }

    final jm = days < 186
        ? 1 + days ~/ 31
        : 7 + (days - 186) ~/ 30;

    final jd = days < 186
        ? 1 + days % 31
        : 1 + (days - 186) % 30;

    return [jy, jm, jd];
  }

  static String digits(Object value) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    return value.toString().replaceAllMapped(
      RegExp(r'[0-9]'),
      (match) => fa[int.parse(match.group(0)!)],
    );
  }

  static DateTime monthStart(DateTime date) {
    final current = fromGregorian(date);
    var result = DateTime(date.year, date.month, date.day);

    while (fromGregorian(result)[2] != 1) {
      result = result.subtract(const Duration(days: 1));
    }

    return result;
  }

  static DateTime moveMonth(DateTime date, int direction) {
    var result = monthStart(date);

    if (direction > 0) {
      final current = fromGregorian(result);
      do {
        result = result.add(const Duration(days: 1));
      } while (
          fromGregorian(result)[0] == current[0] &&
          fromGregorian(result)[1] == current[1]);
    } else {
      result = result.subtract(const Duration(days: 1));
      result = monthStart(result);
    }

    return result;
  }
}

class Prime32CalendarView extends StatefulWidget {
  final List<Prime32CalendarEntry> entries;
  final ValueChanged<DateTime>? onDateSelected;

  const Prime32CalendarView({
    super.key,
    this.entries = const [],
    this.onDateSelected,
  });

  @override
  State<Prime32CalendarView> createState() =>
      _Prime32CalendarViewState();
}

class _Prime32CalendarViewState
    extends State<Prime32CalendarView> {
  late DateTime selected;
  late DateTime displayedMonth;

  @override
  void initState() {
    super.initState();
    selected = DateTime.now();
    displayedMonth = Prime32Jalali.monthStart(selected);
  }

  @override
  Widget build(BuildContext context) {
    final jalali = Prime32Jalali.fromGregorian(displayedMonth);
    final next = Prime32Jalali.moveMonth(displayedMonth, 1);
    final daysCount = next.difference(displayedMonth).inDays;
    final offset = (displayedMonth.weekday + 1) % 7;
    final summary = Prime32CalendarData.summary(
      selected,
      widget.entries,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Card(
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => setState(() {
                      displayedMonth =
                          Prime32Jalali.moveMonth(
                            displayedMonth, -1);
                    }),
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'ماه قبل',
                  ),
                  Text(
                    '${Prime32Jalali.months[jalali[1] - 1]} '
                    '${Prime32Jalali.digits(jalali[0])}',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() {
                      displayedMonth =
                          Prime32Jalali.moveMonth(
                            displayedMonth, 1);
                    }),
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'ماه بعد',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 7,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1.3,
                ),
                itemBuilder: (context, index) => Center(
                  child: Text(
                    Prime32Jalali.weekdays[index],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: offset + daysCount,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  if (index < offset) {
                    return const SizedBox.shrink();
                  }

                  final date = displayedMonth.add(
                    Duration(days: index - offset),
                  );
                  final dayNumber =
                      Prime32Jalali.fromGregorian(date)[2];
                  final active =
                      DateUtils.isSameDay(selected, date);
                  final daySummary =
                      Prime32CalendarData.summary(
                        date, widget.entries);

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() => selected = date);
                      widget.onDateSelected?.call(date);
                    },
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFF087F75)
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Text(
                            Prime32Jalali.digits(dayNumber),
                            style: TextStyle(
                              color: active
                                  ? Colors.white
                                  : null,
                              fontWeight: active
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          if (daySummary.expense > 0)
                            Container(
                              width: 5,
                              height: 5,
                              margin:
                                  const EdgeInsets.only(top: 3),
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 24),
              Text(
                'روز ${Prime32Jalali.digits(Prime32Jalali.fromGregorian(selected)[2])}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'هزینه: ${Prime32Jalali.digits(summary.expense)} تومان',
              ),
              Text(
                'درآمد: ${Prime32Jalali.digits(summary.income)} تومان',
              ),
              Text(
                'تعداد تراکنش: '
                '${Prime32Jalali.digits(summary.transactionCount)}',
              ),
              
              const SizedBox(height: 12),
              ...Prime32CalendarData.entriesOn(
                selected,
                widget.entries,
              ).map((entry) => ListTile(
                dense: true,
                leading: Icon(
                  entry.kind == 'expense'
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  color: entry.kind == 'expense'
                      ? Colors.redAccent
                      : Colors.green,
                ),
                title: Text(entry.category),
                subtitle: Text(entry.note),
                trailing: Text(
                  '${Prime32Jalali.digits(entry.amount)} تومان',
                ),
              )),

            ],
          ),
        ),
      ),
    );
  }
}
