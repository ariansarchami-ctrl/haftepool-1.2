import 'prime_wallet_engine.dart';

/// Read-only audit: the legacy budget and the independent wallet ledger are
/// different accounting scopes. This never merges balances or creates money.
class PrimeWalletReconciliation {
  final int legacySpendable;
  final int legacySavings;
  final int walletTotal;
  final int walletProtected;
  final int walletSpendable;
  final int legacyTransferCount;
  final int walletTransferCount;
  final bool hasIndependentWallets;
  final bool legacySpendableIsNegative;

  const PrimeWalletReconciliation._({
    required this.legacySpendable,
    required this.legacySavings,
    required this.walletTotal,
    required this.walletProtected,
    required this.walletSpendable,
    required this.legacyTransferCount,
    required this.walletTransferCount,
    required this.hasIndependentWallets,
    required this.legacySpendableIsNegative,
  });

  factory PrimeWalletReconciliation.audit({
    required int legacySpendable,
    required int legacySavings,
    required int legacyTransferCount,
    required PrimeWalletLedger ledger,
  }) {
    if (legacyTransferCount < 0) {
      throw ArgumentError.value(legacyTransferCount, 'legacyTransferCount');
    }
    return PrimeWalletReconciliation._(
      legacySpendable: legacySpendable,
      legacySavings: legacySavings,
      walletTotal: ledger.totalBalance,
      walletProtected: ledger.protectedBalance,
      walletSpendable: ledger.spendableBalance,
      legacyTransferCount: legacyTransferCount,
      walletTransferCount: ledger.movements.length,
      hasIndependentWallets: ledger.wallets.isNotEmpty,
      legacySpendableIsNegative: legacySpendable < 0,
    );
  }

  /// Intentionally returns no combined total. Such a sum could double count.
  bool get automaticMergeIsSafe => false;
}
