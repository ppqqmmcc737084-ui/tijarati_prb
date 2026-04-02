import 'dart:io';
import 'dart:convert'; // ✅ ضروري لفك تشفير الصورة
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb; 

class SmartInvoicePage extends StatefulWidget {
  const SmartInvoicePage({super.key});

  @override
  State<SmartInvoicePage> createState() => _SmartInvoicePageState();
}

class _SmartInvoicePageState extends State<SmartInvoicePage> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  final ScreenshotController _screenshotController = ScreenshotController();
  final Box box = Hive.box('tajarti_royal_v1');
  
  List<Map<String, dynamic>> _parsedItems = [];
  double _grandTotal = 0;
  final fmt = intl.NumberFormat("#,##0");
  bool _isCapturing = false;

  void _parseText(String input) {
    List<Map<String, dynamic>> items = [];
    double total = 0;

    var parts = input.split(RegExp(r'\n|\+'));

    for (var part in parts) {
      if (part.trim().isEmpty) continue;

      double qty = 1;
      double price = 0;
      String name = part.trim();

      var numbersMatch = RegExp(r'\d+').allMatches(part);
      List<double> numbers = numbersMatch.map((m) => double.parse(m.group(0)!)).toList();

      if (numbers.isNotEmpty) {
        if (part.contains('*') || part.contains('x') || part.contains('×')) {
          if (numbers.length >= 2) {
            qty = numbers[0]; 
            price = numbers[1]; 
            name = part.replaceAll(RegExp(r'[\d*x×]'), '').trim();
          }
        } else {
          price = numbers.last;
          name = part.replaceAll(RegExp(r'\d+'), '').trim();
        }
      }

      name = name.replaceAll(RegExp(r'(الف|ريال|حبات|حبة|سعر|سعره)'), '').trim();

      if (price > 0 || name.isNotEmpty) {
        double lineTotal = qty * price;
        total += lineTotal;
        items.add({
          'name': name.isEmpty ? 'منتج غير محدد' : name,
          'qty': qty,
          'price': price,
          'total': lineTotal,
        });
      }
    }

    setState(() {
      _parsedItems = items;
      _grandTotal = total;
    });
  }

  void _saveAndShareInvoice() async {
    if (_parsedItems.isEmpty) return;

    setState(() => _isCapturing = true);

    String clientName = _nameController.text.trim();
    if (clientName.isEmpty) clientName = "عميل نقدي";
    String phone = _phoneController.text.trim();

    int lastInvoiceNum = box.get('last_cash_invoice_number', defaultValue: 1000);
    int newInvoiceNum = lastInvoiceNum + 1;
    box.put('last_cash_invoice_number', newInvoiceNum); 

    String invoiceId = 'cash_inv_${DateTime.now().millisecondsSinceEpoch}';
    Map<String, dynamic> invoiceData = {
      'type': 'cash_invoice',
      'invoiceNumber': newInvoiceNum, 
      'clientName': clientName,
      'phone': phone,
      'total': _grandTotal,
      'items': _parsedItems,
      'date': DateTime.now().toString(),
    };

    box.put(invoiceId, invoiceData);

    try {
      String uid = box.get('user_uid') ?? box.get('device_id') ?? 'local_user';
      await FirebaseFirestore.instance.collection('users').doc(uid).collection('cash_invoices').doc(invoiceId).set(invoiceData);
    } catch (e) {
      debugPrint("Firebase Sync Error: $e");
    }

    try {
      final imageBytes = await _screenshotController.capture(delay: const Duration(milliseconds: 50));
      setState(() => _isCapturing = false);

      if (imageBytes != null) {
        if (kIsWeb) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("✅ تم حفظ الفاتورة النقدية بنجاح! رقمها: #$newInvoiceNum"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ));
        } else {
          final directory = await getApplicationDocumentsDirectory();
          final imagePath = await File('${directory.path}/smart_invoice_$newInvoiceNum.png').create();
          await imagePath.writeAsBytes(imageBytes);

          await Share.shareXFiles(
            [XFile(imagePath.path)], 
            text: "فاتورة مبيعات نقدية رقم #$newInvoiceNum\nالعميل: $clientName\nإجمالي المبلغ: ${fmt.format(_grandTotal)} ريال",
          );
        }
      }
    } catch (e) {
      setState(() => _isCapturing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("حدث خطأ: $e")));
    }
  }

  // ✅ الدالة الذكية لعرض الشعار المخصص أو الافتراضي
  Widget _buildInvoiceLogo() {
    String? customLogo = box.get('custom_logo');
    if (customLogo != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          base64Decode(customLogo),
          width: 50,
          height: 50,
          fit: BoxFit.cover,
        ),
      );
    } else {
      return Image.asset('assets/images/app_icon.png', width: 40, height: 40);
    }
  }

  @override
  Widget build(BuildContext context) {
    String shopName = box.get('shop_name') ?? "المتجر";
    String currentDate = intl.DateFormat('yyyy/MM/dd - hh:mm a').format(DateTime.now());
    int currentExpectedNum = box.get('last_cash_invoice_number', defaultValue: 1000) + 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("فاتورة VIP النقدية", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D256C),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: "اسم العميل",
                        prefixIcon: const Icon(Icons.person, color: Color(0xFF0D256C)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (v) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: "رقم الهاتف (اختياري)",
                        prefixIcon: const Icon(Icons.phone, color: Color(0xFF0D256C)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (v) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),

            Container(
              margin: const EdgeInsets.all(15),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.yellow[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.shade300, width: 2),
              ),
              child: TextField(
                controller: _textController,
                onChanged: _parseText,
                maxLines: 4,
                style: const TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF0D256C)),
                decoration: const InputDecoration(
                  hintText: "اكتب المشتريات هنا... \nمثال: جوال 50000 + 2 سماعة * 3000",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(15),
                ),
              ),
            ),

            Screenshot(
              controller: _screenshotController,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _buildInvoiceLogo(), // ✅ استدعاء الشعار هنا
                            const SizedBox(width: 10),
                            Text(shopName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0D256C))),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(5)),
                              child: const Text("فاتورة نقدية", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 5),
                            Text("رقم: #$currentExpectedNum", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          ],
                        )
                      ],
                    ),
                    const Divider(thickness: 2, height: 20),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("العميل: ${_nameController.text.isEmpty ? 'عميل نقدي' : _nameController.text}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            if (_phoneController.text.isNotEmpty) Text("الهاتف: ${_phoneController.text}", style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                        Text(currentDate, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF0D256C), borderRadius: BorderRadius.circular(5)),
                      child: const Row(
                        children: [
                          Expanded(flex: 3, child: Text("البيان", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          Expanded(flex: 1, child: Text("الكمية", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text("الإجمالي", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.left)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    if (_parsedItems.isEmpty)
                      const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("الفاتورة فارغة", style: TextStyle(color: Colors.grey)))),
                    
                    ..._parsedItems.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text(item['name'], style: const TextStyle(fontSize: 14))),
                          Expanded(flex: 1, child: Text("${item['qty'].toInt()}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 14))),
                          Expanded(flex: 2, child: Text(fmt.format(item['total']), textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                    )),
                    
                    const Divider(thickness: 1, height: 30),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("الإجمالي النهائي:", style: TextStyle(fontSize: 14, color: Colors.grey)),
                            Text(
                              "${fmt.format(_grandTotal)} ريال", 
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFD81B60))
                            ),
                          ],
                        ),
                        Transform.rotate(
                          angle: -0.2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.green, width: 2),
                              borderRadius: BorderRadius.circular(10)
                            ),
                            child: const Text("خالص نقداً", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1)),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Center(child: Text("شكراً لتعاملكم معنا - تطبيق تجارتي برو", style: TextStyle(color: Colors.grey, fontSize: 10))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(15),
        child: SizedBox(
          height: 55,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D256C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: _parsedItems.isEmpty ? null : () {
              _saveAndShareInvoice();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.save_alt),
            label: const Text("تخزين الكاش وإصدار الفاتورة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}