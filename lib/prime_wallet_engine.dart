/// Pure-Dart wallet ledger. Amounts are integer tomans; no implicit transfers.
/// This module does not mutate the existing FinanceModel until UI integration.
class PrimeWallet {
  final String id;
  final String name;
  final int openingBalance;
  final bool protected;
  const PrimeWallet({required this.id, required this.name,
    this.openingBalance = 0, this.protected = false});
  Map<String, Object> toJson() => {'id': id, 'name': name,
    'openingBalance': openingBalance, 'protected': protected};
  factory PrimeWallet.fromJson(Map<String, dynamic> json) => PrimeWallet(
    id: json['id'] as String, name: json['name'] as String,
    openingBalance: (json['openingBalance'] as num?)?.toInt() ?? 0,
    protected: json['protected'] == true);
}

class PrimeWalletMovement {
  final String id;
  final String fromId;
  final String toId;
  final int amount;
  final DateTime occurredAt;
  const PrimeWalletMovement({required this.id, required this.fromId,
    required this.toId, required this.amount, required this.occurredAt});
  Map<String, Object> toJson() => {'id': id, 'fromId': fromId,
    'toId': toId, 'amount': amount, 'occurredAt': occurredAt.toIso8601String()};
  factory PrimeWalletMovement.fromJson(Map<String, dynamic> json) => PrimeWalletMovement(
    id: json['id'] as String, fromId: json['fromId'] as String,
    toId: json['toId'] as String, amount: (json['amount'] as num).toInt(),
    occurredAt: DateTime.parse(json['occurredAt'] as String));
}

/// Validates every transfer before returning a new immutable ledger.
/// A transfer is NOT income or expense, and does not change total funds.
class PrimeWalletLedger {
  final List<PrimeWallet> wallets;
  final List<PrimeWalletMovement> movements;
  PrimeWalletLedger({required List<PrimeWallet> wallets,
    List<PrimeWalletMovement> movements = const []})
      : wallets = List.unmodifiable(wallets),
        movements = List.unmodifiable(movements) {
    if (wallets.map((w) => w.id).toSet().length != wallets.length) {
      throw StateError('شناسه کیف‌پول تکراری است');
    }
    for (final w in wallets) {
      if (w.id.isEmpty || w.name.trim().isEmpty || w.openingBalance < 0) {
        throw StateError('اطلاعات کیف‌پول نامعتبر است');
      }
    }
    if (movements.map((m) => m.id).toSet().length != movements.length) {
      throw StateError('شناسه انتقال تکراری است');
    }
    final balances = {for (final w in wallets) w.id: w.openingBalance};
    for (final movement in movements) {
      if (movement.amount <= 0 || movement.fromId == movement.toId ||
          !balances.containsKey(movement.fromId) ||
          !balances.containsKey(movement.toId)) {
        throw StateError('انتقال نامعتبر است');
      }
      if (balances[movement.fromId]! < movement.amount) {
        throw StateError('موجودی کیف‌پول کافی نیست');
      }
      balances[movement.fromId] = balances[movement.fromId]! - movement.amount;
      balances[movement.toId] = balances[movement.toId]! + movement.amount;
    }
  }
  int balanceOf(String walletId) {
    final wallet = wallets.where((w) => w.id == walletId);
    if (wallet.isEmpty) throw StateError('کیف‌پول پیدا نشد');
    var result = wallet.first.openingBalance;
    for (final m in movements) {
      if (m.fromId == walletId) result -= m.amount;
      if (m.toId == walletId) result += m.amount;
    }
    return result;
  }
  int get totalBalance => wallets.fold<int>(0, (sum, w) => sum + w.openingBalance);
  int get protectedBalance => wallets.where((w) => w.protected)
      .fold<int>(0, (sum, w) => sum + balanceOf(w.id));
  int get spendableBalance => totalBalance - protectedBalance;
  PrimeWalletLedger transfer(PrimeWalletMovement movement,
      {bool allowProtectedWithdrawal = false}) {
    if (movement.amount <= 0 || movement.fromId == movement.toId ||
        movements.any((m) => m.id == movement.id)) {
      throw StateError('انتقال نامعتبر یا تکراری است');
    }
    final from = wallets.where((w) => w.id == movement.fromId);
    final to = wallets.where((w) => w.id == movement.toId);
    if (from.isEmpty || to.isEmpty) throw StateError('کیف‌پول پیدا نشد');
    if (from.first.protected && !allowProtectedWithdrawal) {
      throw StateError('برداشت از صندوق محافظت‌شده نیازمند تأیید است');
    }
    if (balanceOf(movement.fromId) < movement.amount) {
      throw StateError('موجودی کافی نیست');
    }
    return PrimeWalletLedger(wallets: wallets,
        movements: [...movements, movement]);
  }
  Map<String, Object> toJson() => {
    'wallets': wallets.map((w) => w.toJson()).toList(),
    'movements': movements.map((m) => m.toJson()).toList(),
  };
  factory PrimeWalletLedger.fromJson(Map<String, dynamic> json) => PrimeWalletLedger(
    wallets: (json['wallets'] as List).map((e) =>
        PrimeWallet.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    movements: (json['movements'] as List? ?? []).map((e) =>
        PrimeWalletMovement.fromJson(Map<String, dynamic>.from(e as Map))).toList());
}
