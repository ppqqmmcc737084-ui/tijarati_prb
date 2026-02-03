import 'package:flutter/material.dart';

class CashInvoiceScreen extends StatefulWidget {
  @override
  _CashInvoiceScreenState createState() => _CashInvoiceScreenState();
}

class _CashInvoiceScreenState extends State<CashInvoiceScreen> {
  // قائمة المشتريات
  List<Map<String, dynamic>> items = [];
  
  // أدوات الكتابة
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  // حساب الإجمالي
  double get totalAmount {
    double total = 0;
    for (var item in items) {
      total += item['price'];
    }
    return total;
  }

  // دالة الإضافة (زايد زايد)
  void addItem() {
    if (nameController.text.isNotEmpty && priceController.text.isNotEmpty) {
      setState(() {
        items.add({
          'name': nameController.text,
          'price': double.tryParse(priceController.text) ?? 0,
        });
        nameController.clear();
        priceController.clear();
      });
    }
  }

  // دالة الحفظ
  void saveInvoice() {
    String allItemsNames = items.map((e) => e['name']).join(' + ');
    String finalDescription = "فاتورة نقدية: $allItemsNames";
    double finalPrice = totalAmount;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("✅ تم التجهيز"),
        content: Text("البيان: $finalDescription\nالإجمالي: $finalPrice ريال"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("موافق"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("نظام الكاشير"), backgroundColor: Colors.blue[800]),
      body: Column(
        children: [
          // الإدخال
          Container(
            padding: EdgeInsets.all(10),
            color: Colors.blue[50],
            child: Row(
              children: [
                IconButton(icon: Icon(Icons.add_circle, size: 40, color: Colors.blue[800]), onPressed: addItem),
                SizedBox(width: 10),
                Expanded(child: TextField(controller: priceController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "السعر", filled: true, fillColor: Colors.white))),
                SizedBox(width: 10),
                Expanded(flex: 2, child: TextField(controller: nameController, decoration: InputDecoration(labelText: "الاسم (عدسات..)", filled: true, fillColor: Colors.white))),
              ],
            ),
          ),
          // القائمة
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (ctx, i) => Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text("${i+1}")),
                  title: Text(items[i]['name']),
                  trailing: Text("${items[i]['price']} ريال"),
                  onLongPress: () => setState(() => items.removeAt(i)),
                ),
              ),
            ),
          ),
          // الإجمالي
          Container(
            padding: EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              children: [
                Text("الإجمالي: $totalAmount ريال", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                SizedBox(height: 10),
                SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800]), onPressed: items.isEmpty ? null : saveInvoice, child: Text("إتمام العملية", style: TextStyle(fontSize: 18)))),
              ],
            ),
          )
        ],
      ),
    );
  }
}