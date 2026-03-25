import 'cash_invoice.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'client_detail.dart';
import 'expenses_page.dart';
import 'settings_page.dart';
import 'inventory_page.dart';
import '../services/backup_service.dart';

// مسارات ملفات التصميم
import '../widgets/custom_letter_icon.dart'; 
import '../widgets/royal_card.dart'; 

// استيراد حزمة السحابة
import 'package:cloud_firestore/cloud_firestore.dart'; 

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Box box = Hive.box('tajarti_royal_v1');
  
  final PageController _pageController = PageController(viewportFraction: 0.85);
  final TextEditingController _searchController = TextEditingController();
  int _currentIndex = 0;
  final List<String> currencies = ['ريال يمني', 'ريال سعودي', 'دولار أمريكي'];
  String get selectedCurrency => currencies[_currentIndex];
  bool _isBalanceHidden = false;
  String _searchText = "";

  // ✅ 1. تعريف "كاميرا السحابة" هنا لكي لا يتم إعادة إنشائها
  late Stream<QuerySnapshot> _clientsStream;

  @override
  void initState() {
    super.initState();
    // ✅ 2. تشغيل الكاميرا والاتصال بالإنترنت "مرة واحدة فقط" عند فتح الشاشة
    _clientsStream = FirebaseFirestore.instance.collection('clients').snapshots();
  }

  Map<String, double> _getDashboardStats(List<QueryDocumentSnapshot> docs, String currency) {
    double totalDebt = 0;
    int clientCount = 0;
    for (var doc in docs) {
      var c = doc.data() as Map<String, dynamic>;
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

  Map<String, double> _getData(List<QueryDocumentSnapshot> docs, String currency) { 
    double toMe=0, onMe=0; 
    for(var doc in docs){ 
      var c = doc.data() as Map<String, dynamic>;
      if((c['currency']??'ريال يمني')==currency && c['trans']!=null){ 
        for(var t in c['trans']){ 
          double amt=double.tryParse(t['amt'].toString())??0; 
          if(t['type']=='out') toMe+=amt; else onMe+=amt; 
        } 
      } 
    } 
    return {'toMe':toMe, 'onMe':onMe, 'net':toMe-onMe}; 
  }

  void _editOrDeleteClient(String id, Map client) {
    showModalBottomSheet(context: context, builder: (ctx) => Container(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.edit, color: Colors.blue), title: const Text("تعديل بيانات العميل"), onTap: () {Navigator.pop(ctx); _showEditClientDialog(id, client);}),
        ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text("حذف العميل نهائياً"), onTap: () {
            Navigator.pop(ctx);
            showDialog(context: context, builder: (dCtx) => AlertDialog(title: const Text("تأكيد الحذف"), content: const Text("سيتم حذف العميل وكل ديونه. هل أنت متأكد؟"), actions: [
              TextButton(onPressed: ()=>Navigator.pop(dCtx), child: const Text("إلغاء")), 
              TextButton(onPressed: () async { 
                box.delete(id); 
                try { await FirebaseFirestore.instance.collection('clients').doc(id).delete(); } catch(e) { print(e); }
                setState((){}); 
                Navigator.pop(dCtx); 
              }, child: const Text("حذف", style: TextStyle(color: Colors.red)))
            ]));
          }) 
      ]),
    ));
  }

  void _showEditClientDialog(String id, Map client) {
    final n = TextEditingController(text: client['name']);
    final p = TextEditingController(text: client['phone']);
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("تعديل العميل"), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: n, decoration: const InputDecoration(labelText: "الاسم")), TextField(controller: p, decoration: const InputDecoration(labelText: "الهاتف"))]), actions: [
      ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
        onPressed: () async { 
          client['name'] = n.text; 
          client['phone'] = p.text; 
          box.put(id, client); 
          try { await FirebaseFirestore.instance.collection('clients').doc(id).update({'name': n.text, 'phone': p.text}); } catch (e) { print(e); }
          setState((){}); 
          Navigator.pop(ctx); 
        }, 
        child: const Text("حفظ التعديلات")
      )
    ]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      appBar: AppBar(elevation: 0, backgroundColor: const Color(0xFF1565C0), title: const Text("تجارتي برو", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)), centerTitle: true, iconTheme: const IconThemeData(color: Colors.white), actions: [IconButton(icon: Icon(_isBalanceHidden ? Icons.visibility_off : Icons.visibility, color: Colors.white), onPressed: () => setState(() => _isBalanceHidden = !_isBalanceHidden))]),
      drawer: _buildDrawer(),
      body: StreamBuilder<QuerySnapshot>(
        stream: _clientsStream, // ✅ 3. هنا نستخدم الكاميرا المثبتة بدلاً من إنشاء واحدة جديدة
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          var docs = snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot>[];
          var stats = _getDashboardStats(docs, selectedCurrency);

          return Column(children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Row(children: [Expanded(child: _buildInfoChip("إجمالي الديون (لك)", _isBalanceHidden ? "****" : intl.NumberFormat.compact().format(stats['debt']))), const SizedBox(width: 10), Expanded(child: _buildInfoChip("عدد العملاء", "${stats['count']!.toInt()}"))])),
            
            SizedBox(
              height: 220, 
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemCount: currencies.length,
                itemBuilder: (ctx, i) {
                   return AnimatedBuilder(
                     animation: _pageController,
                     builder: (context, child) {
                       double value = 1.0;
                       if (_pageController.position.haveDimensions) {
                         value = _pageController.page! - i;
                         value = (1 - (value.abs() * 0.1)).clamp(0.9, 1.0);
                       } else {
                         value = i == _currentIndex ? 1.0 : 0.9;
                       }
                       return Center(child: SizedBox(height: Curves.easeOut.transform(value) * 220, width: Curves.easeOut.transform(value) * 400, child: child));
                     },
                     child: RoyalCard(
                       currency: currencies[i],
                       isBalanceHidden: _isBalanceHidden,
                       netBalance: _getData(docs, currencies[i])['net'] ?? 0.0,
                       shopName: box.get('shop_name') ?? "المتجر",
                     ),
                   );
                }
              ),
            ),

            Padding(padding: const EdgeInsets.only(top: 10, bottom: 10), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(currencies.length, (index) { bool isActive = _currentIndex == index; return AnimatedContainer(duration: const Duration(milliseconds: 300), margin: const EdgeInsets.symmetric(horizontal: 4), height: 8, width: isActive ? 24 : 8, decoration: BoxDecoration(color: isActive ? Colors.white : Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(4))); }))),
            
            Expanded(child: Container(decoration: const BoxDecoration(color: Color(0xFFF5F5F5), borderRadius: BorderRadius.vertical(top: Radius.circular(30))), child: Column(children: [
              Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 5), child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: TextField(controller: _searchController, onChanged: (val) => setState(() => _searchText = val), decoration: const InputDecoration(hintText: "بحث عن عميل...", prefixIcon: Icon(Icons.search, color: Color(0xFF1565C0)), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15))))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10), child: Row(children: [Text("قائمة العملاء ($selectedCurrency)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)), const Spacer(), Text("${_getFilteredCount(docs)} عميل", style: const TextStyle(color: Colors.grey, fontSize: 12))])),
              Expanded(child: _buildClientList(docs)),
            ])))
          ]);
        }
      ),
      floatingActionButton: Column(mainAxisAlignment: MainAxisAlignment.end, children: [FloatingActionButton(heroTag: "cash", backgroundColor: Colors.blue[800], child: const Icon(Icons.calculate), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CashInvoiceScreen()))), const SizedBox(height: 15), FloatingActionButton(heroTag: "add",backgroundColor: const Color(0xFFD81B60), onPressed: _addClient, child: const Icon(Icons.add, size: 30, color: Colors.white))]),
    );
  }

  Widget _buildInfoChip(String label, String value) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)), const SizedBox(height: 4), Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]));

  Widget _buildDrawer() => Drawer(child: ListView(children: [UserAccountsDrawerHeader(decoration: const BoxDecoration(color: Color(0xFF1565C0)), accountName: Text(box.get('shop_name') ?? "تجارتي برو", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), accountEmail: const Text("الإصدار الماسي"), currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.store, color: Color(0xFF1565C0), size: 30))), ListTile(leading: const Icon(Icons.person_add, color: Colors.teal), title: const Text("اضافة حساب"), onTap: (){Navigator.pop(context); _addClient();}), ListTile(leading: const Icon(Icons.description, color: Colors.teal), title: const Text("تقارير الديون"), onTap: () {Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesPage()));}), ListTile(leading: const Icon(Icons.inventory, color: Colors.purple), title: const Text("إدارة المخزون"), onTap: () {Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryPage()));}), const Divider(), ListTile(leading: const Icon(Icons.save, color: Colors.blue), title: const Text("حفظ نسخة احتياطية"), onTap: () => BackupService.createBackup(context)), ListTile(leading: const Icon(Icons.restore, color: Colors.orange), title: const Text("استرجاع نسخة"), onTap: () => BackupService.restoreBackup(context, () => setState((){}))), const Divider(), ListTile(leading: const Icon(Icons.settings, color: Colors.grey), title: const Text("الإعدادات"), onTap: () {Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));})]));

  int _getFilteredCount(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) { 
      var c = doc.data() as Map<String, dynamic>; 
      return (c['currency']??'ريال يمني')==selectedCurrency && (c['name']??"").toLowerCase().contains(_searchText.toLowerCase()); 
    }).length;
  }
  
  Widget _buildClientList(List<QueryDocumentSnapshot> allClients) {
    if (allClients.isEmpty) return const Center(child: Text("لا يوجد عملاء حتى الآن", style: TextStyle(color: Colors.grey, fontSize: 16)));

    var filteredClients = allClients.where((doc) {
      var data = doc.data() as Map<String, dynamic>;
      String c = data['currency'] ?? 'ريال يمني';
      String n = data['name'] ?? '';
      return c == selectedCurrency && n.toLowerCase().contains(_searchText.toLowerCase());
    }).toList();

    if (filteredClients.isEmpty) return const Center(child: Text("لا يوجد عملاء مطابقين للبحث", style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      itemCount: filteredClients.length,
      itemBuilder: (ctx, i) {
        var doc = filteredClients[i];
        var client = doc.data() as Map<String, dynamic>;
        String id = doc.id; 

        double bal = 0;
        if (client['trans'] != null) {
          for (var t in client['trans']) bal += (t['type'] == 'out' ? 1 : -1) * (double.tryParse(t['amt'].toString()) ?? 0);
        }

        String name = client['name'] ?? "عميل"; 
        String firstChar = name.isNotEmpty ? name[0] : "?"; 
        bool isLate = bal >= 50000;
        
        return Card(
          elevation: 2, margin: const EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), 
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientDetail(id: id))).then((_) => setState(() {})),
            onLongPress: () => _editOrDeleteClient(id, client),
            leading: Stack(children: [CustomLetterIcon(letter: firstChar), if(isLate) const Positioned(right: 0, top: 0, child: CircleAvatar(radius: 5, backgroundColor: Colors.red))]), 
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), 
            trailing: Text(_isBalanceHidden ? "****" : intl.NumberFormat("#,##0").format(bal.abs()), style: TextStyle(color: bal >= 0 ? const Color(0xFFD81B60) : Colors.green, fontWeight: FontWeight.bold, fontSize: 16))
        ));
      }
    );
  }

  void _addClient() {
    final n = TextEditingController();
    final p = TextEditingController();
    String c = selectedCurrency;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("عميل جديد"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: n, decoration: const InputDecoration(labelText: "الاسم")), TextField(controller: p, decoration: const InputDecoration(labelText: "الهاتف")), DropdownButtonFormField<String>(value: c, items: currencies.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => c = v!))]),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
            onPressed: () async {
              if (n.text.isNotEmpty) {
                String newId = DateTime.now().millisecondsSinceEpoch.toString();
                box.put(newId, {'name': n.text, 'phone': p.text, 'currency': c, 'trans': []});
                try { await FirebaseFirestore.instance.collection('clients').doc(newId).set({'name': n.text, 'phone': p.text, 'currency': c, 'trans': []}); } catch (e) { print(e); }
                setState(() {});
                Navigator.pop(ctx);
              }
            },
            child: const Text("حفظ")
          )
        ]
      )
    );
  }
}