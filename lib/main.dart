import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:math';
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
class FinanceModel extends ChangeNotifier {
  final List<Entry> entries=[]; final List<Goal> goals=[];
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
      budgets.addAll((m['budgets'] as Map? ?? {}).map((k,v)=>MapEntry('$k',(v as num).toInt())));
      targets.addAll((m['targets'] as Map? ?? {}).map((k,v)=>MapEntry('$k',(v as num).toInt())));
      debts.addAll((m['debts'] as Map? ?? {}).map((k,v)=>MapEntry('$k',(v as num).toInt())));
      (m['settlements'] as Map? ?? {}).forEach((k,v){settlements['$k']=Map<String,int>.from((v as Map).map((a,b)=>MapEntry('$a',(b as num).toInt())));});
      if(m['weights'] is List && (m['weights'] as List).length==7)weights=List<int>.from(m['weights']);
      dayStartHour=(m['dayStartHour'] as num? ?? 0).toInt();
    }catch(_){}}
    loaded=true;notifyListeners();
  }
  Map<String,dynamic> toJson()=>{'entries':entries.map((e)=>e.toJson()).toList(),'goals':goals.map((e)=>e.toJson()).toList(),'budgets':budgets,'targets':targets,'settlements':settlements,'debts':debts,'weights':weights,'dayStartHour':dayStartHour};
  Future<void> save()async{await prefs.setString('haftepool_native_v1',jsonEncode(toJson()));notifyListeners();}
  DateTime get financialToday {final now=DateTime.now();return day(now.hour<dayStartHour?now.subtract(const Duration(days:1)):now);}
  String get currentWeek=>dateKey(weekStart(financialToday));
  String weekOf(String d)=>dateKey(weekStart(parseDate(d)));
  List<Entry> entriesFor(String week)=>entries.where((e)=>weekOf(e.date)==week).toList();
  int total(String week,String kind)=>entriesFor(week).where((e)=>e.kind==kind).fold(0,(a,e)=>a+e.amount);
  int get currentBudget=>budgets[currentWeek]??0;
  int get currentTarget=>targets[currentWeek]??0;
  int get carryIn=>settlements.entries.where((x)=>dateKey(weekStart(parseDate(x.key).add(const Duration(days:7))))==currentWeek).fold(0,(a,x)=>a+(x.value['next']??0));
  int get income=>total(currentWeek,'income');
  int get expense=>total(currentWeek,'expense');
  int get available=>currentBudget+carryIn+income-expense-total(currentWeek,'transferOut');
  num get savedBalance=>entries.where((e)=>e.kind=='transferOut'&&e.toAccount=='savings').fold(0,(a,e)=>a+e.amount)-entries.where((e)=>e.kind=='transferIn'&&e.account=='savings').fold(0,(a,e)=>a+e.amount)+settlements.values.fold(0,(a,x)=>a+(x['saving']??0));
  num goalBalance(Goal g)=>g.initial+entries.where((e)=>e.kind=='transferOut'&&e.toAccount=='goal:${g.id}').fold(0,(a,e)=>a+e.amount)-entries.where((e)=>e.kind=='transferIn'&&e.account=='goal:${g.id}').fold(0,(a,e)=>a+e.amount);
  int dailyAllowance(int i){final alloc=max(0,currentBudget-currentTarget),sum=weights.reduce((a,b)=>a+b);return sum>0?(alloc*weights[i]/sum).floor():0;}
  int spentOn(DateTime d)=>entries.where((e)=>e.kind=='expense'&&e.date==dateKey(d)).fold(0,(a,e)=>a+e.amount);
  double get expectedSpend {final h=budgets.keys.where((k)=>k!=currentWeek&&k.compareTo(currentWeek)<0).toList()..sort();if(h.isEmpty)return 0;final last=h.reversed.take(8).toList();return last.map((k)=>total(k,'expense')).reduce((a,b)=>a+b)/last.length;}
  int? get suggestedSavings {final h=budgets.keys.where((k)=>k.compareTo(currentWeek)<0).toList()..sort();if(h.isEmpty)return null;final recent=h.reversed.take(8).toList();final vals=recent.map((k)=>max(0,(budgets[k]??0)+total(k,'income')-total(k,'expense'))).toList();return (vals.reduce((a,b)=>a+b)/vals.length/50000).floor()*50000;}
  int get projectedSpend {final idx=(financialToday.difference(weekStart(financialToday)).inDays).clamp(0,6);final elapsed=idx+1;final actual=expense;final pace=actual/elapsed*7;return max(actual,((pace*0.65)+(expectedSpend>0?expectedSpend:pace)*0.35).round());}
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
  void addEntry(String kind,int amount,{String category='سایر',String note='',String account='budget',String toAccount=''}){if(amount<=0)return;entries.add(Entry(id:DateTime.now().microsecondsSinceEpoch.toString(),kind:kind,amount:amount,date:dateKey(financialToday),category:category,note:note,account:account,toAccount:toAccount));save();}
  void transfer(int amount,String to){if(amount<=0||amount>available)throw StateError('موجودی بودجه کافی نیست');addEntry('transferOut',amount,toAccount:to);}
  void settle(String week,int saving){if(settlements.containsKey(week))throw StateError('این هفته قبلاً تسویه شده');final rem=max(0,(budgets[week]??0)+total(week,'income')-total(week,'expense')-total(week,'transferOut'));if(saving<0||saving>rem)throw StateError('مبلغ تقسیم نامعتبر است');settlements[week]={'saving':saving,'next':rem-saving};save();}
  void configureWeek(int budget,int target){budgets[currentWeek]=budget;targets[currentWeek]=target;save();}
  void addGoal(String name,int price,int initial,int weekly){if(name.isEmpty||price<=0||initial<0||weekly<0)return;goals.add(Goal(DateTime.now().microsecondsSinceEpoch.toString(),name,price,initial,weekly));save();}
  void changeDebt(String name,int amount){debts[name]=(debts[name]??0)+amount;save();}
}

