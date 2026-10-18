/// User-declared opening balance date. Entries on/before the date are presumed
/// included in opening balance for PREVIEW ONLY; no ledger is posted.
class PrimeWalletCutoff {
  final String walletId;
  final DateTime openingDate;
  PrimeWalletCutoff({required this.walletId, required DateTime openingDate})
      : openingDate = DateTime(openingDate.year, openingDate.month, openingDate.day) {
    if (walletId.trim().isEmpty) throw const FormatException('شناسه کیف‌پول نامعتبر');
  }
  Map<String, String> toJson() => {
    'walletId': walletId,
    'openingDate': '${openingDate.year.toString().padLeft(4, '0')}-${openingDate.month.toString().padLeft(2, '0')}-${openingDate.day.toString().padLeft(2, '0')}',
  };
  factory PrimeWalletCutoff.fromJson(Map<String, dynamic> json) {
    final id = json['walletId'];
    final raw = json['openingDate'];
    if (id is! String || raw is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      throw const FormatException('تاریخ مبنای موجودی نامعتبر');
    }
    final date = DateTime.tryParse(raw);
    if (date == null || date.year.toString().padLeft(4,'0') != raw.substring(0,4) ||
        date.month.toString().padLeft(2,'0') != raw.substring(5,7) ||
        date.day.toString().padLeft(2,'0') != raw.substring(8,10)) {
      throw const FormatException('تاریخ مبنای موجودی نامعتبر');
    }
    return PrimeWalletCutoff(walletId:id, openingDate:date);
  }
}

class PrimeDatedWalletImpact {
  final String walletId, kind, date;
  final int amount;
  const PrimeDatedWalletImpact(this.walletId, this.kind, this.date, this.amount);
}

class PrimeCutoffPreview {
  final Map<String,int> postOpeningNet;
  final int included, beforeOrOnCutoff, missingCutoff, excludedTransfers;
  const PrimeCutoffPreview(this.postOpeningNet,this.included,
      this.beforeOrOnCutoff,this.missingCutoff,this.excludedTransfers);
  static PrimeCutoffPreview calculate({
    required Iterable<String> walletIds,
    required Map<String,PrimeWalletCutoff> cutoffs,
    required Iterable<PrimeDatedWalletImpact> entries,
  }) {
    final ids=walletIds.toSet();
    if(ids.length!=walletIds.length)throw StateError('شناسه کیف‌پول تکراری');
    final net={for(final id in ids)id:0};
    for(final item in cutoffs.entries){
      if(!ids.contains(item.key)||item.value.walletId!=item.key)throw StateError('تاریخ مبنای کیف‌پول نامعتبر');
    }
    var included=0,earlier=0,missing=0,transfers=0;
    for(final e in entries){
      if(!ids.contains(e.walletId)||e.amount<=0)throw StateError('تراکنش نامعتبر');
      if(e.kind!='income'&&e.kind!='expense'){transfers++;continue;}
      final cutoff=cutoffs[e.walletId];
      if(cutoff==null){missing++;continue;}
      final parsed=DateTime.tryParse(e.date);
      if(parsed==null)throw const FormatException('تاریخ تراکنش نامعتبر');
      final entryDate=DateTime(parsed.year,parsed.month,parsed.day);
      if(!entryDate.isAfter(cutoff.openingDate)){earlier++;continue;}
      net[e.walletId]=net[e.walletId]!+(e.kind=='income'?e.amount:-e.amount);
      included++;
    }
    return PrimeCutoffPreview(Map.unmodifiable(net),included,earlier,missing,transfers);
  }
}
