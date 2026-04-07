import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';

class ManageProductsPage extends StatefulWidget {
  const ManageProductsPage({super.key});

  @override
  State<ManageProductsPage> createState() => _ManageProductsPageState();
}

class _ManageProductsPageState extends State<ManageProductsPage> {
  final Box box = Hive.box('tajarti_royal_v1');

  List<dynamic> get _products => box.get('pos_products', defaultValue: []);

  Future<void> _addProduct() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String? base64Image;
    
    // ✅ 1. أضفنا هذا المتغير للتحكم في قفل الزر وتشغيل التحميل
    bool isSaving = false; 

    await showDialog(
      context: context,
      barrierDismissible: false, // يمنع إغلاق النافذة باللمس خارجها أثناء التحميل
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("إضافة منتج جديد"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    FilePickerResult? result = await FilePicker.platform.pickFiles(
                      type: FileType.image, 
                      withData: true
                    );
                    if (result != null && result.files.first.bytes != null) {
                      setModalState(() {
                        base64Image = base64Encode(result.files.first.bytes!);
                      });
                    }
                  },
                  child: Container(
                    height: 120, 
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[200], 
                      borderRadius: BorderRadius.circular(15), 
                      border: Border.all(color: Colors.grey)
                    ),
                    child: base64Image != null 
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(15), 
                            child: Image.memory(
                              base64Decode(base64Image!), 
                              fit: BoxFit.cover
                            )
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center, 
                            children: [
                              Icon(Icons.add_a_photo, size: 40, color: Colors.grey), 
                              Text("اختر صورة")
                            ]
                          ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: nameCtrl, 
                  decoration: const InputDecoration(
                    labelText: "اسم المنتج (مثال: شاحن لاسلكي)", 
                    border: OutlineInputBorder()
                  )
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: priceCtrl, 
                  keyboardType: TextInputType.number, 
                  decoration: const InputDecoration(
                    labelText: "سعر البيع", 
                    border: OutlineInputBorder()
                  )
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              // ✅ 2. نقفل زر الإلغاء إذا كان جاري الحفظ
              onPressed: isSaving ? null : () => Navigator.pop(ctx), 
              child: const Text("إلغاء")
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              // ✅ 3. نقفل زر الحفظ إذا كان isSaving يساوي صح
              onPressed: isSaving ? null : () async {
                final name = nameCtrl.text.trim();
                final priceText = priceCtrl.text.trim();

                // 🌟 حماية 1: التحقق من أن الحقول غير فارغة مع تنبيه للمستخدم
                if (name.isEmpty || priceText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("الرجاء إدخال اسم وسعر المنتج!", style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
                  );
                  return; // نوقف العملية هنا
                }

                // 🌟 حماية 2: التحقق من أن السعر رقم صحيح (يمنع انهيار التطبيق)
                final price = double.tryParse(priceText);
                if (price == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("السعر غير صحيح، الرجاء إدخال أرقام فقط!", style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
                  );
                  return;
                }

                // ✅ 4. هنا نبدأ التحميل (نحدث شاشة النافذة فقط)
                setModalState(() {
                  isSaving = true;
                });

                try {
                  List<dynamic> currentProducts = List.from(_products);
                  currentProducts.add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'name': name,
                    'price': price,
                    'image': base64Image,
                  });
                  
                  // نعطي تأخير بسيط جداً ربع ثانية عشان يكتمل الأنيميشن حق الدائرة ويمنع ضغطات المستخدم السريعة
                  await Future.delayed(const Duration(milliseconds: 250));
                  await box.put('pos_products', currentProducts);
                  
                  setState(() {}); // تحديث الشاشة الرئيسية بالخلف
                  Navigator.pop(ctx); // إغلاق النافذة
                  
                } catch (e) {
                  // في حال صار خطأ، نوقف التحميل ونفتح الزر من جديد
                  setModalState(() {
                    isSaving = false;
                  });
                }
              },
              // ✅ 5. تغيير شكل الزر إلى دائرة تحميل إذا كان يتم الحفظ
              child: isSaving 
                  ? const SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                    )
                  : const Text("حفظ", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  void _deleteProduct(int index) {
    List<dynamic> currentProducts = List.from(_products);
    currentProducts.removeAt(index);
    box.put('pos_products', currentProducts);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إدارة قائمة المنتجات", style: TextStyle(color: Colors.white)), 
        backgroundColor: const Color(0xFF0D256C), 
        iconTheme: const IconThemeData(color: Colors.white)
      ),
      body: _products.isEmpty
          ? const Center(child: Text("لم تقم بإضافة أي منتجات بعد. اضغط على + للبدء."))
          : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _products.length,
              itemBuilder: (ctx, i) {
                var p = _products[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: p['image'] != null 
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8), 
                            child: Image.memory(
                              base64Decode(p['image']), 
                              width: 50, 
                              height: 50, 
                              fit: BoxFit.cover
                            )
                          )
                        : const Icon(Icons.inventory_2, size: 40, color: Colors.blueGrey),
                    title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      "${p['price']} ريال", 
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red), 
                      onPressed: () => _deleteProduct(i)
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFD81B60), 
        onPressed: _addProduct, 
        child: const Icon(Icons.add, color: Colors.white)
      ),
    );
  }
}