class HaftepoolApp extends StatefulWidget {const HaftepoolApp({super.key});@override State<HaftepoolApp> createState()=>_HaftepoolAppState();}
class _HaftepoolAppState extends State<HaftepoolApp>{final model=FinanceModel();@override void initState(){super.initState();model.load();} @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,title:'هفته‌پول PRIME',locale:const Locale('fa'),theme:ThemeData(useMaterial3:true,colorSchemeSeed:const Color(0xff087f75),scaffoldBackgroundColor:const Color(0xfff6f8f7)),home:AnimatedBuilder(animation:model,builder:(context,_)=>model.loaded?Home(model):const Scaffold(body:Center(child:CircularProgressIndicator()))));}
class Home extends StatefulWidget{final FinanceModel m;const Home(this.m,{super.key});@override State<Home> createState()=>_HomeState();}
class _HomeState extends State<Home>{int tab=0;FinanceModel get m=>widget.m;
Future<void> entryDialog(String kind)async{final amount=TextEditingController(),note=TextEditingController();String category='خوراک';await showDialog(context:context,builder:(c)=>AlertDialog(title:Text(kind=='expense'?'ثبت خرید':'ثبت درآمد'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'مبلغ به تومان')),if(kind=='expense')DropdownButtonFormField<String>(initialValue:category,items:['خوراک','رفت‌وآمد','تفریح','خرید','قبض','سایر'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>category=x??category),TextField(controller:note,decoration:const InputDecoration(labelText:'توضیح'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('انصراف')),FilledButton(onPressed:(){final n=int.tryParse(amount.text)??0;if(n>0){m.addEntry(kind,n,category:category,note:note.text);Navigator.pop(c);}},child:const Text('ثبت'))]));}
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
Future<void> setupDialog()async{final b=TextEditingController(text:'${m.currentBudget}'),s=TextEditingController(text:'${m.suggestedSavings??m.currentTarget}');await showDialog(context:context,builder:(c)=>AlertDialog(title:const Text('تنظیم بودجه این هفته'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:b,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'بودجه هفته')),TextField(controller:s,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'هدف پس‌انداز'))]),actions:[FilledButton(onPressed:(){final budget=int.tryParse(b.text)??0,target=int.tryParse(s.text)??0;if(budget>=0&&target>=0&&target<=budget){m.configureWeek(budget,target);Navigator.pop(c);}},child:const Text('تأیید'))]));}
Future<void> goalDialog()async{final name=TextEditingController(),price=TextEditingController(),initial=TextEditingController(text:'0'),weekly=TextEditingController(text:'0');await showDialog(context:context,builder:(c)=>AlertDialog(title:const Text('هدف خرید جدید'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'نام کالا')),TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'قیمت')),TextField(controller:initial,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'موجودی اولیه')),TextField(controller:weekly,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'پس‌انداز هفتگی'))])),actions:[FilledButton(onPressed:(){m.addGoal(name.text,int.tryParse(price.text)??0,int.tryParse(initial.text)??0,int.tryParse(weekly.text)??0);Navigator.pop(c);},child:const Text('ساخت قلک'))]));}
Future<void> transferDialog({String? goal})async{final amount=TextEditingController();String to=goal??'savings';await showDialog(context:context,builder:(c)=>AlertDialog(title:const Text('انتقال واقعی از بودجه'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'مبلغ')),DropdownButtonFormField<String>(initialValue:to,items:[const DropdownMenuItem(value:'savings',child:Text('پس‌انداز عمومی')),...m.goals.map((g)=>DropdownMenuItem(value:'goal:${g.id}',child:Text(g.name)))],onChanged:(x)=>to=x??to)]),actions:[FilledButton(onPressed:(){try{m.transfer(int.tryParse(amount.text)??0,to);Navigator.pop(c);}catch(e){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}},child:const Text('انتقال'))]));}
Future<void> settleDialog(String key)async{final rem=max(0,(m.budgets[key]??0)+m.total(key,'income')-m.total(key,'expense')-m.total(key,'transferOut'));final value=TextEditingController(text:'$rem');await showDialog(context:context,builder:(c)=>AlertDialog(title:const Text('تقسیم مانده پایان هفته'),content:Column(mainAxisSize:MainAxisSize.min,children:[Text('مانده: ${toman(rem)}'),TextField(controller:value,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'سهم پس‌انداز؛ باقی به هفته بعد'))]),actions:[FilledButton(onPressed:(){try{m.settle(key,int.parse(value.text));Navigator.pop(c);}catch(e){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}},child:const Text('تأیید نهایی'))]));}
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
  String coach;
  if(m.currentBudget==0){coach='اول بودجه این هفته را ثبت کن.';}
  else if(overWeek){coach='هشدار: هزینه‌های این هفته از بودجه قابل خرج بیشتر شده است. پیش از خرید بعدی، بودجه و پس‌انداز را بررسی کن.';}
  else if(overToday){coach='هشدار: امروز ${toman(todaySpent-allowance)} بیشتر از سهم روزانه خرج کردی؛ حتی اگر هنوز از بودجه کل هفته عبور نکرده باشی. برای جبران، هزینه روزهای بعد را بازبینی کن.';}
  else if(m.projectedSpend>m.currentBudget+m.income){coach='با روند فعلی ممکن است بودجه کافی نباشد. هزینه‌های اختیاری را کاهش بده.';}
  else{coach='خرج امروز در محدوده سهم روزانه است. برای هدف خرید، مبلغی را که واقعاً کنار می‌گذاری به قلک منتقل کن.';}
  return ListView(padding:const EdgeInsets.all(14),children:[
    if(past.isNotEmpty)card('تسویه هفته گذشته',Column(children:[Text('هفته ${past.last} هنوز تسویه نشده'),FilledButton(onPressed:()=>settleDialog(past.last),child:const Text('تقسیم دستی مانده'))])),
    card('موجودی قابل خرج',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(toman(m.available),style:const TextStyle(fontSize:30,fontWeight:FontWeight.w800,color:Color(0xff087f75))),
      Text('سهم ${weekdays[idx]}: ${toman(allowance)}'),
      Text('خرج امروز: ${toman(todaySpent)}'),
      Text('هدف پس‌انداز: ${toman(m.currentTarget)}'),
      const SizedBox(height:10),
      Wrap(spacing:8,children:[FilledButton(onPressed:()=>entryDialog('expense'),child:const Text('ثبت خرید +')),OutlinedButton(onPressed:()=>entryDialog('income'),child:const Text('درآمد +')),OutlinedButton(onPressed:setupDialog,child:const Text('بودجه هفته'))])
    ])),
    card('درصد مصرف بودجه',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('امروز: ${allowance>0?todayPct.toStringAsFixed(1):'—'}٪ از سهم روزانه'),
      LinearProgressIndicator(value:allowance>0?(todayPct/100).clamp(0.0,1.0):0,color:overToday?Colors.red:const Color(0xff087f75)),
      const SizedBox(height:12),
      Text('هفته: ${spendable>0?weekPct.toStringAsFixed(1):'—'}٪ از بودجه قابل خرج'),
      LinearProgressIndicator(value:spendable>0?(weekPct/100).clamp(0.0,1.0):0,color:overWeek?Colors.red:const Color(0xff087f75)),
      if(allowance==0||spendable==0)const Padding(padding:EdgeInsets.only(top:8),child:Text('برای نمایش درصد، بودجه قابل خرج تعیین کن.')),
    ])),
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
Widget goalsPage()=>ListView(padding:const EdgeInsets.all(14),children:[FilledButton(onPressed:goalDialog,child:const Text('ساخت هدف خرید جدید')),for(final g in m.goals)card(g.name,Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${toman(m.goalBalance(g))} از ${toman(g.price)}'),LinearProgressIndicator(value:(m.goalBalance(g)/g.price).clamp(0,1)),const SizedBox(height:8),Text(g.weekly>0?'زمان تقریبی: ${(max(0,g.price-m.goalBalance(g))/g.weekly).ceil()} هفته':'پس‌انداز هفتگی تعیین نشده'),OutlinedButton(onPressed:()=>transferDialog(goal:'goal:${g.id}'),child:const Text('واریز از بودجه'))]))]);
Widget historyPage(){final keys=m.budgets.keys.toList()..sort((a,b)=>b.compareTo(a));return ListView(padding:const EdgeInsets.all(14),children:[for(final k in keys)card('هفته $k',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('بودجه: ${toman(m.budgets[k]??0)}'),Text('خرج: ${toman(m.total(k,'expense'))}'),Text('درآمد: ${toman(m.total(k,'income'))}'),if(m.settlements.containsKey(k))Text('پس‌انداز نهایی: ${toman(m.settlements[k]!['saving']??0)} • انتقال: ${toman(m.settlements[k]!['next']??0)}')]))]);}
Widget debtsPage(){final name=TextEditingController(),amount=TextEditingController();return ListView(padding:const EdgeInsets.all(14),children:[card('طلب و بدهی',Column(children:[TextField(controller:name,decoration:const InputDecoration(labelText:'نام شخص')),TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'مبلغ؛ طلب مثبت، بدهی منفی')),FilledButton(onPressed:(){if(name.text.trim().isNotEmpty){m.changeDebt(name.text.trim(),int.tryParse(amount.text)??0);setState((){});}},child:const Text('ثبت / تسویه'))])),for(final e in m.debts.entries)card(e.key,Text('${e.value>=0?'طلب':'بدهی'}: ${toman(e.value.abs())}'))]);}
@override Widget build(BuildContext context)=>Directionality(textDirection:ui.TextDirection.rtl,child:Scaffold(appBar:AppBar(title:const Text('هفته‌پول PRIME'),actions:[IconButton(onPressed:()=>transferDialog(),icon:const Icon(Icons.savings_outlined),tooltip:'انتقال به پس‌انداز')]),body:[dashboard(),goalsPage(),historyPage(),debtsPage()][tab],bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const [NavigationDestination(icon:Icon(Icons.dashboard_outlined),label:'داشبورد'),NavigationDestination(icon:Icon(Icons.flag_outlined),label:'اهداف'),NavigationDestination(icon:Icon(Icons.history),label:'تاریخچه'),NavigationDestination(icon:Icon(Icons.handshake_outlined),label:'طلب و بدهی')])));}

