import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'prime_data_safety.dart';
import 'prime_analytics.dart';
import 'prime_savings_advisor.dart';
import 'prime_planning_engine.dart' hide PrimeWallet, PrimeWalletLedger;
import 'prime_wallet_engine.dart';
import 'prime_wallet_reconciliation.dart';
import 'prime_wallet_mapping_audit.dart';
import 'prime_wallet_entry_mapping.dart';
import 'prime_wallet_impact_preview.dart';
import 'prime_wallet_cutoff.dart';
import 'prime_wallet_readiness.dart';
import 'prime_wallet_opening_confirmation.dart';
import 'prime_wallet_provenance.dart';
import 'prime_health_score.dart';
import 'prime_purchase_forecast.dart';
import 'prime_cashflow_risk.dart';
import 'prime_goal_scenarios.dart' hide PrimeChallengeEngine;
import 'prime_challenges.dart';
import 'prime_reporting_engine.dart';
import 'prime_preferences.dart';
import 'prime31_dashboard.dart';
import 'prime32_calendar_data.dart';
import 'prime32_calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const HaftepoolApp()); }

final nf = NumberFormat.decimalPattern('fa');
String toman(num value) => '${nf.format(value.round())} تومان';
DateTime day(DateTime d) => DateTime(d.year,d.month,d.day);
DateTime weekStart(DateTime d) => day(d).subtract(Duration(days:(d.weekday+1)%7));
String dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
DateTime parseDate(String s) => DateTime.parse(s);
const weekdays=['شنبه','یکشنبه','دوشنبه','سه‌شنبه','چهارشنبه','پنجشنبه','جمعه'];

class Entry {
  final String id,kind,category,note,date,account,toAccount;
  final int amount;
  Entry({required this.id,required this.kind,required this.amount,required this.date,this.category='سایر',this.note='',this.account='budget',this.toAccount='' });
  Map<String,dynamic> toJson()=>{'id':id,'kind':kind,'amount':amount,'date':date,'category':category,'note':note,'account':account,'toAccount':toAccount};
  factory Entry.fromJson(Map<String,dynamic> x)=>Entry(id:'${x['id']}',kind:'${x['kind']}',amount:(x['amount'] as num).toInt(),date:'${x['date']}',category:'${x['category']??'سایر'}',note:'${x['note']??''}',account:'${x['account']??'budget'}',toAccount:'${x['toAccount']??''}');
}
class Goal {
  String id,name; int price,initial,weekly;
  Goal(this.id,this.name,this.price,this.initial,this.weekly);
  Map<String,dynamic> toJson()=>{'id':id,'name':name,'price':price,'initial':initial,'weekly':weekly};
  factory Goal.fromJson(Map<String,dynamic> x)=>Goal('${x['id']}','${x['name']}',(x['price'] as num).toInt(),(x['initial'] as num).toInt(),(x['weekly'] as num).toInt());
}
Map<String,dynamic> scheduleToJson(PrimeScheduledItem s)=>{
  'id':s.id,'title':s.title,'amount':s.amount,'isExpense':s.isExpense,
  'firstDue':dateKey(s.firstDue),'frequency':s.frequency.name,
  'endDate':s.endDate==null?null:dateKey(s.endDate!),
};
PrimeScheduledItem scheduleFromJson(Map<String,dynamic> x)=>PrimeScheduledItem(
  id:x['id'] as String,title:x['title'] as String,amount:(x['amount'] as num).toInt(),
  isExpense:x['isExpense'] as bool,firstDue:parseDate(x['firstDue'] as String),
  frequency:x['frequency']=='monthly'?PrimeScheduleFrequency.monthly:PrimeScheduleFrequency.weekly,
  endDate:x['endDate']==null?null:parseDate(x['endDate'] as String),
);

class FinanceModel extends ChangeNotifier {
  final List<Entry> entries=[]; final List<Goal> goals=[];
  final List<PrimeScheduledItem> schedules=[];
  final List<PrimeChallenge> challenges=[];
  PrimeWalletLedger walletLedger=PrimeWalletLedger(wallets:[]);
  final Map<String,PrimeWalletProvenance> walletProvenance={};
  final Map<String,PrimeWalletEntryMapping> walletEntryMappings={};
  final Map<String,PrimeWalletCutoff> walletCutoffs={};
  final Map<String,PrimeWalletOpeningConfirmation> walletOpeningConfirmations={};
  final Map<String,int> budgets={},targets={};
  final Map<String,Map<String,int>> settlements={};
  final Map<String,int> debts={};
  List<int> weights=[10,10,10,10,10,15,18];
  int dayStartHour=0; bool loaded=false;
  late SharedPreferences prefs;
  Future<void> load() async {
    prefs=await SharedPreferences.getInstance();
    final raw=prefs.getString('haftepool_native_v1');
    if(raw!=null){try{
      final m=jsonDecode(raw) as Map<String,dynamic>;
      entries.addAll((m['entries'] as List? ?? []).map((x)=>Entry.fromJson(Map<String,dynamic>.from(x))));
      goals.addAll((m['goals'] as List? ?? []).map((x)=>Goal.fromJson(Map<String,dynamic>.from(x))));
      schedules.addAll((m['primeSchedules'] as List? ?? []).map((x)=>scheduleFromJson(Map<String,dynamic>.from(x))));
      challenges.addAll((m['primeChallenges'] as List? ?? []).map((x)=>PrimeChallenge.fromJson(Map<String,dynamic>.from(x))));
      if(m['primeWalletLedger'] is Map)walletLedger=PrimeWalletLedger.fromJson(Map<String,dynamic>.from(m['primeWalletLedger'] as Map));
      for(final x in (m['primeWalletProvenance'] as List? ?? [])){
        final item=PrimeWalletProvenance.fromJson(Map<String,dynamic>.from(x as Map));
        if(walletLedger.wallets.any((w)=>w.id==item.walletId))walletProvenance[item.walletId]=item;
      }
      for(final x in (m['primeWalletEntryMappings'] as List? ?? [])){
        final item=PrimeWalletEntryMapping.fromJson(Map<String,dynamic>.from(x as Map));
        if(entries.any((e)=>e.id==item.entryId) && walletLedger.wallets.any((w)=>w.id==item.walletId)){
          walletEntryMappings[item.entryId]=item;
        }
      }
      for(final x in (m['primeWalletCutoffs'] as List? ?? [])){
        final item=PrimeWalletCutoff.fromJson(Map<String,dynamic>.from(x as Map));
        if(walletLedger.wallets.any((w)=>w.id==item.walletId))walletCutoffs[item.walletId]=item;
      }
      for(final x in (m['primeWalletOpeningConfirmations'] as List? ?? [])){
        final item=PrimeWalletOpeningConfirmation.fromJson(Map<String,dynamic>.from(x as Map));
        final wallet=walletLedger.wallets.where((w)=>w.id==item.walletId);
        final cutoff=walletCutoffs[item.walletId];
        if(wallet.isNotEmpty && cutoff!=null && item.matches(wallet:item.walletId,
            date:dateKey(cutoff.openingDate),balance:wallet.first.openingBalance)){
          walletOpeningConfirmations[item.walletId]=item;
        }
      }
      budgets.addAll((m['budgets'] as Map? ?? {}).map((k,v)=>MapEntry('$k',(v as num).toInt())));
      targets.addAll((m['targets'] as Map? ?? {}).map((k,v)=>MapEntry('$k',(v as num).toInt())));
      debts.addAll((m['debts'] as Map? ?? {}).map((k,v)=>MapEntry('$k',(v as num).toInt())));
      (m['settlements'] as Map? ?? {}).forEach((k,v){settlements['$k']=Map<String,int>.from((v as Map).map((a,b)=>MapEntry('$a',(b as num).toInt())));});
      if(m['weights'] is List && (m['weights'] as List).length==7)weights=List<int>.from(m['weights']);
      dayStartHour=(m['dayStartHour'] as num? ?? 0).toInt();
    }catch(_){}}
    loaded=true;notifyListeners();
  }
  Map<String,dynamic> toJson()=>{'entries':entries.map((e)=>e.toJson()).toList(),'goals':goals.map((e)=>e.toJson()).toList(),'budgets':budgets,'targets':targets,'settlements':settlements,'debts':debts,'weights':weights,'dayStartHour':dayStartHour,'primeSchedules':schedules.map(scheduleToJson).toList(),'primeChallenges':challenges.map((c)=>c.toJson()).toList(),'primeWalletLedger':walletLedger.toJson(),'primeWalletProvenance':walletProvenance.values.map((x)=>x.toJson()).toList(),'primeWalletEntryMappings':walletEntryMappings.values.map((x)=>x.toJson()).toList(),'primeWalletCutoffs':walletCutoffs.values.map((x)=>x.toJson()).toList(),'primeWalletOpeningConfirmations':walletOpeningConfirmations.values.map((x)=>x.toJson()).toList()};
  Future<void> save()async{await prefs.setString('haftepool_native_v1',jsonEncode(toJson()));notifyListeners();}
  String createPortableBackup()=>PrimeBackup.exportJson(toJson());
  Future<void> restorePortableBackup(String raw) async {
    final state=PrimeBackup.previewImport(raw);
    // Parse every known field BEFORE modifying persisted or in-memory data.
    final parsedEntries=(state['entries'] as List? ?? [])
        .map((x)=>Entry.fromJson(Map<String,dynamic>.from(x as Map))).toList();
    final parsedSchedules=(state['primeSchedules'] as List? ?? []).map((x)=>scheduleFromJson(Map<String,dynamic>.from(x as Map))).toList();
    final parsedChallenges=(state['primeChallenges'] as List? ?? []).map((x)=>PrimeChallenge.fromJson(Map<String,dynamic>.from(x as Map))).toList();
    final parsedLedger=state['primeWalletLedger'] is Map ? PrimeWalletLedger.fromJson(Map<String,dynamic>.from(state['primeWalletLedger'] as Map)) : PrimeWalletLedger(wallets:[]);
    final parsedProvenance=<String,PrimeWalletProvenance>{};
    for(final x in (state['primeWalletProvenance'] as List? ?? [])){
      final item=PrimeWalletProvenance.fromJson(Map<String,dynamic>.from(x as Map));
      if(!parsedLedger.wallets.any((w)=>w.id==item.walletId)||parsedProvenance.containsKey(item.walletId)){
        throw const FormatException('اطلاعات منبع موجودی کیف‌پول نامعتبر است');
      }
      parsedProvenance[item.walletId]=item;
    }
    final parsedMappings=<String,PrimeWalletEntryMapping>{};
    for(final x in (state['primeWalletEntryMappings'] as List? ?? [])){
      final item=PrimeWalletEntryMapping.fromJson(Map<String,dynamic>.from(x as Map));
      if(parsedMappings.containsKey(item.entryId))throw const FormatException('تطبیق تکراری است');
      parsedMappings[item.entryId]=item;
    }
    PrimeWalletEntryMappingRules.validate(
      entryIds:parsedEntries.map((e)=>e.id).toList(),
      walletIds:parsedLedger.wallets.map((w)=>w.id).toList(),
      mappings:parsedMappings.values.toList());
    final parsedCutoffs=<String,PrimeWalletCutoff>{};
    for(final x in (state['primeWalletCutoffs'] as List? ?? [])){
      final item=PrimeWalletCutoff.fromJson(Map<String,dynamic>.from(x as Map));
      if(!parsedLedger.wallets.any((w)=>w.id==item.walletId)||parsedCutoffs.containsKey(item.walletId)){
        throw const FormatException('تاریخ مبنای کیف‌پول نامعتبر است');
      }
      parsedCutoffs[item.walletId]=item;
    }
    final parsedConfirmations=<String,PrimeWalletOpeningConfirmation>{};
    for(final x in (state['primeWalletOpeningConfirmations'] as List? ?? [])){
      final item=PrimeWalletOpeningConfirmation.fromJson(Map<String,dynamic>.from(x as Map));
      final wallets=parsedLedger.wallets.where((w)=>w.id==item.walletId);
      final cutoff=parsedCutoffs[item.walletId];
      if(parsedConfirmations.containsKey(item.walletId)||wallets.isEmpty||cutoff==null||
          !item.matches(wallet:item.walletId,date:dateKey(cutoff.openingDate),
            balance:wallets.first.openingBalance)){
        throw const FormatException('تأیید موجودی اولیه با تاریخ یا مبلغ کیف‌پول سازگار نیست');
      }
      parsedConfirmations[item.walletId]=item;
    }
    final parsedGoals=(state['goals'] as List? ?? [])
        .map((x)=>Goal.fromJson(Map<String,dynamic>.from(x as Map))).toList();
    Map<String,int> numbers(String key)=> (state[key] as Map? ?? {})
        .map((k,v)=>MapEntry('$k',(v as num).toInt()));
    final parsedBudgets=numbers('budgets');
    final parsedTargets=numbers('targets');
    final parsedDebts=numbers('debts');
    final parsedSettlements=<String,Map<String,int>>{};
    (state['settlements'] as Map? ?? {}).forEach((k,v){
      parsedSettlements['$k']=Map<String,int>.from(
          (v as Map).map((a,b)=>MapEntry('$a',(b as num).toInt())));
    });
    final parsedWeights=state['weights']==null ? List<int>.from(weights)
        : List<int>.from(state['weights'] as List);
    final parsedHour=(state['dayStartHour'] as num? ?? 0).toInt();
    if(parsedHour<0||parsedHour>23)throw StateError('ساعت شروع روز نامعتبر است');
    // A failed persistent write must leave the active state untouched.
    final ok=await prefs.setString('haftepool_native_v1',jsonEncode(state));
    if(!ok)throw StateError('ذخیره فایل بازیابی ناموفق بود');
    entries..clear()..addAll(parsedEntries);
    goals..clear()..addAll(parsedGoals);
    schedules..clear()..addAll(parsedSchedules);
    challenges..clear()..addAll(parsedChallenges);
    walletLedger=parsedLedger;
    walletProvenance..clear()..addAll(parsedProvenance);
    walletEntryMappings..clear()..addAll(parsedMappings);
    walletCutoffs..clear()..addAll(parsedCutoffs);
    walletOpeningConfirmations..clear()..addAll(parsedConfirmations);
    budgets..clear()..addAll(parsedBudgets);
    targets..clear()..addAll(parsedTargets);
    debts..clear()..addAll(parsedDebts);
    settlements..clear()..addAll(parsedSettlements);
    weights=parsedWeights;
    dayStartHour=parsedHour;
    notifyListeners();
  }

