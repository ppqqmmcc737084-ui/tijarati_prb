import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';

class CashInvoicesHistoryPage extends StatefulWidget {
  const CashInvoicesHistoryPage({super.key});

  @override
  State<CashInvoicesHistoryPage> createState() => _CashInvoicesHistoryPageState();
}

class _CashInvoicesHistoryPageState extends State<CashInvoicesHistoryPage> {
  final Box box = Hive.box('tajarti_royal_v1');
  final fmt = intl.NumberFormat("#,##0");
  final ScreenshotController _screenshotController = ScreenshotController();

  // ✅ دالة الحذف السحرية (تمسح من الهاتف والسحابة)
  void _deleteInvoice(String invoiceId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد الحذف", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("هل أنت متأكد من حذف هذه الفاتورة النقدية نهائياً؟ لا يمكن التراجع عن هذا الإجراء."),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("إلغاء", style: TextStyle(color: Colors.grey, fontSize: 16))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              // 1. الحذف من الهاتف (Hive)
              box.delete(invoiceId);
              
              // 2. الحذف من السحابة (Firebase) في الخلفية
              try {
                String uid = box.get('user_uid') ?? box.get('device_id') ?? 'local_user';
                await FirebaseFirestore.instance.collection('users').doc(uid).collection('cash_invoices').doc(invoiceId).delete();
              } catch (e) {
                debugPrint("Delete Sync Error: $e");
              }
              
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حذف الفاتورة بنجاح!"), backgroundColor: Colors.red));
            }, 
            child: const Text("حذف الفاتورة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  // دالة التقاط وإعادة مشاركة الفاتورة القديمة
  void _shareOldInvoice(Map data) async {
    try {
      final imageBytes = await _screenshotController.capture(delay: const Duration(milliseconds: 50));

      if (imageBytes != null) {
        if (kIsWeb) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("✅ يمكنك إرسال الفاتورة عبر الواتساب عند استخدام التطبيق على الجوال!"),
            backgroundColor: Colors.blue,
          ));
        } else {
          final directory = await getApplicationDocumentsDirectory();
          final imagePath = await File('${directory.path}/invoice_copy.png').create();
          await imagePath.writeAsBytes(imageBytes);

          String clientName = data['clientName'] ?? "عميل نقدي";
          await Share.shareXFiles(
            [XFile(imagePath.path)], 
            text: "نسخة من فاتورة مبيعات نقدية - $clientName\nإجمالي المبلغ: ${fmt.format(data['total'])}",
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("حدث خطأ: $e")));
    }
  }

  // نافذة عرض وإعادة إصدار الفاتورة
  void _showInvoiceDetails(Map data) {
    List items = data['items'] ?? [];
    String shopName = box.get('shop_name') ?? "المتجر";
    DateTime dt = DateTime.tryParse(data['date'].toString()) ?? DateTime.now();
    String formattedDate = intl.DateFormat('yyyy/MM/dd - hh:mm a').format(dt);
    String invoiceId = data['id']; // جلب الـ ID للحذف

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFFF5F5F5),
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(child: Container(width: 50, height: 6, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 10),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 📸 الفاتورة الفخمة
                    Screenshot(
                      controller: _screenshotController,
                      child: Container(
                        margin: const EdgeInsets.all(20),
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
                                    Image.asset('assets/images/app_icon.png', width: 40, height: 40),
                                    const SizedBox(width: 10),
                                    Text(shopName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0D256C))),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(5)),
                                  child: const Text("نسخة فاتورة", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                )
                              ],
                            ),
                            const Divider(thickness: 2, height: 30),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("العميل: ${data['clientName']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    if (data['phone'] != null && data['phone'].toString().isNotEmpty) 
                                      Text("الهاتف: ${data['phone']}", style: const TextStyle(color: Colors.grey)),
                                  ],
                                ),
                                Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                            
                            ...items.map((item) => Padding(
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
                                    Text("${fmt.format(data['total'])} ريال", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFD81B60))),
                                  ],
                                ),
                                Transform.rotate(
                                  angle: -0.2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                                    decoration: BoxDecoration(border: Border.all(color: Colors.green, width: 2), borderRadius: BorderRadius.circular(10)),
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
                  ],
                ),
              ),
            ),
            
            // 🔘 أزرار التحكم الجديدة (يوجد بها زر الحذف)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
              ),
              child: Row(
                children: [
                  // ✅ زر الحذف الجديد
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx); // إغلاق النافذة المنبثقة أولاً
                        _deleteInvoice(invoiceId); // استدعاء دالة الحذف
                      },
                      child: const Icon(Icons.delete, size: 28),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // زر المشاركة
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D256C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: () => _shareOldInvoice(data),
                      icon: const Icon(Icons.share),
                      label: const Text("مشاركة الفاتورة", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("سجل فواتير الكاش", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D256C),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box box, _) {
          var invoices = box.keys
              .where((k) => k.toString().startsWith('cash_inv_'))
              .map((k) => {'id': k, ...box.get(k) as Map})
              .toList();
          
          invoices.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

          if (invoices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text("لا توجد مبيعات نقدية حتى الآن", style: TextStyle(color: Colors.grey.shade600, fontSize: 18)),
                ],
              )
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: invoices.length,
            itemBuilder: (ctx, i) {
              var inv = invoices[i];
              DateTime dt = DateTime.tryParse(inv['date'].toString()) ?? DateTime.now();
              String formattedDate = intl.DateFormat('yyyy/MM/dd - hh:mm a').format(dt);

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  onTap: () => _showInvoiceDetails(inv), 
                  // ✅ ميزة الحذف بالضغط المطول
                  onLongPress: () => _deleteInvoice(inv['id']),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F5E9),
                    radius: 25,
                    child: Icon(Icons.check_circle, color: Colors.green, size: 30),
                  ),
                  title: Text(inv['clientName'] ?? 'عميل نقدي', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(fmt.format(inv['total']), style: const TextStyle(color: Color(0xFF0D256C), fontWeight: FontWeight.bold, fontSize: 18)),
                      const Text("ريال", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          );
        }
      ),
    );
  }
}