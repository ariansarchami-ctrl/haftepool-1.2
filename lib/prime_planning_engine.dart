/// PRIME 3.0 planning and wallet accounting primitives.
/// Pure Dart, all amounts in integer tomans. No writes or automatic payments.

class PrimeWallet {
  final String id;
  final String title;
  final int balance;
  const PrimeWallet(this.id, this.title, this.balance);
}

class WalletTransfer {
  final String fromId;
  final String toId;
  final int amount;
  final DateTime at;
  const WalletTransfer(this.fromId, this.toId, this.amount, this.at);
}

class TransferPreview {
  final bool valid;
  final String message;
  final Map<String, int> balancesAfter;
  const TransferPreview(this.valid, this.message, this.balancesAfter);
}

class PrimeWalletLedger {
  /// Read-only proposal. UI must request explicit confirmation before persisting.
  static TransferPreview previewTransfer({
    required List<PrimeWallet> wallets,
    required String fromId,
    required String toId,
    required int amount,
  }) {
    final balances = <String, int>{};
    for (final wallet in wallets) {
      if (wallet.id.isEmpty || balances.containsKey(wallet.id) || wallet.balance < 0) {
        return const TransferPreview(false, 'کیف‌پول نامعتبر یا تکراری', {});
      }
      balances[wallet.id] = wallet.balance;
    }
    if (fromId == toId || amount <= 0 || !balances.containsKey(fromId) ||
        !balances.containsKey(toId)) {
      return const TransferPreview(false, 'مقصد، مبدأ یا مبلغ نامعتبر', {});
    }
    if (balances[fromId]! < amount) {
      return const TransferPreview(false, 'موجودی کیف‌پول کافی نیست', {});
    }
    balances[fromId] = balances[fromId]! - amount;
    balances[toId] = balances[toId]! + amount;
    return TransferPreview(true, 'انتقال آماده تأیید است', Map.unmodifiable(balances));
  }
}

enum PrimeScheduleFrequency { weekly, monthly }

class PrimeScheduledItem {
  final String id;
  final String title;
  final int amount;
  final bool isExpense;
  final DateTime firstDue;
  final PrimeScheduleFrequency frequency;
  final DateTime? endDate;

  PrimeScheduledItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.isExpense,
    required this.firstDue,
    required this.frequency,
    this.endDate,
  }) {
    if (id.isEmpty || title.trim().isEmpty || amount <= 0 ||
        (endDate != null && endDate!.isBefore(firstDue))) {
      throw ArgumentError('برنامه پرداخت نامعتبر');
    }
  }
}

class PrimeScheduledOccurrence {
  final String scheduleId;
  final DateTime due;
  final int signedAmount;
  const PrimeScheduledOccurrence(this.scheduleId, this.due, this.signedAmount);
}

class PrimeCalendarPlanner {
  static DateTime _date(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _monthly(DateTime original, int monthOffset) {
    final first = DateTime(original.year, original.month + monthOffset, 1);
    final lastDay = DateTime(first.year, first.month + 1, 0).day;
    final day = original.day < lastDay ? original.day : lastDay;
    return DateTime(first.year, first.month, day);
  }

  /// Generates a bounded preview, not an automatic transaction.
  static List<PrimeScheduledOccurrence> upcoming({
    required List<PrimeScheduledItem> schedules,
    required DateTime from,
    required DateTime through,
    int maxOccurrences = 500,
  }) {
    if (_date(through).isBefore(_date(from)) || maxOccurrences < 1) {
      throw ArgumentError('بازه زمانی نامعتبر');
    }
    final output = <PrimeScheduledOccurrence>[];
    for (final item in schedules) {
      for (var index = 0; index < maxOccurrences; index++) {
        final due = item.frequency == PrimeScheduleFrequency.weekly
            ? _date(item.firstDue).add(Duration(days: index * 7))
            : _monthly(item.firstDue, index);
        if (due.isAfter(_date(through)) ||
            (item.endDate != null && due.isAfter(_date(item.endDate!)))) break;
        if (!due.isBefore(_date(from))) {
          output.add(PrimeScheduledOccurrence(item.id, due,
              item.isExpense ? -item.amount : item.amount));
          if (output.length >= maxOccurrences) {
            output.sort((a, b) => a.due.compareTo(b.due));
            return List.unmodifiable(output);
          }
        }
      }
    }
    output.sort((a, b) => a.due.compareTo(b.due));
    return List.unmodifiable(output);
  }

  static int projectedBalance(int openingBalance, List<PrimeScheduledOccurrence> events) {
    if (openingBalance < 0) throw ArgumentError('موجودی اولیه نامعتبر');
    return events.fold<int>(openingBalance, (sum, event) => sum + event.signedAmount);
  }
}
