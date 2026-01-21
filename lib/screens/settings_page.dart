import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final Box box = Hive.box('tajarti_royal_v1');
  late TextEditingController nameC;
  late TextEditingController phoneC;
  bool _fingerprint = false;

  @override
  void initState() {
    super.initState();
    nameC = TextEditingController(text: box.get('shop_name', defaultValue: ''));
    phoneC = TextEditingController(text: box.get('shop_phone', defaultValue: ''));
    _fingerprint = box.get('fingerprint_enabled', defaultValue: false);
  }

  void _save() {
    box.put('shop_name', nameC.text);
    box.put('shop_phone', phoneC.text);
    box.put('fingerprint_enabled', _fingerprint);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حفظ الإعدادات")));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("الإعدادات"), backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(controller: nameC, decoration: const InputDecoration(labelText: "اسم المتجر", border: OutlineInputBorder(), prefixIcon: Icon(Icons.store))),
          const SizedBox(height: 15),
          TextField(controller: phoneC, decoration: const InputDecoration(labelText: "رقم الهاتف", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone))),
          const Divider(height: 40),
          SwitchListTile(
            title: const Text("تفعيل البصمة"),
            value: _fingerprint,
            activeColor: const Color(0xFF1565C0),
            onChanged: (val) => setState(() => _fingerprint = val),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, padding: const EdgeInsets.all(15)),
            onPressed: _save,
            child: const Text("حفظ", style: TextStyle(fontSize: 18)),
          )
        ],
      ),
    );
  }
}