  DateTime get financialToday {final now=DateTime.now();return day(now.hour<dayStartHour?now.subtract(const Duration(days:1)):now);}
  String get currentWeek=>dateKey(weekStart(financialToday));
  String weekOf(String d)=>dateKey(weekStart(parseDate(d)));
  List<Entry> entriesFor(String week)=>entries.where((e)=>weekOf(e.date)==week).toList();
  int total(String week,String kind)=>entriesFor(week).where((e)=>e.kind==kind).fold(0,(a,e)=>a+e.amount);
  int get currentBudget=>budgets[currentWeek]??0;
  int get currentTarget=>targets[currentWeek]??0;
  int get carryIn=>settlements.entries.where((x)=>dateKey(weekStart(parseDate(x.key).add(const Duration(days:7))))==currentWeek).fold<int>(0,(a,x)=>a+((x.value['next']??0) as num).toInt());
  int get income=>total(currentWeek,'income');
  int get expense=>total(currentWeek,'expense');
  int get available=>currentBudget+carryIn+income-expense-total(currentWeek,'transferOut');
  int get savedBalance=>entries.where((e)=>e.kind=='transferOut'&&e.toAccount=='savings').fold<int>(0,(a,e)=>a+e.amount)-entries.where((e)=>e.kind=='transferIn'&&e.account=='savings').fold<int>(0,(a,e)=>a+e.amount)+settlements.values.fold<int>(0,(a,x)=>a+((x['saving']??0) as num).toInt());
  int goalBalance(Goal g)=>g.initial+entries.where((e)=>e.kind=='transferOut'&&e.toAccount=='goal:${g.id}').fold<int>(0,(a,e)=>a+e.amount)-entries.where((e)=>e.kind=='transferIn'&&e.account=='goal:${g.id}').fold<int>(0,(a,e)=>a+e.amount);
  int dailyAllowance(int i){final alloc=max(0,currentBudget-currentTarget),sum=weights.reduce((a,b)=>a+b);return sum>0?(alloc*weights[i]/sum).floor():0;}
  int spentOn(DateTime d)=>entries.where((e)=>e.kind=='expense'&&e.date==dateKey(d)).fold(0,(a,e)=>a+e.amount);
  double get expectedSpend {final h=budgets.keys.where((k)=>k!=currentWeek&&k.compareTo(currentWeek)<0).toList()..sort();if(h.isEmpty)return 0;final last=h.reversed.take(8).toList();return last.map((k)=>total(k,'expense')).reduce((a,b)=>a+b)/last.length;}
  int? get suggestedSavings {final h=budgets.keys.where((k)=>k.compareTo(currentWeek)<0).toList()..sort();if(h.isEmpty)return null;final recent=h.reversed.take(8).toList();final vals=recent.map((k)=>max(0,(budgets[k]??0)+total(k,'income')-total(k,'expense'))).toList();return (vals.reduce((a,b)=>a+b)/vals.length/50000).floor()*50000;}
  int get projectedSpend {final idx=(financialToday.difference(weekStart(financialToday)).inDays).clamp(0,6);final elapsed=idx+1;final actual=expense;final pace=actual/elapsed*7;return max<int>(actual, ((pace * 0.65) + (expectedSpend > 0 ? expectedSpend : pace) * 0.35).round());}
  bool get unusualExpense {final idx=(financialToday.difference(weekStart(financialToday)).inDays).clamp(0,6);final historical=<int>[];for(final k in budgets.keys){if(k==currentWeek)continue;final d=parseDate(k).add(Duration(days:idx));historical.add(spentOn(d));}if(historical.length<3)return false;final avg=historical.reduce((a,b)=>a+b)/historical.length;return spentOn(financialToday)>max(100000,avg*1.8);}
  void updateEntry(String id,int amount,String category,String note){
    if(amount<=0)throw StateError('مبلغ باید بیشتر از صفر باشد');
    final i=entries.indexWhere((e)=>e.id==id);
    if(i<0)throw StateError('تراکنش پیدا نشد');
    final old=entries[i];
    if(old.kind!='expense'&&old.kind!='income')throw StateError('ویرایش این نوع تراکنش هنوز فعال نیست');
    entries[i]=Entry(id:old.id,kind:old.kind,amount:amount,date:old.date,category:category,note:note,account:old.account,toAccount:old.toAccount);
    save();
  }
  void deleteEntry(String id){
    final i=entries.indexWhere((e)=>e.id==id);
    if(i<0)throw StateError('تراکنش پیدا نشد');
    if(entries[i].kind!='expense'&&entries[i].kind!='income')throw StateError('حذف این نوع تراکنش هنوز فعال نیست');
    entries.removeAt(i);save();
  }
  void addEntry(
    String kind,
    int amount, {
    String category = 'سایر',
    String note = '',
    String account = 'budget',
    String toAccount = '',
    DateTime? selectedDate,
  }) {
    if (amount <= 0) return;
    final entryDate = selectedDate ?? financialToday;
    if (entryDate.isAfter(financialToday)) {
      throw StateError('ثبت تراکنش برای روزهای آینده مجاز نیست');
    }
    entries.add(Entry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      kind: kind,
      amount: amount,
      date: dateKey(entryDate),
      category: category,
      note: note,
      account: account,
      toAccount: toAccount,
    ));
    save();
  }

  void transfer(int amount,String to){if(amount<=0||amount>available)throw StateError('موجودی بودجه کافی نیست');addEntry('transferOut',amount,toAccount:to);}
  void settle(String week,int saving){if(settlements.containsKey(week))throw StateError('این هفته قبلاً تسویه شده');final rem=max(0,(budgets[week]??0)+total(week,'income')-total(week,'expense')-total(week,'transferOut'));if(saving<0||saving>rem)throw StateError('مبلغ تقسیم نامعتبر است');settlements[week]={'saving':saving,'next':rem-saving};save();}
  void configureWeek(int budget,int target){
    if(budget<0||target<0||target>budget)throw StateError('بودجه یا هدف پس‌انداز نامعتبر است');
    budgets[currentWeek]=budget;targets[currentWeek]=target;save();
  }
  void planNextWeek(int budget,int saving,{bool replaceExisting=false}){
    if(budget<0||saving<0||saving>budget)throw StateError('مبلغ بودجه یا پس‌انداز نامعتبر است');
    final next=dateKey(weekStart(financialToday).add(const Duration(days:7)));
    if(!replaceExisting&&(budgets.containsKey(next)||targets.containsKey(next))){
      throw StateError('برای هفته آینده قبلاً برنامه ثبت شده است');
    }
    budgets[next]=budget;targets[next]=saving;save();
  }
  void addGoal(String name,int price,int initial,int weekly){if(name.isEmpty||price<=0||initial<0||weekly<0)return;goals.add(Goal(DateTime.now().microsecondsSinceEpoch.toString(),name,price,initial,weekly));save();}
  Future<void> addSchedule(PrimeScheduledItem item) async {
    if(schedules.any((x)=>x.id==item.id))throw StateError('شناسه تکراری');
    schedules.add(item);
    try { await save(); } catch (_) { schedules.remove(item); rethrow; }
  }
  Future<void> removeSchedule(String id) async {
    final index=schedules.indexWhere((x)=>x.id==id);
    if(index<0)return;
    final removed=schedules.removeAt(index);
    try { await save(); } catch (_) { schedules.insert(index,removed); rethrow; }
  }
  Future<void> updatePreferences(PrimePreferences preferences) async {
    // Persist first: a failed write does not mutate the live preferences.
    final next=Map<String,dynamic>.from(toJson());
    next['dayStartHour']=preferences.dayStartHour;
    next['weights']=preferences.dayWeights.toList();
    final ok=await prefs.setString('haftepool_native_v1',jsonEncode(next));
    if(!ok)throw StateError('ذخیره تنظیمات انجام نشد');
    dayStartHour=preferences.dayStartHour;
    weights=preferences.dayWeights.toList();
    notifyListeners();
  }
  void changeDebt(String name,int amount){debts[name]=(debts[name]??0)+amount;save();}
}

class HaftepoolApp extends StatefulWidget {const HaftepoolApp({super.key});@override State<HaftepoolApp> createState()=>_HaftepoolAppState();}
class _HaftepoolAppState extends State<HaftepoolApp>{final model=FinanceModel();@override void initState(){super.initState();model.load();} @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,title:'هفته‌پول PRIME',locale:const Locale('fa'),theme:ThemeData(useMaterial3:true,colorSchemeSeed:const Color(0xff087f75),scaffoldBackgroundColor:const Color(0xfff1f5f9)),home:AnimatedBuilder(animation:model,builder:(context,_)=>model.loaded?Home(model):const Scaffold(body:Center(child:CircularProgressIndicator()))));}
class Home extends StatefulWidget{final FinanceModel m;const Home(this.m,{super.key});@override State<Home> createState()=>_HomeState();}
class _HomeState extends State<Home>{
  int tab=0;
  bool showCalendar=false;
  bool showWallets=false;
  String historyQuery='';
  String historyKind='all';
  String historyCategory='all';
  FinanceModel get m=>widget.m;
Future<void> preferencesDialog() async {
  int hour=m.dayStartHour;
  final chosen=List<int>.from(m.weights);
  await showDialog<void>(context:context,builder:(dialogContext)=>StatefulBuilder(
    builder:(context,refresh)=>AlertDialog(
      title:const Text('شخصی‌سازی هفته‌پول'),
      content:SizedBox(width:440,child:SingleChildScrollView(child:Column(
        mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          const Text('ساعت شروع روز مالی'),
          DropdownButton<int>(isExpanded:true,value:hour,
            items:[for(var i=0;i<24;i++)DropdownMenuItem(value:i,child:Text('${i.toString().padLeft(2,'0')}:00'))],
            onChanged:(v){if(v!=null)refresh(()=>hour=v);}),
          const Text('سهم نسبی هر روز از بودجه قابل‌خرج هفته'),
          const Text('این اعداد درصد نیستند؛ برنامه نسبت آن‌ها را محاسبه می‌کند.',style:TextStyle(fontSize:12)),
          for(var i=0;i<7;i++)Row(children:[
            SizedBox(width:85,child:Text(weekdays[i])),
            Expanded(child:Slider(value:chosen[i].clamp(0,100).toDouble(),min:0,max:100,divisions:20,
              label:'${chosen[i]}',onChanged:(v)=>refresh(()=>chosen[i]=v.round()))),
            SizedBox(width:30,child:Text('${chosen[i]}')),
          ]),
          Text('مجموع سهم‌ها: ${chosen.fold<int>(0,(a,b)=>a+b)}'),
          if(chosen.every((x)=>x==0))const Text('حداقل سهم یک روز باید بیشتر از صفر باشد.',style:TextStyle(color:Colors.red)),
          TextButton(onPressed:()=>refresh((){for(var i=0;i<7;i++)chosen[i]=10;hour=0;}),child:const Text('بازنشانی تنظیمات')),
        ],
      ))),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('انصراف')),
        FilledButton(onPressed:chosen.every((x)=>x==0)?null:() async {
          try {
            await m.updatePreferences(PrimePreferences(dayStartHour:hour,dayWeights:chosen));
            if(dialogContext.mounted)Navigator.pop(dialogContext);
          } catch(e) {
            if(dialogContext.mounted)ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content:Text('خطا در ذخیره تنظیمات: $e')));
          }
        },child:const Text('ذخیره')),
      ],
    ),
  ));
}

Future<void> cashflowForecastDialog() async {
  final now=day(m.financialToday);
  final until=now.add(const Duration(days:30));
  final scheduled=PrimeCalendarPlanner.upcoming(
    schedules:m.schedules,from:now,through:until);
  // Existing spendable balance is the only starting balance. Wallet balances
  // remain separate until the legacy migration has been reconciled.
  final opening=max(0,m.available);
  final forecast=PrimeCashflowRisk.forecast(
    openingBalance:opening,protectedReserve:0,from:now,
    through:until,occurrences:scheduled);
  if(!mounted)return;
  await showDialog<void>(context:context,builder:(c)=>AlertDialog(
    title:const Text('پیش‌بینی جریان نقدی ۳۰ روزه'),
    content:SizedBox(width:420,child:SingleChildScrollView(child:Column(
      mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,
      children:[
        const Text('بر اساس مانده قابل‌خرج فعلی و فقط سررسیدهای تکرارشونده ثبت‌شده. این پیش‌بینی پرداخت واقعی انجام نمی‌دهد.'),
        const SizedBox(height:10),
        Text('مانده آغازین: ${toman(opening)}'),
        Text('کمترین مانده پیش‌بینی‌شده: ${toman(forecast.lowestBalance)}'),
        if(forecast.firstShortfall!=null)...[
          Text('اولین روز کسری: ${dateKey(forecast.firstShortfall!)}',
            style:const TextStyle(color:Colors.deepOrange,fontWeight:FontWeight.bold)),
          Text('پول موردنیاز برای جلوگیری از کسری: ${toman(forecast.requiredBuffer)}'),
        ]else const Text('با برنامه‌های ثبت‌شده، کسری پیش‌بینی نمی‌شود.'),
        const Divider(),
        if(scheduled.isEmpty)const Text('هیچ سررسید تکرارشونده‌ای برای ۳۰ روز آینده ثبت نشده است.'),
        for(final point in forecast.days.where((d)=>d.incoming>0||d.outgoing>0))
          ListTile(dense:true,contentPadding:EdgeInsets.zero,
            title:Text(dateKey(point.day)),
            subtitle:Text('ورودی: ${toman(point.incoming)} | خروجی: ${toman(point.outgoing)}'),
            trailing:Text(toman(point.closingBalance),
              style:TextStyle(color:point.belowReserve?Colors.deepOrange:null))),
        const SizedBox(height:8),
        const Text('هزینه‌های روزمره پیش‌بینی‌نشده، درآمدهای ثبت‌نشده و موجودی کیف‌پول‌های مستقل در این محاسبه لحاظ نشده‌اند.',
          style:TextStyle(fontSize:12)),
      ]))),
    actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('بستن'))],
  ));
}

