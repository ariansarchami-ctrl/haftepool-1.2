/// A user-confirmed association between an existing legacy transaction and a
/// wallet. This is annotation ONLY: it must never post a second transaction.
class PrimeWalletEntryMapping {
  final String entryId;
  final String walletId;
  final String note;
  const PrimeWalletEntryMapping({required this.entryId,required this.walletId,this.note=''});
  Map<String,dynamic> toJson()=>{'entryId':entryId,'walletId':walletId,'note':note};
  factory PrimeWalletEntryMapping.fromJson(Map<String,dynamic> x)=>PrimeWalletEntryMapping(
    entryId:x['entryId'] as String,walletId:x['walletId'] as String,note:x['note'] as String? ?? '');
}

class PrimeWalletEntryMappingRules {
  static void validate({required Iterable<String> entryIds,required Iterable<String> walletIds,
      required Iterable<PrimeWalletEntryMapping> mappings}) {
    final validEntries=entryIds.toSet(), validWallets=walletIds.toSet();
    if(validEntries.length!=entryIds.length)throw StateError('شناسه تراکنش تکراری است');
    if(validWallets.length!=walletIds.length)throw StateError('شناسه کیف‌پول تکراری است');
    final seen=<String>{};
    for(final link in mappings){
      if(!validEntries.contains(link.entryId)||!validWallets.contains(link.walletId)||!seen.add(link.entryId)){
        throw StateError('تطبیق تراکنش با کیف‌پول نامعتبر یا تکراری است');
      }
    }
  }
}
