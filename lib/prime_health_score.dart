/// Transparent financial health indicator, based only on completed weeks.
/// It is an educational budgeting indicator, not a credit score.
class PrimeHealthResult {
  final int? score;
  final int weeksUsed;
  final int budgetPoints;
  final int savingsPoints;
  final int consistencyPoints;
  final String explanation;
  const PrimeHealthResult({required this.score,required this.weeksUsed,
    required this.budgetPoints,required this.savingsPoints,
    required this.consistencyPoints,required this.explanation});
}

class PrimeHealthWeek {
  final int budget;
  final int expense;
  final int saved;
  const PrimeHealthWeek({required this.budget,required this.expense,required this.saved});
}

class PrimeHealthScore {
  /// 50 points: spending within budget; 30: actual saving relative to budget;
  /// 20: regularity of staying within budget. Minimum 4 completed funded weeks.
  static PrimeHealthResult calculate(List<PrimeHealthWeek> weeks) {
    final eligible=weeks.where((w)=>w.budget>0&&w.expense>=0&&w.saved>=0).toList();
    if(eligible.length<4){return PrimeHealthResult(score:null,weeksUsed:eligible.length,
      budgetPoints:0,savingsPoints:0,consistencyPoints:0,
      explanation:'برای امتیاز معتبر، حداقل ۴ هفته کامل با بودجه ثبت‌شده لازم است.');}
    final sample=eligible.length>12?eligible.sublist(eligible.length-12):eligible;
    final budgetTotal=sample.fold<int>(0,(s,w)=>s+w.budget);
    final expenseTotal=sample.fold<int>(0,(s,w)=>s+w.expense);
    final savedTotal=sample.fold<int>(0,(s,w)=>s+w.saved);
    // Overspending reduces points proportionally; underspending cannot exceed 50.
    final budgetRatio=expenseTotal<=budgetTotal?1.0:
      (1.0-(expenseTotal-budgetTotal)/budgetTotal).clamp(0.0,1.0);
    final budgetPoints=(50*budgetRatio).round();
    // Full savings points require 10% *actual* savings; no credit for targets.
    final savingsRatio=(savedTotal/(budgetTotal*0.10)).clamp(0.0,1.0);
    final savingsPoints=(30*savingsRatio).round();
    final within=sample.where((w)=>w.expense<=w.budget).length;
    final consistencyPoints=(20*within/sample.length).round();
    return PrimeHealthResult(score:budgetPoints+savingsPoints+consistencyPoints,
      weeksUsed:sample.length,budgetPoints:budgetPoints,savingsPoints:savingsPoints,
      consistencyPoints:consistencyPoints,
      explanation:'بودجه ۵۰ امتیاز، پس‌انداز واقعی ۳۰ امتیاز، ثبات هفتگی ۲۰ امتیاز. این امتیاز اعتبار بانکی نیست.');
  }
}
