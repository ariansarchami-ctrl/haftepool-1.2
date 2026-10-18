/// User-declared provenance of opening balances. Metadata only: no accounting
/// effects, no automatic reconciliation, and no claims of verified ownership.
enum PrimeOpeningSource { unknown, legacyFunds, externalFunds, mixed }

class PrimeWalletProvenance {
  final String walletId;
  final PrimeOpeningSource source;
  final String note;
  const PrimeWalletProvenance({required this.walletId, required this.source, this.note = ''});

  Map<String, dynamic> toJson() => {
    'walletId': walletId,
    'source': source.name,
    'note': note,
  };

  factory PrimeWalletProvenance.fromJson(Map<String, dynamic> json) {
    final id = json['walletId'];
    final raw = json['source'];
    if (id is! String || id.trim().isEmpty || raw is! String) {
      throw const FormatException('Invalid wallet provenance');
    }
    final matches = PrimeOpeningSource.values.where((e) => e.name == raw);
    if (matches.length != 1) throw const FormatException('Unknown source');
    final note = json['note'];
    if (note != null && note is! String) throw const FormatException('Invalid note');
    return PrimeWalletProvenance(walletId: id, source: matches.single, note: note ?? '');
  }
}

class PrimeWalletProvenanceAudit {
  static bool hasUnresolved({
    required Iterable<String> walletIds,
    required Map<String, PrimeWalletProvenance> declarations,
  }) => walletIds.any((id) =>
      declarations[id] == null ||
      declarations[id]!.source == PrimeOpeningSource.unknown ||
      declarations[id]!.source == PrimeOpeningSource.mixed);

  /// Even a fully labeled ledger needs manual reconciliation: labels are
  /// user statements, not evidence that balances are disjoint.
  static bool get automaticMergeAllowed => false;
}
