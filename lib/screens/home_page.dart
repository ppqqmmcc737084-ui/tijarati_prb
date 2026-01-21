import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'client_detail.dart';
import 'expenses_page.dart';
import 'settings_page.dart';
import 'inventory_page.dart';
import '../services/backup_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Box box = Hive.box('tajarti_royal_v1');
  
  // ✅ التعديل السحري: الرقم 0.85 يعني أن البطاقة تأخذ 85% من الشاشة
  // والباقي (15%) يتوزع لظهور البطاقات الجانبية يمين ويسار
  final PageController _pageController = PageController(viewportFraction: 0.85);
  
  final TextEditingController _searchController = TextEditingController();
  int _currentIndex = 0;
  final List<String> currencies = ['ريال يمني', 'ريال سعودي', 'دولار أمريكي'];
  String get selectedCurrency => currencies[_currentIndex];
  bool _isBalanceHidden = false;
  String _searchText = "";

  Map<String, double> _getDashboardStats(String currency) {
    double totalDebt = 0;
    int clientCount = 0;
    for (var k in box.keys) {
      if (k.toString().startsWith('shop_') || k.toString().startsWith('inv_') || k == 'expenses' || k == 'fingerprint_enabled') continue;
      var c = box.get(k);
      if (c == null || c is! Map) continue;
      if ((c['currency'] ?? 'ريال يمني') == currency) {
        clientCount++;
        if (c['trans'] != null) {
          double bal = 0;
          for (var t in c['trans']) bal += (t['type'] == 'out' ? 1 : -1) * (double.tryParse(t['amt'].toString()) ?? 0);
          if (bal > 0) totalDebt += bal;
        }
      }
    }
    return {'debt': totalDebt, 'count': clientCount.toDouble()};
  }

  void _editOrDeleteClient(String id, Map client) {
    showModalBottomSheet(context: context, builder: (ctx) => Container(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.edit, color: Colors.blue), title: const Text("تعديل بيانات العميل"), onTap: () {Navigator.pop(ctx); _showEditClientDialog(id, client);}),
        ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text("حذف العميل نهائياً"), onTap: () {
            Navigator.pop(ctx);
            showDialog(context: context, builder: (dCtx) => AlertDialog(title: const Text("تأكيد الحذف"), content: const Text("سيتم حذف العميل وكل ديونه. هل أنت متأكد؟"), actions: [TextButton(onPressed: ()=>Navigator.pop(dCtx), child: const Text("إلغاء")), TextButton(onPressed: (){ box.delete(id); setState((){}); Navigator.pop(dCtx); }, child: const Text("حذف", style: TextStyle(color: Colors.red)))]));
          }),
      ]),
    ));
  }

  void _showEditClientDialog(String id, Map client) {
    final n = TextEditingController(text: client['name']);
    final p = TextEditingController(text: client['phone']);
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("تعديل العميل"), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: n, decoration: const InputDecoration(labelText: "الاسم")), TextField(controller: p, decoration: const InputDecoration(labelText: "الهاتف"))]), actions: [ElevatedButton(onPressed: (){ client['name'] = n.text; client['phone'] = p.text; box.put(id, client); setState((){}); Navigator.pop(ctx); }, child: const Text("حفظ التعديلات"))]));
  }

  @override
  Widget build(BuildContext context) {
    var stats = _getDashboardStats(selectedCurrency);
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      appBar: AppBar(elevation: 0, backgroundColor: const Color(0xFF1565C0), title: const Text("تجارتي برو", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)), centerTitle: true, iconTheme: const IconThemeData(color: Colors.white), actions: [IconButton(icon: Icon(_isBalanceHidden ? Icons.visibility_off : Icons.visibility, color: Colors.white), onPressed: () => setState(() => _isBalanceHidden = !_isBalanceHidden))]),
      drawer: _buildDrawer(),
      body: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Row(children: [Expanded(child: _buildInfoChip("إجمالي الديون (لك)", _isBalanceHidden ? "****" : intl.NumberFormat.compact().format(stats['debt']))), const SizedBox(width: 10), Expanded(child: _buildInfoChip("عدد العملاء", "${stats['count']!.toInt()}"))])),
        
        // ✅ منطقة البطاقات المعدلة (كاروسيل احترافي)
        SizedBox(
          height: 220, 
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemCount: currencies.length,
            // نستخدم AnimatedBuilder لجعل الحركة ناعمة
            itemBuilder: (ctx, i) {
               return AnimatedBuilder(
                 animation: _pageController,
                 builder: (context, child) {
                   double value = 1.0;
                   if (_pageController.position.haveDimensions) {
                     value = _pageController.page! - i;
                     value = (1 - (value.abs() * 0.1)).clamp(0.9, 1.0);
                   } else {
                     // الحالة الأولية (قبل التحريك)
                     value = i == _currentIndex ? 1.0 : 0.9;
                   }
                   return Center(
                     child: SizedBox(
                       height: Curves.easeOut.transform(value) * 220,
                       width: Curves.easeOut.transform(value) * 400,
                       child: child,
                     ),
                   );
                 },
                 child: _buildRoyalCard(currencies[i]),
               );
            }
          ),
        ),

        // مؤشر النقاط
        Padding(padding: const EdgeInsets.only(top: 10, bottom: 10), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(currencies.length, (index) { bool isActive = _currentIndex == index; return AnimatedContainer(duration: const Duration(milliseconds: 300), margin: const EdgeInsets.symmetric(horizontal: 4), height: 8, width: isActive ? 24 : 8, decoration: BoxDecoration(color: isActive ? Colors.white : Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(4))); }))),
        
        Expanded(child: Container(decoration: const BoxDecoration(color: Color(0xFFF5F5F5), borderRadius: BorderRadius.vertical(top: Radius.circular(30))), child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 5), child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: TextField(controller: _searchController, onChanged: (val) => setState(() => _searchText = val), decoration: const InputDecoration(hintText: "بحث عن عميل...", prefixIcon: Icon(Icons.search, color: Color(0xFF1565C0)), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15))))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10), child: Row(children: [Text("قائمة العملاء ($selectedCurrency)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)), const Spacer(), Text("${_getFilteredCount()} عميل", style: const TextStyle(color: Colors.grey, fontSize: 12))])),
          Expanded(child: _buildClientList()),
        ])))
      ]),
      floatingActionButton: FloatingActionButton(backgroundColor: const Color(0xFFD81B60), onPressed: _addClient, child: const Icon(Icons.add, size: 30, color: Colors.white)),
    );
  }

  Widget _buildInfoChip(String label, String value) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)), const SizedBox(height: 4), Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]));

  Widget _buildRoyalCard(String currency) {
    var data = _getData(currency);
    final fmt = intl.NumberFormat("#,##0");
    List<Color> colors = currency.contains("يمني") ? [const Color(0xFFC2185B), const Color(0xFF880E4F)] : (currency.contains("سعودي") ? [const Color(0xFF2E7D32), const Color(0xFF1B5E20)] : [const Color(0xFF37474F), const Color(0xFF212121)]);
    
    // ✅ هنا البطاقة نفسها (بدون هوامش كبيرة لأن PageView يتكفل بذلك)
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5), // هامش صغير جداً
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: colors[0].withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: ClipRRect( // ClipRRect لضمان عدم خروج المحتوى
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 1.586,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Stack(
              children: [
                Positioned(right: -20, top: -20, child: Icon(Icons.public, size: 120, color: Colors.white.withOpacity(0.05))),
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Icon(Icons.sim_card, color: Colors.amberAccent, size: 30), Text(currency, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))]), Center(child: Text(_isBalanceHidden ? "****" : fmt.format(data['net']), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'Courier'))), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("CARD HOLDER", style: TextStyle(color: Colors.white54, fontSize: 8)), Text(box.get('shop_name') ?? "المتجر", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))]), const Text("PRO", style: TextStyle(color: Colors.white, fontStyle: FontStyle.italic, fontWeight: FontWeight.w900, fontSize: 18))])])
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() => Drawer(child: ListView(children: [UserAccountsDrawerHeader(decoration: const BoxDecoration(color: Color(0xFF1565C0)), accountName: Text(box.get('shop_name') ?? "تجارتي برو", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), accountEmail: const Text("الإصدار الماسي"), currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.store, color: Color(0xFF1565C0), size: 30))), ListTile(leading: const Icon(Icons.person_add, color: Colors.teal), title: const Text("اضافة حساب"), onTap: (){Navigator.pop(context); _addClient();}), ListTile(leading: const Icon(Icons.description, color: Colors.teal), title: const Text("تقارير الديون"), onTap: () {Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesPage()));}), ListTile(leading: const Icon(Icons.inventory, color: Colors.purple), title: const Text("إدارة المخزون"), onTap: () {Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryPage()));}), const Divider(), ListTile(leading: const Icon(Icons.save, color: Colors.blue), title: const Text("حفظ نسخة احتياطية"), onTap: () => BackupService.createBackup(context)), ListTile(leading: const Icon(Icons.restore, color: Colors.orange), title: const Text("استرجاع نسخة"), onTap: () => BackupService.restoreBackup(context, () => setState((){}))), const Divider(), ListTile(leading: const Icon(Icons.settings, color: Colors.grey), title: const Text("الإعدادات"), onTap: () {Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));})]));

  int _getFilteredCount() => box.keys.where((k) { if(k.toString().startsWith('shop_')||k.toString().startsWith('inv_')||k=='expenses'||k=='fingerprint_enabled')return false; var c=box.get(k); if(c==null||c is! Map)return false; return (c['currency']??'ريال يمني')==selectedCurrency && (c['name']??"").toLowerCase().contains(_searchText.toLowerCase()); }).length;
  
  Map<String, double> _getData(String currency) { double toMe=0, onMe=0; for(var k in box.keys){ if(k.toString().startsWith('shop_')||k.toString().startsWith('inv_')||k=='expenses'||k=='fingerprint_enabled')continue; var c=box.get(k); if(c==null||c is! Map)continue; if((c['currency']??'ريال يمني')==currency && c['trans']!=null){ for(var t in c['trans']){ double amt=double.tryParse(t['amt'].toString())??0; if(t['type']=='out') toMe+=amt; else onMe+=amt; } } } return {'toMe':toMe, 'onMe':onMe, 'net':toMe-onMe}; }

  Widget _buildClientList() {
    final keys = box.keys.where((k) { if(k.toString().startsWith('shop_')||k.toString().startsWith('inv_')||k=='expenses'||k=='fingerprint_enabled')return false; var c=box.get(k); if(c==null||c is! Map)return false; return (c['currency']??'ريال يمني')==selectedCurrency && (c['name']??"").toLowerCase().contains(_searchText.toLowerCase()); }).toList();
    if(keys.isEmpty) return const Center(child: Text("لا يوجد عملاء", style: TextStyle(color: Colors.grey)));
    return ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5), itemCount: keys.length, itemBuilder: (ctx, i) {
      var k=keys[i]; var client=box.get(k); double bal=0; if(client['trans']!=null){ for(var t in client['trans']) bal+=(t['type']=='out'?1:-1)*(double.tryParse(t['amt'].toString())??0); }
      String name=client['name']??"عميل"; String firstChar=name.isNotEmpty?name[0]:"?"; bool isLate=bal>=50000;
      return Card(elevation: 2, margin: const EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        onTap: ()=>Navigator.push(context, MaterialPageRoute(builder: (_)=>ClientDetail(id: k.toString()))).then((_)=>setState((){})),
        onLongPress: () => _editOrDeleteClient(k.toString(), client),
        leading: Stack(children: [CircleAvatar(backgroundColor: const Color(0xFFE3F2FD), child: Text(firstChar, style: const TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold))), if(isLate)const Positioned(right: 0, top: 0, child: CircleAvatar(radius: 5, backgroundColor: Colors.red))]), title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), trailing: Text(_isBalanceHidden?"****":intl.NumberFormat("#,##0").format(bal.abs()), style: TextStyle(color: bal>=0?const Color(0xFFD81B60):Colors.green, fontWeight: FontWeight.bold, fontSize: 16))));
    });
  }

  void _addClient() { final n=TextEditingController(); final p=TextEditingController(); String c=selectedCurrency; showDialog(context: context, builder: (ctx)=>AlertDialog(title: const Text("عميل جديد"), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: n, decoration: const InputDecoration(labelText: "الاسم")), TextField(controller: p, decoration: const InputDecoration(labelText: "الهاتف")), DropdownButtonFormField<String>(value: c, items: currencies.map((e)=>DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v)=>setState(()=>c=v!))]), actions: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white), onPressed: (){ if(n.text.isNotEmpty){ box.put(DateTime.now().millisecondsSinceEpoch.toString(), {'name':n.text, 'phone':p.text, 'currency':c, 'trans':[]}); setState((){}); Navigator.pop(ctx); } }, child: const Text("حفظ"))])); }
}