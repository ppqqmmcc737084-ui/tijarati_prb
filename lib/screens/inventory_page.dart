import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'package:mobile_scanner/mobile_scanner.dart'; 

// ✅ استيراد مكتبات السحابة والمصادقة
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final Box box = Hive.box('tajarti_royal_v1');
  final fmt = intl.NumberFormat("#,##0");
  String _searchText = "";
  final TextEditingController _searchController = TextEditingController();

  // ✅ جلب الرقم التعريفي للتاجر (للوصول لخزنته الخاصة)
  String get uid => FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

  // --- 📷 1. نظام الباركود والكاميرا ---
  void _openScanner({required Function(String) onDetect}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (ctx) => SizedBox(
        height: 450, 
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.black, 
              title: const Text("امسح الباركود الآن", style: TextStyle(color: Colors.white)),
              leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
            ),
            Expanded(
              child: MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                    final code = barcodes.first.rawValue!;
                    Navigator.pop(ctx); 
                    onDetect(code); 
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ البيع السريع عبر الكاميرا (تم ربطه بالسحابة)
  void _scanToSell() {
    _openScanner(onDetect: (code) async {
      // البحث عن المنتج بالباركود في السحابة
      var query = await FirebaseFirestore.instance.collection('users').doc(uid).collection('inventory').where('barcode', isEqualTo: code).get();
      
      if (query.docs.isNotEmpty) {
        var doc = query.docs.first;
        var item = doc.data();
        _sellOne(doc.id, item);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 10), Text("تم بيع 1 ${item['name']} بنجاح!")]),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("⚠️ هذا المنتج غير مسجل! الكود: $code"),
            backgroundColor: Colors.red,
            action: SnackBarAction(label: "تسجيله؟", textColor: Colors.white, onPressed: () => _addItem(initialBarcode: code)),
          ));
        }
      }
    });
  }

  // --- 2. العمليات (إضافة، تعديل، حذف) ---
  void _addItem({String? initialBarcode}) {
    final nameC = TextEditingController();
    final qtyC = TextEditingController();
    final costC = TextEditingController();
    final sellC = TextEditingController();
    final barcodeC = TextEditingController(text: initialBarcode);

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("إضافة صنف جديد"),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: TextField(controller: barcodeC, decoration: const InputDecoration(labelText: "الباركود", prefixIcon: Icon(Icons.qr_code)))),
            IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.blue),
              onPressed: () {
                Navigator.pop(ctx); 
                _openScanner(onDetect: (code) {
                  _addItem(initialBarcode: code); 
                });
              }, 
            )
          ]),
          const SizedBox(height: 10),
          TextField(controller: nameC, decoration: const InputDecoration(labelText: "اسم المنتج", prefixIcon: Icon(Icons.shopping_bag))),
          TextField(controller: qtyC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "الكمية", prefixIcon: Icon(Icons.numbers))),
          Row(children: [
            Expanded(child: TextField(controller: costC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "شراء", labelStyle: TextStyle(color: Colors.red)))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: sellC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "بيع", labelStyle: TextStyle(color: Colors.green)))),
          ]),
        ]),
      ),
      actions: [
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white), onPressed: () async {
          if(nameC.text.isNotEmpty) {
            final id = "inv_${DateTime.now().millisecondsSinceEpoch}";
            final item = {
              'name': nameC.text,
              'qty': double.tryParse(qtyC.text) ?? 0,
              'cost': double.tryParse(costC.text) ?? 0,
              'sell': double.tryParse(sellC.text) ?? 0,
              'sold': 0.0,
              'barcode': barcodeC.text
            };
            
            // 1. حفظ في الهاتف للسرعة
            box.put(id, item); 
            
            // 2. حفظ في الخزنة السحابية الخاصة
            try {
              await FirebaseFirestore.instance.collection('users').doc(uid).collection('inventory').doc(id).set(item);
            } catch (e) {
              print(e);
            }
            
            if (mounted) Navigator.pop(ctx);
          }
        }, child: const Text("حفظ"))
      ],
    ));
  }

  void _editOrDeleteItem(String id, Map item) {
    showModalBottomSheet(context: context, builder: (ctx) => Container(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.edit, color: Colors.blue), title: const Text("تعديل الصنف"), onTap: (){ Navigator.pop(ctx); _showEditDialog(id, item); }),
        ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text("حذف الصنف"), onTap: () async { 
            Navigator.pop(ctx); 
            box.delete(id); 
            try {
              await FirebaseFirestore.instance.collection('users').doc(uid).collection('inventory').doc(id).delete();
            } catch (e) { print(e); }
          }),
      ]),
    ));
  }

  void _showEditDialog(String id, Map item) {
    final nameC = TextEditingController(text: item['name']);
    final qtyC = TextEditingController(text: item['qty'].toString());
    final costC = TextEditingController(text: item['cost'].toString());
    final sellC = TextEditingController(text: item['sell'].toString());
    final barcodeC = TextEditingController(text: item['barcode'] ?? "");

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("تعديل"),
      content: SingleChildScrollView(child: Column(children: [
        TextField(controller: barcodeC, decoration: const InputDecoration(labelText: "الباركود")),
        TextField(controller: nameC, decoration: const InputDecoration(labelText: "الاسم")),
        TextField(controller: qtyC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "الكمية")),
        Row(children: [
          Expanded(child: TextField(controller: costC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "شراء"))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: sellC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "بيع"))),
        ]),
      ])),
      actions: [ElevatedButton(onPressed: () async {
        Map<String, dynamic> updatedItem = Map.from(item);
        updatedItem['name'] = nameC.text;
        updatedItem['qty'] = double.tryParse(qtyC.text) ?? 0;
        updatedItem['cost'] = double.tryParse(costC.text) ?? 0;
        updatedItem['sell'] = double.tryParse(sellC.text) ?? 0;
        updatedItem['barcode'] = barcodeC.text;
        
        box.put(id, updatedItem);
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).collection('inventory').doc(id).update(updatedItem);
        } catch (e) { print(e); }
        
        if (mounted) Navigator.pop(ctx);
      }, child: const Text("حفظ"))],
    ));
  }

  void _sellOne(String id, Map item) async {
    double currentQty = double.tryParse(item['qty'].toString()) ?? 0;
    if(currentQty > 0) {
      double newQty = currentQty - 1;
      double newSold = (double.tryParse(item['sold'].toString()) ?? 0) + 1;
      
      Map<String, dynamic> updatedItem = Map.from(item);
      updatedItem['qty'] = newQty;
      updatedItem['sold'] = newSold;
      
      box.put(id, updatedItem);
      
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('inventory').doc(id).update({
          'qty': newQty,
          'sold': newSold
        });
      } catch (e) { print(e); }
    }
  }

  // --- 3. الواجهة (محاسبية ونظيفة + زر الكاميرا + البث المباشر) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("إدارة المخزون", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, size: 28),
            onPressed: _scanToSell,
            tooltip: "بيع سريع بالباركود",
          ),
          const SizedBox(width: 10),
        ],
      ),
      // ✅ استبدال الواجهة القديمة بكاميرا بث مباشر تقرأ من السحابة الخاصة بالتاجر
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('inventory').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)));
          }

          var docs = snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot>[];

          // حساب الإجمالي
          double totalCapital = 0;
          for (var doc in docs) {
            var i = doc.data() as Map<String, dynamic>;
            totalCapital += (double.tryParse(i['qty'].toString()) ?? 0) * (double.tryParse(i['cost'].toString()) ?? 0);
          }

          // الفلترة حسب البحث
          var filteredDocs = docs.where((doc) {
            var item = doc.data() as Map<String, dynamic>;
            bool matchName = (item['name'] ?? "").toString().toLowerCase().contains(_searchText.toLowerCase());
            bool matchCode = (item['barcode'] ?? "").toString().contains(_searchText);
            return matchName || matchCode;
          }).toList();

          return Column(
            children: [
              // شريط المعلومات الرقمي
              Container(
                padding: const EdgeInsets.all(15),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(child: _buildStatItem("الأصناف", "${docs.length}", Icons.category, Colors.blue)),
                    Container(width: 1, height: 40, color: Colors.grey[300]),
                    Expanded(child: _buildStatItem("رأس المال", fmt.format(totalCapital), Icons.monetization_on, Colors.indigo)),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // البحث
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchText = val),
                  decoration: InputDecoration(
                    hintText: "بحث (اسم أو باركود)...",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code, color: Colors.blue), 
                      onPressed: () => _openScanner(onDetect: (code){ 
                        _searchController.text = code; 
                        setState(() => _searchText = code); 
                      }),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 15),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true, fillColor: Colors.white
                  ),
                ),
              ),

              // القائمة المتصلة بالسحابة
              Expanded(
                child: filteredDocs.isEmpty 
                  ? const Center(child: Text("لا توجد أصناف", style: TextStyle(color: Colors.grey, fontSize: 16)))
                  : ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: filteredDocs.length,
                  itemBuilder: (ctx, i) {
                    final doc = filteredDocs[i];
                    final item = doc.data() as Map<String, dynamic>;
                    double qty = double.tryParse(item['qty'].toString()) ?? 0;
                    double sell = double.tryParse(item['sell'].toString()) ?? 0;

                    return Card(
                      elevation: 2, margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        onLongPress: () => _editOrDeleteItem(doc.id, item),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                          child: Icon(item['barcode']!=null && item['barcode']!="" ? Icons.qr_code_2 : Icons.inventory_2, color: Colors.blue[800]),
                        ),
                        title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("الكمية: ${fmt.format(qty)}", style: TextStyle(color: qty<=5 ? Colors.red : Colors.grey[700], fontWeight: FontWeight.bold)),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          onPressed: () => _sellOne(doc.id, item),
                          child: Text("بيع ${fmt.format(sell)}"),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        }
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem, 
        backgroundColor: const Color(0xFF1565C0), 
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: "إضافة صنف جديد",
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 5),
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    ]);
  }
}