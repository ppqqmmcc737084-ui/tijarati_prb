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

import 'reports_page.dart'; 
import 'smart_invoice_page.dart';
import 'cash_invoices_history_page.dart';

import 'manage_products_page.dart';
import 'pos_screen.dart';
// ✅ استدعاء شاشة باقات الكروت الجديدة
import 'wifi_packages_screen.dart';

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
  bool _isBalanceHidden = false;
  String _searchText = "";
  
  List<String> _currencies = [];
  
  String get selectedCurrency => _currencies.isNotEmpty && _currentIndex < _currencies.length 
      ? _currencies[_currentIndex] 
      : 'ريال يمني'; 

  bool get _isViewingSuppliers {
     bool isSupplierEnabled = box.get('is_supplier_enabled', defaultValue: false);
     return isSupplierEnabled && _currentIndex == _currencies.length;
  }

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
    _loadCurrencies(); 
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoginStatus();
    });
  }

  void _loadCurrencies() {
    List<String> baseCurrencies = ['ريال يمني', 'ريال سعودي', 'دولار أمريكي'];
    List<String> customCurrencies = List<String>.from(box.get('custom_currencies', defaultValue: []));
    String defaultCurrency = box.get('default_currency', defaultValue: 'ريال يمني');

    Set<String> allCurrenciesSet = {...baseCurrencies, ...customCurrencies};
    List<String> allCurrenciesList = allCurrenciesSet.toList();

    if (allCurrenciesList.contains(defaultCurrency)) {
      allCurrenciesList.remove(defaultCurrency);
      allCurrenciesList.insert(0, defaultCurrency);
    }

    setState(() {
      _currencies = allCurrenciesList;
      _currentIndex = 0; 
    });
  }

  void _checkLoginStatus() {
    String? uid = box.get('user_uid');
    bool hideWarning = box.get('hide_guest_warning', defaultValue: false);
    
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
            TextButton(
              onPressed: () {
                box.put('hide_guest_warning', true);
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

  List<Map<String, dynamic>> _getClientsFromHive() {
    List<Map<String, dynamic>> clients = [];
    List<String> settingsKeys = [
      'user_uid', 'device_id', 'shop_name', 'app_password', 
      'is_password_enabled', 'is_fingerprint_enabled', 
      'custom_logo', 'last_cash_invoice_number', 
      'hide_guest_warning', 'store_unique_prefix', 
      'pos_products', 'custom_currencies', 'default_currency',
      'expenses', 'sms_balance', 'is_supplier_enabled', 'is_wifi_cards_enabled',
      'wifi_packages' // ✅ استثناء الباقات من العملاء
    ];

    for (var key in box.keys) {
      if (!settingsKeys.contains(key.toString())) {
        if (!key.toString().startsWith('cash_inv_') && 
            !key.toString().startsWith('pos_inv_') &&
            !key.toString().startsWith('supplier_')) {
          var data = box.get(key);
          if (data is Map) {
            var clientMap = Map<String, dynamic>.from(data);
            clientMap['id'] = key.toString(); 
            clients.add(clientMap);
          }
        }
      }
    }
    return clients;
  }

  List<Map<String, dynamic>> _getSuppliersFromHive() {
    List<Map<String, dynamic>> suppliers = [];
    for (var key in box.keys) {
      if (key.toString().startsWith('supplier_')) {
        var data = box.get(key);
        if (data is Map) {
          var supMap = Map<String, dynamic>.from(data);
          supMap['id'] = key.toString(); 
          suppliers.add(supMap);
        }
      }
    }
    return suppliers;
  }

  Map<String, double> _getDashboardStats(List<Map<String, dynamic>> clients, String currency) {
    double totalDebt = 0;
    int clientCount = 0;
    for (var c in clients) {
      if ((c['currency'] ?? 'ريال يمني') == currency) {
        clientCount++;
        if (c['trans'] != null) {
          double bal = 0;
          for (var t in c['trans']) {
            bal += (t['type'] == 'out' ? 1 : -1) * (double.tryParse(t['amt'].toString()) ?? 0);
          }
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

  Map<String, double> _getSupplierData(List<Map<String, dynamic>> suppliers) { 
    double toMe=0, onMe=0; 
    for(var c in suppliers){ 
      if(c['trans']!=null){ 
        for(var t in c['trans']){ 
          double amt=double.tryParse(t['amt'].toString())??0; 
          if(t['type'] == 'out') toMe+=amt; else onMe+=amt; 
        } 
      } 
    } 
    return {'toMe':toMe, 'onMe':onMe, 'net': onMe-toMe}; 
  }

  void _editOrDeleteClient(String id, Map client) {
    showModalBottomSheet(
      context: context, 
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue), 
              title: Text(_isViewingSuppliers ? "تعديل بيانات المورد" : "تعديل بيانات العميل"), 
              onTap: () {
                Navigator.pop(ctx); 
                _showEditClientDialog(id, client);
              }
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red), 
              title: Text(_isViewingSuppliers ? "حذف المورد نهائياً" : "حذف العميل نهائياً"), 
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context, 
                  builder: (dCtx) => AlertDialog(
                    title: const Text("تأكيد الحذف"), 
                    content: const Text("سيتم الحذف مع كل القيود. هل أنت متأكد؟"), 
                    actions: [
                      TextButton(onPressed: ()=>Navigator.pop(dCtx), child: const Text("إلغاء")), 
                      TextButton(
                        onPressed: () async { 
                          box.delete(id); 
                          try { 
                            FirebaseFirestore.instance.collection('users').doc(currentUserUid).collection('clients').doc(id).delete(); 
                          } catch(e) { debugPrint(e.toString()); }
                          Navigator.pop(dCtx); 
                        }, 
                        child: const Text("حذف", style: TextStyle(color: Colors.red))
                      )
                    ]
                  )
                );
              }
            ) 
          ]
        ),
      )
    );
  }

  void _showEditClientDialog(String id, Map client) {
    final n = TextEditingController(text: client['name']);
    final p = TextEditingController(text: client['phone']);
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: Text(_isViewingSuppliers ? "تعديل المورد" : "تعديل العميل"), 
        content: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            TextField(controller: n, decoration: const InputDecoration(labelText: "الاسم")), 
            TextField(controller: p, decoration: const InputDecoration(labelText: "الهاتف"))
          ]
        ), 
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
            onPressed: () async { 
              client['name'] = n.text; 
              client['phone'] = p.text; 
              box.put(id, client); 
              try { 
                 FirebaseFirestore.instance.collection('users').doc(currentUserUid).collection('clients').doc(id).update({'name': n.text, 'phone': p.text}); 
              } catch (e) { debugPrint(e.toString()); }
              Navigator.pop(ctx); 
            }, 
            child: const Text("حفظ التعديلات")
          )
        ]
      )
    );
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
          IconButton(
            icon: Icon(_isBalanceHidden ? Icons.visibility_off : Icons.visibility, color: Colors.white), 
            onPressed: () => setState(() => _isBalanceHidden = !_isBalanceHidden)
          ),
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: Image.asset("assets/images/app_icon.png", width: 30, height: 30),
          ),
        ]
      ),
      drawer: _buildDrawer(),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(), 
        builder: (context, Box box, _) {
          
          bool isSupplierEnabled = box.get('is_supplier_enabled', defaultValue: false);
          int totalCards = _currencies.length + (isSupplierEnabled ? 1 : 0);

          var allClients = _getClientsFromHive();
          var allSuppliers = _getSuppliersFromHive();
          
          if (_currencies.isEmpty) return const Center(child: CircularProgressIndicator());
          
          var clientStats = _getDashboardStats(allClients, selectedCurrency);
          var supplierStats = _getSupplierData(allSuppliers);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), 
                child: Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        _isViewingSuppliers ? "إجمالي الديون (عليك)" : "إجمالي الديون (لك)", 
                        _isBalanceHidden ? "****" : intl.NumberFormat.compact().format(_isViewingSuppliers ? supplierStats['net'] : clientStats['debt'])
                      )
                    ), 
                    const SizedBox(width: 10), 
                    Expanded(
                      child: _buildInfoChip(
                        _isViewingSuppliers ? "عدد الموردين" : "عدد العملاء", 
                        "${_isViewingSuppliers ? allSuppliers.length : clientStats['count']!.toInt()}"
                      )
                    )
                  ]
                )
              ),
            
              SizedBox(
                height: 220, 
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentIndex = i),
                  itemCount: totalCards,
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
                         return Center(
                           child: SizedBox(
                             height: Curves.easeOut.transform(value) * 220, 
                             width: Curves.easeOut.transform(value) * 400, 
                             child: child
                           )
                         );
                       },
                       child: (isSupplierEnabled && i == _currencies.length) 
                        ? Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8E0E00), Color(0xFF1F1C18)], 
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(25), 
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8E0E00).withOpacity(0.5),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                )
                              ],
                            ),
                            padding: const EdgeInsets.all(25),
                            child: Stack(
                              children: [
                                Positioned(
                                  right: -20,
                                  bottom: -20,
                                  child: Icon(Icons.business_center, size: 120, color: Colors.white.withOpacity(0.05)),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text("سجل الموردين", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                                          child: const Text("المشتريات", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                        )
                                      ],
                                    ),
                                    const Spacer(),
                                    Text(
                                      _isBalanceHidden ? "****" : "${intl.NumberFormat("#,##0").format(supplierStats['net'])} ريال", 
                                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)
                                    ),
                                    const SizedBox(height: 5),
                                    const Text("إجمالي الديون المستحقة (عليك)", style: TextStyle(color: Colors.white70, fontSize: 13)),
                                  ],
                                ),
                              ],
                            ),
                          )
                        : RoyalCard(
                            currency: _currencies[i],
                            isBalanceHidden: _isBalanceHidden,
                            netBalance: _getData(allClients, _currencies[i])['net'] ?? 0.0,
                            shopName: box.get('shop_name') ?? "المتجر",
                          ),
                     );
                  }
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 10), 
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center, 
                  children: List.generate(totalCards, (index) { 
                    bool isActive = _currentIndex == index; 
                    bool isSupplierDot = isSupplierEnabled && index == _currencies.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300), 
                      margin: const EdgeInsets.symmetric(horizontal: 4), 
                      height: 8, 
                      width: isActive ? 24 : 8, 
                      decoration: BoxDecoration(
                        color: isActive ? (isSupplierDot ? Colors.redAccent : Colors.white) : Colors.white.withOpacity(0.3), 
                        borderRadius: BorderRadius.circular(4)
                      )
                    ); 
                  })
                )
              ),
            
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F5F5), 
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30))
                  ), 
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 5), 
                        child: Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), 
                          child: TextField(
                            controller: _searchController, 
                            onChanged: (val) => setState(() => _searchText = val), 
                            decoration: InputDecoration(
                              hintText: _isViewingSuppliers ? "بحث عن مورد..." : "بحث عن عميل...", 
                              prefixIcon: const Icon(Icons.search, color: Color(0xFF1565C0)), 
                              border: InputBorder.none, 
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)
                            )
                          )
                        )
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10), 
                        child: Row(
                          children: [
                            Text(
                              _isViewingSuppliers ? "قائمة الموردين (المشتريات)" : "قائمة العملاء ($selectedCurrency)", 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)
                            ), 
                            const Spacer(), 
                            Text(
                              _isViewingSuppliers ? "${_getFilteredSuppliers(allSuppliers).length} مورد" : "${_getFilteredCount(allClients)} عميل", 
                              style: const TextStyle(color: Colors.grey, fontSize: 12)
                            )
                          ]
                        )
                      ),
                      Expanded(child: _buildClientList(allClients, allSuppliers)),
                    ]
                  )
                )
              )
            ]
          );
        }
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end, 
        children: [
          FloatingActionButton(
            heroTag: "cash", 
            backgroundColor: Colors.blue[800], 
            child: const Icon(Icons.calculate), 
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CashInvoiceScreen()))
          ), 
          const SizedBox(height: 15), 
          FloatingActionButton(
            heroTag: "add",
            backgroundColor: _isViewingSuppliers ? const Color(0xFF8E0E00) : const Color(0xFFD81B60), 
            onPressed: _addClientOrSupplier, 
            child: const Icon(Icons.add, size: 30, color: Colors.white)
          )
        ]
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) => Container(
    padding: const EdgeInsets.all(12), 
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15), 
      borderRadius: BorderRadius.circular(12)
    ), 
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)), 
        const SizedBox(height: 4), 
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
      ]
    )
  );

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero, 
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF0D256C)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset('assets/images/app_icon.png', width: 70, height: 70, fit: BoxFit.cover),
                ),
                const SizedBox(height: 10),
                const Text('تجارتي برو', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ListTile(leading: const Icon(Icons.person_add, color: Colors.teal), title: const Text("اضافة حساب"), onTap: (){Navigator.pop(context); _addClientOrSupplier();}),
          
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            child: Text("نظام المطاعم والكافيهات", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.touch_app, color: Colors.blue), 
            title: const Text("الكاشير السريع (نقطة البيع)", style: TextStyle(fontWeight: FontWeight.bold)), 
            onTap: () {
              Navigator.pop(context); 
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PosScreen()));
            }
          ),
          ListTile(
            leading: const Icon(Icons.fastfood, color: Colors.orange), 
            title: const Text("إدارة المنتجات (المنيو)"), 
            onTap: () {
              Navigator.pop(context); 
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageProductsPage()));
            }
          ),
          const Divider(),

          // ✅ قسم كروت الإنترنت (يظهر فقط إذا كان مفعلاً في الإعدادات)
          if (box.get('is_wifi_cards_enabled', defaultValue: false)) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: Text("نظام كروت الشبكات 📶", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.settings_input_antenna, color: Colors.indigo), 
              title: const Text("إدارة باقات الكروت", style: TextStyle(fontWeight: FontWeight.bold)), 
              onTap: () {
                Navigator.pop(context); 
                Navigator.push(context, MaterialPageRoute(builder: (_) => const WifiPackagesScreen()));
              }
            ),
            const Divider(),
          ],

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
            title: const Text("سجل فواتير الكاش"), 
            onTap: () {
              Navigator.pop(context); 
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CashInvoicesHistoryPage()));
            }
          ),
          
          const Divider(),
          ListTile(leading: const Icon(Icons.account_balance_wallet, color: Colors.red), title: const Text("المصروفات"), onTap: () {Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesPage()));}),
          ListTile(leading: const Icon(Icons.save, color: Colors.blue), title: const Text("حفظ نسخة احتياطية"), onTap: () => BackupService.createBackup(context)),
          ListTile(leading: const Icon(Icons.restore, color: Colors.orange), title: const Text("استرجاع نسخة"), onTap: () => BackupService.restoreBackup(context, () {
            setState((){});
            _loadCurrencies(); 
          })),
          const Divider(),
          ListTile(leading: const Icon(Icons.settings, color: Colors.grey), title: const Text("الإعدادات"), onTap: () {
            Navigator.pop(context); 
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())).then((_) => _loadCurrencies());
          }),
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

  List<Map<String, dynamic>> _getFilteredSuppliers(List<Map<String, dynamic>> suppliers) {
    return suppliers.where((s) => (s['name']??"").toLowerCase().contains(_searchText.toLowerCase())).toList();
  }
  
  Widget _buildClientList(List<Map<String, dynamic>> allClients, List<Map<String, dynamic>> allSuppliers) {
    
    List<Map<String, dynamic>> dataToShow = [];
    String emptyMessage = "";

    if (_isViewingSuppliers) {
        dataToShow = _getFilteredSuppliers(allSuppliers);
        emptyMessage = "لا يوجد موردين حتى الآن";
    } else {
        dataToShow = allClients.where((c) {
          String curr = c['currency'] ?? 'ريال يمني';
          String n = c['name'] ?? '';
          return curr == selectedCurrency && n.toLowerCase().contains(_searchText.toLowerCase());
        }).toList();
        emptyMessage = "لا يوجد عملاء حتى الآن";
    }

    if (dataToShow.isEmpty) return Center(child: Text(emptyMessage, style: const TextStyle(color: Colors.grey, fontSize: 16)));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      itemCount: dataToShow.length,
      itemBuilder: (ctx, i) {
        var person = dataToShow[i];
        String id = person['id']; 

        double bal = 0;
        if (person['trans'] != null) {
           for (var t in person['trans']) {
             if (_isViewingSuppliers) {
                bal += (t['type'] == 'in' ? 1 : -1) * (double.tryParse(t['amt'].toString()) ?? 0);
             } else {
                bal += (t['type'] == 'out' ? 1 : -1) * (double.tryParse(t['amt'].toString()) ?? 0);
             }
           }
        }

        String name = person['name'] ?? (_isViewingSuppliers ? "مورد" : "عميل"); 
        String firstChar = name.isNotEmpty ? name[0] : "?"; 
        bool isLate = bal >= 50000;
        
        return Card(
          elevation: 2, 
          margin: const EdgeInsets.only(bottom: 10), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), 
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientDetail(id: id))),
            onLongPress: () => _editOrDeleteClient(id, person),
            leading: Stack(
              children: [
                CustomLetterIcon(letter: firstChar), 
                if(isLate) const Positioned(right: 0, top: 0, child: CircleAvatar(radius: 5, backgroundColor: Colors.red))
              ]
            ), 
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), 
            subtitle: _isViewingSuppliers ? const Text("مورد", style: TextStyle(color: Colors.grey, fontSize: 12)) : null,
            trailing: Text(
              _isBalanceHidden ? "****" : intl.NumberFormat("#,##0").format(bal.abs()), 
              style: TextStyle(
                color: _isViewingSuppliers 
                  ? (bal > 0 ? Colors.red[800] : Colors.green) 
                  : (bal >= 0 ? const Color(0xFFD81B60) : Colors.green), 
                fontWeight: FontWeight.bold, 
                fontSize: 16
              )
            )
          )
        );
      }
    );
  }

  void _addClientOrSupplier() {
    final n = TextEditingController();
    final p = TextEditingController();
    String c = selectedCurrency;
    
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (ctx) => StatefulBuilder( 
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_isViewingSuppliers ? "إضافة مورد جديد" : "عميل جديد"),
          content: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              TextField(controller: n, decoration: InputDecoration(labelText: _isViewingSuppliers ? "اسم المورد/الشركة" : "الاسم")), 
              TextField(controller: p, decoration: const InputDecoration(labelText: "الهاتف")), 
              if (!_isViewingSuppliers) 
                DropdownButtonFormField<String>(
                  value: _currencies.contains(c) ? c : _currencies.first, 
                  items: _currencies.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), 
                  onChanged: (v) => setDialogState(() => c = v!)
                )
            ]
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx), 
              child: const Text("إلغاء", style: TextStyle(color: Colors.grey))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isViewingSuppliers ? const Color(0xFF8E0E00) : const Color(0xFF1565C0), 
                foregroundColor: Colors.white
              ),
              onPressed: isSaving ? null : () async {
                if (n.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الرجاء إدخال الاسم"), backgroundColor: Colors.red));
                  return;
                }

                setDialogState(() => isSaving = true);

                String timeId = DateTime.now().millisecondsSinceEpoch.toString();
                String newId = _isViewingSuppliers ? 'supplier_$timeId' : timeId;
                
                await box.put(newId, {
                  'name': n.text.trim(), 
                  'phone': p.text.trim(), 
                  'currency': _isViewingSuppliers ? 'ريال يمني' : c, 
                  'trans': []
                });
                
                try { 
                  FirebaseFirestore.instance.collection('users').doc(currentUserUid).collection('clients').doc(newId)
                  .set({
                    'name': n.text.trim(), 
                    'phone': p.text.trim(), 
                    'currency': _isViewingSuppliers ? 'ريال يمني' : c, 
                    'trans': []
                  }); 
                } catch (e) { debugPrint("Firebase Error: $e"); }
                
                await Future.delayed(const Duration(milliseconds: 300));
                
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  setState(() {}); 
                }
              },
              child: isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("حفظ")
            )
          ]
        )
      )
    );
  }
}