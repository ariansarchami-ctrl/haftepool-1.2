import 'prime_wallet_engine.dart';
import 'prime_wallet_provenance.dart';

/// Read-only readiness report. Legacy entries have no walletId, so they must
/// never be assigned to a wallet by matching amounts or dates.
class PrimeWalletMappingAudit {
  final int legacyIncomeCount;
  final int legacyExpenseCount;
  final int legacyInternalTransferCount;
  final int unsupportedEntryCount;
  final int unknownWalletCount;
  final int mixedWalletCount;
  final int legacyFundedWalletCount;
  final int externalFundedWalletCount;
  final int legacyOpeningBalanceExposure;

  const PrimeWalletMappingAudit._({
    required this.legacyIncomeCount,
    required this.legacyExpenseCount,
    required this.legacyInternalTransferCount,
    required this.unsupportedEntryCount,
    required this.unknownWalletCount,
    required this.mixedWalletCount,
    required this.legacyFundedWalletCount,
    required this.externalFundedWalletCount,
    required this.legacyOpeningBalanceExposure,
  });

  /// [entries] must be a copy of legacy records, represented only by kind.
  /// All legacy entries are unassigned because the original schema has no
  /// wallet identifier; this audit does not invent a relationship.
  static PrimeWalletMappingAudit inspect({
    required Iterable<String> entryKinds,
    required PrimeWalletLedger ledger,
    required Map<String, PrimeWalletProvenance> provenance,
  }) {
    var income = 0, expense = 0, transfer = 0, other = 0;
    for (final kind in entryKinds) {
      switch (kind) {
        case 'income': income++; break;
        case 'expense': expense++; break;
        case 'transferOut':
        case 'transferIn': transfer++; break;
        default: other++; break;
      }
    }
    var unknown = 0, mixed = 0, legacy = 0, external = 0, exposure = 0;
    for (final wallet in ledger.wallets) {
      final source = provenance[wallet.id]?.source ?? PrimeOpeningSource.unknown;
      switch (source) {
        case PrimeOpeningSource.unknown: unknown++; break;
        case PrimeOpeningSource.mixed: mixed++; break;
        case PrimeOpeningSource.legacyFunds:
          legacy++;
          exposure += wallet.openingBalance;
          break;
        case PrimeOpeningSource.externalFunds: external++; break;
      }
    }
    return PrimeWalletMappingAudit._(
      legacyIncomeCount: income, legacyExpenseCount: expense,
      legacyInternalTransferCount: transfer, unsupportedEntryCount: other,
      unknownWalletCount: unknown, mixedWalletCount: mixed,
      legacyFundedWalletCount: legacy, externalFundedWalletCount: external,
      legacyOpeningBalanceExposure: exposure,
    );
  }

  int get unassignedLegacyEntries => legacyIncomeCount + legacyExpenseCount +
      legacyInternalTransferCount + unsupportedEntryCount;
  bool get automaticMigrationSafe => false;
}
