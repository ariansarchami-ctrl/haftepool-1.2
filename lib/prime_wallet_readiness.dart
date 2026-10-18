/// Conservative readiness gate for a future, explicit wallet reconciliation.
/// This never posts entries or changes any balance.
class PrimeWalletReadiness {
  final List<String> blockers;
  final int mapped, total;
  const PrimeWalletReadiness(this.blockers, this.mapped, this.total);
  bool get readyForReview => blockers.isEmpty;
  static PrimeWalletReadiness inspect({
    required Iterable<String> walletIds,
    required Iterable<String> legacyEntryIds,
    required Map<String,String> entryWalletIds,
    required Iterable<String> walletIdsWithCutoff,
    required Iterable<String> walletIdsWithConfirmedOpening,
    required Iterable<String> walletIdsWithResolvedSource,
  }) {
    final ids=walletIds.toList();
    final entries=legacyEntryIds.toList();
    final idSet=ids.toSet(), entrySet=entries.toSet();
    final blockers=<String>[];
    if(ids.length!=idSet.length || entries.length!=entrySet.length){
      blockers.add('شناسه‌های تکراری در اطلاعات وجود دارد');
    }
    if(ids.isEmpty) blockers.add('هیچ کیف‌پولی ثبت نشده است');
    if(entryWalletIds.keys.any((id)=>!entrySet.contains(id)) ||
       entryWalletIds.values.any((id)=>!idSet.contains(id))){
      blockers.add('تطبیق نامعتبر یا مربوط به رکورد حذف‌شده وجود دارد');
    }
    final mapped=entries.where(entryWalletIds.containsKey).length;
    if(mapped<entries.length)blockers.add('${entries.length-mapped} تراکنش هنوز به کیف‌پول مرتبط نشده است');
    final cutoffs=walletIdsWithCutoff.toSet();
    final confirmed=walletIdsWithConfirmedOpening.toSet();
    final sources=walletIdsWithResolvedSource.toSet();
    if(idSet.difference(cutoffs).isNotEmpty)blockers.add('تاریخ مبنای همه کیف‌پول‌ها تعیین نشده است');
    if(idSet.difference(confirmed).isNotEmpty)blockers.add('موجودی اولیه در تاریخ مبنا برای همه کیف‌پول‌ها تأیید نشده است');
    if(idSet.difference(sources).isNotEmpty)blockers.add('منشأ موجودی برخی کیف‌پول‌ها نامشخص یا ترکیبی است');
    return PrimeWalletReadiness(List.unmodifiable(blockers),mapped,entries.length);
  }
}
