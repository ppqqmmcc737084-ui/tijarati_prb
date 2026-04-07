import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});
  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final Box box = Hive.box('tajarti_royal_v1');
  List expenses = [];

  // ✅ جلب هوية المستخدم لضمان رفع المصروفات للغرفة الصحيحة
  String get currentUserUid {
    String? uid = box.get('user_uid');
    if (uid != null && uid.isNotEmpty) return uid;
    return box.get('device_id') ?? 'local_user';
  }

  @override
  void initState() {
    super.initState();
    expenses = List.from(box.get('expenses', defaultValue: []));
  }

  // --- 🗑️ ميزة حذف المصروف لو تسجل بالغلط ---
  void _deleteExpense(int index) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 10), Text("حذف منصرف")]),
        content: const Text("هل أنت متأكد من حذف هذا المصروف؟ سيؤثر ذلك على إجمالي حساباتك."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              setState(() {
                expenses.removeAt(expenses.length - 1 - index);
                box.put('expenses', expenses);
              });
              
              // تحديث السحابة في الخلفية
              FirebaseFirestore.instance.collection('users').doc(currentUserUid).set({'expenses': expenses}, SetOptions(merge: true))
                  .catchError((e) => debugPrint(e.toString()));

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم الحذف بنجاح"), backgroundColor: Colors.red));
            }, 
            child: const Text("حذف", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      )
    );
  }

  // --- 💰 ميزة إضافة مصروف مع قفل الحماية ---
  void _addExpense() {
    TextEditingController note = TextEditingController();
    TextEditingController amt = TextEditingController();
    
    bool isSaving = false; // ✅ قفل الزر

    showDialog(
      context: context, 
      barrierDismissible: false, // يمنع إغلاق النافذة بالغلط
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [Icon(Icons.money_off, color: Colors.red), SizedBox(width: 10), Text("تسجيل منصرف")]),
          content: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              TextField(controller: note, decoration: const InputDecoration(labelText: "البيان (مثال: غداء، كهرباء)", prefixIcon: Icon(Icons.edit, color: Colors.grey))),
              const SizedBox(height: 10),
              TextField(controller: amt, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "المبلغ", prefixIcon: Icon(Icons.attach_money, color: Colors.grey))),
            ]
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx), 
              child: const Text("إلغاء", style: TextStyle(color: Colors.grey))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: isSaving ? null : () async {
                double parsedAmt = double.tryParse(amt.text.trim()) ?? 0;
                
                if (parsedAmt > 0) {
                  setDialogState(() => isSaving = true); // 🌟 تشغيل دائرة التحميل والقفل

                  var newExpense = {
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'note': note.text.trim().isEmpty ? "بدون بيان" : note.text.trim(),
                    'amt': parsedAmt,
                    'date': DateTime.now().toString()
                  };

                  // 1. الحفظ المحلي السريع
                  setState(() {
                    expenses.add(newExpense);
                    box.put('expenses', expenses);
                  });

                  // 2. الرفع السحابي بصمت
                  try {
                    await FirebaseFirestore.instance.collection('users').doc(currentUserUid).set({'expenses': expenses}, SetOptions(merge: true));
                  } catch(e) {
                    debugPrint("Firebase Sync Error: $e");
                  }

                  await Future.delayed(const Duration(milliseconds: 300)); // تأخير بسيط للأنيميشن
                  if (ctx.mounted) Navigator.pop(ctx);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الرجاء إدخال مبلغ صحيح!"), backgroundColor: Colors.red));
                }
              }, 
              child: isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("حفظ", style: TextStyle(fontWeight: FontWeight.bold))
            )
          ],
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    double total = expenses.fold(0, (sum, item) => sum + (item['amt'] as double));
    final fmt = intl.NumberFormat("#,##0");

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text("سجل المصروفات", style: TextStyle(fontWeight: FontWeight.bold)), 
          backgroundColor: const Color(0xFF1565C0), 
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Column(
          children: [
            // 🌟 بطاقة الإجمالي الفخمة
            Container(
              padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
              decoration: const BoxDecoration(
                color: Color(0xFF1565C0),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))]
              ),
              width: double.infinity,
              child: Column(
                children: [
                  const Text("إجمالي المصروفات", style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 5),
                  Text(
                    "${fmt.format(total)} ريال", 
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)
                  )
                ]
              ),
            ),
            const SizedBox(height: 10),
            
            // 🌟 قائمة المصروفات
            Expanded(
              child: expenses.isEmpty 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.money_off, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        Text("لا توجد مصروفات مسجلة", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    itemCount: expenses.length,
                    itemBuilder: (ctx, i) {
                      var e = expenses[expenses.length - 1 - i]; // عكس الترتيب (الأحدث فوق)
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: ListTile(
                          onLongPress: () => _deleteExpense(i), // الحذف بالضغطة المطولة
                          leading: CircleAvatar(
                            backgroundColor: Colors.red[50], 
                            child: const Icon(Icons.arrow_outward, color: Colors.red)
                          ),
                          title: Text(e['note'] ?? "بدون بيان", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Text(e['date'].toString().substring(0, 16), style: const TextStyle(fontSize: 12)),
                          trailing: Text(
                            fmt.format(e['amt']), 
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 18)
                          ),
                        ),
                      );
                    },
                  ),
            )
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addExpense, 
          backgroundColor: const Color(0xFFC2185B), // لون مميز للزر
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text("تسجيل منصرف", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}