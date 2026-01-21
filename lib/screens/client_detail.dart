import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart' as intl;
import '../services/pdf_service.dart';

class ClientDetail extends StatefulWidget {
  final String id;
  const ClientDetail({super.key, required this.id});
  @override
  State<ClientDetail> createState() => _ClientDetailState();
}

class _ClientDetailState extends State<ClientDetail> {
  final Box box = Hive.box('tajarti_royal_v1');
  Map? client;
  List trans = [];

  @override
  void initState() {
    super.initState();
    client = box.get(widget.id);
    trans = List.from(client!['trans'] ?? []);
  }

  // ✅ دالة حذف حركة دين أو سداد
  void _deleteTransaction(int index) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("حذف الحركة"),
      content: const Text("هل تريد حذف هذا القيد؟ لا يمكن التراجع."),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("إلغاء")),
        TextButton(onPressed: () {
          setState(() {
            trans.removeAt(trans.length - 1 - index); // حذف حسب الترتيب المعكوس
            client!['trans'] = trans;
            box.put(widget.id, client!);
          });
          Navigator.pop(ctx);
        }, child: const Text("حذف", style: TextStyle(color: Colors.red))),
      ],
    ));
  }

  void _showWhatsAppOptions(double balance) {
    String phone = client!['phone'] ?? ""; String name = client!['name'] ?? ""; String curr = client!['currency'] ?? ""; String amt = intl.NumberFormat("#,##0").format(balance.abs()); String shop = box.get('shop_name') ?? "المتجر";
    if (phone.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا يوجد رقم هاتف"))); return; }
    if (phone.startsWith('0')) phone = phone.substring(1);
    showModalBottomSheet(context: context, builder: (ctx) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text("اختر نوع الرسالة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1565C0))), const SizedBox(height: 20),
      _buildMsgOption(ctx, Icons.sentiment_satisfied_alt, "تذكير لطيف", "مرحباً عزيزي $name،\nحبيت أذكرك بخصوص الرصيد المتبقي ($amt $curr).\nنقدر تعاملك معنا.\n$shop", phone),
      _buildMsgOption(ctx, Icons.warning_amber_rounded, "مطالبة رسمية", "الأخ المحترم $name،\nنرجو منكم التكرم بسداد المبلغ المستحق ($amt $curr) في أقرب وقت.\nشاكرين تعاونكم.\nإدارة $shop", phone),
      _buildMsgOption(ctx, Icons.account_balance, "إرسال الحساب", "كشف حساب مختصر:\nالمبلغ المطلوب: $amt $curr\nيرجى التحويل أو السداد.\n$shop", phone),
    ])));
  }

  Widget _buildMsgOption(BuildContext ctx, IconData icon, String title, String msg, String phone) => ListTile(leading: CircleAvatar(backgroundColor: Colors.teal[50], child: Icon(icon, color: Colors.teal)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(msg, maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () async { Navigator.pop(ctx); final url = Uri.parse("https://wa.me/967$phone?text=${Uri.encodeComponent(msg)}"); if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication); });

  void _printStatement(bool share) { final noteC = TextEditingController(); showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(share?"مشاركة":"طباعة"), content: TextField(controller: noteC, decoration: const InputDecoration(labelText: "ملاحظة")), actions: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white), onPressed: () { Navigator.pop(ctx); PdfService.generateStatement(client!, trans, noteC.text); }, child: const Text("تأكيد"))])); }

  void _addTrans(String type) { final noteC=TextEditingController(); final priceC=TextEditingController(); int quantity=1; double unitPrice=0; showDialog(context: context, builder: (ctx)=>StatefulBuilder(builder: (context, setState){ double currentTotal=type=='out'?(quantity*unitPrice):0; return AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: Row(children: [Icon(type=='out'?Icons.remove_circle:Icons.add_circle, color: type=='out'?Colors.red:Colors.green), const SizedBox(width: 10), Text(type=='out'?"قيد دين":"قيد سداد")]), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: noteC, decoration: const InputDecoration(labelText: "البيان", prefixIcon: Icon(Icons.description))), const SizedBox(height: 15), if(type=='out')...[Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("العدد:", style: TextStyle(fontWeight: FontWeight.bold)), Row(children: [IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: (){if(quantity>1)setState(()=>quantity--);}), Text("$quantity", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: ()=>setState(()=>quantity++))])])), const SizedBox(height: 10), TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "السعر", prefixIcon: Icon(Icons.attach_money)), onChanged: (val)=>setState(()=>unitPrice=double.tryParse(val)??0)), const Divider(height: 30), Text("الإجمالي: ${currentTotal.toStringAsFixed(0)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)))]else...[TextField(controller: priceC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "المبلغ", prefixIcon: Icon(Icons.money)))]])), actions: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white), onPressed: (){ double finalAmount=type=='out'?(quantity*unitPrice):(double.tryParse(priceC.text)??0); if(finalAmount>0){ trans.add({'type':type, 'amt':finalAmount, 'qty':type=='out'?quantity:null, 'note':noteC.text.isEmpty?"بدون بيان":noteC.text, 'date':DateTime.now().toString()}); client!['trans']=trans; box.put(widget.id, client!); this.setState((){}); Navigator.pop(ctx); } }, child: const Text("حفظ"))]); })); }

  @override
  Widget build(BuildContext context) {
    if(client==null)return const Scaffold(body: Center(child: Text("خطأ")));
    double balance=0; for(var t in trans) balance+=(t['type']=='out'?1:-1)*(double.tryParse(t['amt'].toString())??0);
    return Scaffold(backgroundColor: Colors.grey[50], appBar: AppBar(backgroundColor: const Color(0xFF1565C0), iconTheme: const IconThemeData(color: Colors.white), title: Text(client!['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), actions: [IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: ()=>_printStatement(true)), IconButton(icon: const Icon(Icons.print, color: Colors.white), onPressed: ()=>_printStatement(false)), IconButton(icon: const Icon(Icons.chat, color: Colors.white), onPressed: ()=>_showWhatsAppOptions(balance))]), body: Column(children: [Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20), decoration: const BoxDecoration(color: Color(0xFF1565C0), borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))), child: Column(children: [Text("الرصيد الحالي", style: TextStyle(color: Colors.blue[100])), Text("${intl.NumberFormat("#,##0").format(balance.abs())} ${client!['currency']}", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)), Text(balance>=0?"عليه (مدين)":"له (دائن)", style: const TextStyle(color: Colors.white70))])), Expanded(child: ListView.builder(padding: const EdgeInsets.all(15), itemCount: trans.length, itemBuilder: (ctx, i){ var t=trans[trans.length-1-i]; bool isDebt=t['type']=='out'; return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
      // ✅ إضافة خاصية الضغط المطول لحذف القيد
      onLongPress: () => _deleteTransaction(i),
      leading: CircleAvatar(backgroundColor: isDebt?Colors.red[50]:Colors.green[50], child: Icon(isDebt?Icons.arrow_upward:Icons.arrow_downward, color: isDebt?Colors.red:Colors.green)), title: Text(t['note'], style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(t['qty']!=null?"العدد: ${t['qty']} | ${t['date'].substring(0,10)}":t['date'].substring(0,10)), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text("${t['amt']}", style: TextStyle(color: isDebt?Colors.red[700]:Colors.green[700], fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.share, size: 20, color: Colors.blue), onPressed: ()=>PdfService.shareTransaction(client!, t))]))); }))]), bottomNavigationBar: Padding(padding: const EdgeInsets.all(20), child: Row(children: [Expanded(child: FloatingActionButton.extended(heroTag: "b1", backgroundColor: const Color(0xFFD32F2F), icon: const Icon(Icons.remove, color: Colors.white), label: const Text("دين", style: TextStyle(color: Colors.white)), onPressed: ()=>_addTrans('out'))), const SizedBox(width: 20), Expanded(child: FloatingActionButton.extended(heroTag: "b2", backgroundColor: const Color(0xFF388E3C), icon: const Icon(Icons.add, color: Colors.white), label: const Text("سداد", style: TextStyle(color: Colors.white)), onPressed: ()=>_addTrans('in')))])));
  }
}