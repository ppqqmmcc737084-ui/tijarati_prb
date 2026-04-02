import 'cash_invoice.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'client_detail.dart';
import 'expenses_page.dart';
import 'settings_page.dart';
import 'inventory_page.dart';
import '../services/backup_service.dart';

import 'login_screen.dart'; 
import '../widgets/custom_letter_icon.dart'; 
import '../widgets/royal_card.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 

// ✅ استدعاء الصفحات الجديدة
import 'reports_page.dart'; 
import 'smart_invoice_page.dart';
// ✅ استدعاء صفحة سجل فواتير الكاش
import 'cash_invoices_history_page.dart';

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

  // ✅ الدالة السحرية لتحديد غرفة المستخدم (السحابية أو المحلية)
  String get currentUserUid {
    String? uid = box.get('user_uid');
    if (uid != null && uid.isNotEmpty) return uid;
    
    String? deviceId = box.get('device_id');
    if (deviceId == null) {
      deviceId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      box.put('device_id', deviceId);
    }
    return deviceId;
  }

  @override
  void initState() {
    super.initState();
    // ✅ تشغيل التنبيه بعد فتح الشاشة مباشرة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoginStatus();
    });
  }

  // ✅ الدالة الذكية اللي تفحص وتطلع رسالة (بدون إزعاج مستمر)
  void _checkLoginStatus() {
    String? uid = box.get('user_uid');
    bool hideWarning = box.get('hide_guest_warning', defaultValue: false);
    
    // إذا كان زائر + وما قد ضغط على زر "لا تذكرني"
    if ((uid == null || uid.isEmpty || uid.startsWith('local_')) && !hideWarning) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 30),
              SizedBox(width: 10),
              Text("تنبيه هام!", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            "أنت تستخدم التطبيق كزائر محلي. \n\nلتجنب فقدان بياناتك في حال حذف التطبيق، يرجى إنشاء حساب لضمان حفظ فواتيرك وبيانات عملائك في السحابة.",
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            // زر إسكات التنبيه للأبد
            TextButton(
              onPressed: () {
                box.put('hide_guest_warning', true); // حفظ أمر الإسكات
                Navigator.pop(ctx); 
              }, 
              child: const Text("لا تذكرني", style: TextStyle(color: Colors.red))
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx), 
                  child: const Text("لاحقاً", style: TextStyle(color: Colors.grey))
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D256C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                  ),
                  onPressed: () {
                    Navigator.pop(ctx); 
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())); 
                  },
                  child: const Text("تسجيل", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            )
          ],
        )
      );
    }
  }

  // ✅ جلب العملاء من الذاكرة المحلية
  List<Map<String, dynamic>> _getClientsFromHive() {
    List<Map<String, dynamic>> clients = [];
    for (var key in box.keys) {
      if (!['user_uid', 'device_id', 'shop_name', 'app_password', 'is_password_enabled', 'is_fingerprint_enabled', 'custom_logo', 'last_cash_invoice_number', 'hide_guest_warning'].contains(key)) {
        var data = box.get(key);
        if (data is Map) {
          var clientMap = Map<String, dynamic>.from(data);
          clientMap['id'] = key.toString(); 
          clients.add(clientMap);
        }
      }
    }
    return clients;
  }

  Map<String, double> _getDashboardStats(List<Map<String, dynamic>> clients, String currency) {
    double totalDebt = 0;
    int clientCount = 0;
    for (var c in clients) {
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

  Map<String, double> _getData(List<Map<String, dynamic>> clients, String currency) { 
    double toMe=0, onMe=0; 
    for(var c in clients){ 
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
                try { await FirebaseFirestore.instance.collection('users').doc(currentUserUid).collection('clients').doc(id).delete(); } catch(e) { debugPrint(e.toString()); }
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
          try { await FirebaseFirestore.instance.collection('users').doc(currentUserUid).collection('clients').doc(id).update({'name': n.text, 'phone': p.text}); } catch (e) { debugPrint(e.toString()); }
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
      appBar: AppBar(
        elevation: 0, 
        backgroundColor: const Color(0xFF1565C0), 
        title: const Text("تجارتي برو", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)), 
        centerTitle: true, 
        iconTheme: const IconThemeData(color: Colors.white), 
        actions: [
          IconButton(icon: Icon(_isBalanceHidden ? Icons.visibility_off : Icons.visibility, color: Colors.white), onPressed: () => setState(() => _isBalanceHidden = !_isBalanceHidden)),
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: Image.asset("assets/images/app_icon.png", width: 30, height: 30), // استخدمت الأيقونة المحلية بدلاً من رابط النت
          ),
        ]
      ),
      drawer: _buildDrawer(),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(), 
        builder: (context, Box box, _) {
          
          var allClients = _getClientsFromHive();
          var stats = _getDashboardStats(allClients, selectedCurrency);

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
                       netBalance: _getData(allClients, currencies[i])['net'] ?? 0.0,
                       shopName: box.get('shop_name') ?? "المتجر",
                     ),
                   );
                }
              ),
            ),

            Padding(padding: const EdgeInsets.only(top: 10, bottom: 10), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(currencies.length, (index) { bool isActive = _currentIndex == index; return AnimatedContainer(duration: const Duration(milliseconds: 300), margin: const EdgeInsets.symmetric(horizontal: 4), height: 8, width: isActive ? 24 : 8, decoration: BoxDecoration(color: isActive ? Colors.white : Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(4))); }))),
            
            Expanded(child: Container(decoration: const BoxDecoration(color: Color(0xFFF5F5F5), borderRadius: BorderRadius.vertical(top: Radius.circular(30))), child: Column(children: [
              Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 5), child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: TextField(controller: _searchController, onChanged: (val) => setState(() => _searchText = val), decoration: const InputDecoration(hintText: "بحث عن عميل...", prefixIcon: Icon(Icons.search, color: Color(0xFF1565C0)), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15))))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10), child: Row(children: [Text("قائمة العملاء ($selectedCurrency)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)), const Spacer(), Text("${_getFilteredCount(allClients)} عميل", style: const TextStyle(color: Colors.grey, fontSize: 12))])),
              Expanded(child: _buildClientList(allClients)),
            ])))
          ]);
        }
      ),
      floatingActionButton: Column(mainAxisAlignment: MainAxisAlignment.end, children: [FloatingActionButton(heroTag: "cash", backgroundColor: Colors.blue[800], child: const Icon(Icons.calculate), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CashInvoiceScreen()))), const SizedBox(height: 15), FloatingActionButton(heroTag: "add",backgroundColor: const Color(0xFFD81B60), onPressed: _addClient, child: const Icon(Icons.add, size: 30, color: Colors.white))]),
    );
  }

  Widget _buildInfoChip(String label, String value) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)), const SizedBox(height: 4), Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]));

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero, 
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF0D256C), 
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset(
                    'assets/images/app_icon.png', 
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'تجارتي برو',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(leading: const Icon(Icons.person_add, color: Colors.teal), title: const Text("اضافة حساب"), onTap: (){Navigator.pop(context); _addClient();}),
          
          ListTile(
            leading: const Icon(Icons.analytics, color: Colors.teal), 
            title: const Text("الجرود والتقارير"), 
            onTap: () {
              Navigator.pop(context); 
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsPage()));
            }
          ),
          
          ListTile(leading: const Icon(Icons.inventory, color: Colors.purple), title: const Text("إدارة المخزون"), onTap: () {Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryPage()));}),
          
          ListTile(
            leading: const Icon(Icons.bolt, color: Colors.orange), 
            title: const Text("الفاتورة السريعة (الذكية)"), 
            onTap: () {
              Navigator.pop(context); 
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartInvoicePage()));
            }
          ),

          ListTile(
            leading: const Icon(Icons.receipt_long, color: Colors.green), 
            title: const Text("سجل فواتير الكاش", style: TextStyle(fontWeight: FontWeight.bold)), 
            onTap: () {
              Navigator.pop(context); 
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CashInvoicesHistoryPage()));
            }
          ),
          
          const Divider(),
          ListTile(leading: const Icon(Icons.save, color: Colors.blue), title: const Text("حفظ نسخة احتياطية"), onTap: () => BackupService.createBackup(context)),
          ListTile(leading: const Icon(Icons.restore, color: Colors.orange), title: const Text("استرجاع نسخة"), onTap: () => BackupService.restoreBackup(context, () => setState((){}))),
          const Divider(),
          ListTile(leading: const Icon(Icons.settings, color: Colors.grey), title: const Text("الإعدادات"), onTap: () {Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));}),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.login, color: Colors.blueAccent),
            title: const Text("تسجيل الدخول", style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context); 
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())); 
            },
          ),
        ],
      ),
    );
  }

  int _getFilteredCount(List<Map<String, dynamic>> clients) {
    return clients.where((c) { 
      return (c['currency']??'ريال يمني')==selectedCurrency && (c['name']??"").toLowerCase().contains(_searchText.toLowerCase()); 
    }).length;
  }
  
  Widget _buildClientList(List<Map<String, dynamic>> allClients) {
    if (allClients.isEmpty) return const Center(child: Text("لا يوجد عملاء حتى الآن", style: TextStyle(color: Colors.grey, fontSize: 16)));

    var filteredClients = allClients.where((c) {
      String curr = c['currency'] ?? 'ريال يمني';
      String n = c['name'] ?? '';
      return curr == selectedCurrency && n.toLowerCase().contains(_searchText.toLowerCase());
    }).toList();

    if (filteredClients.isEmpty) return const Center(child: Text("لا يوجد عملاء مطابقين للبحث", style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      itemCount: filteredClients.length,
      itemBuilder: (ctx, i) {
        var client = filteredClients[i];
        String id = client['id']; 

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
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientDetail(id: id))),
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
                
                try { 
                  await FirebaseFirestore.instance.collection('users').doc(currentUserUid).collection('clients').doc(newId).set({'name': n.text, 'phone': p.text, 'currency': c, 'trans': []}); 
                } catch (e) { debugPrint(e.toString()); }
                
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