/// User-attested opening balance evidence. This is NOT bank verification and
/// never posts any ledger movements.
class PrimeWalletOpeningConfirmation {
  final String walletId;
  final String cutoffDate;
  final int openingBalance;
  final String evidenceNote;
  final DateTime attestedAt;
  PrimeWalletOpeningConfirmation({required this.walletId, required this.cutoffDate,
    required this.openingBalance, required this.evidenceNote, required this.attestedAt}) {
    if(walletId.trim().isEmpty || openingBalance<0 || evidenceNote.trim().length<8 ||
       !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(cutoffDate) ||
       DateTime.tryParse(cutoffDate)==null) {
      throw const FormatException('تأیید موجودی اولیه نامعتبر است');
    }
  }
  Map<String,dynamic> toJson()=>{'walletId':walletId,'cutoffDate':cutoffDate,
    'openingBalance':openingBalance,'evidenceNote':evidenceNote,
    'attestedAt':attestedAt.toIso8601String()};
  factory PrimeWalletOpeningConfirmation.fromJson(Map<String,dynamic> json)=>
    PrimeWalletOpeningConfirmation(walletId:json['walletId'] as String,
      cutoffDate:json['cutoffDate'] as String,
      openingBalance:(json['openingBalance'] as num).toInt(),
      evidenceNote:json['evidenceNote'] as String,
      attestedAt:DateTime.parse(json['attestedAt'] as String));
  bool matches({required String wallet,required String date,required int balance})=>
    walletId==wallet && cutoffDate==date && openingBalance==balance;
}
