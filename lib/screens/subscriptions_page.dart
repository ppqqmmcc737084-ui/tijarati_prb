import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({super.key});

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  final Box box = Hive.box('tajarti_royal_v1');
  final nController = TextEditingController(); // لاسم المشترك
  final pController = TextEditingController(); // لرقم الهاتف
  
  bool isLoading = false;
  bool isCodeGenerated = false;
  String generatedCode = "";

  void _generateReferenceCode() {
    if (nController.text.isEmpty || pController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إدخال الاسم والرقم أولاً")));
      return;
    }
    const chars = 'ABCDE12345';
    Random rnd = Random();
    String randomStr = String.fromCharCodes(Iterable.generate(5, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    setState(() {
      generatedCode = "VIP-$randomStr";
      isCodeGenerated = true;
    });
  }

  Future<void> _confirmAndSave() async {
    setState(() => isLoading = true);
    String uid = box.get('user_uid', defaultValue: 'unknown');

    try {
      // حفظ البيانات الاحترازية في الفايربيس (اسم، رقم، رمز)
      await FirebaseFirestore.instance.collection('subscription_requests').doc(uid).set({
        'uid': uid,
        'subscriber_name': nController.text.trim(),
        'subscriber_phone': pController.text.trim(),
        'reference_code': generatedCode,
        'status': 'pending',
        'date': DateTime.now().toString(),
      });

      // حفظ الرمز محلياً عند العميل للرجوع إليه
      await box.put('my_pending_code', generatedCode);

      if (mounted) _showFinalStepDialog();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("خطأ في الاتصال")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showFinalStepDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تم حفظ بياناتك"),
        content: Text("الآن قم بالتحويل وضع الرمز $generatedCode في ملاحظة الحوالة. سنقوم بتفعيل حسابك فور وصولها."),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("فهمت"))],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("طلب اشتراك VIP")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (!isCodeGenerated) ...[
              TextField(controller: nController, decoration: const InputDecoration(labelText: "اسمك الكامل (المشترك)")),
              const SizedBox(height: 10),
              TextField(controller: pController, decoration: const InputDecoration(labelText: "رقم هاتفك للتواصل"), keyboardType: TextInputType.phone),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _generateReferenceCode, child: const Text("توليد رمز التحقق الخاص بي")),
            ] else ...[
              const Text("بيانات اشتراكك المحفوظة:", style: TextStyle(fontWeight: FontWeight.bold)),
              ListTile(title: const Text("الاسم"), subtitle: Text(nController.text)),
              ListTile(title: const Text("الرمز العشوائي"), subtitle: Text(generatedCode, style: const TextStyle(fontSize: 24, color: Colors.red, fontWeight: FontWeight.bold))),
              const Divider(),
              const Text("⚠️ انسخ الرمز وضعه في ملاحظة الحوالة الآن", style: TextStyle(color: Colors.red)),
              const SizedBox(height: 20),
              isLoading 
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: _confirmAndSave, child: const Text("تأكيد إرسال طلب التفعيل")),
            ]
          ],
        ),
      ),
    );
  }
}