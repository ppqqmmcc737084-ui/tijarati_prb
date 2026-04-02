import 'dart:io';
import 'dart:convert'; // ✅ ضروري هنا أيضاً
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
  
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  void _deleteInvoice(String invoiceId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد الحذف", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("هل أنت متأكد من حذف هذه الفاتورة النقدية نهائياً؟"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              box.delete(invoiceId);
              try {
                String uid = box.get('user_uid') ?? box.get('device_id') ?? 'local_user';
                await FirebaseFirestore.instance.collection('users').doc(uid).collection('cash_invoices').doc(invoiceId).delete();
              } catch (e) { debugPrint(e.toString()); }
              Navigator.pop(ctx);
            }, 
            child: const Text("حذف", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }

  void _shareOldInvoice(Map data) async {
    try {
      final imageBytes = await _screenshotController.capture(delay: const Duration(milliseconds: 50));
      if (imageBytes != null) {
        if (!kIsWeb) {
          final directory = await getApplicationDocumentsDirectory();
          final imagePath = await File('${directory.path}/inv_${data['invoiceNumber']}.png').create();
          await imagePath.writeAsBytes(imageBytes);
          await Share.shareXFiles([XFile(imagePath.path)], text: "فاتورة رقم #${data['invoiceNumber']}");
        } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("هذه الميزة تعمل بكفاءة على الجوال"), backgroundColor: Colors.blue));
        }
      }
    } catch (e) { debugPrint(e.toString()); }
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

  void _showInvoiceDetails(Map data) {
    List items = data['items'] ?? [];
    String shopName = box.get('shop_name') ?? "المتجر";
    String invNum = data['invoiceNumber']?.toString() ?? "---";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(color: Color(0xFFF5F5F5), borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(child: Container(width: 50, height: 6, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10)))),
            Expanded(
              child: SingleChildScrollView(
                child: Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
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
                            Text("رقم: #$invNum", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          ],
                        ),
                        const Divider(thickness: 2, height: 30),
                        Text("العميل: ${data['clientName']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 20),
                        ...items.map((item) => ListTile(
                          title: Text(item['name']),
                          subtitle: Text("${item['qty'].toInt()} × ${fmt.format(item['price'])}"),
                          trailing: Text(fmt.format(item['total']), style: const TextStyle(fontWeight: FontWeight.bold)),
                        )),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("الإجمالي:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text("${fmt.format(data['total'])} ريال", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  IconButton(onPressed: () { Navigator.pop(ctx); _deleteInvoice(data['id']); }, icon: const Icon(Icons.delete, color: Colors.red)),
                  Expanded(child: ElevatedButton.icon(onPressed: () => _shareOldInvoice(data), icon: const Icon(Icons.share), label: const Text("مشاركة"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D256C), foregroundColor: Colors.white))),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: const InputDecoration(
                  hintText: "ابحث بالاسم أو رقم الفاتورة...",
                  prefixIcon: Icon(Icons.search, color: Color(0xFF0D256C)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: box.listenable(),
              builder: (context, Box box, _) {
                var invoices = box.keys
                    .where((k) => k.toString().startsWith('cash_inv_'))
                    .map((k) => {'id': k, ...box.get(k) as Map})
                    .toList();
                
                var filtered = invoices.where((inv) {
                  String name = (inv['clientName'] ?? "").toString().toLowerCase();
                  String num = (inv['invoiceNumber'] ?? "").toString();
                  return name.contains(_searchQuery.toLowerCase()) || num.contains(_searchQuery);
                }).toList();

                filtered.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

                if (filtered.isEmpty) {
                  return const Center(child: Text("لا توجد فواتير مطابقة للبحث", style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    var inv = filtered[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        onTap: () => _showInvoiceDetails(inv),
                        onLongPress: () => _deleteInvoice(inv['id']),
                        leading: CircleAvatar(backgroundColor: Colors.blue.shade50, child: const Icon(Icons.receipt, color: Color(0xFF0D256C))),
                        title: Text("${inv['clientName'] ?? 'عميل نقدي'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("فاتورة رقم: #${inv['invoiceNumber'] ?? '---'}"),
                        trailing: Text("${fmt.format(inv['total'])}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD81B60))),
                      ),
                    );
                  },
                );
              }
            ),
          ),
        ],
      ),
    );
  }
}