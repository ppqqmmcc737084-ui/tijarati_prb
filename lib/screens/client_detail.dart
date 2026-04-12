import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart' as intl;
import '../services/pdf_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ استدعاء صفحة الباركود الملكي وشاشة فاتورة المشتريات
import 'qr_share_page.dart';
import 'purchase_invoice_screen.dart'; 

class ClientDetail extends StatefulWidget {
  final String id;
  const ClientDetail({super.key, required this.id});
  @override
  State<ClientDetail> createState() => _ClientDetailState();
}

class _ClientDetailState extends State<ClientDetail> {
  final Box box = Hive.box('tajarti_royal_v1');
  final fmt = intl.NumberFormat("#,##0"); // ✅ تهيئة منسق الأرقام
  Map? client;
  List trans = [];
  bool isLoading = true; 

  // ✅ اكتشاف هل هو مورد أم عميل من خلال الـ ID
  bool get isSupplier => widget.id.startsWith('supplier_');
  
  // ✅ التحقق من تفعيل ميزة كروت الإنترنت
  bool get isWifiEnabled => box.get('is_wifi_cards_enabled', defaultValue: false);

  // ✅ جلب هوية المستخدم لضمان الرفع للغرفة الصحيحة
  String get currentUserUid {
    String? uid = box.get('user_uid');
    if (uid != null && uid.isNotEmpty) return uid;
    return box.get('device_id') ?? 'local_user';
  }

  @override
  void initState() {
    super.initState();
    _loadClientData(); 
  }

  Future<void> _loadClientData() async {
    var localData = box.get(widget.id);
    if (localData != null) {
      setState(() {
        client = localData;
        trans = List.from(client!['trans'] ?? []);
        isLoading = false;
      });
    } else {
      try {
        var doc = await FirebaseFirestore.instance.collection('users').doc(currentUserUid).collection('clients').doc(widget.id).get();
        if (doc.exists) {
          setState(() {
            client = doc.data() as Map<String, dynamic>;
            trans = List.from(client!['trans'] ?? []);
            box.put(widget.id, client!); 
            isLoading = false;
          });
        } else {
          setState(() => isLoading = false);
        }
      } catch (e) {
        setState(() => isLoading = false);
      }
    }
  }