Future<void> purchaseForecastDialog() async {
  final amount=TextEditingController();
  PrimePurchasePreview? preview;
  await showDialog<void>(context:context,builder:(dialogContext)=>StatefulBuilder(
    builder:(context,refresh)=>AlertDialog(
      title:const Text('PRIME Forecast — قبل از خرید'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,
        crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('این محاسبه فقط پیش‌نمایش است؛ هیچ تراکنشی ثبت نمی‌شود.'),
        const SizedBox(height:12),
        Text('مانده قابل‌خرج فعلی: ${toman(m.available)}'),
        Text('هدف پس‌انداز هفتگی: ${toman(m.currentTarget)}'),
        const SizedBox(height:8),
        TextField(controller:amount,keyboardType:TextInputType.number,
          decoration:const InputDecoration(labelText:'قیمت خرید (تومان)')),
        const SizedBox(height:12),
        if(preview!=null)...[
          Text('مانده پس از خرید: ${toman(preview!.availableAfter)}',
            style:TextStyle(fontWeight:FontWeight.bold,
              color:preview!.affordable?Colors.teal:Colors.deepOrange)),
          if(!preview!.affordable)Text('کسری احتمالی: ${toman(preview!.shortfall)}'),
          const Text('این پیش‌نمایش از پس‌انداز محافظت‌شده برداشت نمی‌کند.'),
        ],
      ])),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('بستن')),
        FilledButton(onPressed:(){
          final price=int.tryParse(amount.text.trim().replaceAll(',',''));
          if(price==null||price<=0){
            ScaffoldMessenger.of(this.context).showSnackBar(
              const SnackBar(content:Text('مبلغ خرید باید عددی مثبت باشد.')));
            return;
          }
          refresh(()=>preview=PrimePurchaseForecast.simulate(
            available:m.available,purchaseAmount:price,
            protectedSavings:m.currentTarget));
        },child:const Text('محاسبه اثر خرید')),
      ],
    )));
  amount.dispose();
}

Future<void> backupDialog() async {
  final input=TextEditingController();
  await showDialog<void>(context:context,builder:(c)=>AlertDialog(
    title:const Text('پشتیبان‌گیری و بازیابی'),
    content:SizedBox(width:420,child:SingleChildScrollView(child:Column(
      mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,
      children:[
        const Text('برای نگهداری نسخه پشتیبان، متن JSON را کپی و در یک فایل امن ذخیره کنید. این متن حاوی اطلاعات مالی شماست.'),
        const SizedBox(height:12),
        FilledButton.icon(icon:const Icon(Icons.copy),label:const Text('کپی نسخه پشتیبان'),
          onPressed:() async {
            try {
              await Clipboard.setData(ClipboardData(text:m.createPortableBackup()));
              if(!mounted)return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('نسخه پشتیبان کپی شد؛ آن را در یک فایل امن ذخیره کنید.')));
            }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('خطا در کپی: $e')));}
          }),
        const Divider(height:30),
        const Text('برای بازیابی، متن نسخه پشتیبان را اینجا جای‌گذاری کنید. اطلاعات فعلی فقط بعد از تأیید شما جایگزین می‌شوند.'),
        TextField(controller:input,minLines:3,maxLines:6,decoration:const InputDecoration(labelText:'متن فایل پشتیبان JSON')),
        const SizedBox(height:12),
        OutlinedButton.icon(icon:const Icon(Icons.restore),label:const Text('بررسی و بازیابی'),
          onPressed:() async {
            try {
              final state=PrimeBackup.previewImport(input.text.trim());
              final count=(state['entries'] as List? ?? []).length;
              if(!c.mounted)return;
              final approved=await showDialog<bool>(context:c,builder:(confirm)=>AlertDialog(
                title:const Text('تأیید بازیابی اطلاعات'),
                content:Text('فایل شامل $count تراکنش است. اطلاعات مالی فعلی این دستگاه با اطلاعات پشتیبان جایگزین می‌شوند. ادامه می‌دهید؟'),
                actions:[TextButton(onPressed:()=>Navigator.pop(confirm,false),child:const Text('انصراف')),
                  FilledButton(onPressed:()=>Navigator.pop(confirm,true),child:const Text('بازیابی و جایگزینی'))]));
              if(approved!=true)return;
              await m.restorePortableBackup(input.text.trim());
              if(!mounted||!c.mounted)return;
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('اطلاعات با موفقیت بازیابی شدند.')));
            }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('بازیابی انجام نشد: $e')));}
          }),
      ]))),
    actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('بستن'))],
  ));
  input.dispose();
}
Future<void> entryDialog(String kind, {DateTime? selectedDate})async{final amount=TextEditingController(),note=TextEditingController();String category='خوراک';await showDialog(context:context,builder:(c)=>AlertDialog(title:Text(kind=='expense'?'ثبت خرید':'ثبت درآمد'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'مبلغ به تومان')),if(kind=='expense')DropdownButtonFormField<String>(initialValue:category,items:['خوراک','رفت‌وآمد','تفریح','خرید','قبض','سایر'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>category=x??category),TextField(controller:note,decoration:const InputDecoration(labelText:'توضیح'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('انصراف')),FilledButton(onPressed:(){final n=int.tryParse(amount.text)??0;if(n>0){m.addEntry(kind,n,category:category,note:note.text,selectedDate:selectedDate);Navigator.pop(c);}},child:const Text('ثبت'))]));}
Future<void> editEntryDialog(Entry e)async{
  if(e.kind!='expense'&&e.kind!='income')return;
  final amount=TextEditingController(text:'${e.amount}'),note=TextEditingController(text:e.note);
  const cats=['خوراک','رفت‌وآمد','تفریح','خرید','قبض','سایر'];
  String category=cats.contains(e.category)?e.category:'سایر';
  await showDialog(context:context,builder:(c)=>StatefulBuilder(builder:(c,refresh)=>AlertDialog(
    title:Text(e.kind=='expense'?'ویرایش خرج':'ویرایش درآمد'),
    content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      Text('تاریخ: ${e.date}'),
      TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'مبلغ به تومان')),
      if(e.kind=='expense')DropdownButtonFormField<String>(initialValue:category,items:cats.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>refresh(()=>category=x??category)),
      TextField(controller:note,decoration:const InputDecoration(labelText:'توضیح')),
    ])),
    actions:[
      TextButton(onPressed:()=>Navigator.pop(c),child:const Text('انصراف')),
      TextButton(onPressed:()async{
        final yes=await showDialog<bool>(context:c,builder:(d)=>AlertDialog(title:const Text('حذف تراکنش؟'),content:const Text('این تراکنش حذف می‌شود و محاسبات بودجه به‌روز خواهند شد.'),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('حذف'))]));
        if(yes==true){m.deleteEntry(e.id);if(c.mounted)Navigator.pop(c);}
      },child:const Text('حذف',style:TextStyle(color:Colors.red))),
      FilledButton(onPressed:(){final n=int.tryParse(amount.text.replaceAll(',',''));if(n!=null&&n>0){m.updateEntry(e.id,n,category,note.text);Navigator.pop(c);}},child:const Text('ذخیره تغییرات')),
    ])));
  amount.dispose();note.dispose();
}

Future<void> setupDialog() async {
  final b = TextEditingController(text: '${m.currentBudget}');
  final s = TextEditingController(
    text: '${m.suggestedSavings ?? m.currentTarget}',
  );

  String readable(int value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(2)} میلیارد تومان';
    }
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)} میلیون تومان';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)} هزار تومان';
    }
    return '$value تومان';
  }

  await showDialog(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, refresh) {
        final budget = int.tryParse(b.text) ?? 0;
        final target = int.tryParse(s.text) ?? 0;

        return AlertDialog(
          title: const Text('تنظیم بودجه این هفته'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: b,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => refresh(() {}),
                  decoration: const InputDecoration(
                    labelText: 'بودجه هفته (تومان)',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  readable(budget),
                  style: const TextStyle(
                    color: Color(0xFF087F75),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: s,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => refresh(() {}),
                  decoration: const InputDecoration(
                    labelText: 'هدف پس‌انداز (تومان)',
                    prefixIcon: Icon(Icons.savings_outlined),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  readable(target),
                  style: const TextStyle(
                    color: Color(0xFF087F75),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                if (budget >= 0 &&
                    target >= 0 &&
                    target <= budget) {
                  m.configureWeek(budget, target);
                  Navigator.pop(c);
                }
              },
              child: const Text('تأیید'),
            ),
          ],
        );
      },
    ),
  );
  b.dispose();
  s.dispose();
}

