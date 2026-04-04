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

    await showDialog(
      context: context,
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
                    // ✅ تم التعديل إلى مثال تجاري احترافي
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
              onPressed: () => Navigator.pop(ctx), 
              child: const Text("إلغاء")
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                if (nameCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
                  List<dynamic> currentProducts = List.from(_products);
                  currentProducts.add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'name': nameCtrl.text.trim(),
                    'price': double.parse(priceCtrl.text.trim()),
                    'image': base64Image,
                  });
                  
                  box.put('pos_products', currentProducts);
                  setState(() {});
                  Navigator.pop(ctx);
                }
              },
              child: const Text("حفظ", style: TextStyle(color: Colors.white)),
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
                        // ✅ تم تغيير الأيقونة لتناسب البضائع والتجارة
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