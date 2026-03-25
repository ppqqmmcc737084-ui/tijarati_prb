import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'package:mobile_scanner/mobile_scanner.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';

class CashInvoiceScreen extends StatefulWidget {
  const CashInvoiceScreen({super.key});

  @override
  State<CashInvoiceScreen> createState() => _CashInvoiceScreenState();
}

class _CashInvoiceScreenState extends State<CashInvoiceScreen> {
  final Box box = Hive.box('tajarti_royal_v1');
  final fmt = intl.NumberFormat("#,##0");
  
  // سلة المشتريات (الفاتورة الحالية)
  List<Map<String, dynamic>> _cart = [];

  // حساب الإجمالي
  double get _totalAmount {
    double total = 0;
    for (var item in _cart) {
      total += (item['sell'] * item['cartQty']);
    }
    return total;
  }

  // --- 📷 نظام الكاميرا والباركود ---
  void _openScanner() {
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
              title: const Text("امسح باركود المنتج", style: TextStyle(color: Colors.white)),
              leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
            ),
            Expanded(
              child: MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                    final code = barcodes.first.rawValue!;
                    Navigator.pop(ctx); 
                    _addItemByBarcode(code); 
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addItemByBarcode(String code) {
    // البحث عن المنتج في المخزون المحلي (Hive) للسرعة
    final itemKey = box.keys.firstWhere((k) {
      if (!k.toString().startsWith('inv_')) return false;
      var item = box.get(k);
      return item['barcode'] == code;
    }, orElse: () => null);

    if (itemKey != null) {
      var item = box.get(itemKey);
      double availableQty = double.tryParse(item['qty'].toString()) ?? 0;

      if (availableQty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ هذا المنتج نفد من المخزون!"), backgroundColor: Colors.red));
        return;
      }

      // التحقق هل المنتج موجود مسبقاً في الفاتورة لزيادة كميته فقط
      int existingIndex = _cart.indexWhere((element) => element['id'] == itemKey.toString());
      
      setState(() {
        if (existingIndex >= 0) {
          if (_cart[existingIndex]['cartQty'] < availableQty) {
            _cart[existingIndex]['cartQty'] += 1;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الكمية المطلوبة تتجاوز المخزون!"), backgroundColor: Colors.orange));
          }
        } else {
          _cart.add({
            'id': itemKey.toString(),
            'name': item['name'],
            'sell': double.tryParse(item['sell'].toString()) ?? 0,
            'cartQty': 1.0,
            'maxQty': availableQty,
          });
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("⚠️ منتج غير مسجل! الكود: $code"), backgroundColor: Colors.red));
    }
  }

  // --- التحكم بكميات الفاتورة ---
  void _updateCartQty(int index, double delta) {
    setState(() {
      double newQty = _cart[index]['cartQty'] + delta;
      if (newQty > 0 && newQty <= _cart[index]['maxQty']) {
        _cart[index]['cartQty'] = newQty;
      } else if (newQty <= 0) {
        _cart.removeAt(index); // حذف المنتج إذا وصلت الكمية لصفر
      }
    });
  }

  // --- 💰 إتمام البيع وخصم المخزون ---
  void _checkout() async {
    if (_cart.isEmpty) return;

    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0))));

    for (var cartItem in _cart) {
      String id = cartItem['id'];
      double soldQty = cartItem['cartQty'];

      // جلب المنتج من الذاكرة
      var dbItem = box.get(id);
      if (dbItem != null) {
        double currentQty = double.tryParse(dbItem['qty'].toString()) ?? 0;
        double currentSold = double.tryParse(dbItem['sold'].toString()) ?? 0;

        // تحديث الكميات
        dbItem['qty'] = currentQty - soldQty;
        dbItem['sold'] = currentSold + soldQty;

        // الحفظ في الهاتف (Hive)
        box.put(id, dbItem);

        // الحفظ في السحابة (Firebase) ليعمل التزامن التلقائي
        try {
          // بما أننا ألغينا تسجيل الدخول، سنحفظ في مسار عام مؤقت (أو مسار المخزون الذي حددناه)
          // ملاحظة: إذا كنت تستخدم uid، استخدمه هنا. أما الآن سنستخدم مساراً مباشراً.
          await FirebaseFirestore.instance.collection('inventory_global').doc(id).set(Map<String, dynamic>.from(dbItem));
        } catch (e) {
          print("Cloud Sync Error: $e");
        }
      }
    }

    if (mounted) {
      Navigator.pop(context); // إغلاق دائرة التحميل
      setState(() {
        _cart.clear(); // تفريغ الفاتورة
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10), Text("تم البيع بنجاح، وخُصمت الكميات!")]),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text("فاتورة نقدية", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner, size: 28),
              onPressed: _openScanner,
              tooltip: "مسح منتج",
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: Column(
          children: [
            // 📋 قائمة المنتجات في الفاتورة
            Expanded(
              child: _cart.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 10),
                          Text("الفاتورة فارغة", style: TextStyle(color: Colors.grey[500], fontSize: 18)),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: _openScanner,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text("امسح منتج للبدء"),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
                          )
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(15),
                      itemCount: _cart.length,
                      itemBuilder: (ctx, i) {
                        var item = _cart[i];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text("السعر: ${fmt.format(item['sell'])}", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                    ],
                                  ),
                                ),
                                // أزرار التحكم بالكمية
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                      onPressed: () => _updateCartQty(i, -1),
                                    ),
                                    Text("${item['cartQty'].toInt()}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                      onPressed: () => _updateCartQty(i, 1),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 10),
                                // الإجمالي الفرعي
                                Text(
                                  fmt.format(item['sell'] * item['cartQty']),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0), fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // 💳 شريط الدفع السفلي
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)],
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("الإجمالي المطلوب:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
                        Text(fmt.format(_totalAmount), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFD81B60))),
                      ],
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: _cart.isEmpty ? null : _checkout,
                        child: const Text("إتمام البيع", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}