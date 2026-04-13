import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // لتشغيل ميزة النسخ للحافظة
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({super.key});

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  final Box box = Hive.box('tajarti_royal_v1');

  // ✅ بيانات حساباتك الحقيقية في المحافظ اليمنية (عدل الأرقام لأرقامك الفعلية)
  final Map<String, String> myAccounts = {
    "الكريمي": "123456789",
    "شلن (Shilin)": "77XXXXXXX",
    "جيب (Jeeb)": "71XXXXXXX",
    "جوالي (Jawaly)": "70XXXXXXX",
    "عدن كاش": "73XXXXXXX",
  };

  // ✅ ألوان الهوية الخاصة بكل محفظة لزيادة الاحترافية
  final Map<String, Color> walletColors = {
    "الكريمي": const Color(0xFF005CAB),
    "شلن (Shilin)": const Color(0xFF00B4D8),
    "جيب (Jeeb)": const Color(0xFF6A0DAD),
    "جوالي (Jawaly)": const Color(0xFFE63946),
    "عدن كاش": const Color(0xFFFB8C00),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("ترقية الحساب والاشتراكات 💎", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0D256C),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderHeader(),
            const SizedBox(height: 20),
            const Text("اختر الباقة المناسبة لك:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            // باقات الرسائل
            _buildPackageCard(
              title: "باقة 100 رسالة إشعار",
              price: "2,500 ريال",
              features: ["إرسال تقارير ديون تلقائية", "إشعارات سداد فورية", "رصيد لا تنتهي صلاحيته"],
              icon: Icons.message,
              color: Colors.blue,
              onTap: () => _showPaymentDialog("باقة 100 رسالة", 2500),
            ),
            
            _buildPackageCard(
              title: "النسخة الاحترافية (VIP)",
              price: "5,000 ريال / شهرياً",
              features: ["نسخ سحابي تلقائي", "إدارة غير محدودة للموردين", "تقارير أرباح متقدمة", "إزالة الإعلانات"],
              icon: Icons.star,
              color: Colors.amber[800]!,
              onTap: () => _showPaymentDialog("النسخة الاحترافية - شهر", 5000),
            ),

            const SizedBox(height: 30),
            _buildCurrentStatus(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0D256C), Color(0xFF1565C0)]),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
        ]
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome, color: Colors.amber, size: 40),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("طوّر أعمالك مع تجارتي برو", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text("احصل على ميزات حصرية ونظام إشعارات متطور", style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard({required String title, required String price, required List<String> features, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            trailing: Text(price, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(children: features.map((f) => Row(children: [const Icon(Icons.check_circle, size: 16, color: Colors.green), const SizedBox(width: 8), Text(f, style: const TextStyle(color: Colors.grey, fontSize: 13))])).toList()),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color, 
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                onPressed: onTap,
                child: const Text("طلب تفعيل الآن", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showPaymentDialog(String packageName, double price) {
    final transIdCtrl = TextEditingController();
    String selectedWallet = myAccounts.keys.first;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text("تفعيل $packageName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("يرجى تحويل مبلغ ($price ريال) إلى أحد حساباتنا:", style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 15),
                  
                  // عرض قائمة المحافظ
                  ...myAccounts.entries.map((entry) => _buildPaymentTile(
                    entry.key, 
                    entry.value, 
                    walletColors[entry.key] ?? Colors.grey
                  )),
                  
                  const Divider(height: 30),
                  
                  DropdownButtonFormField<String>(
                    value: selectedWallet,
                    decoration: const InputDecoration(labelText: "المحفظة التي استخدمتها للتحويل", border: OutlineInputBorder()),
                    items: myAccounts.keys.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                    onChanged: (v) => setModalState(() => selectedWallet = v!),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: transIdCtrl,
                    decoration: const InputDecoration(
                      labelText: "أدخل رقم العملية / الإشعار",
                      hintText: "مثال: 12345678",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.confirmation_number_outlined)
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: isSubmitting ? null : () => Navigator.pop(ctx), child: const Text("إلغاء", style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D256C),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                onPressed: isSubmitting ? null : () async {
                  if (transIdCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الرجاء إدخال رقم العملية للتأكد"), backgroundColor: Colors.red));
                    return;
                  }
                  
                  setModalState(() => isSubmitting = true);
                  
                  try {
                    String uid = box.get('user_uid') ?? box.get('device_id') ?? 'unknown';
                    
                    await FirebaseFirestore.instance.collection('subscription_requests').add({
                      'user_uid': uid,
                      'shop_name': box.get('shop_name', defaultValue: 'متجر جديد'),
                      'package': packageName,
                      'price': price,
                      'wallet_used': selectedWallet,
                      'transaction_id': transIdCtrl.text.trim(),
                      'status': 'pending',
                      'timestamp': FieldValue.serverTimestamp(),
                    });

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      _showSuccessDialog();
                    }
                  } catch (e) {
                    setModalState(() => isSubmitting = false);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("فشل الاتصال: $e"), backgroundColor: Colors.red));
                    }
                  }
                },
                child: isSubmitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("تأكيد وإرسال", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ],
          );
        }
      ),
    );
  }

  Widget _buildPaymentTile(String name, String account, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2))
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 14, backgroundColor: color, child: const Icon(Icons.account_balance_wallet, size: 14, color: Colors.white)),
          const SizedBox(width: 10),
          Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
          const Spacer(),
          SelectableText(account, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
          const SizedBox(width: 5),
          IconButton(
            icon: const Icon(Icons.copy, size: 18, color: Colors.grey),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: account));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم نسخ رقم حساب $name"), duration: const Duration(seconds: 2), backgroundColor: Colors.green));
            },
          )
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 10), Text("تم إرسال الطلب ✅")]),
        content: const Text("سيقوم فريق الإدارة بمراجعة الحوالة وتفعيل الباقة لك قريباً. شكراً لثقتك!"),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D256C)),
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("حسناً", style: TextStyle(color: Colors.white))
          )
        ],
      ),
    );
  }

  Widget _buildCurrentStatus() {
    int sms = box.get('sms_balance', defaultValue: 0);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[300]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("حالة حسابك الحالية:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("رصيد الرسائل المتبقي:", style: TextStyle(fontSize: 15)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Text("$sms رسالة", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 15)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}