Future<void> goalDialog()async{final name=TextEditingController(),price=TextEditingController(),initial=TextEditingController(text:'0'),weekly=TextEditingController(text:'0');await showDialog(context:context,builder:(c)=>AlertDialog(title:const Text('هدف خرید جدید'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'نام کالا')),TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'قیمت')),TextField(controller:initial,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'موجودی اولیه')),TextField(controller:weekly,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'پس‌انداز هفتگی'))])),actions:[FilledButton(onPressed:(){m.addGoal(name.text,int.tryParse(price.text)??0,int.tryParse(initial.text)??0,int.tryParse(weekly.text)??0);Navigator.pop(c);},child:const Text('ساخت قلک'))]));}
Future<void> transferDialog({String? goal})async{final amount=TextEditingController();String to=goal??'savings';await showDialog(context:context,builder:(c)=>AlertDialog(title:const Text('انتقال واقعی از بودجه'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'مبلغ')),DropdownButtonFormField<String>(initialValue:to,items:[const DropdownMenuItem(value:'savings',child:Text('پس‌انداز عمومی')),...m.goals.map((g)=>DropdownMenuItem(value:'goal:${g.id}',child:Text(g.name)))],onChanged:(x)=>to=x??to)]),actions:[FilledButton(onPressed:(){try{m.transfer(int.tryParse(amount.text)??0,to);Navigator.pop(c);}catch(e){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}},child:const Text('انتقال'))]));}
Future<void> settleDialog(String key)async{final rem=max(0,(m.budgets[key]??0)+m.total(key,'income')-m.total(key,'expense')-m.total(key,'transferOut'));final value=TextEditingController(text:'$rem');await showDialog(context:context,builder:(c)=>AlertDialog(title:const Text('تقسیم مانده پایان هفته'),content:Column(mainAxisSize:MainAxisSize.min,children:[Text('مانده: ${toman(rem)}'),TextField(controller:value,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'سهم پس‌انداز؛ باقی به هفته بعد'))]),actions:[FilledButton(onPressed:(){try{m.settle(key,int.parse(value.text));Navigator.pop(c);}catch(e){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}},child:const Text('تأیید نهایی'))]));}
Future<void> savingsAdviceDialog() async {
  final incomeController=TextEditingController(text:'${m.currentBudget}');
  final fixedController=TextEditingController(text:'0');
  PrimeSavingAdvice? advice;
  String? error;
  final chosenController=TextEditingController();
  final completed=(m.budgets.keys.where((k)=>k.compareTo(m.currentWeek)<0).toList()..sort());
  final snapshots=<PrimeWeekSnapshot>[];
  for(final key in completed){
    final income=max(0,(m.budgets[key]??0)+m.total(key,'income'));
    final expenses=max(0,m.total(key,'expense'));
    final saved=max(0,(m.settlements[key]?['saving']??0)+m.entriesFor(key)
      .where((e)=>e.kind=='transferOut'&&e.toAccount=='savings')
      .fold<int>(0,(sum,e)=>sum+e.amount));
    snapshots.add(PrimeWeekSnapshot(income:income,expenses:expenses,
      saved:saved,plannedSaving:max(0,m.targets[key]??0)));
  }
  try {
    await showDialog<void>(context:context,builder:(dialogContext)=>StatefulBuilder(
      builder:(dialogContext,refresh)=>AlertDialog(
        title:const Text('پیشنهاد پس‌انداز هفته آینده'),
        content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('مبالغ را به تومان وارد کن. بودجه هفته فعلی فقط به‌عنوان مقدار اولیه نمایش داده شده است.'),
          TextField(controller:incomeController,keyboardType:TextInputType.number,
            decoration:const InputDecoration(labelText:'کل پول در دسترس هفته آینده')),
          TextField(controller:fixedController,keyboardType:TextInputType.number,
            decoration:const InputDecoration(labelText:'هزینه‌های ثابت هفته آینده')),
          const SizedBox(height:12),
          if(error!=null)Text(error!,style:const TextStyle(color:Colors.red)),
          if(advice!=null)...[
            Text(advice!.explanation),
            if(advice!.hasEnoughData)...[
              const SizedBox(height:8),
              Text('پس‌انداز پیشنهادی: ${toman(advice!.suggestedAmount!)}'),
              Text('سهم تقریبی روزانه: ${toman(advice!.dailySpendingBudget!)}'),
              Text('تفاوت با هدف فعلی: ${toman(advice!.differenceFromCurrent!)}'),
              TextField(controller:chosenController,keyboardType:TextInputType.number,
                decoration:const InputDecoration(labelText:'مبلغ پس‌انداز انتخابی (قابل ویرایش)')),
              const SizedBox(height:8),
              const Text('پذیرش، فقط بودجه و هدف پس‌انداز هفته آینده را ثبت می‌کند؛ هیچ پولی جابه‌جا نمی‌شود.',style:TextStyle(fontSize:12)),
            ],
          ],
          const SizedBox(height:8),
          const Text('محاسبه پیشنهاد به‌تنهایی اطلاعات مالی را تغییر نمی‌دهد.',
            style:TextStyle(fontSize:12)),
        ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('رد / بستن')),
          if(advice?.hasEnoughData==true)OutlinedButton(
            onPressed:() async {
              final income=int.tryParse(incomeController.text.replaceAll(',',''));
              final fixed=int.tryParse(fixedController.text.replaceAll(',',''));
              final selected=int.tryParse(chosenController.text.replaceAll(',',''));
              if(income==null||fixed==null||selected==null||fixed>income||selected<0||selected>income-fixed){
                refresh(() => error='پس‌انداز انتخابی باید بین صفر و پول باقی‌مانده پس از هزینه‌های ثابت باشد.');
                return;
              }
              final next=dateKey(weekStart(m.financialToday).add(const Duration(days:7)));
              final exists=m.budgets.containsKey(next)||m.targets.containsKey(next);
              final confirmed=await showDialog<bool>(context:dialogContext,builder:(c)=>AlertDialog(
                title:const Text('تأیید برنامه هفته آینده'),
                content:Text('بودجه هفته $next: ${toman(income)}\nهدف پس‌انداز: ${toman(selected)}\nهزینه ثابت پیش‌بینی‌شده: ${toman(fixed)}\n${exists?'هشدار: برنامه قبلی این هفته جایگزین می‌شود.':'هیچ تراکنش یا انتقال واقعی انجام نمی‌شود.'}'),
                actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('انصراف')),
                  FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('تأیید و ذخیره'))],
              ));
              if(confirmed!=true||!dialogContext.mounted)return;
              try{
                m.planNextWeek(income,selected,replaceExisting:exists);
                Navigator.pop(dialogContext);
                if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('برنامه هفته آینده ذخیره شد.')));
              }catch(e){refresh(()=>error='$e');}
            },child:const Text('پذیرش / ثبت مبلغ دلخواه')),
          FilledButton(onPressed:(){
            final income=int.tryParse(incomeController.text.replaceAll(',',''));
            final fixed=int.tryParse(fixedController.text.replaceAll(',',''));
            if(income==null||fixed==null||income<0||fixed<0){
              refresh((){error='مبلغ‌ها باید عدد صحیح نامنفی باشند.';advice=null;});
              return;
            }
            refresh((){
              error=null;
              advice=recommendNextWeekSavings(completedWeeks:snapshots,
                upcomingIncome:income,upcomingFixedCosts:fixed,
                currentSavingTarget:max(0,m.currentTarget));
              chosenController.text=advice?.suggestedAmount?.toString()??'';
            });
          },child:const Text('محاسبه پیشنهاد')),
        ],
      )));
  } finally {
    incomeController.dispose();fixedController.dispose();chosenController.dispose();
  }
}
Widget card(String title,Widget child)=>Card(margin:const EdgeInsets.symmetric(vertical:7),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold)),const SizedBox(height:10),child])));
Widget dashboard(){
  final idx=(m.financialToday.difference(weekStart(m.financialToday)).inDays).clamp(0,6);
  final past=m.budgets.keys.where((k)=>k.compareTo(m.currentWeek)<0&&!m.settlements.containsKey(k)).toList()..sort();
  final allowance=m.dailyAllowance(idx);
  final todaySpent=m.spentOn(m.financialToday);
  final todayPct=allowance>0?todaySpent/allowance*100:0.0;
  final spendable=max(0,m.currentBudget-m.currentTarget);
  final weekPct=spendable>0?m.expense/spendable*100:0.0;
  final overToday=allowance>0&&todaySpent>allowance;
  final overWeek=spendable>0&&m.expense>spendable;
  
final previousWeek = dateKey(
  weekStart(m.financialToday).subtract(
    const Duration(days: 7),
  ),
);
final previousExpense = m.total(previousWeek, 'expense');
final expenseDifference = m.expense - previousExpense;
final hasPreviousWeekData = m.entriesFor(previousWeek).isNotEmpty;
  
final categoryExpenses = <String, int>{};

for (final entry in m.entriesFor(m.currentWeek)) {
  if (entry.kind == 'expense') {
    categoryExpenses.update(
      entry.category,
      (amount) => amount + entry.amount,
      ifAbsent: () => entry.amount,
    );
  }
}

final sortedCategories = categoryExpenses.entries.toList()
  ..sort((a, b) => b.value.compareTo(a.value));


  String coach;
  if(m.currentBudget==0){coach='اول بودجه این هفته را ثبت کن.';}
  else if(overWeek){coach='هشدار: هزینه‌های این هفته از بودجه قابل خرج بیشتر شده است. پیش از خرید بعدی، بودجه و پس‌انداز را بررسی کن.';}
  else if(overToday){coach='هشدار: امروز ${toman(todaySpent-allowance)} بیشتر از سهم روزانه خرج کردی؛ حتی اگر هنوز از بودجه کل هفته عبور نکرده باشی. برای جبران، هزینه روزهای بعد را بازبینی کن.';}
  else if(m.projectedSpend>m.currentBudget+m.income){coach='با روند فعلی ممکن است بودجه کافی نباشد. هزینه‌های اختیاری را کاهش بده.';}
  else{coach='خرج امروز در محدوده سهم روزانه است. برای هدف خرید، مبلغی را که واقعاً کنار می‌گذاری به قلک منتقل کن.';}
  return ListView(padding:const EdgeInsets.all(14),children:[
    if(past.isNotEmpty)card('تسویه هفته گذشته',Column(children:[Text('هفته ${past.last} هنوز تسویه نشده'),FilledButton(onPressed:()=>settleDialog(past.last),child:const Text('تقسیم دستی مانده'))])),

    Card(
      margin: const EdgeInsets.symmetric(vertical: 7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    color: Color(0xFF087F75)),
                SizedBox(width: 8),
                Text('موجودی قابل خرج',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              toman(m.available),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Color(0xFF087F75),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF6F2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.today,
                            color: Color(0xFF087F75)),
                        const SizedBox(height: 6),
                        Text('سهم ${weekdays[idx]}'),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            toman(allowance),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.receipt_long_outlined),
                        const SizedBox(height: 6),
                        const Text('خرج امروز'),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            toman(todaySpent),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.savings_outlined,
                    color: Color(0xFF087F75)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'هدف پس‌انداز: ${toman(m.currentTarget)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => entryDialog('expense'),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('ثبت هزینه'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => entryDialog('income'),
                    icon: const Icon(Icons.add),
                    label: const Text('ثبت درآمد'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: setupDialog,
              icon: const Icon(Icons.tune),
              label: const Text('تنظیم بودجه هفته'),
            ),
          ],
        ),
      ),
    ),

    
    card('پیشرفت بودجه', Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('خرج امروز: ${toman(todaySpent)} از ${toman(allowance)}'),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: allowance > 0
              ? (todaySpent / allowance).clamp(0.0, 1.0)
              : 0.0,
          minHeight: 12,
          borderRadius: BorderRadius.circular(12),
          color: overToday ? Colors.redAccent : const Color(0xFF087F75),
          backgroundColor: Colors.black12,
        ),
        const SizedBox(height: 18),
        Text('خرج هفته: ${toman(m.expense)} از ${toman(spendable)}'),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: spendable > 0
              ? (m.expense / spendable).clamp(0.0, 1.0)
              : 0.0,
          minHeight: 12,
          borderRadius: BorderRadius.circular(12),
          color: overWeek ? Colors.redAccent : const Color(0xFF087F75),
          backgroundColor: Colors.black12,
        ),
      ],
    )),

    
card(
  'مقایسه با هفته قبل',
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('هزینه این هفته: ${toman(m.expense)}'),
      Text('هزینه هفته قبل: ${toman(previousExpense)}'),
      const SizedBox(height: 12),
      if (!hasPreviousWeekData)
        const Text('برای هفته قبل هنوز تراکنشی ثبت نشده است.')
      else
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: expenseDifference > 0
                ? const Color(0xFFFFEBED)
                : const Color(0xFFEAF6F2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                expenseDifference > 0
                    ? Icons.trending_up
                    : expenseDifference < 0
                        ? Icons.trending_down
                        : Icons.trending_flat,
                color: expenseDifference > 0
                    ? Colors.red
                    : const Color(0xFF087F75),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  expenseDifference == 0
                      ? 'هزینه‌ها با هفته قبل برابر است.'
                      : expenseDifference > 0
                          ? '${toman(expenseDifference)} بیشتر از هفته قبل'
                          : '${toman(-expenseDifference)} کمتر از هفته قبل',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 8),
      const Text(
        'مقایسه مجموع هزینه‌های ثبت‌شده؛ هفته جاری ممکن است هنوز کامل نشده باشد.',
        style: TextStyle(fontSize: 11, color: Colors.grey),
      ),
    ],
  ),
),

card(
  'هزینه‌ها به تفکیک دسته‌بندی',
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (sortedCategories.isEmpty)
        const Text('هنوز هزینه‌ای برای این هفته ثبت نشده است.')
      else
        ...sortedCategories.asMap().entries.map((item) {
          final category = item.value;
          final colors = [
            const Color(0xFF087F75),
            const Color(0xFF6366F1),
            const Color(0xFFEA8B35),
            const Color(0xFFE65B65),
            const Color(0xFF0EA5E9),
          ];
          final color = colors[item.key % colors.length];
          final percent = m.expense > 0
              ? category.value / m.expense
              : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        category.key,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text('${(percent * 100).toStringAsFixed(1)}٪'),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  toman(category.value),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0,
                    end: percent.clamp(0.0, 1.0).toDouble(),
                  ),
                  duration: const Duration(milliseconds: 700),
                  builder: (context, value, child) {
                    return LinearProgressIndicator(
                      value: value,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(10),
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.12),
                    );
                  },
                ),
              ],
            ),
          );
        }),
    ],
  ),
),

Prime31BudgetAlert(
  budget: spendable,
  spent: m.expense,
),
card('درصد مصرف بودجه', Column(
  children: [
    const SizedBox(height: 12),
    
    Prime31BudgetRing(
      budget: spendable,
      spent: m.expense,
    ),

    const SizedBox(height: 18),
    Text('کل بودجه قابل خرج: ${toman(spendable)}'),
    Text('هزینه این هفته: ${toman(m.expense)}'),
    Text('باقی‌مانده: ${toman(max(0, spendable - m.expense))}'),
    const SizedBox(height: 16),
    Text(
      'مصرف امروز: ${allowance > 0 ? todayPct.toStringAsFixed(1) : '—'}٪',
    ),
    LinearProgressIndicator(
      value: allowance > 0
          ? (todayPct / 100).clamp(0.0, 1.0)
          : 0.0,
      minHeight: 7,
      borderRadius: BorderRadius.circular(10),
      color: overToday ? Colors.red : const Color(0xff087f75),
      backgroundColor: const Color(0xffe5eeeb),
    ),
    if (spendable == 0)
      const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text('برای نمایش درصد، بودجه قابل خرج تعیین کن.'),
      ),
  ],
)),

card(
  'تحلیل تصویری هزینه‌ها',
  Prime31WeeklyChart(
    dailyExpenses: List.generate(
      7,
      (i) => m.spentOn(
        weekStart(m.financialToday).add(Duration(days: i)),
      ),
    ),
    todayIndex: idx,
  ),
),

card('روزهای هفته', Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Text(
      'هزینه‌های این هفته',
      style: TextStyle(
        fontSize: 14,
        color: Color(0xff64748b),
      ),
    ),
    const SizedBox(height: 14),
    Row(
      children: List.generate(7, (i) {
        final date = weekStart(m.financialToday)
            .add(Duration(days: i));
        final spent = m.spentOn(date);
        final isToday = i == idx;

        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isToday
                  ? const Color(0xff087f75)
                  : const Color(0xfff0f5f3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  weekdays[i].substring(0, 1),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isToday ? Colors.white : const Color(0xff123b43),
                  ),
                ),
                const SizedBox(height: 8),
                Icon(
                  spent > 0
                      ? Icons.circle
                      : Icons.circle_outlined,
                  size: 12,
                  color: isToday
                      ? Colors.white
                      : spent > 0
                          ? const Color(0xff087f75)
                          : const Color(0xffa3b5b0),
                ),
                const SizedBox(height: 8),
                Text(
                  nf.format(spent),
                  style: TextStyle(
                    fontSize: 9,
                    color: isToday ? Colors.white : const Color(0xff123b43),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }),
    ),
    const SizedBox(height: 10),
    const Text(
      'مبالغ به تومان هستند؛ روز جاری با رنگ سبز مشخص شده است.',
      style: TextStyle(fontSize: 11, color: Color(0xff64748b)),
    ),
  ],
)),


card(
  'قلک هوشمند PRIME 3.1',
  Prime31SavingsCard(
    title: 'پس‌انداز این هفته',
    target: m.currentTarget,
    saved: m.entriesFor(m.currentWeek)
        .where((e) =>
            e.kind == 'transferOut' &&
            e.toAccount == 'savings')
        .fold<int>(0, (sum, e) => sum + e.amount),
    formatMoney: (value) => toman(value),
  ),
),


