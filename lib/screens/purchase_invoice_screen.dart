import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseInvoiceScreen extends StatefulWidget {
  final String supplierId;
  final String supplierName;

  const PurchaseInvoiceScreen({
    super.key,
    required this.supplierId,
    required this.supplierName,
  });

  @override
  State<PurchaseInvoiceScreen> createState() => _PurchaseInvoiceScreenState();
}

class _PurchaseInvoiceScreenState extends State<PurchaseInvoiceScreen> {
  final Box box = Hive.box('tajarti_royal_v1');
  final fmt = intl.NumberFormat("#,##0");
  
  // سلة المشتريات (معرف المنتج -> {الاسم، الكمية، سعر الشراء، التكلفة الإجمالية})
  Map<String, Map<String, dynamic>> cart = {}; 
  bool _isProcessing = false;

  final TextEditingController _paidAmountCtrl = TextEditingController();
  final TextEditingController _invoiceNoteCtrl = TextEditingController();

  List<dynamic> get _products => box.get('pos_products', defaultValue: []);

  String get currentUserUid {
    String? uid = box.get('user_uid');
    if (uid != null && uid.isNotEmpty) return uid;
    return box.get('device_id') ?? 'local_user';
  }

  double get _totalInvoicePrice {
    double total = 0;
    cart.values.forEach((item) => total += item['totalCost']);
    return total;
  }

