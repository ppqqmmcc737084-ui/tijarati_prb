import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ضرورية لزر النسخ
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({super.key});

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  final Box box = Hive.box('tajarti_royal_v1');
  bool isLoading = false;
  String generatedCode = "";

  // رقم حسابك أو محفظتك (قم بتغييره برقمك الحقيقي)
  final String myWalletNumber = "77XXXXXXX"; 

  @override
  void initState() {
    super.initState();
    _generateReferenceCode();
  }

  // 🎲 دالة توليد كود عشوائي قوي (مثل: PAY-A7B2X)
  void _generateReferenceCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    String randomStr = String.fromCharCodes(Iterable.generate(5, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    setState(() {
      generatedCode = "PAY-$randomStr";
    });
  }

  // 📋 دالة لنسخ النصوص
  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    ));
  }

  // 🚀 دالة إرسال الطلب للفايربيس
  Future<void> _submitSubscriptionRequest() async {
    setState(() => isLoading = true);
    
    String uid = box.get('user_uid', defaultValue: '');
    String shopName = box.get('shop_name', defaultValue: 'متجر غير معروف');

    if (uid.isEmpty || uid.startsWith('local_')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("يجب تسجيل الدخول أولاً لطلب الاشتراك!"),
        backgroundColor: Colors.red,
      ));
      setState(() => isLoading = false);
      return;
    }

    try {
      // حفظ الطلب في جدول خاص بالطلبات المعلقة في الفايربيس
      await FirebaseFirestore.instance.collection('subscription_requests').doc(uid).set({
        'uid': uid,
        'shop_name': shopName,
        'reference_code': generatedCode,
        'status': 'pending', // pending = قيد المراجعة
        'request_date': DateTime.now().toString(),
      });

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("حدث خطأ أثناء إرسال الطلب. تأكد من الإنترنت."),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: const Text(
          "تم استلام طلبك بنجاح!\n\nسنقوم بمراجعة الحوالة وتفعيل حسابك خلال دقائق. شكراً لثقتك بنا.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, height: 1.5),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D256C)),
              onPressed: () {
                Navigator.pop(ctx); // إغلاق النافذة
                Navigator.pop(context); // العودة للصفحة الرئيسية
              },
              child: const Text("حسناً", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D256C),
        title: const Text("ترقية الحساب (VIP)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 🌟 بطاقة التعليمات الصارمة
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.orange, width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 50),
                  const SizedBox(height: 10),
                  const Text("خطوات التفعيل الدقيقة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  _buildInstructionRow("1", "قم بنسخ رقم الحساب/المحفظة أدناه."),
                  _buildInstructionRow("2", "انسخ (كود التحقق) الخاص بك."),
                  _buildInstructionRow("3", "اذهب لتطبيق البنك وحول مبلغ (10,000 ريال)."),
                  _buildInstructionRow("4", "⚠️ هام جداً: الصق (كود التحقق) في خانة (الملاحظات) أثناء التحويل في تطبيق البنك.", isWarning: true),
                  _buildInstructionRow("5", "اضغط على زر (أرسلت الحوالة) بالأسفل."),
                ],
              ),
            ),
            
            const SizedBox(height: 25),

            // 💳 بطاقة بيانات التحويل
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("بيانات التحويل", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
                    const Divider(),
                    
                    // رقم الحساب
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("رقم المحفظة (الكريمي/جوالي)"),
                            Text(myWalletNumber, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2, color: Color(0xFF0D256C))),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.blue),
                          onPressed: () => _copyToClipboard(myWalletNumber, "تم نسخ رقم المحفظة"),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),

                    // كود التحقق (السر هنا)
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("كود التحقق (ضعه في ملاحظة الحوالة) :", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                              Text(generatedCode, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 3, color: Colors.red)),
                            ],
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => _copyToClipboard(generatedCode, "تم نسخ الكود! الصقه في ملاحظات الحوالة"), 
                            icon: const Icon(Icons.copy, color: Colors.white, size: 18), 
                            label: const Text("نسخ", style: TextStyle(color: Colors.white))
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // 🚀 زر الإرسال
            isLoading 
              ? const CircularProgressIndicator()
              : SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                    ),
                    onPressed: _submitSubscriptionRequest,
                    child: const Text("أرسلت الحوالة والملاحظة - تفعيل", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                )
          ],
        ),
      ),
    );
  }

  // ويدجت مساعدة لترتيب التعليمات
  Widget _buildInstructionRow(String number, String text, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 12, backgroundColor: isWarning ? Colors.red : const Color(0xFF0D256C), child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 12))),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: isWarning ? Colors.red : Colors.black87, fontWeight: isWarning ? FontWeight.bold : FontWeight.normal))),
        ],
      ),
    );
  }
}