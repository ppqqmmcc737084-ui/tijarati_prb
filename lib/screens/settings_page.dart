import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final Box box = Hive.box('tajarti_royal_v1');
  bool _isFingerprintEnabled = false;

  @override
  void initState() {
    super.initState();
    // قراءة حالة البصمة الحالية من الذاكرة
    _isFingerprintEnabled = box.get('fingerprint_enabled', defaultValue: false);
  }

  // دالة تغيير اسم المتجر
  void _changeShopName() {
    final nameC = TextEditingController(text: box.get('shop_name') ?? "تجارتي برو");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("اسم المتجر"),
        content: TextField(
          controller: nameC,
          decoration: const InputDecoration(hintText: "أدخل اسم متجرك الجديد"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
            onPressed: () {
              if (nameC.text.isNotEmpty) {
                box.put('shop_name', nameC.text);
                setState(() {});
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم تغيير اسم المتجر بنجاح!"), backgroundColor: Colors.green));
              }
            },
            child: const Text("حفظ"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("الإعدادات", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // 🔒 إعدادات الأمان
            const Text("الأمان والخصوصية", style: TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: SwitchListTile(
                activeColor: const Color(0xFF1565C0),
                secondary: const Icon(Icons.fingerprint, color: Color(0xFF1565C0), size: 30),
                title: const Text("قفل التطبيق بالبصمة", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("طلب البصمة في كل مرة تفتح فيها التطبيق"),
                value: _isFingerprintEnabled,
                onChanged: (val) {
                  setState(() => _isFingerprintEnabled = val);
                  box.put('fingerprint_enabled', val); // حفظ الحالة في الذاكرة
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(val ? "تم تفعيل القفل بالبصمة 🔒" : "تم إلغاء القفل بالبصمة 🔓"),
                    backgroundColor: val ? Colors.green : Colors.orange,
                  ));
                },
              ),
            ),

            const SizedBox(height: 30),

            // 🏪 إعدادات المتجر
            const Text("إعدادات المتجر", style: TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                leading: const Icon(Icons.store, color: Color(0xFF1565C0), size: 30),
                title: const Text("اسم المتجر", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(box.get('shop_name') ?? "تجارتي برو"),
                trailing: const Icon(Icons.edit, color: Colors.grey),
                onTap: _changeShopName,
              ),
            ),
          ],
        ),
      ),
    );
  }
}