  void _showAddItemDialog(Map product) {
    int qty = 1;
    // نفترض أن سعر البيع هو الافتراضي، والتاجر بيعدله لسعر الشراء الفعلي
    double buyPrice = double.tryParse(product['price'].toString()) ?? 0; 
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Text("شراء: ${product['name']}", style: const TextStyle(color: Color(0xFF8E0E00))),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("الكمية المشترى:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () { if (qty > 1) setModalState(() => qty--); }),
                        Text("$qty", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: () => setModalState(() => qty++)),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 15),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "سعر الشراء للقطعة", prefixIcon: Icon(Icons.money)),
                  onChanged: (val) => setModalState(() => buyPrice = double.tryParse(val) ?? 0),
                  controller: TextEditingController(text: buyPrice.toStringAsFixed(0))..selection = TextSelection.fromPosition(TextPosition(offset: buyPrice.toStringAsFixed(0).length)),
                ),
                const Divider(height: 30),
                Text("الإجمالي: ${fmt.format(qty * buyPrice)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء", style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E0E00)),
                onPressed: () {
                  setState(() {
                    cart[product['id']] = {
                      'name': product['name'],
                      'qty': qty,
                      'buyPrice': buyPrice,
                      'totalCost': qty * buyPrice,
                    };
                  });
                  Navigator.pop(ctx);
                },
                child: const Text("إضافة للفاتورة", style: TextStyle(color: Colors.white)),
              )
            ],
          );
        }
      )
    );
  }

  void _removeFromCart(String id) {
    setState(() => cart.remove(id));
  }

  // 🌟 العملية المحاسبية المتكاملة (السحر) 🌟
  Future<void> _processPurchase() async {
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الفاتورة فارغة!"), backgroundColor: Colors.red));
      return;
    }
    
    double paidAmount = double.tryParse(_paidAmountCtrl.text) ?? 0;
    if (paidAmount > _totalInvoicePrice) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("المبلغ المدفوع أكبر من قيمة الفاتورة!"), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isProcessing = true);
    double remainingDebt = _totalInvoicePrice - paidAmount;
    String invoiceNote = _invoiceNoteCtrl.text.isEmpty ? "فاتورة مشتريات بضاعة" : _invoiceNoteCtrl.text;

    try {
      // 1️⃣ تحديث حساب المورد (تسجيل الفاتورة والدفعات)
      var supplierData = box.get(widget.supplierId);
      List trans = List.from(supplierData['trans'] ?? []);
      
      // قيد الفاتورة (in) يرفع مديونية المورد علينا
      trans.add({
        'type': 'in',
        'amt': _totalInvoicePrice,
        'qty': cart.length, // عدد الأصناف المشتراة
        'note': invoiceNote,
        'date': DateTime.now().toString()
      });

      // إذا دفعنا كاش، نضيف قيد سداد (out) ينزل المديونية
      if (paidAmount > 0) {
        trans.add({
          'type': 'out',
          'amt': paidAmount,
          'qty': null,
          'note': "دفعة نقدية لفاتورة المشتريات",
          'date': DateTime.now().toString()
        });
      }
      
      supplierData['trans'] = trans;
      await box.put(widget.supplierId, supplierData);
      FirebaseFirestore.instance.collection('users').doc(currentUserUid).collection('clients').doc(widget.supplierId).update({'trans': trans});

      // 2️⃣ تسجيل الدفعة النقدية في قسم "المصروفات" (ليتأثر الصندوق الفعلي)
      if (paidAmount > 0) {
         List expenses = List.from(box.get('expenses', defaultValue: []));
         expenses.add({
           'id': DateTime.now().millisecondsSinceEpoch.toString(),
           'title': "سداد مورد (${widget.supplierName})",
           'amount': paidAmount,
           'date': DateTime.now().toString()
         });
         await box.put('expenses', expenses);
         FirebaseFirestore.instance.collection('users').doc(currentUserUid).update({'expenses': expenses});
      }

      // 3️⃣ تحديث المخزون (Inventory)
      // ملاحظة: بما أن التطبيق الحالي لا يملك جدول مخزون منفصل، سنكتفي حالياً بتسجيل المشتريات والديون. 
      // سيتم إضافة زيادة المخزون هنا لاحقاً عندما نؤسس صفحة الجرد والمخزون بشكل متقدم.

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم تقييد فاتورة المشتريات بنجاح! 📦✅"), backgroundColor: Colors.green));
        Navigator.pop(context); // الرجوع لصفحة المورد
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("حدث خطأ: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("شراء من: ${widget.supplierName}", style: const TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: const Color(0xFF8E0E00), // العنابي الفخم للموردين
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // قائمة المنتجات المتاحة للشراء
          Container(
            height: 140,
            color: Colors.white,
            child: _products.isEmpty
                ? const Center(child: Text("لا توجد منتجات مسجلة في النظام"))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(10),
                    itemCount: _products.length,
                    itemBuilder: (ctx, i) {
                      var p = _products[i];
                      return GestureDetector(
                        onTap: () => _showAddItemDialog(p),
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(left: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.inventory_2, size: 40, color: Colors.blueGrey),
                              const SizedBox(height: 5),
                              Text(p['name'], textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          const Divider(height: 1, thickness: 2),
          
          // سلة المشتريات الحالية
          Expanded(
            child: cart.isEmpty
                ? const Center(child: Text("لم تقم بإضافة منتجات للفاتورة بعد.", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: cart.length,
                    itemBuilder: (ctx, i) {
                      String key = cart.keys.elementAt(i);
                      var item = cart[key]!;
                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 5),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.red[50], child: Text("${item['qty']}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                          title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("السعر: ${item['buyPrice']} ريال"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("${fmt.format(item['totalCost'])}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              IconButton(icon: const Icon(Icons.delete, color: Colors.grey, size: 20), onPressed: () => _removeFromCart(key))
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // لوحة الدفع والحفظ
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20))
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("إجمالي الفاتورة:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text("${fmt.format(_totalInvoicePrice)} ريال", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF8E0E00))),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _invoiceNoteCtrl,
                  decoration: InputDecoration(
                    labelText: "رقم الفاتورة أو ملاحظة (اختياري)",
                    prefixIcon: const Icon(Icons.receipt, color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _paidAmountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "المبلغ المدفوع كاش (آجل = اتركه فارغ)",
                    prefixIcon: const Icon(Icons.money, color: Colors.green),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E0E00), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: _isProcessing ? null : _processPurchase,
                    icon: _isProcessing ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text("اعتماد الفاتورة للمورد", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}