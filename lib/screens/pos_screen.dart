import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' as intl;

// استدعاء شاشة الفاتورة الذكية القديمة عشان نرسل لها الطلبات وتطبعها
import 'smart_invoice_page.dart'; 

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final Box box = Hive.box('tajarti_royal_v1');
  
  // سلة المشتريات: المفتاح هو الـ ID، والقيمة هي الكمية
  Map<String, int> cart = {}; 

  List<dynamic> get _products => box.get('pos_products', defaultValue: []);

  void _addToCart(String id) {
    setState(() {
      cart[id] = (cart[id] ?? 0) + 1;
    });
  }

  void _removeFromCart(String id) {
    setState(() {
      if (cart.containsKey(id) && cart[id]! > 0) {
        cart[id] = cart[id]! - 1;
        if (cart[id] == 0) cart.remove(id);
      }
    });
  }

  double get _totalPrice {
    double total = 0;
    for (var p in _products) {
      if (cart.containsKey(p['id'])) {
        total += (p['price'] as double) * cart[p['id']]!;
      }
    }
    return total;
  }

  // ✅ تحويل السلة إلى نص وإرساله لشاشة الفاتورة السريعة للطباعة
  void _goToCheckout() {
    if (cart.isEmpty) return;

    String invoiceText = "";
    for (var p in _products) {
      if (cart.containsKey(p['id'])) {
        int qty = cart[p['id']]!;
        double price = p['price'];
        String name = p['name'];
        // تكوين السطر
        invoiceText += "$name $qty * ${price.toInt()} \n";
      }
    }

    // الانتقال لصفحة الفاتورة
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => const SmartInvoicePage())
    ).then((_) {
      // تفريغ السلة بعد العودة
      setState(() => cart.clear());
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("قم بلصق الطلبات في مربع الفاتورة واطبع!"), 
        backgroundColor: Colors.blue
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("الكاشير السريع", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D256C),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh), 
            onPressed: () => setState(() => cart.clear())
          )
        ],
      ),
      body: Column(
        children: [
          // 🌟 شبكة المنتجات (المنيو)
          Expanded(
            child: _products.isEmpty
                ? const Center(child: Text("المنيو فارغ، أضف منتجات من الإعدادات."))
                : GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, // 3 منتجات في كل صف
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: _products.length,
                    itemBuilder: (ctx, i) {
                      var p = _products[i];
                      int qty = cart[p['id']] ?? 0;

                      return GestureDetector(
                        onTap: () => _addToCart(p['id']), // ضغطة تزيد واحد
                        onLongPress: () => _removeFromCart(p['id']), // ضغطة مطولة تنقص واحد
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: qty > 0 ? Colors.green : Colors.grey.shade300, 
                              width: qty > 0 ? 3 : 1
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05), 
                                blurRadius: 5
                              )
                            ],
                          ),
                          child: Stack(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                      child: p['image'] != null
                                          ? Image.memory(
                                              base64Decode(p['image']), 
                                              fit: BoxFit.cover, 
                                              gaplessPlayback: true
                                            )
                                          // ✅ تم تغيير الأيقونة لتناسب التجارة العامة
                                          : const Icon(Icons.inventory_2, size: 50, color: Colors.blueGrey),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    color: Colors.white,
                                    child: Column(
                                      children: [
                                        Text(
                                          p['name'], 
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), 
                                          maxLines: 1, 
                                          overflow: TextOverflow.ellipsis
                                        ),
                                        Text(
                                          "${p['price']} ريال", 
                                          style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                              // شارة الكمية (العداد الأحمر)
                              if (qty > 0)
                                Positioned(
                                  top: 5, right: 5,
                                  child: CircleAvatar(
                                    backgroundColor: Colors.red, 
                                    radius: 12, 
                                    child: Text(
                                      "$qty", 
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)
                                    )
                                  ),
                                )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // 🌟 الشريط السفلي (السلة وزر الطباعة)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1), 
                  blurRadius: 20, 
                  offset: const Offset(0, -5)
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("الإجمالي:", style: TextStyle(color: Colors.grey, fontSize: 14)),
                    Text(
                      "${intl.NumberFormat("#,##0").format(_totalTotal)} ريال", 
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFD81B60))
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: cart.isEmpty ? null : _goToCheckout,
                  icon: const Icon(Icons.receipt_long),
                  label: const Text("حساب وطباعة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  double get _totalTotal => _totalPrice;
}