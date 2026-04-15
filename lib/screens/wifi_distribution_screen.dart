import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; // ضرورية لفتح الواتساب
import 'package:intl/intl.dart' as intl;
import '../services/sms_service.dart';

class WifiDistributionScreen extends StatefulWidget {
  const WifiDistributionScreen({super.key});

  @override
  State<WifiDistributionScreen> createState() => _WifiDistributionScreenState();
}

class _WifiDistributionScreenState extends State<WifiDistributionScreen> {
  final Box box = Hive.box('tajarti_royal_v1');
  
  String? selectedClientId; 
  String? selectedCardName;
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  bool _isLoading = false;

  final fmt = intl.NumberFormat("#,##0");

  List<Map<String, dynamic>> _getClients() {
    List<Map<String, dynamic>> clients = [];
    for (var key in box.keys) {
      if (!key.toString().startsWith('pos_') && !key.toString().startsWith('supplier_') && !key.toString().startsWith('cash_')) {
        var data = box.get(key);
        if (data is Map && data.containsKey('name')) {
          clients.add({'id': key.toString(), 'name': data['name'], 'phone': data['phone']});
        }
      }
    }
    return clients;
  }

  // 💬 دالة تجهيز وإرسال كشف الحساب / المطالبة عبر الواتساب
  Future<void> _sendStatementViaWhatsApp() async {
    if (selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الرجاء اختيار المحل أولاً")));
      return;
    }

    Map<dynamic, dynamic> clientData = box.get(selectedClientId);
    String phone = clientData['phone'] ?? "";
    String name = clientData['name'] ?? "العميل";
    
    // حساب الرصيد الحالي للمحل
    double balance = 0;
    if (clientData['trans'] != null) {
      for (var t in clientData['trans']) {
        double amt = double.tryParse(t['amt'].toString()) ?? 0;
        if (t['type'] == 'out') {
          balance += amt; // دين عليه
        } else {
          balance -= amt; // سداد منه
        }
      }
    }

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("رقم هاتف المحل غير مسجل!"), backgroundColor: Colors.orange));
      return;
    }

    // تنظيف رقم الهاتف للواتساب (إزالة الأصفار في البداية وإضافة مفتاح اليمن إذا لزم)
    String waPhone = phone.replaceAll(RegExp(r'^0+'), '');
    if (!waPhone.startsWith('967')) {
      waPhone = '967$waPhone';
    }

    String message = "مرحباً ($name) 👋\n\n"
        "إليك كشف حساب مبسط من نظام توزيع الكروت:\n"
        "إجمالي المديونية المستحقة عليك: *${fmt.format(balance)} ريال*\n\n"
        "يرجى مراجعة الحساب وإجراء السداد المتاح. شكراً لك!";

    String encodedMessage = Uri.encodeComponent(message);
    Uri waUrl = Uri.parse("https://wa.me/$waPhone?text=$encodedMessage");

    try {
      if (await canLaunchUrl(waUrl)) {
        await launchUrl(waUrl, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا يمكن فتح الواتساب. تأكد من تثبيت التطبيق.")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("حدث خطأ: $e")));
    }
  }

  Future<void> _saveAndSend() async {
    if (selectedClientId == null || selectedCardName == null || _qtyController.text.isEmpty || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الرجاء تعبئة كل الحقول الأساسية")));
      return;
    }

    setState(() => _isLoading = true);

    int qty = int.tryParse(_qtyController.text) ?? 0;
    double price = double.tryParse(_priceController.text) ?? 0.0;
    double total = qty * price;

    try {
      Map<dynamic, dynamic> clientData = box.get(selectedClientId);
      String clientPhone = clientData['phone'] ?? "";
      String clientName = clientData['name'] ?? "العميل";

      List trans = clientData['trans'] ?? [];
      trans.add({
        'date': DateTime.now().toString(),
        'amt': total,
        'type': 'out', 
        'note': 'استلام عدد $qty كروت ($selectedCardName)'
      });
      clientData['trans'] = trans;
      
      await box.put(selectedClientId, clientData);

      String uid = box.get('user_uid', defaultValue: 'local');
      if (!uid.startsWith('local')) {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('clients').doc(selectedClientId).update({'trans': trans});
      }

      if (clientPhone.isNotEmpty) {
        String smsMessage = "مرحباً ($clientName)\nتم تسليمك عدد $qty كروت من فئة ($selectedCardName) بسعر $price للكرت.\nإجمالي المبلغ المقيد على حسابك: $total ريال.\nبالتوفيق!";
        await SmsService.sendSms(phone: clientPhone, message: smsMessage);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم تسليم الكروت وتقييد المبلغ بنجاح!"), backgroundColor: Colors.green));
        Navigator.pop(context); 
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("حدث خطأ: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var clients = _getClients();

    return Scaffold(
      appBar: AppBar(title: const Text("توزيع كروت الجملة"), backgroundColor: const Color(0xFF0D256C), iconTheme: const IconThemeData(color: Colors.white), titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("المحل / نقطة البيع:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              hint: const Text("اختر المحل من القائمة"),
              value: selectedClientId,
              items: clients.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name']))).toList(),
              onChanged: (val) => setState(() => selectedClientId = val),
            ),
            const SizedBox(height: 20),

            // 🌟 الزر الجديد: يظهر فقط إذا اخترت محلاً
            if (selectedClientId != null)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green[700], 
                  side: BorderSide(color: Colors.green[700]!),
                  minimumSize: const Size(double.infinity, 45)
                ),
                onPressed: _sendStatementViaWhatsApp,
                icon: const Icon(Icons.send_to_mobile), // أيقونة بديلة للواتساب
                label: const Text("إرسال مطالبة رصيد عبر الواتساب", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            
            if (selectedClientId != null) const SizedBox(height: 20),

            const Divider(),
            const SizedBox(height: 10),

            const Text("تسليم كروت جديدة:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              hint: const Text("اختر فئة الكرت"),
              value: selectedCardName,
              items: ['أبو 100', 'أبو 200', 'أبو 500', 'أبو 1000'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => setState(() => selectedCardName = val),
            ),
            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: "العدد (كم كرت؟)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    onChanged: (v) => setState((){}), 
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: "سعر الكرت الواحد", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    onChanged: (v) => setState((){}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("إجمالي القيمة:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                    "${fmt.format((int.tryParse(_qtyController.text) ?? 0) * (double.tryParse(_priceController.text) ?? 0))} ريال", 
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: const Color(0xFF0D256C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: _saveAndSend,
                  child: const Text("تسجيل كدين وإرسال SMS", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
          ],
        ),
      ),
    );
  }
}