import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart' as intl;
import '../services/pdf_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final fmt = intl.NumberFormat("#,##0"); 
  Map? client;
  List trans = [];
  bool isLoading = true; 

  bool get isSupplier => widget.id.startsWith('supplier_');
  
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا يوجد رقم هاتف مسجل!"), backgroundColor: Colors.red)); 
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

  // ⚡ نافذة تسجيل الدين/السداد (سريعة ومبسطة جداً)
  void _addTrans(String type) { 
    final noteC = TextEditingController(); 
    final priceC = TextEditingController(); 
    bool isSaving = false;

    String titleText = type == 'out' 
        ? (isSupplier ? "قيد مشتريات 📦" : "تسجيل دين جديد 📝") 
        : (isSupplier ? "سداد للمورد 💸" : "قيد سداد 💰");
        
    Color btnColor = isSupplier ? const Color(0xFF8E0E00) : const Color(0xFF0D256C);

    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) { 
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), 
            title: Row(children: [
              Icon(type == 'out' ? Icons.remove_circle : Icons.add_circle, color: type == 'out' ? Colors.red : Colors.green), 
              const SizedBox(width: 10), 
              Text(titleText, style: const TextStyle(fontSize: 18))
            ]), 
            content: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                // ⚡ تركيز على السرعة: حقلين فقط للمستخدم (المبلغ والبيان)
                TextField(
                  controller: priceC, 
                  keyboardType: TextInputType.number, 
                  autofocus: true, // يفتح الكيبورد تلقائياً لسرعة الإدخال
                  decoration: const InputDecoration(labelText: "المبلغ", prefixIcon: Icon(Icons.attach_money), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: noteC, 
                  decoration: InputDecoration(labelText: isSupplier && type=='out' ? "رقم الفاتورة أو البيان" : "البيان (اختياري)", prefixIcon: const Icon(Icons.edit_note), border: const OutlineInputBorder()),
                ), 
              ]
            ), 
            actions: [
              TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text("إلغاء", style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: btnColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)), 
                onPressed: isSaving ? null : () async { 
                  double finalAmount = double.tryParse(priceC.text.trim()) ?? 0; 
                  if(finalAmount > 0){ 
                    setDialogState(() => isSaving = true);
                    
                    String note = noteC.text.trim().isEmpty ? "بدون بيان" : noteC.text.trim();
                    var newTrans = {
                      'type': type, 
                      'amt': finalAmount, 
                      'note': note, 
                      'date': DateTime.now().toString()
                    };

                    trans.add(newTrans); 
                    client!['trans'] = trans; 
                    await box.put(widget.id, client!); 
                    
                    // تحديث صامت للفايربيس لضمان السرعة
                    FirebaseFirestore.instance.collection('users').doc(currentUserUid).collection('clients').doc(widget.id).update({
                      'trans': trans
                    }).catchError((e) => debugPrint(e.toString()));
                    
                    await Future.delayed(const Duration(milliseconds: 200));
                    
                    if (ctx.mounted) {
                      Navigator.pop(ctx); 
                      setState((){}); 
                      
                      // استدعاء رسالة الإشعار
                      if (!isSupplier) { 
                        _askToSendNotification(finalAmount, type, note); 
                      }
                    } 
                  } else {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الرجاء إدخال مبلغ صحيح!"), backgroundColor: Colors.red));
                  }
                }, 
                child: isSaving 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("حفظ", style: TextStyle(fontWeight: FontWeight.bold))
              )
            ]
          ); 
        }
      )
    ); 
  }

  // 🌟 نظام الإشعارات (كما اتفقنا عليه مسبقاً)
  void _askToSendNotification(double amount, String type, String note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(children: [Icon(Icons.mark_email_unread, color: Colors.blue), SizedBox(width: 10), Text("إشعار العميل")]),
        content: const Text("تم الحفظ بنجاح. هل تريد إرسال إشعار تفصيلي للعميل؟ (يخصم 1 رسالة)"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("تخطي", style: TextStyle(color: Colors.grey))),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(ctx);
              _processAndSendMessage(amount, type, note); 
            },
            icon: const Icon(Icons.send, color: Colors.white, size: 18),
            label: const Text("نعم، أرسل", style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );
  }

  void _processAndSendMessage(double amount, String type, String note) async {
    String phone = client!['phone'] ?? "";
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Row(children: [Icon(Icons.error_outline, color: Colors.white), SizedBox(width: 10), Text("العميل ليس لديه رقم هاتف!")]), backgroundColor: Colors.red));
      return;
    }

    int currentSmsBalance = box.get('sms_balance', defaultValue: 0);
    if (currentSmsBalance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Row(children: [Icon(Icons.block, color: Colors.white), SizedBox(width: 10), Text("لا يوجد رصيد رسائل. يرجى الشحن!")]), backgroundColor: Colors.orange));
      return;
    }

    box.put('sms_balance', currentSmsBalance - 1);

    double currentBalance = 0;
    for(var t in trans) {
       currentBalance += (t['type'] == 'out' ? 1 : -1) * (double.tryParse(t['amt'].toString()) ?? 0);
    }

    String shopName = box.get('shop_name') ?? "تجارتي برو";
    String currency = client!['currency'] ?? "ريال";
    String actionType = type == 'out' ? "تسجيل دين جديد" : "سداد دفعة";
    
    String msg = "مرحباً ${client!['name']} 🌷\nتم $actionType:\nالبيان: $note\nالمبلغ: ${fmt.format(amount)} $currency\n------------------\nالرصيد الإجمالي: ${fmt.format(currentBalance.abs())} $currency ${currentBalance >= 0 ? '(عليكم)' : '(لكم)'}\nبواسطة: $shopName";

    HapticFeedback.heavyImpact(); 
    SystemSound.play(SystemSoundType.click); 
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 10), Text("تم! رصيد الرسائل المتبقي: ${currentSmsBalance - 1}")]), backgroundColor: Colors.green));

    if (phone.startsWith('0')) phone = phone.substring(1);
    final url = Uri.parse("https://wa.me/967$phone?text=${Uri.encodeComponent(msg)}"); 
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication); 
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return Scaffold(backgroundColor: Colors.white, appBar: AppBar(backgroundColor: isSupplier ? const Color(0xFF8E0E00) : const Color(0xFF0D256C)), body: Center(child: CircularProgressIndicator(color: isSupplier ? const Color(0xFF8E0E00) : const Color(0xFF0D256C))));
    if(client == null) return Scaffold(appBar: AppBar(backgroundColor: isSupplier ? const Color(0xFF8E0E00) : const Color(0xFF0D256C)), body: const Center(child: Text("لم يتم العثور على السجل", style: TextStyle(fontSize: 18))));

    double balance=0; 
    for(var t in trans) {
       if (isSupplier) {
           balance+=(t['type']=='in'?1:-1)*(double.tryParse(t['amt'].toString())??0);
       } else {
           balance+=(t['type']=='out'?1:-1)*(double.tryParse(t['amt'].toString())??0);
       }
    }
    
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
              Navigator.push(context, MaterialPageRoute(builder: (_) => QrSharePage(shopName: box.get('shop_name') ?? "المتجر", clientName: client!['name'] ?? "عميل", netBalance: balance, currency: client!['currency'] ?? "ريال يمني", clientId: widget.id, ownerUid: currentUserUid)));
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
            decoration: BoxDecoration(color: primaryColor, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))), 
            child: Column(
              children: [
                Text("الرصيد الحالي", style: TextStyle(color: isSupplier ? Colors.red[100] : Colors.blue[100])), 
                Text("${fmt.format(balance.abs())} ${client!['currency']}", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)), 
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
                IconData iconToShow = isDebt ? (isSupplier ? Icons.shopping_cart : Icons.arrow_upward) : Icons.arrow_downward;
                Color iconColor = isDebt ? Colors.red : Colors.green;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 10), 
                  elevation: 1, // خففنا الظل للسرعة
                  child: ListTile(
                    onLongPress: () => _deleteTransaction(i),
                    leading: CircleAvatar(backgroundColor: iconColor.withOpacity(0.1), child: Icon(iconToShow, color: iconColor)), 
                    title: Text(t['note'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), 
                    subtitle: Text(t['date'].substring(0,10)), 
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
            Expanded(
              child: FloatingActionButton.extended(
                heroTag: "b1", 
                backgroundColor: isSupplier ? const Color(0xFF8E0E00) : const Color(0xFFD81B60), 
                icon: Icon(isSupplier ? Icons.shopping_cart : Icons.remove, color: Colors.white), 
                label: Text(isSupplier ? "مشتريات" : "دين", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)), 
                onPressed: () {
                  if (isSupplier) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => PurchaseInvoiceScreen(supplierId: widget.id, supplierName: client!['name']))).then((_) => _loadClientData()); 
                  } else {
                    _addTrans('out'); 
                  }
                }
              )
            ), 
            const SizedBox(width: 15), 
            Expanded(
              child: FloatingActionButton.extended(
                heroTag: "b2", 
                backgroundColor: Colors.green, 
                icon: const Icon(Icons.payment, color: Colors.white), 
                label: Text(isSupplier ? "سداد مورد" : "سداد", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)), 
                onPressed: ()=>_addTrans(isSupplier ? 'out' : 'in') 
              )
            )
          ]
        )
      )
    );
  }
}