card('پس‌انداز این هفته', Container(
  width: double.infinity,
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    gradient: const LinearGradient(
      colors: [
        Color(0xff123b43),
        Color(0xff087f75),
      ],
    ),
    borderRadius: BorderRadius.circular(18),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Row(
        children: [
          Icon(Icons.savings_outlined, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'هدف پس‌انداز',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Text(
        toman(m.currentTarget),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 27,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'مبلغی که برای پس‌انداز این هفته برنامه‌ریزی کرده‌ای',
        style: TextStyle(color: Colors.white70, fontSize: 12),
      ),
    ],
  ),
)),

    card('پیش‌بینی تا پایان هفته',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('خرج تخمینی: ${toman(m.projectedSpend)}'),Text('مانده تخمینی: ${toman(m.currentBudget+m.carryIn+m.income-m.projectedSpend-m.total(m.currentWeek,'transferOut'))}'),if(m.unusualExpense)const Text('هشدار: خرج امروز از الگوی گذشته بیشتر است',style:TextStyle(color:Colors.deepOrange))])),
    card('مربی مالی',Text(coach,style:TextStyle(color:overToday||overWeek?Colors.deepOrange:null))),
    card('تراکنش‌های هفته',Column(children:m.entriesFor(m.currentWeek).reversed.map((e)=>ListTile(
      title:Text('${e.kind=='expense'?'خرج':e.kind=='income'?'درآمد':'انتقال'} • ${e.category}'),
      subtitle:Text('${e.date} ${e.note}'),
      trailing:Row(mainAxisSize:MainAxisSize.min,children:[Text(toman(e.amount)),if(e.kind=='expense'||e.kind=='income')IconButton(icon:const Icon(Icons.edit_outlined),tooltip:'ویرایش یا حذف',onPressed:()=>editEntryDialog(e))]),
      onTap:(e.kind=='expense'||e.kind=='income')?()=>editEntryDialog(e):null,
    )).toList()))
  ]);
}
Future<void> goalScenarioDialog(Goal goal) async {
  final today=day(m.financialToday);
  DateTime deadline=today.add(const Duration(days:84));
  final reduction=TextEditingController(text:'0');
  // Use only recorded goal deposits/withdrawals in completed weeks.
  // A planned weekly goal amount is NOT evidence of actual saving.
  final weeks=<DateTime>[];
  for(var i=4;i>=1;i--){
    weeks.add(weekStart(today).subtract(Duration(days:7*i)));
  }
  int savedInWeek(DateTime start){
    final key=dateKey(start);
    return m.entriesFor(key).where((e)=>
      (e.kind=='transferOut'&&e.toAccount=='goal:${goal.id}')||
      (e.kind=='transferIn'&&e.account=='goal:${goal.id}'))
      .fold<int>(0,(sum,e)=>sum+(e.kind=='transferOut'?e.amount:-e.amount));
  }
  final completed=weeks.where((d)=>m.budgets.containsKey(dateKey(d))).length;
  final observed=weeks.fold<int>(0,(sum,d)=>sum+savedInWeek(d));
  final actualAverage=max(0,observed~/4);
  if(!mounted)return;
  await showDialog<void>(context:context,builder:(dialogContext)=>StatefulBuilder(
    builder:(context,refresh){
      final extra=max(0,int.tryParse(reduction.text.trim())??0);
      final current=PrimeGoalScenarios.compare(
        target:goal.price,saved:max(0,m.goalBalance(goal)),today:today,
        deadline:deadline,averageWeeklySaving:actualAverage,
        completedHistoryWeeks:completed);
      final improved=PrimeGoalScenarios.compare(
        target:goal.price,saved:max(0,m.goalBalance(goal)),today:today,
        deadline:deadline,averageWeeklySaving:actualAverage+extra,
        completedHistoryWeeks:completed);
      return AlertDialog(
        title:Text('سناریوی هدف: ${goal.name}'),
        content:SingleChildScrollView(child:Column(
          mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            Text('باقی‌مانده هدف: ${toman(current.remaining)}'),
            const SizedBox(height:8),
            OutlinedButton.icon(icon:const Icon(Icons.event),
              label:Text('مهلت فرضی: ${dateKey(deadline)}'),
              onPressed:()async{
                final selected=await showDatePicker(context:context,
                  initialDate:deadline,firstDate:today,
                  lastDate:today.add(const Duration(days:3650)));
                if(selected!=null)refresh(()=>deadline=selected);
              }),
            Text('پس‌انداز لازم در هفته: ${toman(current.requiredWeeklySaving)}'),
            Text('میانگین واریز خالص واقعی به این هدف در ۴ هفته اخیر: ${toman(actualAverage)}'),
            Text('هفته‌های دارای بودجه ثبت‌شده: $completed از ۴'),
            const SizedBox(height:10),
            TextField(controller:reduction,keyboardType:TextInputType.number,
              decoration:const InputDecoration(labelText:'کاهش هزینه و واریز اضافه در هر هفته (تومان)',
                helperText:'فقط برای مقایسه؛ پولی جابه‌جا نمی‌شود'),
              onChanged:(_)=>refresh((){})),
            const SizedBox(height:10),
            if(!current.enoughHistory)
              const Text('برای برآورد زمان اتمام با روند واقعی، دست‌کم ۴ هفته بودجه ثبت‌شده لازم است.'),
            if(current.enoughHistory)...[
              Text('زمان اتمام با روند فعلی: ${current.currentPaceCompletion==null?'نامشخص':dateKey(current.currentPaceCompletion!)}'),
              Text('زمان اتمام با کاهش هزینه پیشنهادی: ${improved.currentPaceCompletion==null?'نامشخص':dateKey(improved.currentPaceCompletion!)}'),
              if(improved.daysRelativeToDeadline!=null)
                Text(improved.daysRelativeToDeadline!<=0?'سناریوی پیشنهادی تا مهلت انتخابی می‌رسد.':'سناریوی پیشنهادی ${improved.daysRelativeToDeadline} روز بعد از مهلت به هدف می‌رسد.'),
            ],
            const SizedBox(height:8),
            const Text('این محاسبه یک سناریوی فرضی است، نه تضمین رسیدن به هدف. مبلغ اضافه باید واقعاً پس‌انداز شود.',
              style:TextStyle(fontSize:12)),
          ])),
        actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('بستن'))],
      );
    }));
  reduction.dispose();
}
Widget goalsPage()=>ListView(padding:const EdgeInsets.all(14),children:[FilledButton(onPressed:goalDialog,child:const Text('ساخت هدف خرید جدید')),for(final g in m.goals)card(g.name,Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${toman(m.goalBalance(g))} از ${toman(g.price)}'),LinearProgressIndicator(value:(m.goalBalance(g)/g.price).clamp(0,1)),const SizedBox(height:8),Text(g.weekly>0?'زمان تقریبی: ${(max(0,g.price-m.goalBalance(g))/g.weekly).ceil()} هفته':'پس‌انداز هفتگی تعیین نشده'),OutlinedButton(onPressed:()=>transferDialog(goal:'goal:${g.id}'),child:const Text('واریز از بودجه')),OutlinedButton.icon(onPressed:()=>goalScenarioDialog(g),icon:const Icon(Icons.auto_graph_outlined),label:const Text('مقایسه سناریوهای هدف'))]))]);
Widget historyPage(){
  final categories=m.entries.where((e)=>e.kind=='expense'||e.kind=='income')
    .map((e)=>e.category).toSet().toList()..sort();
  final selectedCategory=historyCategory=='all'||categories.contains(historyCategory)
    ?historyCategory:'all';
  final q=historyQuery.trim().toLowerCase();
  final filtered=m.entries.where((e){
    if(historyKind!='all'&&e.kind!=historyKind)return false;
    if(selectedCategory!='all'&&e.category!=selectedCategory)return false;
    if(q.isEmpty)return true;
    return e.note.toLowerCase().contains(q)||e.category.toLowerCase().contains(q)
      ||e.date.contains(q)||e.amount.toString().contains(q);
  }).toList()..sort((a,b){final date=b.date.compareTo(a.date);
    return date!=0?date:b.id.compareTo(a.id);
  });
  final expenseSum=filtered.where((e)=>e.kind=='expense').fold<int>(0,(a,e)=>a+e.amount);
  final incomeSum=filtered.where((e)=>e.kind=='income').fold<int>(0,(a,e)=>a+e.amount);
  return ListView(padding:const EdgeInsets.all(14),children:[
    card('جست‌وجو و فیلتر تراکنش‌ها',Column(children:[
      TextField(onChanged:(value)=>setState(()=>historyQuery=value),
        decoration:const InputDecoration(prefixIcon:Icon(Icons.search),
          labelText:'جست‌وجوی توضیح، دسته، تاریخ یا مبلغ')),
      const SizedBox(height:10),
      Row(children:[
        Expanded(child:DropdownButtonFormField<String>(value:historyKind,
          decoration:const InputDecoration(labelText:'نوع'),
          items:const [DropdownMenuItem(value:'all',child:Text('همه')),
            DropdownMenuItem(value:'expense',child:Text('هزینه')),
            DropdownMenuItem(value:'income',child:Text('درآمد')),
            DropdownMenuItem(value:'transferOut',child:Text('انتقال خروجی')),
            DropdownMenuItem(value:'transferIn',child:Text('انتقال ورودی'))],
          onChanged:(v)=>setState(()=>historyKind=v??'all'))),
        const SizedBox(width:8),
        Expanded(child:DropdownButtonFormField<String>(value:selectedCategory,
          decoration:const InputDecoration(labelText:'دسته'),
          items:[const DropdownMenuItem(value:'all',child:Text('همه')),
            ...categories.map((c)=>DropdownMenuItem(value:c,child:Text(c,
              overflow:TextOverflow.ellipsis)))],
          onChanged:(v)=>setState(()=>historyCategory=v??'all'))),
      ]),
      const SizedBox(height:10),
      Align(alignment:Alignment.centerRight,child:Text(
        '${filtered.length} تراکنش • هزینه: ${toman(expenseSum)} • درآمد: ${toman(incomeSum)}')),
    ])),
    if(filtered.isEmpty)card('نتیجه',const Text('تراکنشی با این فیلتر پیدا نشد.')),
    for(final e in filtered)Card(child:ListTile(
      title:Text('${e.kind=='expense'?'هزینه':e.kind=='income'?'درآمد':'انتقال'} • ${e.category}'),
      subtitle:Text('${e.date}  ${e.note}'),
      trailing:Text(toman(e.amount)),
      onTap:(e.kind=='expense'||e.kind=='income')?()=>editEntryDialog(e):null,
    )),
    card('خلاصه هفته‌های گذشته',Column(children:[
      for(final k in (m.budgets.keys.toList()..sort((a,b)=>b.compareTo(a))))
        ListTile(title:Text('هفته $k'),subtitle:Text(
          'بودجه ${toman(m.budgets[k]??0)} • خرج ${toman(m.total(k,'expense'))}')),
    ])),
  ]);
}

/// PRIME 3.0 analytics preview backed by actual stored transactions.
/// This screen is read-only and does not modify the legacy storage format.
Future<void> challengeDialog() async {
  var type=PrimeChallengeType.categoryCap;
  final category=TextEditingController();
  final target=TextEditingController();
  await showDialog<void>(context:context,builder:(dialog)=>StatefulBuilder(
    builder:(dialog,refresh)=>AlertDialog(title:const Text('چالش مالی این هفته'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<PrimeChallengeType>(value:type,
          items:const [DropdownMenuItem(value:PrimeChallengeType.categoryCap,child:Text('سقف هزینه یک دسته')),
            DropdownMenuItem(value:PrimeChallengeType.noSpendDays,child:Text('روزهای بدون هزینه'))],
          onChanged:(v){if(v!=null)refresh(()=>type=v);}),
        if(type==PrimeChallengeType.categoryCap)TextField(controller:category,
          decoration:const InputDecoration(labelText:'نام دقیق دسته‌بندی')),
        TextField(controller:target,keyboardType:TextInputType.number,
          decoration:InputDecoration(labelText:type==PrimeChallengeType.categoryCap?'حداکثر هزینه (تومان)':'تعداد روز (۱ تا ۷)')),
        const SizedBox(height:8),
        const Text('چالش فقط پیشرفت را بررسی می‌کند؛ هیچ تراکنشی خودکار ثبت نمی‌شود.',style:TextStyle(fontSize:12)),
      ]),actions:[TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('انصراف')),
        FilledButton(onPressed:()async{
          final amount=int.tryParse(target.text.replaceAll(',',''));
          if(amount==null){ScaffoldMessenger.of(dialog).showSnackBar(const SnackBar(content:Text('عدد معتبر وارد کنید')));return;}
          try{
            final c=PrimeChallenge(id:DateTime.now().microsecondsSinceEpoch.toString(),
              week:m.currentWeek,type:type,target:amount,category:category.text.trim());
            c.validate();m.challenges.add(c);await m.save();
            if(dialog.mounted)Navigator.pop(dialog);
          }catch(e){if(dialog.mounted)ScaffoldMessenger.of(dialog).showSnackBar(SnackBar(content:Text('$e')));}
        },child:const Text('شروع چالش'))],)));
  category.dispose();target.dispose();
}
Widget challengesSection(){
  final expenses=<PrimeChallengeExpense>[];
  for(final e in m.entries.where((e)=>e.kind=='expense')){
    try{expenses.add(PrimeChallengeExpense(parseDate(e.date),e.category,e.amount));}catch(_){}
  }
  final active=m.challenges.where((c)=>c.week==m.currentWeek).toList();
  return card('چالش‌های مالی',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    OutlinedButton.icon(onPressed:challengeDialog,icon:const Icon(Icons.emoji_events_outlined),
      label:const Text('ساخت چالش جدید')),
    if(active.isEmpty)const Text('هنوز برای این هفته چالشی ثبت نشده است.'),
    for(final c in active)Builder(builder:(context){
      final p=PrimeChallengeEngine.evaluate(c,expenses,today:m.financialToday);
      final title=c.type==PrimeChallengeType.categoryCap?'سقف هزینه ${c.category}':'روزهای بدون هزینه';
      return ListTile(contentPadding:EdgeInsets.zero,title:Text(title),
        subtitle:Text(c.type==PrimeChallengeType.categoryCap
          ?'هزینه: ${toman(p.achieved)} از سقف ${toman(p.target)}'
          :'${p.achieved} روز از ${p.target} روز'),
        trailing:IconButton(icon:const Icon(Icons.delete_outline),tooltip:'حذف چالش',onPressed:()async{
          final yes=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
            title:const Text('حذف چالش؟'),content:const Text('تراکنش‌های مالی حذف نمی‌شوند.'),
            actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('انصراف')),
              FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('حذف'))]));
          if(yes==true){m.challenges.removeWhere((x)=>x.id==c.id);await m.save();}
        }),
        isThreeLine:true,leading:Icon(p.failed?Icons.warning_amber_outlined:
          p.complete?Icons.check_circle_outline:Icons.timelapse));
    }),
  ]));
}
Future<void> weeklyReviewDialog() async {
  final today=m.financialToday;
  final thisWeek=weekStart(today);
  // A completed week only: never present an incomplete current week as final.
  final lastWeek=thisWeek.subtract(const Duration(days:7));
  final previousWeek=lastWeek.subtract(const Duration(days:7));
  final lastKey=dateKey(lastWeek);
  final previousKey=dateKey(previousWeek);
  final records=<PrimeReportEntry>[];
  for(final entry in m.entries){
    if(entry.kind!='income'&&entry.kind!='expense')continue;
    try{
      final date=parseDate(entry.date);
      if(entry.amount<0)continue;
      records.add(PrimeReportEntry(date:date,amount:entry.amount,
        category:entry.category,isExpense:entry.kind=='expense'));
    }catch(_){continue;}
  }
  final current=PrimeReports.weekly(records,lastWeek);
  final previous=PrimeReports.weekly(records,previousWeek);
  final budget=m.budgets[lastKey];
  if(!mounted)return;
  await showDialog<void>(context:context,builder:(dialog)=>AlertDialog(
    title:const Text('گزارش پایان هفته'),
    content:SingleChildScrollView(child:Column(
      mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('هفته $lastKey (شنبه تا جمعه)'),
      const SizedBox(height:8),
      Text('درآمد: ${toman(current.income)}'),
      Text('هزینه: ${toman(current.expenses)}'),
      Text('خالص جریان نقدی ثبت‌شده: ${toman(current.netCashFlow)}'),
      if(budget==null)...[
        const SizedBox(height:8),
        const Text('بودجه این هفته ثبت نشده؛ ارزیابی رعایت بودجه امکان‌پذیر نیست.'),
      ]else...[
        Text('بودجه ثبت‌شده: ${toman(budget)}'),
        Text('اختلاف هزینه با بودجه: ${toman(budget-current.expenses)}'),
      ],
      const Divider(),
      Text('مقایسه با هفته $previousKey'),
      Text('هزینه هفته قبل: ${toman(previous.expenses)}'),
      if(budget!=null)...[
        Builder(builder:(_){
          final review=PrimeWeeklyReview.compare(current,previous,weeklyBudget:budget);
          return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('تغییر هزینه: ${toman(review.expenseChange)}'
              '${review.expenseChangePercent==null?' (درصد نامشخص؛ هزینه هفته قبل صفر بوده)':' (${review.expenseChangePercent!.toStringAsFixed(1)}٪)'}'),
            Text('بیشترین دسته هزینه: ${review.busiestCategory}'),
            const SizedBox(height:8),
            for(final tip in review.suggestions)Padding(
              padding:const EdgeInsets.only(bottom:5),child:Text('• $tip')),
          ]);
        }),
      ]else Text('تغییر هزینه: ${toman(current.expenses-previous.expenses)}'),
      const SizedBox(height:8),
      const Text('این گزارش فقط بر اساس تراکنش‌های ثبت‌شده است. انتقال بین حساب‌ها درآمد یا هزینه محسوب نمی‌شود.',
        style:TextStyle(fontSize:12)),
    ])),
    actions:[TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('بستن'))],
  ));
}
Widget analyticsPage(){
  final start=weekStart(m.financialToday);
  final end=DateTime(start.year,start.month,start.day+6);
  final spendable=max(0,m.currentBudget-m.currentTarget);
  final records=<PrimeRecord>[];
  for(final e in m.entries){
    if(e.kind!='expense'&&e.kind!='income')continue;
    DateTime parsed;
    try{parsed=parseDate(e.date);}catch(_){continue;}
    if(e.amount<0)continue;
    records.add(PrimeRecord(id:e.id,date:parsed,amount:e.amount,
      isExpense:e.kind=='expense',category:e.category.trim().isEmpty?'سایر':e.category,note:e.note));
  }
  // Preserve the exact weekly total, including any rounding remainder.
  final weights=m.weights.map((v)=>max(0,v)).toList();
  final sum=weights.fold<int>(0,(a,b)=>a+b);
  final budgets=<DateTime,int>{};
  var distributed=0;
  for(var i=0;i<7;i++){
    final allocation=sum==0?0:(i==6?spendable-distributed:(spendable*weights[i]~/sum));
    budgets[DateTime(start.year,start.month,start.day+i)]=allocation;
    distributed+=allocation;
  }
  final daily=PrimeAnalytics.dailyChart(records:records,from:start,through:end,dailyBudgets:budgets);
  final categories=PrimeAnalytics.expenseCategories(records:records,from:start,through:end);
  final maximum=max(1,daily.fold<int>(0,(a,d)=>max(a,max(d.budget,d.expense))));
  final categoryMax=categories.isEmpty?1:max(1,categories.first.amount);
  Widget bar(int value,int maxValue,Color color)=>Expanded(child:FractionallySizedBox(
    alignment:Alignment.bottomCenter,heightFactor:(value/maxValue).clamp(0.0,1.0),
    child:Container(decoration:BoxDecoration(color:color,borderRadius:BorderRadius.circular(3)))));
  final completedKeys=m.budgets.keys.where((k){
    try{return m.budgets[k]!>0&&parseDate(k).add(const Duration(days:7)).isBefore(m.financialToday.add(const Duration(days:1)));}
    catch(_){return false;}
  }).toList()..sort();
  final health=PrimeHealthScore.calculate(completedKeys.map((k){
    final settled=m.settlements[k]?['saving']??0;
    final actualTransfers=m.entriesFor(k).where((e)=>e.kind=='transferOut'&&
      (e.toAccount=='savings'||e.toAccount.startsWith('goal:')))
      .fold<int>(0,(sum,e)=>sum+e.amount);
    return PrimeHealthWeek(budget:m.budgets[k]!,expense:m.total(k,'expense'),
      saved:settled+actualTransfers);
  }).toList());
  return ListView(padding:const EdgeInsets.all(14),children:[
    card('گزارش پایان هفته',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('جمع‌بندی آخرین هفته کامل، مقایسه با هفته قبل و پیشنهادهای قابل‌بررسی.'),
      const SizedBox(height:8),
      OutlinedButton.icon(onPressed:weeklyReviewDialog,icon:const Icon(Icons.summarize_outlined),
        label:const Text('مشاهده گزارش پایان هفته')),
    ])),
    card('هشدار جریان نقدی',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('بررسی مانده ۳۰ روز آینده با درنظرگرفتن درآمدها و پرداخت‌های تکرارشونده ثبت‌شده.'),const SizedBox(height:8),OutlinedButton.icon(onPressed:cashflowForecastDialog,icon:const Icon(Icons.trending_down_outlined),label:const Text('بررسی خطر کسری نقدینگی'))])),
    card('پیش‌بینی خرید',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('قبل از خرید، تأثیر مبلغ روی مانده قابل‌خرج هفته را ببینید.'),const SizedBox(height:8),OutlinedButton.icon(onPressed:purchaseForecastDialog,icon:const Icon(Icons.calculate_outlined),label:const Text('شبیه‌سازی خرید'))])),
    card('PRIME Health Score',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(health.score==null?'امتیاز هنوز قابل محاسبه نیست':'${health.score} از ۱۰۰',
        style:const TextStyle(fontSize:26,fontWeight:FontWeight.bold)),
      if(health.score!=null)...[
        LinearProgressIndicator(value:health.score!/100,minHeight:9),
        const SizedBox(height:8),
        Text('کنترل بودجه: ${health.budgetPoints}/۵۰'),
        Text('پس‌انداز واقعی: ${health.savingsPoints}/۳۰'),
        Text('ثبات در رعایت بودجه: ${health.consistencyPoints}/۲۰'),
      ],
      Text('بر پایه ${health.weeksUsed} هفته کامل ثبت‌شده'),
      Text(health.explanation,style:const TextStyle(fontSize:12)),
    ])),
    card('مقایسه بودجه و خرج روزانه',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('سبز: بودجه  •  نارنجی: خرج',style:TextStyle(fontSize:12)),
      const SizedBox(height:14),
      SizedBox(height:155,child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
        for(var i=0;i<7;i++)Expanded(child:Column(children:[
          Expanded(child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
            bar(daily[i].budget,maximum,const Color(0xff087f75)),
            const SizedBox(width:3),
            bar(daily[i].expense,maximum,Colors.deepOrange),
          ])),
          const SizedBox(height:6),Text(weekdays[i].substring(0,1),style:const TextStyle(fontSize:11)),
        ])),
      ])),
      const SizedBox(height:10),
      for(var i=0;i<7;i++)Padding(padding:const EdgeInsets.symmetric(vertical:3),child:Row(children:[
        Expanded(child:Text(weekdays[i])),
        Text('بودجه ${toman(daily[i].budget)}'),
        const SizedBox(width:8),
        Text('خرج ${toman(daily[i].expense)}',style:TextStyle(color:daily[i].remaining<0?Colors.red:null)),
      ])),
    ])),
    card('هزینه‌ها بر اساس دسته‌بندی',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      if(categories.isEmpty)const Text('هنوز هزینه‌ای برای این هفته ثبت نشده است.'),
      for(final category in categories)Padding(padding:const EdgeInsets.symmetric(vertical:7),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(category.category),Text(toman(category.amount))]),
        const SizedBox(height:5),
        LinearProgressIndicator(value:category.amount/categoryMax,minHeight:7,color:const Color(0xff087f75)),
      ])),
    ])),
    card('روند ۱۲ هفته اخیر',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('مقایسه واقعی هزینه و درآمد هفته‌ها؛ هفته‌های بدون سابقه نمایش داده نمی‌شوند.'),
      const SizedBox(height:8),
      for(final key in (m.budgets.keys.where((k)=>k.compareTo(m.currentWeek)<=0)
          .toList()..sort((a,b)=>b.compareTo(a))).take(12))
        Padding(padding:const EdgeInsets.symmetric(vertical:6),child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('هفته $key'),
          Text('خرج: ${toman(m.total(key,'expense'))} • درآمد: ${toman(m.total(key,'income'))}'),
          LinearProgressIndicator(
            value:(m.budgets[key]??0)>0
              ?(m.total(key,'expense')/(m.budgets[key]??1)).clamp(0.0,1.0):0,
            color:m.total(key,'expense')>(m.budgets[key]??0)
              ?Colors.deepOrange:const Color(0xff087f75)),
        ])),
    ])),
    challengesSection(),
    card('پیشنهاد پس‌انداز هفته آینده',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('پیشنهاد بر پایه هفته‌های کامل ثبت‌شده و ورودی‌های هفته آینده محاسبه می‌شود.'),
      const SizedBox(height:8),
      OutlinedButton.icon(onPressed:savingsAdviceDialog,icon:const Icon(Icons.savings_outlined),
        label:const Text('محاسبه پیشنهاد شخصی')),
    ])),
    card('خلاصه این هفته',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('درآمد ثبت‌شده: ${toman(m.income)}'),
      Text('هزینه ثبت‌شده: ${toman(m.expense)}'),
      Text('مانده بودجه قابل‌خرج: ${toman(spendable-m.expense)}'),
      const SizedBox(height:8),
      const Text('این گزارش فقط از تراکنش‌های ثبت‌شده محاسبه می‌شود و پیش‌بینی نیست.',style:TextStyle(fontSize:12)),
    ])),
  ]);
}
Future<void> addScheduleDialog() async {
  final title=TextEditingController();
  final amount=TextEditingController();
  var due=DateTime.now();
  var expense=true;
  var monthly=true;
  await showDialog<void>(context:context,builder:(dialog)=>StatefulBuilder(
    builder:(dialog,refresh)=>AlertDialog(
      title:const Text('برنامه مالی تکرارشونده'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:title,decoration:const InputDecoration(labelText:'عنوان پرداخت یا درآمد')),
        TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'مبلغ به تومان')),
        SwitchListTile(title:Text(expense?'هزینه':'درآمد'),value:expense,onChanged:(v)=>refresh(()=>expense=v)),
        SwitchListTile(title:Text(monthly?'ماهانه':'هفتگی'),value:monthly,onChanged:(v)=>refresh(()=>monthly=v)),
        OutlinedButton.icon(icon:const Icon(Icons.calendar_month),label:Text('اولین سررسید: ${dateKey(due)}'),
          onPressed:()async{final d=await showDatePicker(context:dialog,initialDate:due,firstDate:DateTime(2020),lastDate:DateTime(2100));if(d!=null)refresh(()=>due=d);}),
        const Text('ثبت این برنامه، تراکنش مالی ایجاد نمی‌کند. پرداخت واقعی باید جداگانه تأیید و ثبت شود.',style:TextStyle(fontSize:12)),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('انصراف')),
        FilledButton(onPressed:()async{
          final n=int.tryParse(amount.text.replaceAll(',',''));
          if(title.text.trim().isEmpty||n==null||n<=0){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('عنوان و مبلغ معتبر وارد کنید')));return;}
          try{await m.addSchedule(PrimeScheduledItem(id:DateTime.now().microsecondsSinceEpoch.toString(),title:title.text.trim(),amount:n,isExpense:expense,firstDue:due,frequency:monthly?PrimeScheduleFrequency.monthly:PrimeScheduleFrequency.weekly));
            if(dialog.mounted)Navigator.pop(dialog);
          }catch(e){if(dialog.mounted)ScaffoldMessenger.of(dialog).showSnackBar(SnackBar(content:Text('$e')));}
        },child:const Text('ذخیره برنامه'))],
    )));
  title.dispose();amount.dispose();
}
Widget calendarPage(){
  final from=day(DateTime.now());
  final until=DateTime(from.year,from.month+3,from.day);
  final upcoming=PrimeCalendarPlanner.upcoming(schedules:m.schedules,from:from,through:until);
  final byId={for(final s in m.schedules)s.id:s};
  return ListView(padding:const EdgeInsets.all(14),children:[
    
    Prime32CalendarView(
      entries: m.entries.map((entry) {
        return Prime32CalendarEntry(
          id: entry.id,
          date: parseDate(entry.date),
          kind: entry.kind,
          amount: entry.amount,
          category: entry.category,
          note: entry.note,
        );
      }).toList(),
      
      onAddEntry: (date, kind) => entryDialog(kind, selectedDate: date),
  
    ),

    card('تقویم مالی ۹۰ روز آینده',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('سررسیدهای آینده، صرفاً پیش‌بینی هستند و هیچ مبلغی خودکار از موجودی کم نمی‌شود.'),
      const SizedBox(height:8),FilledButton.icon(onPressed:addScheduleDialog,icon:const Icon(Icons.add),label:const Text('افزودن پرداخت یا درآمد تکراری')),
      if(m.schedules.isEmpty)const Padding(padding:EdgeInsets.all(12),child:Text('هنوز برنامه تکرارشونده‌ای ثبت نشده است.')),
    ])),
    for(final s in m.schedules)card(s.title,Row(children:[
      Expanded(child:Text('${s.isExpense?'هزینه':'درآمد'} • ${s.frequency==PrimeScheduleFrequency.monthly?'ماهانه':'هفتگی'} • ${toman(s.amount)}')),
      IconButton(icon:const Icon(Icons.delete_outline),tooltip:'حذف برنامه',onPressed:()async{
        final yes=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('حذف برنامه؟'),content:Text('برنامه «${s.title}» حذف شود؟ تراکنش‌های ثبت‌شده تغییر نمی‌کنند.'),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('حذف'))]));
        if(yes==true)await m.removeSchedule(s.id);
      }),
    ])),
    card('سررسیدهای پیش رو',Column(children:[
      if(upcoming.isEmpty)const Text('در این بازه سررسیدی وجود ندارد.'),
      for(final event in upcoming)ListTile(
        title:Text(byId[event.scheduleId]?.title??'برنامه حذف‌شده'),
        subtitle:Text(dateKey(event.due)),
        trailing:Text('${event.signedAmount<0?'-':'+'}${toman(event.signedAmount.abs())}',style:TextStyle(color:event.signedAmount<0?Colors.deepOrange:Colors.teal)),
      ),
    ])),
  ]);
}
Future<void> addWalletDialog() async {
  final name=TextEditingController();
  final opening=TextEditingController(text:'0');
  bool protected=false;
  await showDialog<void>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(dialogContext,refresh)=>AlertDialog(
    title:const Text('کیف‌پول جدید'),
    content:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:name,decoration:const InputDecoration(labelText:'نام کیف‌پول')),
      TextField(controller:opening,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'موجودی اولیه (تومان)')),
      SwitchListTile(title:const Text('صندوق اضطراری محافظت‌شده'),value:protected,onChanged:(v)=>refresh(()=>protected=v)),
      const Text('موجودی اولیه را دستی وارد کنید. این بخش فعلاً با تراکنش‌های قدیمی همگام نیست و نباید با موجودی داشبورد جمع شود.'),
    ]),
    actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('انصراف')),
      FilledButton(onPressed:() async {
        final amount=int.tryParse(opening.text.trim());
        if(name.text.trim().isEmpty||amount==null||amount<0){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('نام یا موجودی اولیه نامعتبر است')));return;}
        final wallet=PrimeWallet(id:'wallet_${DateTime.now().microsecondsSinceEpoch}',name:name.text.trim(),openingBalance:amount,protected:protected);
        try{
          final next=PrimeWalletLedger(wallets:[...m.walletLedger.wallets,wallet],movements:m.walletLedger.movements);
          m.walletLedger=next;await m.save();
          if(dialogContext.mounted)Navigator.pop(dialogContext);
          if(mounted)setState((){});
        }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
      },child:const Text('ذخیره'))],
  )));
  name.dispose();opening.dispose();
}
Future<void> walletTransferDialog() async {
  final wallets=m.walletLedger.wallets;
  if(wallets.length<2)return;
  String from=wallets.first.id,to=wallets[1].id;
  final amount=TextEditingController();
  await showDialog<void>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(dialogContext,refresh)=>AlertDialog(
    title:const Text('انتقال بین کیف‌پول‌ها'),
    content:Column(mainAxisSize:MainAxisSize.min,children:[
      DropdownButtonFormField<String>(value:from,decoration:const InputDecoration(labelText:'مبدأ'),items:[for(final w in wallets)DropdownMenuItem(value:w.id,child:Text(w.name))],onChanged:(v){if(v!=null)refresh(()=>from=v);}),
      DropdownButtonFormField<String>(value:to,decoration:const InputDecoration(labelText:'مقصد'),items:[for(final w in wallets)DropdownMenuItem(value:w.id,child:Text(w.name))],onChanged:(v){if(v!=null)refresh(()=>to=v);}),
      TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'مبلغ انتقال (تومان)')),
    ]),
    actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('انصراف')),
      FilledButton(onPressed:() async {
        final value=int.tryParse(amount.text.trim());
        if(value==null||value<=0||from==to){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('مبلغ یا مقصد نامعتبر است')));return;}
        final isProtected=wallets.firstWhere((w)=>w.id==from).protected;
        var authorized=false;
        if(isProtected){
          authorized=await showDialog<bool>(context:dialogContext,builder:(c)=>AlertDialog(title:const Text('برداشت از صندوق اضطراری'),content:Text('آیا برداشت ${toman(value)} از صندوق محافظت‌شده را تأیید می‌کنید؟'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('تأیید برداشت'))]))??false;
          if(!authorized)return;
        }
        try{
          final next=m.walletLedger.transfer(PrimeWalletMovement(id:'move_${DateTime.now().microsecondsSinceEpoch}',fromId:from,toId:to,amount:value,occurredAt:DateTime.now()),allowProtectedWithdrawal:authorized);
          m.walletLedger=next;await m.save();
          if(dialogContext.mounted)Navigator.pop(dialogContext);
          if(mounted)setState((){});
        }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
      },child:const Text('ثبت انتقال'))],
  )));
  amount.dispose();
}
Future<void> walletAuditDialog() async {
  final audit=PrimeWalletReconciliation.audit(
    legacySpendable:m.available,
    legacySavings:m.savedBalance,
    legacyTransferCount:m.entries.where((e)=>e.kind=='transferOut'||e.kind=='transferIn').length,
    ledger:m.walletLedger,
  );
  final mapping=PrimeWalletMappingAudit.inspect(
    entryKinds:m.entries.map((e)=>e.kind),
    ledger:m.walletLedger,
    provenance:m.walletProvenance,
  );
  final impact=PrimeWalletImpactPreview.calculate(
    walletIds:m.walletLedger.wallets.map((w)=>w.id),
    entries:m.entries.where((e)=>m.walletEntryMappings.containsKey(e.id)).map((e)=>
      PrimeMappedEntryImpact(id:e.id,walletId:m.walletEntryMappings[e.id]!.walletId,
        kind:e.kind,amount:e.amount)),
  );
  final cutoffPreview=PrimeCutoffPreview.calculate(
    walletIds:m.walletLedger.wallets.map((w)=>w.id),cutoffs:m.walletCutoffs,
    entries:m.entries.where((e)=>m.walletEntryMappings.containsKey(e.id)).map((e)=>
      PrimeDatedWalletImpact(m.walletEntryMappings[e.id]!.walletId,e.kind,e.date,e.amount)),
  );
  final readiness=PrimeWalletReadiness.inspect(
    walletIds:m.walletLedger.wallets.map((w)=>w.id),
    legacyEntryIds:m.entries.where((e)=>e.kind=='income'||e.kind=='expense').map((e)=>e.id),
    entryWalletIds:{for(final item in m.walletEntryMappings.entries)item.key:item.value.walletId},
    walletIdsWithCutoff:m.walletCutoffs.keys,
    // User-attested evidence only; not independent bank verification.
    walletIdsWithConfirmedOpening:m.walletOpeningConfirmations.keys,
    walletIdsWithResolvedSource:m.walletProvenance.entries.where((e)=>
      e.value.source==PrimeOpeningSource.legacyFunds ||
      e.value.source==PrimeOpeningSource.externalFunds).map((e)=>e.key),
  );
  if(!mounted)return;
  await showDialog<void>(context:context,builder:(c)=>AlertDialog(
    title:const Text('بررسی سازگاری موجودی‌ها'),
    content:SizedBox(width:440,child:SingleChildScrollView(child:Column(
      mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,
      children:[
        const Text('این بررسی فقط خواندنی است و هیچ موجودی یا تراکنشی را تغییر نمی‌دهد.'),
        const Divider(),
        const Text('دروازه ایمنی تطبیق نهایی',style:TextStyle(fontWeight:FontWeight.bold)),
        Text('تطبیق‌شده: ${readiness.mapped} از ${readiness.total} تراکنش درآمد/هزینه'),
        for(final reason in readiness.blockers)Text('• $reason'),
        const Text('تأیید کاربر صرفاً یک اظهار مستند است، نه راستی‌آزمایی بانکی. حتی آمادگی برای بازبینی به معنای مجوز ادغام خودکار نیست.'),

        const Divider(),
        const Text('دفتر قدیمی برنامه',style:TextStyle(fontWeight:FontWeight.bold)),
        Text('مانده قابل‌خرج هفته جاری: ${toman(audit.legacySpendable)}'),
        Text('پس‌انداز ثبت‌شده: ${toman(audit.legacySavings)}'),
        Text('رکوردهای انتقال قدیمی: ${audit.legacyTransferCount}'),
        const Divider(),
        const Text('دفتر مستقل کیف‌پول‌ها',style:TextStyle(fontWeight:FontWeight.bold)),
        Text('مجموع کیف‌پول‌ها: ${toman(audit.walletTotal)}'),
        Text('موجودی محافظت‌شده: ${toman(audit.walletProtected)}'),
        Text('موجودی غیرمحافظت‌شده: ${toman(audit.walletSpendable)}'),
        Text('انتقال‌های کیف‌پول: ${audit.walletTransferCount}'),
      Text('منشأ نامشخص یا ترکیبی: ${PrimeWalletProvenanceAudit.hasUnresolved(walletIds:m.walletLedger.wallets.map((w)=>w.id),declarations:m.walletProvenance)?'وجود دارد':'در توضیحات کاربر مشخص شده'}'),
        const Divider(),
        const Text('آمادگی اتصال تراکنش‌ها',style:TextStyle(fontWeight:FontWeight.bold)),
        Text('تراکنش‌های قدیمی بدون کیف‌پول مشخص: ${mapping.unassignedLegacyEntries-m.walletEntryMappings.length}'),
        Text('تطبیق‌های دستی ثبت‌شده: ${m.walletEntryMappings.length}'),
        const Divider(),
        const Text('اثر فرضی تراکنش‌های تطبیق‌شده (فقط پیش‌نمایش)',style:TextStyle(fontWeight:FontWeight.bold)),
        Text('درآمدهای تطبیق‌شده: ${impact.incomeCount} • هزینه‌ها: ${impact.expenseCount}'),
        Text('رکوردهای کنارگذاشته‌شده از محاسبه: ${impact.excludedCount}'),
        Text('خالص تغییر فرضی: ${toman(impact.netChange)}'),
        for(final w in m.walletLedger.wallets)
          Text('${w.name}: ${toman(impact.netByWallet[w.id] ?? 0)}'),
        const Divider(),
        const Text('پیش‌نمایش پس از تاریخ مبنای اعلام‌شده',style:TextStyle(fontWeight:FontWeight.bold)),
        Text('تراکنش‌های پس از مبنا: ${cutoffPreview.included} • در/قبل از مبنا: ${cutoffPreview.beforeOrOnCutoff}'),
        Text('بدون تاریخ مبنای کیف‌پول: ${cutoffPreview.missingCutoff} • انتقال‌های مستثنا: ${cutoffPreview.excludedTransfers}'),
        for(final w in m.walletLedger.wallets)
          Text('${w.name}: ${m.walletCutoffs[w.id]==null?'مبنا تعیین نشده':toman(cutoffPreview.postOpeningNet[w.id] ?? 0)}'),
        const Text('تاریخ مبنا فقط اظهار کاربر است و ثابت نمی‌کند موجودی اولیه دقیقاً در آن تاریخ محاسبه شده؛ این اعداد به موجودی اضافه نمی‌شوند.'),
        const Text('هشدار: این ارقام نباید به موجودی اولیه کیف‌پول افزوده شوند؛ ممکن است تراکنش‌های قدیمی قبلاً در آن لحاظ شده باشند. هیچ تغییری در موجودی اعمال نشده است.'),
        Text('درآمد: ${mapping.legacyIncomeCount} • هزینه: ${mapping.legacyExpenseCount}'),
        Text('رکوردهای انتقال: ${mapping.legacyInternalTransferCount} • سایر: ${mapping.unsupportedEntryCount}'),
        Text('کیف‌پول با منشأ نامشخص: ${mapping.unknownWalletCount} • ترکیبی: ${mapping.mixedWalletCount}'),
        Text('کیف‌پول با منشأ قدیمی: ${mapping.legacyFundedWalletCount} • پول جدید: ${mapping.externalFundedWalletCount}'),
        Text('مجموع موجودی اولیه اعلام‌شده از پول قدیمی: ${toman(mapping.legacyOpeningBalanceExposure)}'),
        const Text('این مبلغ ممکن است با موجودی دفتر قدیمی هم‌پوشانی داشته باشد؛ اختلاف یا برابری عددی، تطبیق قطعی نیست.'),
        const SizedBox(height:8),
        const Text('تراکنش‌های قدیمی شناسه کیف‌پول ندارند؛ هیچ‌کدام به‌طور خودکار به کیف‌پول نسبت داده نشده‌اند.'),
        if(audit.legacySpendableIsNegative)const Text(
          'هشدار: مانده بودجه قدیمی منفی است.',
          style:TextStyle(color:Colors.deepOrange)),
        const SizedBox(height:12),
        const Text('جمع کردن این دو دفتر مجاز نیست: ممکن است یک پول در هر دو ثبت شده باشد. برای اتصال قطعی، ابتدا باید منبع هر موجودی و تراکنش تعیین و تطبیق داده شود.'),
      ],
    ))),
    actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('بستن'))],
  ));
}

