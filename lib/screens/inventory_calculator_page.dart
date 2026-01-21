import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' as intl;

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final Box box = Hive.box('tajarti_royal_v1');
  final fmt = intl.NumberFormat("#,##0");
  String _searchText = "";

  // --- 1. العمليات الأساسية (إضافة، بيع، تعديل، حذف) ---

  void _addItem() {
    final nameC = TextEditingController();
    final qtyC = TextEditingController();
    final costC = TextEditingController();
    final sellC = TextEditingController();

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("إضافة صنف جديد"),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameC, decoration: const InputDecoration(labelText: "اسم المنتج", prefixIcon: Icon(Icons.shopping_bag))),
          TextField(controller: qtyC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "الكمية المتوفرة", prefixIcon: Icon(Icons.numbers))),
          Row(children: [
            Expanded(child: TextField(controller: costC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "سعر الشراء", labelStyle: TextStyle(color: Colors.red)))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: sellC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "سعر البيع", labelStyle: TextStyle(color: Colors.green)))),
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
              'sold': 0.0
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
        ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text("حذف الصنف نهائياً"), onTap: (){ 
          Navigator.pop(ctx);
          showDialog(context: context, builder: (dCtx)=>AlertDialog(
            title: const Text("حذف"), content: const Text("هل أنت متأكد من حذف هذا الصنف؟"),
            actions: [TextButton(onPressed: (){ box.delete(id); setState((){}); Navigator.pop(dCtx); }, child: const Text("حذف", style: TextStyle(color: Colors.red)))]
          ));
        }),
      ]),
    ));
  }

  void _showEditDialog(String id, Map item) {
    final nameC = TextEditingController(text: item['name']);
    final qtyC = TextEditingController(text: item['qty'].toString());
    final costC = TextEditingController(text: item['cost'].toString());
    final sellC = TextEditingController(text: item['sell'].toString());

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("تعديل الصنف"),
      content: SingleChildScrollView(child: Column(children: [
        TextField(controller: nameC, decoration: const InputDecoration(labelText: "اسم المنتج")),
        TextField(controller: qtyC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "الكمية الحالية")),
        Row(children: [
          Expanded(child: TextField(controller: costC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "شراء"))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: sellC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "بيع"))),
        ]),
      ])),
      actions: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white), onPressed: (){
        item['name'] = nameC.text;
        item['qty'] = double.tryParse(qtyC.text) ?? 0;
        item['cost'] = double.tryParse(costC.text) ?? 0;
        item['sell'] = double.tryParse(sellC.text) ?? 0;
        box.put(id, item);
        setState((){});
        Navigator.pop(ctx);
      }, child: const Text("حفظ التعديلات"))],
    ));
  }

  void _sellOne(String id, Map item) {
    double currentQty = double.tryParse(item['qty'].toString()) ?? 0;
    if(currentQty > 0) {
      item['qty'] = currentQty - 1;
      item['sold'] = (double.tryParse(item['sold'].toString()) ?? 0) + 1;
      box.put(id, item);
      setState((){});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم بيع قطعة واحدة 💰"), duration: Duration(milliseconds: 500)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الكمية نفذت! ❌")));
    }
  }

  // --- 2. زر الجرد الذكي (Stocktaking) ---

  void _showStockTakingReport(List keys) {
    double totalInventoryValue = 0; // قيمة البضاعة الموجودة (رأس المال النائم)
    double totalSoldRevenue = 0;    // إجمالي المبيعات (كاش دخل)
    double totalSoldCost = 0;       // تكلفة البضاعة المباعة
    int totalItems = 0;

    for(var k in keys) {
      var i = box.get(k);
      double qty = double.tryParse(i['qty'].toString()) ?? 0;
      double cost = double.tryParse(i['cost'].toString()) ?? 0;
      double sell = double.tryParse(i['sell'].toString()) ?? 0;
      double sold = double.tryParse(i['sold'].toString()) ?? 0;

      totalInventoryValue += (qty * cost);
      totalSoldRevenue += (sold * sell);
      totalSoldCost += (sold * cost);
      totalItems++;
    }

    double netProfit = totalSoldRevenue - totalSoldCost;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("📊 تقرير الجرد المالي", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
            const Divider(height: 30),
            _buildReportRow("عدد الأصناف", "$totalItems صنف", null),
            _buildReportRow("قيمة البضاعة بالمخزن", fmt.format(totalInventoryValue), Colors.blue[800]),
            _buildReportRow("إجمالي المبيعات (الكاش)", fmt.format(totalSoldRevenue), Colors.green[700]),
            const Divider(),
            _buildReportRow("صافي الربح المحقق", fmt.format(netProfit), Colors.green, isBold: true),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, padding: const EdgeInsets.all(15)),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("إغلاق التقرير", style: TextStyle(fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildReportRow(String label, String value, Color? color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value, style: TextStyle(fontSize: isBold ? 20 : 16, fontWeight: FontWeight.bold, color: color ?? Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // تصفية البيانات
    final keys = box.keys.where((k) {
      if (!k.toString().startsWith('inv_')) return false;
      var item = box.get(k);
      return (item['name'] ?? "").toString().toLowerCase().contains(_searchText.toLowerCase());
    }).toList();

    // حسابات سريعة للبطاقة العلوية
    double currentCapital = 0;
    double expectedProfit = 0;
    for(var k in keys) {
      var i = box.get(k);
      double qty = double.tryParse(i['qty'].toString()) ?? 0;
      double cost = double.tryParse(i['cost'].toString()) ?? 0;
      double sell = double.tryParse(i['sell'].toString()) ?? 0;
      currentCapital += (qty * cost);
      expectedProfit += (qty * (sell - cost)); // ربح متوقع من البضاعة المتبقية
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("المخزون والجرد", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- 1. بطاقة المخزون الملكية (Royal Inventory Card) ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20, top: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1565C0),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.inventory_2, color: Colors.white70),
                      Text("رأس المال (بضاعة)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(fmt.format(currentCapital), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text("ربح متوقع (مخزون)", style: TextStyle(color: Colors.white54, fontSize: 10)),
                        Text("+${fmt.format(expectedProfit)}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                      ]),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white, foregroundColor: const Color(0xFF4A148C),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5)
                        ),
                        onPressed: () => _showStockTakingReport(keys),
                        icon: const Icon(Icons.analytics, size: 18),
                        label: const Text("جرد فوري"),
                      )
                    ],
                  )
                ],
              ),
            ),
          ),

          // --- 2. البحث والقائمة ---
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchText = val),
                    decoration: InputDecoration(
                      hintText: "بحث عن صنف...",
                      prefixIcon: const Icon(Icons.search, color: Colors.purple),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                  ),
                ),
                Expanded(
                  child: keys.isEmpty 
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_shopping_cart, size: 60, color: Colors.grey[300]), const Text("المخزن فارغ، أضف بضاعة!", style: TextStyle(color: Colors.grey))]))
                  : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    itemCount: keys.length,
                    itemBuilder: (ctx, i) {
                      final k = keys[i];
                      final item = box.get(k);
                      double qty = double.tryParse(item['qty'].toString()) ?? 0;
                      double cost = double.tryParse(item['cost'].toString()) ?? 0;
                      double sell = double.tryParse(item['sell'].toString()) ?? 0;
                      double profitPerUnit = sell - cost;

                      return Card(
                        elevation: 2, margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                          onLongPress: () => _editOrDeleteItem(k.toString(), item),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.purple[50], borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.qr_code_2, color: Colors.purple),
                          ),
                          title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const SizedBox(height: 5),
                            Row(children: [
                              Text("الكمية: ${fmt.format(qty)}", style: TextStyle(color: qty < 5 ? Colors.red : Colors.black87, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 10),
                              Text("ربح الحبة: ${fmt.format(profitPerUnit)}", style: const TextStyle(color: Colors.green, fontSize: 12)),
                            ]),
                          ]),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                            onPressed: () => _sellOne(k.toString(), item),
                            child: const Text("بيع"),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        backgroundColor: const Color(0xFF1565C0),
        child: const Icon(Icons.add, size: 30, color: Colors.white),
      ),
    );
  }
}