import 'dart:io';
import 'dart:convert';
import 'dart:math'; 
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:blue_thermal_printer/blue_thermal_printer.dart'; 

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
  
  bool _isPrinting = false;
  bool _isSharing = false;
  
  late String _currentInvoiceNumber;
  late String _invoiceId; 

  @override
  void initState() {
    super.initState();
    _currentInvoiceNumber = _generateUniqueNumber();
    _invoiceId = 'cash_inv_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _generateUniqueNumber() {
    String ms = DateTime.now().millisecondsSinceEpoch.toString();
    String timePart = ms.substring(ms.length - 5); 
    String randomPart = (Random().nextInt(9000) + 1000).toString(); 
    return "$timePart-$randomPart"; 
  }

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
        items.add({'name': name.isEmpty ? 'منتج غير محدد' : name, 'qty': qty, 'price': price, 'total': lineTotal});
      }
    }
    
    setState(() { _parsedItems = items; _grandTotal = total; });
  }

  Future<Uint8List?> _captureInvoice() async {
    return await _screenshotController.capture(delay: const Duration(milliseconds: 100));
  }

  Future<void> _saveInvoiceData() async {
    String clientName = _nameController.text.trim();
    if (clientName.isEmpty) clientName = "عميل نقدي";
    
    Map<String, dynamic> invoiceData = {
      'id': _invoiceId, 'type': 'cash_invoice', 'invoiceNumber': _currentInvoiceNumber, 
      'clientName': clientName, 'phone': _phoneController.text.trim(),
      'total': _grandTotal, 'items': _parsedItems, 'date': DateTime.now().toString(),
    };

    await box.put(_invoiceId, invoiceData);
    String uid = box.get('user_uid') ?? box.get('device_id') ?? 'local_user';
    FirebaseFirestore.instance.collection('users').doc(uid).collection('cash_invoices').doc(_invoiceId).set(invoiceData).catchError((e) { 
      debugPrint("Firebase Sync Error: $e"); 
    });
  }

  // --- 🖨️ الطباعة الذكية مع النافذة ---
  void _printInvoice() async {
    if (_parsedItems.isEmpty || _isPrinting) return;
    
    setState(() => _isPrinting = true);
    await _saveInvoiceData();

    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الطباعة الحرارية لا تعمل على الويب"), backgroundColor: Colors.orange));
      setState(() => _isPrinting = false);
      return;
    }

    try {
      BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
      bool? isConnected = await bluetooth.isConnected;
      
      if (isConnected == true) {
        final imageBytes = await _captureInvoice();
        if (imageBytes != null) {
          await bluetooth.printImageBytes(imageBytes); 
          await bluetooth.printNewLine(); 
          await bluetooth.printNewLine();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ تم الطباعة!"), backgroundColor: Colors.green));
        }
      } else {
        // ❌ نافذة التوجيه للإعدادات
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Row(children: [Icon(Icons.print_disabled, color: Colors.red), SizedBox(width: 10), Text("الطابعة غير متصلة!")]),
              content: const Text("يرجى ربط طابعة البلوتوث من الإعدادات لتتمكن من الطباعة."),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D256C)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("اذهب للإعدادات لربط الطابعة")));
                  },
                  icon: const Icon(Icons.settings, color: Colors.white), label: const Text("الإعدادات", style: TextStyle(color: Colors.white)),
                ),
              ],
            )
          );
        }
      }
    } catch (e) {
      debugPrint("Print error: $e");
    }
    
    if (mounted) setState(() => _isPrinting = false);
  }

  void _shareInvoice() async {
    if (_parsedItems.isEmpty || _isSharing) return;
    
    setState(() => _isSharing = true);
    await _saveInvoiceData();
    
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("المشاركة تعمل على الجوال فقط"), backgroundColor: Colors.blue));
      setState(() => _isSharing = false);
      return;
    }

    final imageBytes = await _captureInvoice();
    
    if (imageBytes != null) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final imagePath = await File('${directory.path}/inv_$_currentInvoiceNumber.png').create();
        await imagePath.writeAsBytes(imageBytes);
        await Share.shareXFiles([XFile(imagePath.path)], text: "فاتورة مبيعات رقم #$_currentInvoiceNumber\nالإجمالي: ${fmt.format(_grandTotal)} ريال");
      } catch (e) {}
    }
    
    if (mounted) setState(() => _isSharing = false);
  }

  // --- دالة سحب الشعار الرسمي ---
  Widget _buildInvoiceLogo() {
    String? customLogo = box.get('custom_logo');
    if (customLogo != null && customLogo.isNotEmpty) {
      try {
        return Container(
          width: 55, height: 55,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF0D256C), width: 2)),
          child: ClipOval(child: Image.memory(base64Decode(customLogo), fit: BoxFit.cover, gaplessPlayback: true)),
        );
      } catch (e) { return const SizedBox(); }
    }
    return Image.asset('assets/images/app_icon.png', width: 50, height: 50);
  }

  @override
  Widget build(BuildContext context) {
    String shopName = box.get('shop_name') ?? "المتجر";
    String currentDate = intl.DateFormat('yyyy/MM/dd - hh:mm a').format(DateTime.now());

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5), 
        appBar: AppBar(title: const Text("فاتورة VIP الذكية"), backgroundColor: const Color(0xFF0D256C), foregroundColor: Colors.white, elevation: 0),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(15), color: Colors.white,
                child: Row(
                  children: [
                    Expanded(child: TextField(controller: _nameController, decoration: InputDecoration(labelText: "اسم العميل", prefixIcon: const Icon(Icons.person, color: Color(0xFF0D256C)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: "رقم الهاتف", prefixIcon: const Icon(Icons.phone, color: Color(0xFF0D256C)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
                  ],
                ),
              ),
              
              Container(
                margin: const EdgeInsets.all(15), padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: Colors.yellow[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.amber.shade400, width: 1.5)),
                child: TextField(controller: _textController, onChanged: _parseText, maxLines: 3, decoration: const InputDecoration(hintText: "اكتب المشتريات هنا...\nمثال: شاورما 4 * 1000 + عصير 500", border: InputBorder.none, contentPadding: EdgeInsets.all(15))),
              ),
              
              // 🌟 تصميم الفاتورة الإبداعي (الذي سيتم طباعته)
              Screenshot(
                controller: _screenshotController,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5), 
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, spreadRadius: 1, offset: Offset(0, 3))]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildInvoiceLogo(), // ✅ وضعنا الشعار
                          const SizedBox(width: 15), 
                          Text(shopName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF0D256C))),
                        ]
                      ),
                      const SizedBox(height: 15),
                      Text("فاتورة مبيعات نقدية", style: TextStyle(fontSize: 16, color: Colors.grey[700], fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 5),
                      Container(height: 1, width: double.infinity, color: Colors.grey[300]),
                      const SizedBox(height: 15),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text("رقم الفاتورة: #$_currentInvoiceNumber", style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            Text("العميل: ${_nameController.text.isEmpty ? 'عميل نقدي' : _nameController.text}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D256C))),
                          ]),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(intl.DateFormat('yyyy/MM/dd').format(DateTime.now()), style: const TextStyle(color: Colors.black87)),
                            const SizedBox(height: 5),
                            Text(intl.DateFormat('hh:mm a').format(DateTime.now()), style: const TextStyle(color: Colors.black87)),
                          ]),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8), 
                        decoration: BoxDecoration(color: const Color(0xFF0D256C), borderRadius: BorderRadius.circular(8)), 
                        child: const Row(children: [
                          Expanded(flex: 3, child: Text("الصنف", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), 
                          Expanded(flex: 1, child: Text("الكمية", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)), 
                          Expanded(flex: 2, child: Text("الإجمالي", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.left))
                        ])
                      ),
                      const SizedBox(height: 10),
                      
                      ..._parsedItems.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8), 
                        child: Row(children: [
                          Expanded(flex: 3, child: Text(item['name'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))), 
                          Expanded(flex: 1, child: Text("${item['qty'].toInt()}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 15))), 
                          Expanded(flex: 2, child: Text(fmt.format(item['total']), textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)))
                        ])
                      )),
                      
                      const SizedBox(height: 15),
                      Container(height: 1, width: double.infinity, color: Colors.grey[300]), 
                      const SizedBox(height: 15),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                        children: [
                          const Text("الإجمالي الكلي:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)), 
                          Text("${fmt.format(_grandTotal)} ريال", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFFD81B60)))
                        ]
                      ),
                      const SizedBox(height: 10),
                      
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Transform.rotate(
                          angle: -0.15, 
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5), 
                            decoration: BoxDecoration(border: Border.all(color: Colors.green, width: 2), borderRadius: BorderRadius.circular(8)), 
                            child: const Text("خالص نقداً", style: TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 18))
                          )
                        ),
                      ),
                      const SizedBox(height: 25),
                      const Text("شكراً لزيارتكم ونتمنى لكم يوماً سعيداً", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(15),
          decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))]),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: (_parsedItems.isEmpty || _isPrinting || _isSharing) ? null : _printInvoice,
                  icon: _isPrinting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.print), 
                  label: Text(_isPrinting ? "جاري الطباعة..." : "طباعة", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D256C), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: (_parsedItems.isEmpty || _isPrinting || _isSharing) ? null : _shareInvoice,
                  icon: _isSharing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.share), 
                  label: Text(_isSharing ? "جاري المشاركة..." : "مشاركة", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}