  void _deleteTransaction(int index) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("حذف الحركة"),
      content: const Text("هل تريد حذف هذا القيد؟ لا يمكن التراجع."),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("إلغاء")),
        TextButton(onPressed: () {
          setState(() {
            trans.removeAt(trans.length - 1 - index); 
            client!['trans'] = trans;
            box.put(widget.id, client!);
          });
          Navigator.pop(ctx);

          FirebaseFirestore.instance.collection('users').doc(currentUserUid).collection('clients').doc(widget.id).update({
            'trans': trans
          }).catchError((e) => debugPrint(e.toString()));
          
        }, child: const Text("حذف", style: TextStyle(color: Colors.red))),
      ],
    ));
  }

  void _showWhatsAppOptions(double balance) {
    String phone = client!['phone'] ?? ""; 
    String name = client!['name'] ?? ""; 
    String curr = client!['currency'] ?? ""; 
    String amt = fmt.format(balance.abs()); 
    String shop = box.get('shop_name') ?? "المتجر";
    
    if (phone.isEmpty) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا يوجد رقم هاتف"), backgroundColor: Colors.red)); 
      return; 
    }
    
    if (phone.startsWith('0')) phone = phone.substring(1);
    
    showModalBottomSheet(context: context, builder: (ctx) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text("اختر نوع الرسالة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0D256C))), const SizedBox(height: 20),
      _buildMsgOption(ctx, Icons.sentiment_satisfied_alt, "تذكير لطيف", "مرحباً عزيزي $name،\nحبيت أذكرك بخصوص الرصيد المتبقي ($amt $curr).\nنقدر تعاملك معنا.\n$shop", phone),
      _buildMsgOption(ctx, Icons.warning_amber_rounded, "مطالبة رسمية", "الأخ المحترم $name،\nنرجو منكم التكرم بسداد المبلغ المستحق ($amt $curr) في أقرب وقت.\nشاكرين تعاونكم.\nإدارة $shop", phone),
      _buildMsgOption(ctx, Icons.account_balance, "إرسال الحساب", "كشف حساب مختصر:\nالمبلغ المطلوب: $amt $curr\nيرجى التحويل أو السداد.\n$shop", phone),
    ])));
  }

  Widget _buildMsgOption(BuildContext ctx, IconData icon, String title, String msg, String phone) => ListTile(
    leading: CircleAvatar(backgroundColor: Colors.teal[50], child: Icon(icon, color: Colors.teal)), 
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), 
    subtitle: Text(msg, maxLines: 1, overflow: TextOverflow.ellipsis), 
    onTap: () async { 
      Navigator.pop(ctx); 
      final url = Uri.parse("https://wa.me/967$phone?text=${Uri.encodeComponent(msg)}"); 
      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication); 
    }
  );

  void _printStatement(bool share) { 
    final noteC = TextEditingController(); 
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(share?"مشاركة":"طباعة"), content: TextField(controller: noteC, decoration: const InputDecoration(labelText: "ملاحظة")), actions: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: isSupplier ? const Color(0xFF8E0E00) : const Color(0xFF0D256C), foregroundColor: Colors.white), onPressed: () { Navigator.pop(ctx); PdfService.generateStatement(client!, trans, noteC.text); }, child: const Text("تأكيد"))])); 
  }

  void _addTrans(String type) { 
    final noteC=TextEditingController(); 
    final priceC=TextEditingController(); 
    int quantity=1; 
    double unitPrice=0; 
    
    bool isSaving = false;

    showDialog(context: context, barrierDismissible: false, builder: (ctx)=>StatefulBuilder(builder: (context, setDialogState){ 
      double currentTotal=type=='out'?(quantity*unitPrice):0; 
      
      // ✅ نصوص ذكية تعتمد على (هل هو مورد أو عميل)
      String titleText = type == 'out' 
          ? (isSupplier ? "قيد مشتريات 📦" : "قيد دين") 
          : (isSupplier ? "سداد للمورد 💸" : "قيد سداد");

      return AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: Row(children: [Icon(type=='out'?Icons.remove_circle:Icons.add_circle, color: type=='out'?Colors.red:Colors.green), const SizedBox(width: 10), Text(titleText)]), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: noteC, decoration: InputDecoration(labelText: isSupplier && type=='out' ? "رقم الفاتورة أو الصنف" : "البيان", prefixIcon: const Icon(Icons.description))), const SizedBox(height: 15), if(type=='out')...[Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("العدد:", style: TextStyle(fontWeight: FontWeight.bold)), Row(children: [IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: (){if(quantity>1)setDialogState(()=>quantity--);}), Text("$quantity", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: ()=>setDialogState(()=>quantity++))])])), const SizedBox(height: 10), TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "السعر", prefixIcon: Icon(Icons.attach_money)), onChanged: (val)=>setDialogState(()=>unitPrice=double.tryParse(val)??0)), const Divider(height: 30), Text("الإجمالي: ${currentTotal.toStringAsFixed(0)}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isSupplier ? const Color(0xFF8E0E00) : const Color(0xFF0D256C)))]else...[TextField(controller: priceC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "المبلغ", prefixIcon: Icon(Icons.money)))]])), 
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: isSupplier ? const Color(0xFF8E0E00) : const Color(0xFF0D256C), foregroundColor: Colors.white), 
          onPressed: isSaving ? null : () async { 
            double finalAmount=type=='out'?(quantity*unitPrice):(double.tryParse(priceC.text)??0); 
            if(finalAmount>0){ 
              setDialogState(() => isSaving = true);
              
              var newTrans = {
                'type':type, 
                'amt':finalAmount, 
                'qty':type=='out'?quantity:null, 
                'note':noteC.text.isEmpty?"بدون بيان":noteC.text, 
                'date':DateTime.now().toString()
              };

              trans.add(newTrans); 
              client!['trans']=trans; 
              await box.put(widget.id, client!); 
              setState((){}); 
              
              FirebaseFirestore.instance.collection('users').doc(currentUserUid).collection('clients').doc(widget.id).update({
                'trans': trans
              }).catchError((e) => debugPrint(e.toString()));
              
              await Future.delayed(const Duration(milliseconds: 300));
              if (ctx.mounted) Navigator.pop(ctx); 
            } 
          }, 
          child: isSaving 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("حفظ")
        )
      ]); 
    })); 
  }

  // 🌟 نافذة توزيع الكروت الاحترافية (لصاحب الشبكة/الموزع) 🌟
  void _showWifiDistributionDialog() {
    List packages = box.get('wifi_packages', defaultValue: []);
    if (packages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الرجاء إضافة فئات الكروت أولاً من إدارة الباقات!"), backgroundColor: Colors.orange));
      return;
    }

    Map? selectedPkg = packages.first;
    final qtyCtrl = TextEditingController(text: "50");
    final paidCtrl = TextEditingController(text: "0");
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          double sellPrice = double.tryParse(selectedPkg!['sellPrice'].toString()) ?? 0;
          int qty = int.tryParse(qtyCtrl.text) ?? 0;
          double total = qty * sellPrice;
          double paid = double.tryParse(paidCtrl.text) ?? 0;
          double debt = total - paid; // المتبقي دين على البقالة

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(children: [Icon(Icons.wifi, color: Colors.indigo), SizedBox(width: 10), Text("تسليم كروت لبقالة", style: TextStyle(fontWeight: FontWeight.bold))]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Map>(
                    value: selectedPkg,
                    decoration: const InputDecoration(labelText: "اختر الفئة الموزعة", prefixIcon: Icon(Icons.style, color: Colors.grey)),
                    items: packages.map((p) => DropdownMenuItem<Map>(value: p as Map, child: Text("${p['name']} (سعر: ${p['sellPrice']})"))).toList(),
                    onChanged: (val) => setModalState(() => selectedPkg = val),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: qtyCtrl, 
                    keyboardType: TextInputType.number, 
                    decoration: const InputDecoration(labelText: "الكمية المُسلّمة (عدد الكروت)", prefixIcon: Icon(Icons.numbers, color: Colors.blue)), 
                    onChanged: (v) => setModalState(() {})
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: paidCtrl, 
                    keyboardType: TextInputType.number, 
                    decoration: const InputDecoration(labelText: "المبلغ المدفوع كاش (اتركه 0 إذا كان آجل)", prefixIcon: Icon(Icons.money, color: Colors.green)), 
                    onChanged: (v) => setModalState(() {})
                  ),
                  const Divider(height: 30, thickness: 2),
                  _buildSummaryRow("الإجمالي المطلوب:", "${fmt.format(total)} ر.ي", Colors.black87),
                  _buildSummaryRow("المتبقي (آجل/دين):", "${fmt.format(debt)} ر.ي", debt > 0 ? Colors.red[700]! : Colors.green[700]!),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text("إلغاء", style: TextStyle(color: Colors.grey))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: isSaving ? null : () async {
                  if (qty <= 0) return;
                  if (paid > total) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("المبلغ المدفوع لا يمكن أن يكون أكبر من الإجمالي!"), backgroundColor: Colors.red));
                    return;
                  }

                  setModalState(() => isSaving = true);
                  
                  // 1. تسجيل الدين على البقالة (إذا كان هناك متبقي)
                  if (debt > 0) {
                     String note = "استلام $qty كرت فئة ${selectedPkg!['name']} (إجمالي: ${fmt.format(total)} | مدفوع: ${fmt.format(paid)})";
                     var newTrans = {
                       'type': 'out', 
                       'amt': debt, 
                       'qty': qty,
                       'note': note, 
                       'date': DateTime.now().toString(), 
                       'is_wifi': true, 
                       'pkg_id': selectedPkg!['id']
                     };
                     
                     trans.add(newTrans);
                     client!['trans'] = trans;
                     await box.put(widget.id, client!);
                     
                     FirebaseFirestore.instance.collection('users').doc(currentUserUid).collection('clients').doc(widget.id).update({
                       'trans': trans
                     }).catchError((e) => debugPrint(e.toString()));
                  }

                  // 2. إذا دفع كاش، نقدر نسجله في الصندوق (مستقبلاً إذا عندك صندوق إيرادات عام)
                  // حالياً نكتفي بخصم الدين.

                  // 3. خصم رصيد SMS (ميزة اشتراكات التطبيق)
                  int currentSms = box.get('sms_balance', defaultValue: 0);
                  if (currentSms > 0) {
                    box.put('sms_balance', currentSms - 1);
                  }

                  // 4. توليد نص كشف الحساب السريع للرسالة
                  String shopName = box.get('shop_name') ?? "الشبكة";
                  String smsBody = "✨ من: $shopName\n👤 إلى: ${client!['name']}\n📦 تم تسليمكم: $qty كرت (${selectedPkg!['name']})\n💰 الإجمالي: ${fmt.format(total)}\n💵 واصل كاش: ${fmt.format(paid)}\n📝 المتبقي ديناً: ${fmt.format(debt)}\n🙏 شكراً لتعاملكم.";
                  
                  await Future.delayed(const Duration(milliseconds: 300));
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    _showSuccessWithSmsOption(smsBody, debt > 0);
                    setState((){});
                  }
                },
                icon: isSaving ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send, color: Colors.white, size: 18),
                label: const Text("حفظ وإرسال إشعار", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ],
          );
        }
      ),
    );
  }

  void _showSuccessWithSmsOption(String msg, bool hasDebt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.check_circle, color: Colors.green, size: 30), SizedBox(width: 10), Text("تم تسجيل الدفعة!")]),
        content: Text("تم حفظ العملية بنجاح${hasDebt ? ' وإضافة الدين على البقالة' : ''}.\n\nهل ترغب في إرسال كشف الحساب فوراً للعميل؟\n\n$msg", style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("تخطي", style: TextStyle(color: Colors.grey))),
          ElevatedButton.icon(
            icon: const Icon(Icons.message, color: Colors.white, size: 18),
            label: const Text("SMS", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () async {
              String phone = client!['phone'] ?? "";
              if (phone.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا يوجد رقم هاتف مسجل!"), backgroundColor: Colors.red)); return; }
              launchUrl(Uri.parse("sms:$phone?body=${Uri.encodeComponent(msg)}"));
              Navigator.pop(ctx);
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.wechat, color: Colors.white, size: 18),
            label: const Text("واتساب", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              String phone = client!['phone'] ?? "";
              if (phone.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا يوجد رقم هاتف مسجل!"), backgroundColor: Colors.red)); return; }
              if (phone.startsWith('0')) phone = phone.substring(1);
              launchUrl(Uri.parse("https://wa.me/967$phone?text=${Uri.encodeComponent(msg)}"));
              Navigator.pop(ctx);
            },
          ),
        ],
      )
    );
  }

  Widget _buildSummaryRow(String label, String val, Color col) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), 
        Text(val, style: TextStyle(fontWeight: FontWeight.bold, color: col, fontSize: 18))
      ]
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (isLoading) return Scaffold(backgroundColor: Colors.white, appBar: AppBar(backgroundColor: isSupplier ? const Color(0xFF8E0E00) : const Color(0xFF0D256C)), body: Center(child: CircularProgressIndicator(color: isSupplier ? const Color(0xFF8E0E00) : const Color(0xFF0D256C))));
    if(client == null) return Scaffold(appBar: AppBar(backgroundColor: isSupplier ? const Color(0xFF8E0E00) : const Color(0xFF0D256C)), body: const Center(child: Text("لم يتم العثور على السجل", style: TextStyle(fontSize: 18))));

    double balance=0; 
    for(var t in trans) {
       // ✅ للموردين: المشتريات (in) تزيد الدين، الدفع (out) ينقص الدين.
       // للعملاء العكس.
       if (isSupplier) {
           balance+=(t['type']=='in'?1:-1)*(double.tryParse(t['amt'].toString())??0);
       } else {
           balance+=(t['type']=='out'?1:-1)*(double.tryParse(t['amt'].toString())??0);
       }
    }
    
    // ✅ الألوان تعتمد على هوية الشخص
    Color primaryColor = isSupplier ? const Color(0xFF8E0E00) : const Color(0xFF0D256C);
    
    return Scaffold(
      backgroundColor: Colors.grey[50], 
      appBar: AppBar(
        backgroundColor: primaryColor, 
        iconTheme: const IconThemeData(color: Colors.white), 
        title: Text(client!['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), 
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code, color: Colors.white), 
            tooltip: 'مشاركة QR Code',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QrSharePage(
                    shopName: box.get('shop_name') ?? "المتجر",
                    clientName: client!['name'] ?? "عميل",
                    netBalance: balance,
                    currency: client!['currency'] ?? "ريال يمني",
                    clientId: widget.id,
                    ownerUid: currentUserUid,
                  ),
                ),
              );
            }
          ),
          IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: ()=>_printStatement(true)), 
          IconButton(icon: const Icon(Icons.print, color: Colors.white), onPressed: ()=>_printStatement(false)), 
          if (!isSupplier) IconButton(icon: const Icon(Icons.wechat, color: Colors.greenAccent), tooltip: 'مراسلة واتساب', onPressed: ()=>_showWhatsAppOptions(balance))
        ]
      ), 
      body: Column(
        children: [
          Container(
            width: double.infinity, 
            padding: const EdgeInsets.symmetric(vertical: 20), 
            decoration: BoxDecoration(
              color: primaryColor, 
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))
            ), 
            child: Column(
              children: [
                Text("الرصيد الحالي", style: TextStyle(color: isSupplier ? Colors.red[100] : Colors.blue[100])), 
                Text(
                  "${fmt.format(balance.abs())} ${client!['currency']}", 
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)
                ), 
                Text(balance>=0 ? (isSupplier ? "دين مستحق له" : "عليه (مدين)") : (isSupplier ? "رصيد لك عنده" : "له (دائن)"), style: const TextStyle(color: Colors.white70))
              ]
            )
          ), 
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(15), 
              itemCount: trans.length, 
              itemBuilder: (ctx, i){ 
                var t=trans[trans.length-1-i]; 
                bool isDebt = t['type']=='out'; 
                bool isWifi = t['is_wifi'] ?? false; // تمييز حركات الكروت
                
                // ✅ تخصيص الأيقونات والألوان حسب المورد أو العميل أو كروت الواي فاي
                IconData iconToShow = isWifi ? Icons.wifi : (isDebt ? (isSupplier ? Icons.shopping_cart : Icons.arrow_upward) : Icons.arrow_downward);
                Color iconColor = isWifi ? Colors.indigo : (isDebt ? Colors.red : Colors.green);
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 10), 
                  child: ListTile(
                    onLongPress: () => _deleteTransaction(i),
                    leading: CircleAvatar(backgroundColor: iconColor.withOpacity(0.1), child: Icon(iconToShow, color: iconColor)), 
                    title: Text(t['note'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), 
                    subtitle: Text(t['qty']!=null?"العدد: ${t['qty']} | ${t['date'].substring(0,10)}":t['date'].substring(0,10)), 
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min, 
                      children: [
                        Text("${fmt.format(t['amt'])}", style: TextStyle(color: iconColor, fontWeight: FontWeight.bold, fontSize: 15)), 
                        IconButton(icon: Icon(Icons.share, size: 20, color: primaryColor), onPressed: ()=>PdfService.shareTransaction(client!, t))
                      ]
                    )
                  )
                ); 
              }
            )
          )
        ]
      ), 
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(15), 
        child: Row(
          children: [
            // 🌟 زر توزيع الكروت الخاص بصاحب الشبكة (يظهر للعملاء فقط إذا الميزة مفعلة)
            if (isWifiEnabled && !isSupplier) ...[
              Expanded(
                child: FloatingActionButton.extended(
                  heroTag: "wifi_dist", 
                  backgroundColor: Colors.indigo, 
                  icon: const Icon(Icons.wifi_tethering, color: Colors.white), 
                  label: const Text("توزيع كروت", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)), 
                  onPressed: _showWifiDistributionDialog 
                )
              ),
              const SizedBox(width: 10),
            ],

            Expanded(
              child: FloatingActionButton.extended(
                heroTag: "b1", 
                backgroundColor: isSupplier ? const Color(0xFF8E0E00) : const Color(0xFFD81B60), 
                icon: Icon(isSupplier ? Icons.shopping_cart : Icons.remove, color: Colors.white), 
                label: Text(isSupplier ? "مشتريات" : "دين", style: const TextStyle(color: Colors.white, fontSize: 12)), 
                onPressed: () {
                  if (isSupplier) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PurchaseInvoiceScreen(
                          supplierId: widget.id,
                          supplierName: client!['name'],
                        ),
                      ),
                    ).then((_) => _loadClientData()); 
                  } else {
                    _addTrans('out'); 
                  }
                }
              )
            ), 
            const SizedBox(width: 10), 
            Expanded(
              child: FloatingActionButton.extended(
                heroTag: "b2", 
                backgroundColor: Colors.green, 
                icon: const Icon(Icons.payment, color: Colors.white), 
                label: Text(isSupplier ? "سداد مورد" : "سداد", style: const TextStyle(color: Colors.white, fontSize: 12)), 
                onPressed: ()=>_addTrans(isSupplier ? 'out' : 'in') 
              )
            )
          ]
        )
      )
    );
  }
}