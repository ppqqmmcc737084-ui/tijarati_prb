import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final Box box = Hive.box('tajarti_royal_v1');
  final fmt = intl.NumberFormat("#,##0");
  
  Map<String, int> cart = {}; 
  bool _isProcessing = false;

  List<dynamic> get _products => box.get('pos_products', defaultValue: []);

  void _addToCart(String id) {
    setState(() { cart[id] = (cart[id] ?? 0) + 1; });
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

  // --- 🖨️ نظام الدفع والطباعة المباشر (بدون النسخ واللصق) ---
  void _goToCheckout() async {
    if (cart.isEmpty || _isProcessing) return;
    setState(() => _isProcessing = true);

    if (kIsWeb) {
      _processSaleLocally(print: false);
      return;
    }

    try {
      BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
      bool? isConnected = await bluetooth.isConnected;

      if (isConnected == true) {
        // ✅ الطابعة متصلة: الدفع والطباعة فوراً
        await _processSaleLocally(print: true, bluetooth: bluetooth);
      } else {
        // ❌ الطابعة غير متصلة: نظهر النافذة الذكية
        setState(() => _isProcessing = false);
        _showSmartPrinterDialog();
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ في البلوتوث: $e"), backgroundColor: Colors.red));
    }
  }

  // --- 💡 النافذة المنبثقة الذكية ---
  void _showSmartPrinterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.print_disabled, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text("الطابعة غير متصلة!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text("لم يتم العثور على طابعة متصلة. هل تريد حفظ الفاتورة بدون طباعة أم الذهاب لربط الطابعة؟", style: TextStyle(fontSize: 15, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _processSaleLocally(print: false); // حفظ بدون طباعة
            }, 
            child: const Text("حفظ فقط", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D256C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى ربط الطابعة من الإعدادات.")));
            },
            icon: const Icon(Icons.settings_bluetooth, color: Colors.white, size: 18),
            label: const Text("الإعدادات", style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );
  }

  // --- دالة الحفظ (والطباعة إذا طلبت) ---
  Future<void> _processSaleLocally({required bool print, BlueThermalPrinter? bluetooth}) async {
    setState(() => _isProcessing = true);
    
    // 1. الخصم من المخزون
    for (var p in _products) {
      if (cart.containsKey(p['id'])) {
        int qtySold = cart[p['id']]!;
        // كود خصم المخزون هنا بناءً على بنية قاعدة بياناتك
      }
    }

    // 2. الطباعة الحرارية السريعة
    if (print && bluetooth != null) {
      String shopName = box.get('shop_name') ?? "تجارتي برو";
      bluetooth.printCustom(shopName, 2, 1);
      bluetooth.printNewLine();
      bluetooth.printCustom("فاتورة مبيعات سريعة", 1, 1);
      bluetooth.printCustom("--------------------------------", 0, 1);
      for (var p in _products) {
        if (cart.containsKey(p['id'])) {
          int qty = cart[p['id']]!;
          double price = p['price'];
          bluetooth.printLeftRight(p['name'], "${qty}x   ${fmt.format(price * qty)}", 1);
        }
      }
      bluetooth.printCustom("--------------------------------", 0, 1);
      bluetooth.printCustom("الاجمالي: ${fmt.format(_totalPrice)}", 2, 1);
      bluetooth.printNewLine();
      bluetooth.printNewLine();
    }

    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() {
        cart.clear();
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(print ? "تم البيع والطباعة بنجاح!" : "تم البيع والحفظ بنجاح!"), 
        backgroundColor: Colors.green
      ));
    }
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() => cart.clear()))
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _products.isEmpty
                ? const Center(child: Text("المنيو فارغ، أضف منتجات من الإعدادات."))
                : GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, 
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: _products.length,
                    itemBuilder: (ctx, i) {
                      var p = _products[i];
                      int qty = cart[p['id']] ?? 0;

                      return GestureDetector(
                        onTap: () => _addToCart(p['id']), 
                        onLongPress: () => _removeFromCart(p['id']), 
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: qty > 0 ? Colors.green : Colors.grey.shade300, width: qty > 0 ? 3 : 1),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
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
                                          ? Image.memory(base64Decode(p['image']), fit: BoxFit.cover, gaplessPlayback: true)
                                          : const Icon(Icons.inventory_2, size: 50, color: Colors.blueGrey),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    color: Colors.white,
                                    child: Column(
                                      children: [
                                        Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Text("${p['price']} ريال", style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                              if (qty > 0)
                                Positioned(
                                  top: 5, right: 5,
                                  child: CircleAvatar(
                                    backgroundColor: Colors.red, 
                                    radius: 12, 
                                    child: Text("$qty", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
                                  ),
                                )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // 🌟 الشريط السفلي (مع التحميل الذكي)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("الإجمالي:", style: TextStyle(color: Colors.grey, fontSize: 14)),
                    Text("${fmt.format(_totalPrice)} ريال", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFD81B60))),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: (cart.isEmpty || _isProcessing) ? null : _goToCheckout,
                  icon: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.receipt_long),
                  label: Text(_isProcessing ? "جاري الدفع..." : "حساب وطباعة", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}