Future<void> walletSourceDialog(PrimeWallet wallet) async {
  final previous=m.walletProvenance[wallet.id];
  var selected=previous?.source ?? PrimeOpeningSource.unknown;
  final note=TextEditingController(text:previous?.note ?? '');
  const names={
    PrimeOpeningSource.unknown:'نامشخص',
    PrimeOpeningSource.legacyFunds:'همان پول ثبت‌شده در سیستم قدیمی',
    PrimeOpeningSource.externalFunds:'پول جداگانه و خارج از دفتر قدیمی',
    PrimeOpeningSource.mixed:'ترکیبی از منابع قدیمی و جدید',
  };
  try {
    await showDialog<void>(context:context,builder:(dialogContext)=>StatefulBuilder(
      builder:(dialogContext,refresh)=>AlertDialog(
        title:Text('منبع موجودی اولیه: ${wallet.name}'),
        content:SizedBox(width:430,child:SingleChildScrollView(child:Column(
          mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('موجودی اولیه: ${toman(wallet.openingBalance)}'),
          const SizedBox(height:8),
          const Text('این انتخاب صرفاً توضیح منشأ پول است؛ موجودی یا تراکنش را تغییر نمی‌دهد.'),
          for(final source in PrimeOpeningSource.values)RadioListTile<PrimeOpeningSource>(
            title:Text(names[source]!),value:source,groupValue:selected,
            onChanged:(v){if(v!=null)refresh(()=>selected=v);}),
          TextField(controller:note,maxLines:2,decoration:const InputDecoration(
            labelText:'توضیح اختیاری درباره منشأ پول')),
        ]))),
        actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('انصراف')),
          FilledButton(onPressed:()async{
            final old=m.walletProvenance[wallet.id];
            m.walletProvenance[wallet.id]=PrimeWalletProvenance(
              walletId:wallet.id,source:selected,note:note.text.trim());
            try{await m.save();if(dialogContext.mounted)Navigator.pop(dialogContext);
              if(mounted)setState((){});
            }catch(e){if(old==null){m.walletProvenance.remove(wallet.id);}else{m.walletProvenance[wallet.id]=old;}
              if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));
            }
          },child:const Text('ذخیره توضیح'))],
      )));
  } finally {note.dispose();}
}

