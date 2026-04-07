import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'package:mobile_scanner/mobile_scanner.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart'; // ✅ مكتبة الطابعة
import 'package:flutter/foundation.dart' show kIsWeb;

class CashInvoiceScreen extends StatefulWidget {
  const CashInvoiceScreen({super.key});

  @override
  State<CashInvoiceScreen> createState() => _CashInvoiceScreenState();
}

class _CashInvoiceScreenState extends State<CashInvoiceScreen> {
  final Box box = Hive.box('tajarti_royal_v1');
  final fmt = intl.NumberFormat("#,##0");
  
  List<Map<String, dynamic>> _cart = [];
  
  bool _isSaving = false;
  bool _isScanning = false;

  double get _totalAmount {
    double total = 0;
    for (var item in _cart) {
      total += (item['sell'] * item['cartQty']);
    }
    return total;
  }

  // --- 📷 نظام الكاميرا والباركود ---
  void _openScanner() {
    _isScanning = false; 
    
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
                  if (_isScanning) return; 
                  
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                    _isScanning = true; 
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

  void _updateCartQty(int index, double delta) {
    setState(() {
      double newQty = _cart[index]['cartQty'] + delta;
      if (newQty > 0 && newQty <= _cart[index]['maxQty']) {
        _cart[index]['cartQty'] = newQty;
      } else if (newQty <= 0) {
        _cart.removeAt(index);
      }
    });
  }

  // --- 🖨️ فحص الطابعة الذكي ---
  void _checkout() async {
    if (_cart.isEmpty || _isSaving) return;

    setState(() => _isSaving = true);

    if (kIsWeb) {
      // الويب ما يدعم طابعات البلوتوث المباشرة، نحفظ فقط
      await _processSale(printReceipt: false);
      return;
    }

    try {
      BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
      bool? isConnected = await bluetooth.isConnected;

      if (isConnected == true) {
        // ✅ الطابعة متصلة: حفظ وطباعة فورية بدون إزعاج
        await _processSale(printReceipt: true, bluetooth: bluetooth);
      } else {
        // ❌ الطابعة غير متصلة: إظهار النافذة الذكية
        setState(() => _isSaving = false); // نوقف التحميل عشان تظهر النافذة
        _showPrinterDialog();
      }
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ في البلوتوث: $e"), backgroundColor: Colors.red));
    }
  }

  // --- 💡 النافذة المنبثقة الأنيقة ---
  void _showPrinterDialog() {
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
        content: const Text("لم يتم العثور على طابعة بلوتوث متصلة.\nهل تريد حفظ الفاتورة بدون طباعة؟ أم الذهاب للإعدادات لربط الطابعة؟", style: TextStyle(fontSize: 15, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("إلغاء", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _processSale(printReceipt: false); // حفظ فقط
            }, 
            child: const Text("حفظ بدون طباعة", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D256C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الرجاء الذهاب لصفحة الإعدادات لربط الطابعة.")));
            },
            icon: const Icon(Icons.settings_bluetooth, color: Colors.white, size: 18),
            label: const Text("الإعدادات", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      )
    );
  }

  // --- 💰 دالة معالجة البيع والطباعة الفعالة ---
  Future<void> _processSale({required bool printReceipt, BlueThermalPrinter? bluetooth}) async {
    setState(() => _isSaving = true);

    try {
      // 1. خصم المخزون والحفظ
      for (var cartItem in _cart) {
        String id = cartItem['id'];
        double soldQty = cartItem['cartQty'];

        var dbItem = box.get(id);
        if (dbItem != null) {
          double currentQty = double.tryParse(dbItem['qty'].toString()) ?? 0;
          double currentSold = double.tryParse(dbItem['sold'].toString()) ?? 0;

          dbItem['qty'] = currentQty - soldQty;
          dbItem['sold'] = currentSold + soldQty;

          await box.put(id, dbItem);
          FirebaseFirestore.instance.collection('inventory_global').doc(id).set(Map<String, dynamic>.from(dbItem)).catchError((e) {
            debugPrint("Cloud Sync Error: $e");
          });
        }
      }

      // 2. الطباعة السريعة (إذا طلبنا)
      if (printReceipt && bluetooth != null) {
        String shopName = box.get('shop_name') ?? "المتجر";
        bluetooth.printCustom(shopName, 2, 1);
        bluetooth.printNewLine();
        bluetooth.printCustom("فاتورة مبيعات", 1, 1);
        bluetooth.printCustom("--------------------------------", 0, 1);
        for (var item in _cart) {
          bluetooth.printLeftRight(item['name'], "${item['cartQty'].toInt()}x   ${fmt.format(item['sell'] * item['cartQty'])}", 1);
        }
        bluetooth.printCustom("--------------------------------", 0, 1);
        bluetooth.printCustom("الاجمالي: ${fmt.format(_totalAmount)}", 2, 1);
        bluetooth.printNewLine();
        bluetooth.printNewLine();
      }

      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        setState(() {
          _cart.clear(); // تفريغ السلة
          _isSaving = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 30),
                const SizedBox(width: 15),
                Expanded(child: Text(printReceipt ? "تم البيع والطباعة بنجاح!" : "تم البيع بنجاح!", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          )
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("حدث خطأ: $e"), backgroundColor: Colors.red));
      }
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
          backgroundColor: const Color(0xFF0D256C),
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
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D256C), foregroundColor: Colors.white),
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
                                Text(
                                  fmt.format(item['sell'] * item['cartQty']),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D256C), fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
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
                          backgroundColor: const Color(0xFF0D256C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: (_cart.isEmpty || _isSaving) ? null : _checkout,
                        
                        child: _isSaving 
                            ? const SizedBox(
                                height: 25, 
                                width: 25, 
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                              )
                            : const Text("إتمام البيع", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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