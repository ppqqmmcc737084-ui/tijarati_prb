import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' as intl;

class WifiPackagesScreen extends StatefulWidget {
  const WifiPackagesScreen({super.key});

  @override
  State<WifiPackagesScreen> createState() => _WifiPackagesScreenState();
}

class _WifiPackagesScreenState extends State<WifiPackagesScreen> {
  final Box box = Hive.box('tajarti_royal_v1');
  final fmt = intl.NumberFormat("#,##0");

  List<dynamic> get _packages => box.get('wifi_packages', defaultValue: []);

  // دالة الإضافة أو التعديل
  Future<void> _addOrEditPackage({int? index}) async {
    Map<String, dynamic>? existingPackage = index != null ? Map<String, dynamic>.from(_packages[index]) : null;

    final nameCtrl = TextEditingController(text: existingPackage?['name'] ?? '');
    final sellPriceCtrl = TextEditingController(text: existingPackage?['sellPrice']?.toString() ?? '');
    final validityCtrl = TextEditingController(text: existingPackage?['validity'] ?? '');

    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.wifi, color: index == null ? Colors.indigo : Colors.orange),
                const SizedBox(width: 10),
                Text(index == null ? "إضافة فئة كروت" : "تعديل الفئة", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: "اسم الفئة (مثال: فئة 100)", prefixIcon: Icon(Icons.label, color: Colors.blueGrey)),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: sellPriceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "سعر البيع للزبون (ريال)", prefixIcon: Icon(Icons.attach_money, color: Colors.green)),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: validityCtrl,
                    decoration: const InputDecoration(labelText: "الوقت (مثال: ساعتين، يوم)", prefixIcon: Icon(Icons.timer, color: Colors.orange)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text("إلغاء", style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D256C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: isSaving ? null : () async {
                  final name = nameCtrl.text.trim();
                  final sellPrice = double.tryParse(sellPriceCtrl.text.trim()) ?? 0;
                  final validity = validityCtrl.text.trim();
                  
                  if (name.isEmpty || sellPrice <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الرجاء إدخال الاسم والسعر بشكل صحيح!"), backgroundColor: Colors.red));
                    return;
                  }

                  setModalState(() => isSaving = true);

                  try {
                    List<dynamic> currentPackages = List.from(_packages);
                    
                    Map<String, dynamic> newPackageData = {
                      'id': existingPackage?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                      'name': name,
                      'sellPrice': sellPrice,
                      'validity': validity.isEmpty ? "غير محدد" : validity,
                    };

                    if (index != null) {
                      currentPackages[index] = newPackageData;
                    } else {
                      currentPackages.add(newPackageData);
                    }
                    
                    await Future.delayed(const Duration(milliseconds: 300));
                    await box.put('wifi_packages', currentPackages);
                    
                    setState(() {}); 
                    Navigator.pop(ctx); 
                    
                  } catch (e) {
                    setModalState(() => isSaving = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("حدث خطأ: $e"), backgroundColor: Colors.red));
                  }
                },
                child: isSaving 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("حفظ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ],
          );
        }
      ),
    );
  }

  // ✅ قائمة الخيارات عند الضغط المطول (تعديل أو حذف)
  void _showOptionsSheet(int index, Map<String, dynamic> pkg) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(pkg['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D256C))),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text("تعديل الفئة"),
              onTap: () {
                Navigator.pop(ctx);
                _addOrEditPackage(index: index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("حذف الفئة"),
              onTap: () {
                Navigator.pop(ctx);
                _deletePackageConfirm(index);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deletePackageConfirm(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: const Text("هل أنت متأكد من حذف هذه الفئة؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          TextButton(
            onPressed: () {
              List<dynamic> currentPackages = List.from(_packages);
              currentPackages.removeAt(index);
              box.put('wifi_packages', currentPackages);
              setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text("حذف", style: TextStyle(color: Colors.red)),
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("فئات كروت الشبكة 📶", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
        backgroundColor: const Color(0xFF0D256C), 
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _packages.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.style, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 15),
                  Text("لم تقم بإضافة فئات الكروت.", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  const SizedBox(height: 5),
                  const Text("اضغط على (+) لإضافة فئة (مثل: فئة 100).", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              )
            )
          : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _packages.length,
              itemBuilder: (ctx, i) {
                var pkg = _packages[i];
                double sellPrice = double.tryParse(pkg['sellPrice']?.toString() ?? '0') ?? 0;

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    // ✅ تم التعديل: الضغط المطول يفتح خيارات التعديل والحذف
                    onLongPress: () => _showOptionsSheet(i, Map<String, dynamic>.from(pkg)),
                    borderRadius: BorderRadius.circular(15),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        children: [
                          Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.wifi, size: 28, color: Colors.indigo),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(pkg['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.timer, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(pkg['validity'], style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text("سعر البيع", style: TextStyle(color: Colors.grey, fontSize: 11)),
                              Text("${fmt.format(sellPrice)} ر.ي", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0D256C), 
        onPressed: () => _addOrEditPackage(), 
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("إضافة فئة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}