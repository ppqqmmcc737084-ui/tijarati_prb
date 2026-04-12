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

  // دالة الإضافة (أو التعديل إذا تم تمرير index)
  Future<void> _addOrEditProduct({int? index}) async {
    Map<String, dynamic>? existingProduct = index != null ? Map<String, dynamic>.from(_products[index]) : null;

    final nameCtrl = TextEditingController(text: existingProduct?['name'] ?? '');
    final priceCtrl = TextEditingController(text: existingProduct?['price']?.toString() ?? '');
    
    // 🌟 الحقول الجديدة للمحاسبة والمخزون
    final costCtrl = TextEditingController(text: existingProduct?['cost']?.toString() ?? '');
    final stockCtrl = TextEditingController(text: existingProduct?['stock']?.toString() ?? '0');
    
    String? base64Image = existingProduct?['image'];
    bool isSaving = false; 

    await showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(index == null ? "إضافة منتج جديد" : "تعديل المنتج", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D256C))),
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
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.inventory)
                  )
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl, 
                        keyboardType: TextInputType.number, 
                        decoration: const InputDecoration(
                          labelText: "سعر البيع", 
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.sell, color: Colors.green)
                        )
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: costCtrl, 
                        keyboardType: TextInputType.number, 
                        decoration: const InputDecoration(
                          labelText: "سعر التكلفة", 
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.money_off, color: Colors.red)
                        )
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: stockCtrl, 
                  keyboardType: TextInputType.number, 
                  decoration: const InputDecoration(
                    labelText: "الكمية المتوفرة (المخزون)", 
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.layers, color: Colors.blue)
                  )
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx), 
              child: const Text("إلغاء", style: TextStyle(color: Colors.grey))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: isSaving ? null : () async {
                final name = nameCtrl.text.trim();
                final priceText = priceCtrl.text.trim();
                final costText = costCtrl.text.trim();
                final stockText = stockCtrl.text.trim();

                if (name.isEmpty || priceText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("الرجاء إدخال اسم وسعر البيع للمنتج!"), backgroundColor: Colors.red),
                  );
                  return; 
                }

                final price = double.tryParse(priceText);
                final cost = double.tryParse(costText) ?? 0.0; // التكلفة افتراضياً صفر إذا لم يُدخلها
                final stock = int.tryParse(stockText) ?? 0; // المخزون افتراضياً صفر

                if (price == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("السعر غير صحيح، الرجاء إدخال أرقام فقط!"), backgroundColor: Colors.red),
                  );
                  return;
                }

                setModalState(() {
                  isSaving = true;
                });

                try {
                  List<dynamic> currentProducts = List.from(_products);
                  
                  Map<String, dynamic> newProductData = {
                    'id': existingProduct?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    'name': name,
                    'price': price,
                    'cost': cost,     // 🌟 التكلفة
                    'stock': stock,   // 🌟 المخزون الحقيقي
                    'image': base64Image,
                  };

                  if (index != null) {
                    currentProducts[index] = newProductData; // تعديل
                  } else {
                    currentProducts.add(newProductData); // إضافة
                  }
                  
                  await Future.delayed(const Duration(milliseconds: 250));
                  await box.put('pos_products', currentProducts);
                  
                  setState(() {}); 
                  Navigator.pop(ctx); 
                  
                } catch (e) {
                  setModalState(() {
                    isSaving = false;
                  });
                }
              },
              child: isSaving 
                  ? const SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                    )
                  : const Text("حفظ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  void _deleteProduct(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("حذف المنتج"),
        content: const Text("هل أنت متأكد من حذف هذا المنتج نهائياً؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          TextButton(
            onPressed: () {
              List<dynamic> currentProducts = List.from(_products);
              currentProducts.removeAt(index);
              box.put('pos_products', currentProducts);
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
        title: const Text("إدارة المنتجات والمخزون", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
        backgroundColor: const Color(0xFF0D256C), 
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _products.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 15),
                  Text("لم تقم بإضافة أي منتجات بعد.", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  const SizedBox(height: 5),
                  const Text("اضغط على الزر (+) للبدء بملء مستودعك", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              )
            )
          : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _products.length,
              itemBuilder: (ctx, i) {
                var p = _products[i];
                
                // جلب القيم الجديدة (بحماية إذا كانت المنتجات القديمة لا تحتوي عليها)
                double cost = double.tryParse(p['cost']?.toString() ?? '0') ?? 0;
                int stock = int.tryParse(p['stock']?.toString() ?? '0') ?? 0;

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: InkWell( // ✅ إضافة InkWell للسماح بتعديل المنتج عند الضغط عليه
                    onTap: () => _addOrEditProduct(index: i),
                    borderRadius: BorderRadius.circular(15),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          // صورة المنتج
                          p['image'] != null 
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10), 
                                  child: Image.memory(
                                    base64Decode(p['image']), 
                                    width: 60, 
                                    height: 60, 
                                    fit: BoxFit.cover
                                  )
                                )
                              : Container(
                                  width: 60, height: 60,
                                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.inventory_2, size: 30, color: Colors.blueGrey),
                                ),
                          
                          const SizedBox(width: 15),
                          
                          // تفاصيل المنتج (الاسم والأسعار)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    Text("البيع: ${p['price']} ر.ي", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                                    const SizedBox(width: 10),
                                    Text("التكلفة: $cost ر.ي", style: TextStyle(color: Colors.red[300], fontSize: 11)),
                                  ],
                                )
                              ],
                            ),
                          ),
                          
                          // المخزون وزر الحذف
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: stock > 5 ? Colors.blue[50] : Colors.red[50], // تحذير إذا المخزون قليل
                                  borderRadius: BorderRadius.circular(10)
                                ),
                                child: Text(
                                  "المخزن: $stock", 
                                  style: TextStyle(color: stock > 5 ? Colors.blue[800] : Colors.red[800], fontWeight: FontWeight.bold, fontSize: 12)
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red), 
                                onPressed: () => _deleteProduct(i),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
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
        backgroundColor: const Color(0xFFD81B60), 
        onPressed: () => _addOrEditProduct(), 
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("إضافة منتج", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}