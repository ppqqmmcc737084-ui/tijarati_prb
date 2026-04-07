import 'dart:convert'; 
import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:file_picker/file_picker.dart'; 

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final Box box = Hive.box('tajarti_royal_v1');
  final LocalAuthentication auth = LocalAuthentication();

  void _pickLogo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true, 
    );

    if (result != null && result.files.first.bytes != null) {
      Uint8List fileBytes = result.files.first.bytes!;
      String base64Image = base64Encode(fileBytes); 
      
      box.put('custom_logo', base64Image);
      
      setState(() {}); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم حفظ الشعار الجديد بنجاح!"), backgroundColor: Colors.green)
        );
      }
    }
  }

  void _changeStoreName(BuildContext context) {
    final TextEditingController nameCtrl = TextEditingController(text: box.get('shop_name', defaultValue: ''));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(children: [Icon(Icons.store, color: Color(0xFF0D256C)), SizedBox(width: 10), Text("اسم المتجر")]),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: "أدخل اسم متجرك (مثال: مؤسسة التقوى)"),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D256C)),
            onPressed: () {
              box.put('shop_name', nameCtrl.text); 
              setState(() {}); 
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ اسم المتجر بنجاح', textAlign: TextAlign.right), backgroundColor: Colors.green));
            },
            child: const Text("حفظ", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // 🌟 الدالة الجديدة: إدارة العملات الديناميكية
  void _showCurrencySettings(BuildContext context) {
    List<String> baseCurrencies = ['ريال يمني', 'ريال سعودي', 'دولار أمريكي'];
    List<String> customCurrencies = List<String>.from(box.get('custom_currencies', defaultValue: []));
    String defaultCurrency = box.get('default_currency', defaultValue: 'ريال يمني');
    TextEditingController newCurrencyCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          List<String> allCurrencies = [...baseCurrencies, ...customCurrencies];
          if (!allCurrencies.contains(defaultCurrency)) defaultCurrency = baseCurrencies.first;

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 15),
                const Center(child: Text("إعدادات العملات 💱", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D256C)))),
                const SizedBox(height: 20),

                // اختيار العملة الافتراضية
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: "العملة الافتراضية (تظهر أولاً في الكروت)",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  ),
                  value: defaultCurrency,
                  items: allCurrencies.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => defaultCurrency = val);
                      box.put('default_currency', val);
                      setState((){}); // لتحديث الشاشة الرئيسية عند الرجوع
                    }
                  },
                ),
                const SizedBox(height: 20),

                // إضافة عملة جديدة
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: newCurrencyCtrl,
                        decoration: InputDecoration(
                          hintText: "إضافة عملة جديدة (مثال: درهم)",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.all(15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: () {
                        String curr = newCurrencyCtrl.text.trim();
                        if (curr.isNotEmpty && !allCurrencies.contains(curr)) {
                          setModalState(() {
                            customCurrencies.add(curr);
                            box.put('custom_currencies', customCurrencies);
                            newCurrencyCtrl.clear();
                          });
                          setState((){});
                        }
                      },
                      child: const Icon(Icons.add, color: Colors.white),
                    )
                  ],
                ),
                const SizedBox(height: 15),

                // قائمة العملات المضافة وحذفها
                if (customCurrencies.isNotEmpty) ...[
                  const Text("العملات المضافة يدوياً:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: customCurrencies.map((curr) => Chip(
                      label: Text(curr, style: const TextStyle(color: Colors.white)),
                      backgroundColor: const Color(0xFF455A64),
                      deleteIcon: const Icon(Icons.close, size: 18, color: Colors.white70),
                      onDeleted: () {
                        setModalState(() {
                          customCurrencies.remove(curr);
                          box.put('custom_currencies', customCurrencies);
                          // إذا حذف العملة الافتراضية، نرجعها لليمني
                          if (defaultCurrency == curr) {
                            defaultCurrency = baseCurrencies.first;
                            box.put('default_currency', defaultCurrency);
                          }
                        });
                        setState((){});
                      },
                    )).toList(),
                  )
                ],
                const SizedBox(height: 20),
              ],
            ),
          );
        }
      )
    );
  }

  void _showSecurityBottomSheet(BuildContext context) {
    bool isPasswordEnabled = box.get('is_password_enabled', defaultValue: false);
    bool isFingerprintEnabled = box.get('is_fingerprint_enabled', defaultValue: false);
    String savedPassword = box.get('app_password', defaultValue: '');
    
    bool obscurePassword = true;
    bool obscureConfirm = true;
    
    final passController = TextEditingController(text: savedPassword);
    final confirmController = TextEditingController(text: savedPassword);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 15),
                const Text("إعدادات الأمان", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 25),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(15)),
                  child: Row(
                    children: [
                      Switch(value: isPasswordEnabled, activeColor: const Color(0xFF0D256C), onChanged: (val) { setModalState(() { isPasswordEnabled = val; if (!val) { isFingerprintEnabled = false; } }); }),
                      const Spacer(),
                      const Text("تمكين كلمة المرور", style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Icon(Icons.lock_outline, color: Colors.grey[600]),
                      const SizedBox(width: 10),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(15)),
                  child: Row(
                    children: [
                      Switch(
                        value: isFingerprintEnabled,
                        activeColor: const Color(0xFF0D256C),
                        onChanged: (val) async {
                          if (val && !isPasswordEnabled) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب تفعيل كلمة المرور أولاً', textAlign: TextAlign.right), backgroundColor: Colors.orange)); return; }
                          if (val) {
                            try {
                              bool canAuthenticate = await auth.canCheckBiometrics || await auth.isDeviceSupported();
                              if (!canAuthenticate) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جهازك لا يدعم البصمة', textAlign: TextAlign.right), backgroundColor: Colors.red)); return; }
                            } catch (e) { print(e); return; }
                          }
                          setModalState(() => isFingerprintEnabled = val);
                        },
                      ),
                      const Spacer(),
                      const Text("تمكين البصمة", style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Icon(Icons.fingerprint, color: Colors.grey[600]),
                      const SizedBox(width: 10),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                if (isPasswordEnabled) ...[
                  TextField(controller: passController, obscureText: obscurePassword, textAlign: TextAlign.right, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: "كلمة المرور (أرقام فقط)", prefixIcon: IconButton(icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: () => setModalState(() => obscurePassword = !obscurePassword)), suffixIcon: Icon(Icons.lock_outline, color: Colors.grey[400]), contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF0D256C))))),
                  const SizedBox(height: 15),
                  TextField(controller: confirmController, obscureText: obscureConfirm, textAlign: TextAlign.right, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: "تأكيد كلمة المرور", prefixIcon: IconButton(icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm)), suffixIcon: Icon(Icons.lock_outline, color: Colors.grey[400]), contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF0D256C))))),
                  const SizedBox(height: 20),
                ],
                
                SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D256C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    onPressed: () {
                      if (isPasswordEnabled) {
                        if (passController.text.isEmpty || passController.text != confirmController.text) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كلمة المرور غير متطابقة', textAlign: TextAlign.right), backgroundColor: Colors.red)); return; }
                        box.put('app_password', passController.text);
                      }
                      box.put('is_password_enabled', isPasswordEnabled); box.put('is_fingerprint_enabled', isFingerprintEnabled);
                      Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ إعدادات الأمان', textAlign: TextAlign.right), backgroundColor: Colors.green));
                    },
                    child: const Text("حفظ", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? customLogo = box.get('custom_logo'); 

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات', style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF0D256C), centerTitle: true, iconTheme: const IconThemeData(color: Colors.white)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // قسم الشعار المخصص 
          Card(
            elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.image, color: Color(0xFF0D256C), size: 30),
                      SizedBox(width: 15),
                      Text('شعار المتجر (للفواتير)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  GestureDetector(
                    onTap: _pickLogo,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: customLogo != null 
                          ? MemoryImage(base64Decode(customLogo)) 
                          : null,
                      child: customLogo == null 
                          ? const Icon(Icons.add_a_photo, size: 40, color: Colors.grey) 
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: _pickLogo, 
                        icon: const Icon(Icons.edit), 
                        label: const Text("اختيار شعار")
                      ),
                      if (customLogo != null)
                        TextButton.icon(
                          onPressed: () { 
                            box.delete('custom_logo'); 
                            setState(() {}); 
                          },
                          icon: const Icon(Icons.delete, color: Colors.red),
                          label: const Text("حذف الشعار", style: TextStyle(color: Colors.red))
                        ),
                    ],
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // زر بيانات المتجر
          Card(
            elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              leading: const Icon(Icons.store, color: Color(0xFF0D256C), size: 30),
              title: const Text('بيانات المتجر', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(box.get('shop_name') ?? 'لم يتم تعيين اسم المتجر', style: const TextStyle(color: Colors.grey)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _changeStoreName(context),
            ),
          ),
          const SizedBox(height: 10),

          // 🌟 زر إعدادات العملات الجديد
          Card(
            elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              leading: const Icon(Icons.currency_exchange, color: Colors.green, size: 30),
              title: const Text('إعدادات العملات', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('إضافة عملات وتحديد العملة الافتراضية', style: TextStyle(color: Colors.grey)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showCurrencySettings(context),
            ),
          ),
          const SizedBox(height: 10),

          // زر الأمان والبصمة
          Card(
            elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              leading: const Icon(Icons.security, color: Color(0xFF0D256C), size: 30),
              title: const Text('الأمان والبصمة', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('إعداد كلمة المرور وبصمة الدخول'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showSecurityBottomSheet(context),
            ),
          ),
          const SizedBox(height: 10),

          // زر رفع البيانات القديمة للسحابة
          Card(
            elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              leading: const Icon(Icons.cloud_upload, color: Colors.blue, size: 30),
              title: const Text('رفع البيانات للسحابة', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('رفع العملاء والفواتير المحفوظة محلياً'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                String? uid = box.get('user_uid');
                if (uid == null || uid.startsWith('local_')) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب تسجيل الدخول أو إنشاء حساب أولاً!', textAlign: TextAlign.right), backgroundColor: Colors.red));
                  return;
                }
                
                int count = 0;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري الرفع... يرجى الانتظار', textAlign: TextAlign.right), backgroundColor: Colors.blue));
                
                // ✅ تأمين الرفع: نتجاهل إعدادات التطبيق كاملة عشان ما تترفع كأنها "عميل"
                List<String> ignoredKeys = [
                  'user_uid', 'device_id', 'shop_name', 'app_password', 
                  'is_password_enabled', 'is_fingerprint_enabled', 
                  'custom_logo', 'last_cash_invoice_number', 
                  'hide_guest_warning', 'store_unique_prefix', 
                  'pos_products', 'custom_currencies', 'default_currency'
                ];

                for (var key in box.keys) {
                  if (!ignoredKeys.contains(key.toString())) { 
                    var data = box.get(key);
                    if (data is Map) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .collection('clients')
                          .doc(key.toString())
                          .set(Map<String, dynamic>.from(data));
                      count++;
                    }
                  }
                }
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم رفع $count عميل للسحابة بنجاح! 🎉', textAlign: TextAlign.right), backgroundColor: Colors.green));
              },
            ),
          ),
        ],
      ),
    );
  }
}