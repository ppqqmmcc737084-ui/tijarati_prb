import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'package:mobile_scanner/mobile_scanner.dart'; // ✅ مكتبة الكاميرا

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

  // --- 📷 1. نظام الباركود والكاميرا ---
  void _openScanner({required Function(String) onDetect}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (ctx) => SizedBox(
        height: 450, // نصف الشاشة للكاميرا
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
                    Navigator.pop(ctx); // إغلاق الكاميرا
                    onDetect(code); // تنفيذ الأمر
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // البيع السريع عبر الكاميرا
  void _scanToSell() {
    _openScanner(onDetect: (code) {
      // البحث عن المنتج بهذا الباركود
      final itemKey = box.keys.firstWhere((k) {
        if (!k.toString().startsWith('inv_')) return false;
        var item = box.get(k);
        return item['barcode'] == code;
      }, orElse: () => null);

      if (itemKey != null) {
        var item = box.get(itemKey);
        _sellOne(itemKey.toString(), item);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 10), Text("تم بيع 1 ${item['name']} بنجاح!")]),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("⚠️ هذا المنتج غير مسجل! الكود: $code"),
          backgroundColor: Colors.red,
          action: SnackBarAction(label: "تسجيله؟", textColor: Colors.white, onPressed: () => _addItem(initialBarcode: code)),
        ));
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
          // حقل الباركود الذكي
          Row(children: [
            Expanded(child: TextField(controller: barcodeC, decoration: const InputDecoration(labelText: "الباركود", prefixIcon: Icon(Icons.qr_code)))),
            IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.blue),
              onPressed: () {
                Navigator.pop(ctx); // إغلاق مؤقت
                _openScanner(onDetect: (code) {
                  // إعادة الفتح مع الكود
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
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white), onPressed: (){
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
            box.put(id, item);
            setState((){});
            Navigator.pop(ctx);
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
        ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text("حذف الصنف"), onTap: (){ Navigator.pop(ctx); box.delete(id); setState((){}); }),
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
      actions: [ElevatedButton(onPressed: (){
        item['name'] = nameC.text;
        item['qty'] = double.tryParse(qtyC.text) ?? 0;
        item['cost'] = double.tryParse(costC.text) ?? 0;
        item['sell'] = double.tryParse(sellC.text) ?? 0;
        item['barcode'] = barcodeC.text;
        box.put(id, item);
        setState((){});
        Navigator.pop(ctx);
      }, child: const Text("حفظ"))],
    ));
  }

  void _sellOne(String id, Map item) {
    double currentQty = double.tryParse(item['qty'].toString()) ?? 0;
    if(currentQty > 0) {
      item['qty'] = currentQty - 1;
      item['sold'] = (double.tryParse(item['sold'].toString()) ?? 0) + 1;
      box.put(id, item);
      setState((){});
    }
  }

  // --- 3. الواجهة (محاسبية ونظيفة + زر الكاميرا) ---
  @override
  Widget build(BuildContext context) {
    final keys = box.keys.where((k) {
      if (!k.toString().startsWith('inv_')) return false;
      var item = box.get(k);
      bool matchName = (item['name'] ?? "").toString().toLowerCase().contains(_searchText.toLowerCase());
      bool matchCode = (item['barcode'] ?? "").toString().contains(_searchText);
      return matchName || matchCode;
    }).toList();

    double totalCapital = 0;
    for(var k in keys) {
      var i = box.get(k);
      totalCapital += (double.tryParse(i['qty'].toString()) ?? 0) * (double.tryParse(i['cost'].toString()) ?? 0);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("إدارة المخزون", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // ✅ زر الكاميرا الأساسي في الأعلى
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, size: 28),
            onPressed: _scanToSell,
            tooltip: "بيع سريع بالباركود",
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // ✅ شريط المعلومات الرقمي (بدون بطاقة كبيرة)
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(child: _buildStatItem("الأصناف", "${keys.length}", Icons.category, Colors.blue)),
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

          // القائمة
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: keys.length,
              itemBuilder: (ctx, i) {
                final k = keys[i];
                final item = box.get(k);
                double qty = double.tryParse(item['qty'].toString()) ?? 0;
                double sell = double.tryParse(item['sell'].toString()) ?? 0;

                return Card(
                  elevation: 2, margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    onLongPress: () => _editOrDeleteItem(k.toString(), item),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                      child: Icon(item['barcode']!=null && item['barcode']!="" ? Icons.qr_code_2 : Icons.inventory_2, color: Colors.blue[800]),
                    ),
                    title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("الكمية: ${fmt.format(qty)}", style: TextStyle(color: qty<=5 ? Colors.red : Colors.grey[700], fontWeight: FontWeight.bold)),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      onPressed: () => _sellOne(k.toString(), item),
                      child: Text("بيع ${fmt.format(sell)}"),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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