import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final fmt = intl.NumberFormat("#,##0");

  // دالة تفعيل الاشتراك (السحر كله هنا)
  Future<void> _approveRequest(String requestId, Map<String, dynamic> requestData) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      String uid = requestData['user_uid'] ?? '';
      String pkg = requestData['package'] ?? '';
      
      int smsToAdd = 0;
      bool setVip = false;

      // تحليل نوع الباقة لمعرفة ماذا نعطي التاجر
      if (pkg.contains('100')) smsToAdd = 100;
      if (pkg.contains('VIP') || pkg.contains('الاحترافية')) setVip = true;

      // 1. تحديث أو إنشاء مجلد التاجر وإضافة الرصيد له
      var userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      
      Map<String, dynamic> updates = {};
      if (smsToAdd > 0) updates['sms_balance'] = FieldValue.increment(smsToAdd);
      if (setVip) updates['is_vip'] = true;

      await userRef.set(updates, SetOptions(merge: true));

      // 2. تحديث حالة الطلب إلى "تمت الموافقة" عشان يختفي من الشاشة
      await FirebaseFirestore.instance.collection('subscription_requests').doc(requestId).update({
        'status': 'approved',
        'approved_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); // إغلاق دائرة التحميل
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ تم تفعيل الباقة للتاجر بنجاح!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ حدث خطأ: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  // دالة رفض الطلب (إذا الحوالة وهمية مثلاً)
  Future<void> _rejectRequest(String requestId) async {
    await FirebaseFirestore.instance.collection('subscription_requests').doc(requestId).update({
      'status': 'rejected',
      'rejected_at': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        title: const Text("لوحة تحكم الإدارة 👑", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1E319D), // لون مميز للإدارة
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // جلب الطلبات اللي حالتها 'pending' (قيد الانتظار) فقط
        stream: FirebaseFirestore.instance
            .collection('subscription_requests')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  const Text("لا توجد طلبات اشتراك جديدة", style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          var requests = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: requests.length,
            itemBuilder: (ctx, i) {
              var doc = requests[i];
              var data = doc.data() as Map<String, dynamic>;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.blue[200]!)),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("🏪 متجر: ${data['shop_name'] ?? 'غير معروف'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(8)),
                            child: const Text("انتظار", style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 12)),
                          )
                        ],
                      ),
                      const Divider(),
                      Text("📦 الباقة المطلوبة: ${data['package']}", style: const TextStyle(fontSize: 15, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text("💳 عبر: ${data['wallet_used']} | المبلغ: ${data['price']} ريال"),
                      const SizedBox(height: 5),
                      SelectableText("🔢 رقم الحوالة: ${data['transaction_id']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              onPressed: () => _approveRequest(doc.id, data),
                              icon: const Icon(Icons.check_circle),
                              label: const Text("تأكيد وتفعيل"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            tooltip: "رفض الطلب",
                            onPressed: () => _rejectRequest(doc.id),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}