Future<void> walletCutoffDialog(PrimeWallet wallet) async {
  final current=m.walletCutoffs[wallet.id];
  final selected=await showDatePicker(context:context,
    initialDate:current?.openingDate ?? DateTime.now(),
    firstDate:DateTime(2000),lastDate:DateTime(2100),
    helpText:'تاریخ مبنای موجودی اولیه');
  if(selected==null||!mounted)return;
  final approved=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
    title:const Text('تأیید تاریخ مبنا'),
    content:Text('آیا موجودی اولیه «${wallet.name}» مربوط به پایان روز ${dateKey(selected)} است؟ این تاریخ صرفاً برای پیش‌نمایش استفاده می‌شود و هیچ مبلغی جابه‌جا نمی‌شود.'),
    actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('انصراف')),
      FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('تأیید'))]));
  if(approved!=true)return;
  final old=m.walletCutoffs[wallet.id];
  m.walletCutoffs[wallet.id]=PrimeWalletCutoff(walletId:wallet.id,openingDate:selected);
  final oldConfirmation=m.walletOpeningConfirmations.remove(wallet.id);
  try{await m.save();if(mounted)setState((){});}catch(e){
    if(old==null){m.walletCutoffs.remove(wallet.id);}else{m.walletCutoffs[wallet.id]=old;}
    if(oldConfirmation!=null)m.walletOpeningConfirmations[wallet.id]=oldConfirmation;
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));
  }
}

