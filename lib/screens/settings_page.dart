import 'dart:convert'; 
import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:file_picker/file_picker.dart'; 
import 'package:blue_thermal_printer/blue_thermal_printer.dart'; // ✅ مكتبة الطابعة
import 'package:flutter/foundation.dart' show kIsWeb; // ✅ لفحص الويب

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final Box box = Hive.box('tajarti_royal_v1');
  final LocalAuthentication auth = LocalAuthentication();
  
  // ✅ متغيرات الطابعة
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  // --- دوال الشعار واسم المتجر (كما هي من كودك الأساسي) ---
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

  // --- دوال العملات والطابعة والأمان (كما هي من كودك الأساسي - تم إخفاؤها هنا لترتيب الرد ولكنها موجودة في الكود الكامل تحت) ---
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
                      setState((){}); 
                    }
                  },
                ),
                const SizedBox(height: 20),

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

  void _showPrinterSettings(BuildContext context) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الطباعة الحرارية غير مدعومة على الويب، استخدم الجوال.", textAlign: TextAlign.right), backgroundColor: Colors.orange));
      return;
    }

    List<BluetoothDevice> devices = [];
    bool isConnected = false;
    bool isScanning = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          void getDevices() async {
            try {
              devices = await bluetooth.getBondedDevices();
              isConnected = await bluetooth.isConnected ?? false;
            } catch (e) {
              debugPrint("Bluetooth Error: $e");
            }
            if (mounted) {
              setModalState(() => isScanning = false);
            }
          }
          if (isScanning) getDevices();

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isConnected ? Icons.print : Icons.print_disabled, color: isConnected ? Colors.green : Colors.red, size: 28),
                    const SizedBox(width: 10),
                    const Text("إعدادات الطابعة الحرارية", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                const Text("ملاحظة: يجب إقران الطابعة بالبلوتوث من إعدادات الجوال أولاً.", style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
                const SizedBox(height: 20),

                if (isScanning)
                  const CircularProgressIndicator()
                else if (devices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text("لم يتم العثور على أجهزة بلوتوث مقترنة.", style: TextStyle(color: Colors.red)),
                  )
                else
                  ...devices.map((device) => Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      leading: const Icon(Icons.bluetooth, color: Colors.blue),
                      title: Text(device.name ?? "جهاز غير معروف"),
                      subtitle: Text(device.address ?? ""),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isConnected ? Colors.grey : Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                        ),
                        onPressed: isConnected ? null : () async {
                          setModalState(() => isScanning = true); 
                          try {
                            await bluetooth.connect(device);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ تم الاتصال بالطابعة بنجاح!"), backgroundColor: Colors.green));
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ فشل الاتصال بالطابعة، تأكد من تشغيلها."), backgroundColor: Colors.red));
                          }
                          getDevices(); 
                        },
                        child: Text(isConnected ? "متصل" : "اتصال", style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  )),
                  
                const SizedBox(height: 15),
                if (isConnected)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                    ),
                    onPressed: () async {
                      await bluetooth.disconnect();
                      setModalState(() => isScanning = true);
                      getDevices();
                    },
                    icon: const Icon(Icons.bluetooth_disabled, color: Colors.white),
                    label: const Text("قطع الاتصال", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
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

  // --- 💡 الدالة السحرية الجديدة (نافذة شحن الباقات) ---
  void _showTopUpDialog() {
    String deviceId = box.get('device_id') ?? 'unknown_device';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("شحن باقة الرسائل 📥", textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF0D256C), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("لشحن رصيد رسائل SMS الخاص بمتجرك، قم بتحويل مبلغ الباقة المطلوبة إلى أحد حساباتنا:", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.5)),
            const SizedBox(height: 15),
            _buildPaymentMethod("كريمي", "123456789", Colors.green),
            _buildPaymentMethod("القطيبي", "987654321", Colors.blue),
            _buildPaymentMethod("شلن (نقطة حاسب)", "M-100-200", Colors.orange),
            const SizedBox(height: 15),
            const Text("بعد التحويل، أرسل صورة الإيصال مع (معرف جهازك) للواتساب لتفعيل الباقة فوراً.", style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
              child: SelectableText("معرف جهازك: $deviceId", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            )
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إغلاق", style: TextStyle(color: Colors.grey)))],
      ),
    );
  }

  // --- دالة مساعدة لتنسيق أرقام الحسابات في النافذة أعلاه ---
  Widget _buildPaymentMethod(String title, String account, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          Text(account, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  // --- دالة مساعدة لترتيب العناوين في صفحة الإعدادات ---
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(right: 10, bottom: 8, top: 15),
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  // ==========================================
  // 🌟 واجهة المستخدم (Build)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    String? customLogo = box.get('custom_logo'); 
    
    // ✅ جلب المتغيرات الجديدة من قاعدة البيانات (أو إعطائها قيم افتراضية)
    int smsBalance = box.get('sms_balance', defaultValue: 0);
    bool isSupplierEnabled = box.get('is_supplier_enabled', defaultValue: false);
    bool isWifiCardsEnabled = box.get('is_wifi_cards_enabled', defaultValue: false);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text('الإعدادات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFF0D256C), centerTitle: true, iconTheme: const IconThemeData(color: Colors.white), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          
          // 🚀 1. قسم الاشتراكات والميزات (جبهة الاستثمار الجديدة)
          _buildSectionTitle("الاشتراكات والميزات الإضافية"),
          Card(
            elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.sms, color: Colors.orange, size: 30),
                  title: const Text('رصيد رسائل SMS', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('المتبقي: $smsBalance رسالة', style: const TextStyle(color: Colors.grey)),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: _showTopUpDialog,
                    child: const Text("شحن الرصيد", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.wifi, color: Colors.blue),
                  title: const Text('نظام كروت الإنترنت (الشبكات)'),
                  subtitle: const Text('إدارة وبيع كروت الواي فاي'),
                  activeColor: const Color(0xFF0D256C),
                  value: isWifiCardsEnabled,
                  onChanged: (val) => setState(() => box.put('is_wifi_cards_enabled', val)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.business_center, color: Colors.indigo),
                  title: const Text('نظام الموردين والمشتريات'),
                  subtitle: const Text('عزل الموردين وإدارة فواتير الشراء'),
                  activeColor: const Color(0xFF0D256C),
                  value: isSupplierEnabled,
                  onChanged: (val) => setState(() => box.put('is_supplier_enabled', val)),
                ),
              ],
            ),
          ),

          // 🏪 2. قسم هوية المتجر (شعار واسم)
          _buildSectionTitle("هوية المتجر"),
          Card(
            elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.store, color: Color(0xFF0D256C), size: 30),
                  title: const Text('بيانات المتجر', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(box.get('shop_name') ?? 'لم يتم تعيين اسم المتجر', style: const TextStyle(color: Colors.grey)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _changeStoreName(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.image, color: Color(0xFF0D256C), size: 30),
                  title: const Text('شعار المتجر', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('للظهور في الفواتير المطبوعة', style: TextStyle(color: Colors.grey)),
                  trailing: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: customLogo != null ? MemoryImage(base64Decode(customLogo)) : null,
                    child: customLogo == null ? const Icon(Icons.add_a_photo, size: 20, color: Colors.grey) : null,
                  ),
                  onTap: _pickLogo,
                ),
              ],
            ),
          ),

          // ⚙️ 3. الأجهزة والعملات
          _buildSectionTitle("الأجهزة والعملات"),
          Card(
            elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.print, color: Colors.blue, size: 30),
                  title: const Text('الطابعة الحرارية', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('ربط طابعة البلوتوث', style: TextStyle(color: Colors.grey)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showPrinterSettings(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.currency_exchange, color: Colors.green, size: 30),
                  title: const Text('إعدادات العملات', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('تحديد العملة الافتراضية وإضافة المزيد', style: TextStyle(color: Colors.grey)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showCurrencySettings(context),
                ),
              ],
            ),
          ),

          // 🔒 4. الأمان والسحابة
          _buildSectionTitle("الأمان والنسخ الاحتياطي"),
          Card(
            elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.security, color: Color(0xFF0D256C), size: 30),
                  title: const Text('الأمان والبصمة', style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showSecurityBottomSheet(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_upload, color: Colors.blue, size: 30),
                  title: const Text('رفع البيانات للسحابة', style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () async {
                    String? uid = box.get('user_uid');
                    if (uid == null || uid.startsWith('local_')) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب تسجيل الدخول أولاً!', textAlign: TextAlign.right), backgroundColor: Colors.red));
                      return;
                    }
                    int count = 0;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري الرفع...', textAlign: TextAlign.right), backgroundColor: Colors.blue));
                    
                    List<String> ignoredKeys = [
                      'user_uid', 'device_id', 'shop_name', 'app_password', 
                      'is_password_enabled', 'is_fingerprint_enabled', 'custom_logo', 
                      'last_cash_invoice_number', 'hide_guest_warning', 'store_unique_prefix', 
                      'pos_products', 'custom_currencies', 'default_currency',
                      'sms_balance', 'is_supplier_enabled', 'is_wifi_cards_enabled' // ✅ حماية المتغيرات الجديدة من الرفع كعملاء
                    ];

                    for (var key in box.keys) {
                      if (!ignoredKeys.contains(key.toString())) { 
                        var data = box.get(key);
                        if (data is Map) {
                          await FirebaseFirestore.instance.collection('users').doc(uid).collection('clients').doc(key.toString()).set(Map<String, dynamic>.from(data));
                          count++;
                        }
                      }
                    }
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم رفع $count عميل للسحابة بنجاح! 🎉', textAlign: TextAlign.right), backgroundColor: Colors.green));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}