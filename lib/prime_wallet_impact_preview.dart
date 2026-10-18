/// Read-only projection of explicitly mapped legacy income/expense entries.
/// Never add these deltas to wallet opening balances automatically: opening
/// balances may already contain the same historical transactions.
class PrimeMappedEntryImpact {
  final String id, walletId, kind;
  final int amount;
  const PrimeMappedEntryImpact({required this.id,required this.walletId,
    required this.kind,required this.amount});
}

class PrimeWalletImpactPreview {
  final Map<String,int> netByWallet;
  final int incomeCount, expenseCount, excludedCount;
  final int netChange;
  const PrimeWalletImpactPreview({required this.netByWallet,
    required this.incomeCount,required this.expenseCount,
    required this.excludedCount,required this.netChange});

  static PrimeWalletImpactPreview calculate({
    required Iterable<String> walletIds,
    required Iterable<PrimeMappedEntryImpact> entries,
  }) {
    final ids=walletIds.toList();
    if(ids.toSet().length!=ids.length)throw StateError('شناسه کیف‌پول تکراری');
    final totals={for(final id in ids) id:0};
    final seen=<String>{};
    var incomes=0,expenses=0,excluded=0,net=0;
    for(final e in entries){
      if(!seen.add(e.id)||!totals.containsKey(e.walletId)||e.amount<=0){
        throw StateError('تراکنش تطبیق‌داده‌شده نامعتبر');
      }
      final int delta;
      if(e.kind=='income'){
        delta=e.amount;incomes++;
      }else if(e.kind=='expense'){
        delta=-e.amount;expenses++;
      }else{
        excluded++;continue; // transfers are not income or expense
      }
      totals[e.walletId]=totals[e.walletId]!+delta;
      net+=delta;
    }
    return PrimeWalletImpactPreview(netByWallet:Map.unmodifiable(totals),
      incomeCount:incomes,expenseCount:expenses,
      excludedCount:excluded,netChange:net);
  }
}
