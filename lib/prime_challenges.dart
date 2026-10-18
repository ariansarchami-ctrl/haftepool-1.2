/// Weekly challenges are observational: they never move money or edit entries.
enum PrimeChallengeType { categoryCap, noSpendDays }

class PrimeChallenge {
  final String id, week, category;
  final PrimeChallengeType type;
  final int target;
  const PrimeChallenge({required this.id,required this.week,required this.type,
    required this.target,this.category=''});
  Map<String,dynamic> toJson()=>{'id':id,'week':week,'type':type.name,
    'target':target,'category':category};
  factory PrimeChallenge.fromJson(Map<String,dynamic> x){
    final type=PrimeChallengeType.values.firstWhere((v)=>v.name==x['type'],
      orElse:()=>throw FormatException('نوع چالش ناشناخته است'));
    final challenge=PrimeChallenge(id:x['id'] as String,week:x['week'] as String,
      type:type,target:(x['target'] as num).toInt(),category:(x['category']??'') as String);
    challenge.validate();return challenge;
  }
  void validate(){
    if(id.trim().isEmpty||!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(week)||
      target<0||(type==PrimeChallengeType.noSpendDays&&(target<1||target>7))||
      (type==PrimeChallengeType.categoryCap&&category.trim().isEmpty)){
      throw const FormatException('اطلاعات چالش نامعتبر است');
    }
    final date=DateTime.tryParse(week);
    if(date==null||date.weekday!=DateTime.saturday)throw const FormatException('هفته چالش نامعتبر است');
  }
}
class PrimeChallengeExpense {
  final DateTime date;
  final String category;
  final int amount;
  const PrimeChallengeExpense(this.date,this.category,this.amount);
}
class PrimeChallengeProgress {
  final int achieved, target;
  final bool complete, failed;
  const PrimeChallengeProgress(this.achieved,this.target,this.complete,this.failed);
}
class PrimeChallengeEngine {
  static PrimeChallengeProgress evaluate(PrimeChallenge challenge,
      List<PrimeChallengeExpense> expenses,{required DateTime today}){
    challenge.validate();
    final start=DateTime.parse(challenge.week);
    final finish=start.add(const Duration(days:6));
    final cutoff=DateTime(today.year,today.month,today.day);
    final relevant=expenses.where((e)=>e.amount>0&&
      !e.date.isBefore(start)&&e.date.isBefore(finish.add(const Duration(days:1)))).toList();
    if(challenge.type==PrimeChallengeType.categoryCap){
      final spent=relevant.where((e)=>e.category==challenge.category)
        .fold<int>(0,(sum,e)=>sum+e.amount);
      return PrimeChallengeProgress(spent,challenge.target,
        !cutoff.isBefore(finish)&&spent<=challenge.target,spent>challenge.target);
    }
    final observedDays=cutoff.isBefore(start)?0:
      (cutoff.isAfter(finish)?7:cutoff.difference(start).inDays+1);
    final spentDates=relevant.where((e)=>!e.date.isAfter(cutoff))
      .map((e)=>DateTime(e.date.year,e.date.month,e.date.day)).toSet();
    final noSpend=observedDays-spentDates.length;
    return PrimeChallengeProgress(noSpend,challenge.target,
      noSpend>=challenge.target,observedDays==7&&noSpend<challenge.target);
  }
}