Future<void> walletOpeningConfirmationDialog(PrimeWallet wallet) async {
  final cutoff=m.walletCutoffs[wallet.id];
  if(cutoff==null){
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ابتدا تاریخ مبنا را تعیین کنید')));
    return;
  }
  final evidence=TextEditingController(text:m.walletOpeningConfirmations[wallet.id]?.evidenceNote ?? '');
  final amount=TextEditingController();
  try{
    final accepted=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:const Text('تأیید مستند موجودی اولیه'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        Text('موجودی اولیه ثبت‌شده برای ${wallet.name}: ${toman(wallet.openingBalance)} در پایان روز ${dateKey(cutoff.openingDate)}'),
        const Text('مبلغ را از صورت‌حساب یا یادداشت مالی همان تاریخ مستقلاً بررسی و دقیقاً وارد کنید. این کار به معنی تأیید بانکی نیست.'),
        TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'مبلغ تأییدشده (تومان)')),
        TextField(controller:evidence,maxLines:2,decoration:const InputDecoration(labelText:'شرح منبع بررسی (حداقل ۸ نویسه)')),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('انصراف')),
        FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ثبت تأیید کاربر'))],
    ));
    if(accepted!=true||!mounted)return;
    final verified=int.tryParse(amount.text.trim());
    if(verified==null||verified!=wallet.openingBalance){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('مبلغ بررسی‌شده باید دقیقاً برابر موجودی اولیه ثبت‌شده باشد')));
      return;
    }
    final item=PrimeWalletOpeningConfirmation(walletId:wallet.id,
      cutoffDate:dateKey(cutoff.openingDate),openingBalance:verified,
      evidenceNote:evidence.text.trim(),attestedAt:DateTime.now());
    final old=m.walletOpeningConfirmations[wallet.id];
    m.walletOpeningConfirmations[wallet.id]=item;
    try{await m.save();if(mounted)setState((){});}catch(e){
      if(old==null){m.walletOpeningConfirmations.remove(wallet.id);}else{m.walletOpeningConfirmations[wallet.id]=old;}
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));
    }
  }on FormatException catch(e){
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.message)));
  }finally{evidence.dispose();amount.dispose();}
}

Future<void> walletEntryMappingDialog() async {
  if(m.walletLedger.wallets.isEmpty){
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('ابتدا یک کیف‌پول ایجاد کنید')));
    return;
  }
  await showDialog<void>(context:context,builder:(dialogContext)=>AlertDialog(
    title:const Text('تطبیق دستی تراکنش‌ها'),
    content:SizedBox(width:480,height:440,child:ListView(children:[
      const Text('فقط برچسب ارتباط ثبت می‌شود. موجودی، بودجه و تراکنش تغییر نمی‌کنند. پیش از انتخاب، منشأ هر تراکنش را بررسی کنید.'),
      const SizedBox(height:12),
      for(final entry in m.entries.reversed.take(100))ListTile(
        title:Text('${entry.category} • ${toman(entry.amount)}'),
        subtitle:Text('${entry.date} • ${entry.kind} • ${m.walletLedger.wallets.where((w)=>w.id==m.walletEntryMappings[entry.id]?.walletId).map((w)=>w.name).join(', ')}'),
        trailing:const Icon(Icons.chevron_left),
        onTap:()async{
          final current=m.walletEntryMappings[entry.id];
          final selected=await showDialog<String>(context:dialogContext,builder:(choiceContext)=>SimpleDialog(
            title:const Text('انتخاب کیف‌پول مرتبط'),children:[
              for(final wallet in m.walletLedger.wallets)SimpleDialogOption(
                onPressed:()=>Navigator.pop(choiceContext,wallet.id),child:Text(wallet.name)),
              if(current!=null)SimpleDialogOption(onPressed:()=>Navigator.pop(choiceContext,'__remove__'),child:const Text('حذف تطبیق')),
            ]));
          if(selected==null)return;
          final old=m.walletEntryMappings[entry.id];
          if(selected=='__remove__'){m.walletEntryMappings.remove(entry.id);}else{
            m.walletEntryMappings[entry.id]=PrimeWalletEntryMapping(entryId:entry.id,walletId:selected);
          }
          try{
            PrimeWalletEntryMappingRules.validate(entryIds:m.entries.map((e)=>e.id).toList(),
              walletIds:m.walletLedger.wallets.map((w)=>w.id).toList(),mappings:m.walletEntryMappings.values.toList());
            await m.save();
            if(mounted)setState((){});
            if(dialogContext.mounted)Navigator.pop(dialogContext);
          }catch(e){
            if(old==null){m.walletEntryMappings.remove(entry.id);}else{m.walletEntryMappings[entry.id]=old;}
            if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));
          }
        },
      ),
    ])),
    actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('بستن'))],
  ));
}

Widget walletsPage(){
  final ledger=m.walletLedger;
  return ListView(padding:const EdgeInsets.all(14),children:[
    card('کیف‌پول‌ها و صندوق اضطراری',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('این دفتر کیف‌پول فعلاً مستقل از درآمد، هزینه و پس‌انداز قدیمی است. برای جلوگیری از دوباره‌شماری، مجموع آن به داشبورد اضافه نمی‌شود.'),
      const SizedBox(height:12),
      Text('مجموع موجودی ثبت‌شده: ${toman(ledger.totalBalance)}'),
      Text('موجودی محافظت‌شده: ${toman(ledger.protectedBalance)}'),
      Text('موجودی قابل‌انتقال عادی: ${toman(ledger.spendableBalance)}'),
      const SizedBox(height:12),
      Wrap(spacing:8,children:[FilledButton.icon(onPressed:addWalletDialog,icon:const Icon(Icons.add),label:const Text('کیف‌پول جدید')),
        OutlinedButton.icon(onPressed:ledger.wallets.length<2?null:walletTransferDialog,icon:const Icon(Icons.swap_horiz),label:const Text('انتقال پول')),
        OutlinedButton.icon(onPressed:walletAuditDialog,icon:const Icon(Icons.fact_check_outlined),label:const Text('بررسی سازگاری موجودی')),
        OutlinedButton.icon(onPressed:walletEntryMappingDialog,icon:const Icon(Icons.link),label:const Text('تطبیق دستی تراکنش‌ها'))]),
    ])),
    for(final wallet in ledger.wallets)card(wallet.name,Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(toman(ledger.balanceOf(wallet.id))),
      if(wallet.protected)const Text('صندوق اضطراری • برداشت با تأیید جداگانه'),
      Text('منبع موجودی اولیه: ${m.walletProvenance[wallet.id]?.source.name ?? 'unknown'}'),
      Text('تاریخ مبنای موجودی: ${m.walletCutoffs[wallet.id]==null?'تعیین نشده':dateKey(m.walletCutoffs[wallet.id]!.openingDate)}'),
      Text(m.walletOpeningConfirmations.containsKey(wallet.id)?'موجودی اولیه: با اظهار مستند کاربر ثبت شده':'موجودی اولیه: تأیید نشده'),
      TextButton.icon(onPressed:()=>walletOpeningConfirmationDialog(wallet),icon:const Icon(Icons.verified_user_outlined),label:const Text('ثبت تأیید مستند موجودی اولیه')),
      TextButton.icon(onPressed:()=>walletCutoffDialog(wallet),icon:const Icon(Icons.event),label:const Text('تعیین تاریخ مبنای موجودی')),
      TextButton.icon(onPressed:()=>walletSourceDialog(wallet),icon:const Icon(Icons.edit_note),label:const Text('ثبت / ویرایش منشأ موجودی')),
    ])),
    if(ledger.movements.isNotEmpty)card('تاریخچه انتقال‌ها',Column(children:[
      for(final move in ledger.movements.reversed.take(30))ListTile(
        title:Text(toman(move.amount)),
        subtitle:Text('${ledger.wallets.firstWhere((w)=>w.id==move.fromId).name} ← ${ledger.wallets.firstWhere((w)=>w.id==move.toId).name} • ${dateKey(move.occurredAt)}'),
      ),
    ])),
  ]);
}
Widget debtsPage(){final name=TextEditingController(),amount=TextEditingController();return ListView(padding:const EdgeInsets.all(14),children:[card('طلب و بدهی',Column(children:[TextField(controller:name,decoration:const InputDecoration(labelText:'نام شخص')),TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'مبلغ؛ طلب مثبت، بدهی منفی')),FilledButton(onPressed:(){if(name.text.trim().isNotEmpty){m.changeDebt(name.text.trim(),int.tryParse(amount.text)??0);setState((){});}},child:const Text('ثبت / تسویه'))])),for(final e in m.debts.entries)card(e.key,Text('${e.value>=0?'طلب':'بدهی'}: ${toman(e.value.abs())}'))]);}
@override Widget build(BuildContext context)=>Directionality(textDirection:ui.TextDirection.rtl,child:Scaffold(appBar:AppBar(title:const Text('هفته‌پول PRIME'),actions:[IconButton(onPressed:preferencesDialog,icon:const Icon(Icons.tune),tooltip:'شخصی‌سازی'),IconButton(onPressed:()=>setState((){showWallets=!showWallets;showCalendar=false;}),icon:Icon(showWallets?Icons.close:Icons.account_balance_wallet_outlined),tooltip:'کیف‌پول‌ها'),IconButton(onPressed:()=>setState((){showCalendar=!showCalendar;showWallets=false;}),icon:Icon(showCalendar?Icons.close:Icons.event_note_outlined),tooltip:'تقویم مالی'),IconButton(onPressed:backupDialog,icon:const Icon(Icons.backup_outlined),tooltip:'پشتیبان‌گیری و بازیابی'),IconButton(onPressed:()=>transferDialog(),icon:const Icon(Icons.savings_outlined),tooltip:'انتقال به پس‌انداز')]),body:showWallets?walletsPage():showCalendar?calendarPage():[dashboard(),goalsPage(),historyPage(),analyticsPage(),debtsPage()][tab],bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState((){tab=i;showCalendar=false;showWallets=false;}),destinations:const [NavigationDestination(icon:Icon(Icons.dashboard_outlined),label:'داشبورد'),NavigationDestination(icon:Icon(Icons.flag_outlined),label:'اهداف'),NavigationDestination(icon:Icon(Icons.history),label:'تاریخچه'),NavigationDestination(icon:Icon(Icons.bar_chart_outlined),label:'گزارش‌ها'),NavigationDestination(icon:Icon(Icons.handshake_outlined),label:'طلب و بدهی')])));}

