import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

// --- المخازن (قواعد البيانات) ---
List<Map<String, dynamic>> invoicesHistory = []; // سجل الفواتير
List<Map<String, dynamic>> productsList = []; // سجل الأصناف

class CashInvoiceScreen extends StatefulWidget {
  @override
  _CashInvoiceScreenState createState() => _CashInvoiceScreenState();
}

class _CashInvoiceScreenState extends State<CashInvoiceScreen> {
  // البيانات
  List<Map<String, dynamic>> currentItems = [];
  
  TextEditingController? _autocompleteController;
  final TextEditingController priceController = TextEditingController();
  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController shopNameController = TextEditingController(text: "متجر تجارتي");
  final TextEditingController notesController = TextEditingController();
  
  final FocusNode nameFocus = FocusNode();
  final FocusNode priceFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // تحميل السجل
    final String? historyData = prefs.getString('invoices_history');
    if (historyData != null) {
      setState(() {
        invoicesHistory = List<Map<String, dynamic>>.from(json.decode(historyData));
      });
    }

    // تحميل المنتجات
    final String? productsData = prefs.getString('saved_products');
    if (productsData != null) {
      setState(() {
        productsList = List<Map<String, dynamic>>.from(json.decode(productsData));
      });
    }

    // اسم المتجر
    String? savedShop = prefs.getString('shop_name');
    if (savedShop != null) shopNameController.text = savedShop;
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('invoices_history', json.encode(invoicesHistory));
    await prefs.setString('shop_name', shopNameController.text);
  }

  double get totalAmount {
    double total = 0;
    for (var item in currentItems) total += item['price'];
    return total;
  }

  // --- حساب مبيعات اليوم (لوحة القيادة) ---
  double get todaySales {
    DateTime now = DateTime.now();
    String todayStr = intl.DateFormat('yyyy-MM-dd').format(now);
    
    return invoicesHistory.where((inv) {
      // نستخرج التاريخ فقط ونقارنه باليوم
      String invDate = intl.DateFormat('yyyy-MM-dd').format(DateTime.parse(inv['date']));
      return invDate == todayStr;
    }).fold(0, (sum, item) => sum + item['total']);
  }

  int get todayCount {
    DateTime now = DateTime.now();
    String todayStr = intl.DateFormat('yyyy-MM-dd').format(now);
    return invoicesHistory.where((inv) => intl.DateFormat('yyyy-MM-dd').format(DateTime.parse(inv['date'])) == todayStr).length;
  }

  // إضافة صنف (سريع)
  void addItem() {
    String name = _autocompleteController?.text ?? "";
    String price = priceController.text;

    if (name.isNotEmpty && price.isNotEmpty) {
      setState(() {
        currentItems.add({
          'name': name,
          'price': double.tryParse(price) ?? 0,
        });
        _autocompleteController?.clear();
        priceController.clear();
        nameFocus.requestFocus(); // العودة للاسم فوراً
      });
    }
  }

  void _selectProduct(Map<String, dynamic> product) {
    if (_autocompleteController != null) _autocompleteController!.text = product['name'];
    priceController.text = product['price'].toString();
    priceFocus.requestFocus(); 
  }

  void saveInvoiceToHistory() {
    if (currentItems.isEmpty) return;
    setState(() {
      invoicesHistory.insert(0, {
        'customer': customerNameController.text.isEmpty ? "زبون نقدي" : customerNameController.text,
        'date': DateTime.now().toIso8601String(),
        'total': totalAmount,
        'items': List.from(currentItems),
        'shop': shopNameController.text,
        'notes': notesController.text,
      });
      _saveHistory();
      currentItems.clear();
      customerNameController.clear();
      notesController.clear();
      nameFocus.requestFocus();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ تم الحفظ"), backgroundColor: Colors.green));
  }

  // --- دالة استرجاع الفاتورة للتعديل ---
  void _restoreInvoiceForEdit(int index) {
    var inv = invoicesHistory[index];
    setState(() {
      // 1. استرجاع البيانات للشاشة الرئيسية
      customerNameController.text = inv['customer'];
      notesController.text = inv['notes'] ?? "";
      currentItems = List<Map<String, dynamic>>.from(inv['items']);
      
      // 2. حذف الفاتورة القديمة من السجل (لأننا سنحفظها كجديدة بعد التعديل)
      invoicesHistory.removeAt(index);
      _saveHistory();
    });
    Navigator.pop(context); // إغلاق السجل والعودة للكاشير
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✏️ تم استرجاع الفاتورة للتعديل"), backgroundColor: Colors.orange));
  }

  void showInvoicePreview(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => InvoicePreviewDialog(
        shopName: shopNameController.text,
        customerName: customerNameController.text.isEmpty ? "زبون نقدي" : customerNameController.text,
        date: DateTime.now(),
        items: currentItems,
        total: totalAmount,
        notes: notesController.text,
        isSaved: false,
        onSave: () {
          saveInvoiceToHistory();
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("نظام الكاشير", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: Colors.blue[900]), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: Icon(Icons.inventory_2, color: Colors.orange[800], size: 28),
            tooltip: "المخزن",
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (c) => ProductManagerScreen()));
              _loadData();
            },
          ),
          IconButton(
            icon: Icon(Icons.history, color: Colors.blue[900], size: 28),
            tooltip: "السجل",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => HistoryScreen(
              onDelete: (i) { setState(() { invoicesHistory.removeAt(i); _saveHistory(); }); },
              onEdit: _restoreInvoiceForEdit, // تمرير دالة التعديل
            ))),
          )
        ],
      ),
      body: Column(
        children: [
          // --- 🌟 لوحة القيادة (Dashboard) ---
          Container(
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.blue[900]!, Colors.blue[700]!]),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, offset: Offset(0, 4))]
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(children: [
                  Text("مبيعات اليوم", style: TextStyle(color: Colors.blue[100], fontSize: 12)),
                  Text("$todaySales ريال", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ]),
                Container(height: 30, width: 1, color: Colors.white24),
                Column(children: [
                  Text("عدد الفواتير", style: TextStyle(color: Colors.blue[100], fontSize: 12)),
                  Text("$todayCount", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ]),
              ],
            ),
          ),

          // إعدادات الفاتورة
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(children: [
              TextField(controller: shopNameController, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[900]), decoration: InputDecoration(hintText: "اسم المتجر", border: InputBorder.none, contentPadding: EdgeInsets.zero)),
              Divider(height: 1),
              TextField(controller: customerNameController, textAlign: TextAlign.right, decoration: InputDecoration(hintText: "اسم العميل", prefixIcon: Icon(Icons.person, size: 18, color: Colors.blue[900]), filled: true, fillColor: Colors.grey[50], border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(10)), contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 10))),
            ]),
          ),

          // القائمة
          Expanded(
            child: currentItems.isEmpty
                ? Center(child: Opacity(opacity: 0.5, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shopping_cart_outlined, size: 60), Text("جاهز للبيع...")])))
                : ListView.separated(
                    itemCount: currentItems.length,
                    separatorBuilder: (ctx, i) => Divider(height: 1),
                    itemBuilder: (ctx, i) => ListTile(
                      title: Text(currentItems[i]['name'], style: TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text("${currentItems[i]['price']} ريال", style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold)),
                        IconButton(icon: Icon(Icons.close, color: Colors.red[300]), onPressed: () => setState(() => currentItems.removeAt(i))),
                      ]),
                    ),
                  ),
          ),

          // --- الإدخال السريع ---
          Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)]),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Autocomplete<Map<String, dynamic>>(
                        optionsBuilder: (v) {
                          if (v.text == '') return const Iterable.empty();
                          return productsList.where((o) => o['name'].contains(v.text));
                        },
                        displayStringForOption: (o) => o['name'],
                        onSelected: _selectProduct,
                        fieldViewBuilder: (ctx, ctrl, node, _) {
                          _autocompleteController = ctrl;
                          return TextField(controller: ctrl, focusNode: nameFocus, textAlign: TextAlign.right, textInputAction: TextInputAction.next, onSubmitted: (_) => priceFocus.requestFocus(), decoration: InputDecoration(hintText: "صنف", filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), prefixIcon: Icon(Icons.search, color: Colors.grey)));
                        },
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: TextField(controller: priceController, focusNode: priceFocus, keyboardType: TextInputType.number, textAlign: TextAlign.center, textInputAction: TextInputAction.done, onSubmitted: (_) => addItem(), decoration: InputDecoration(hintText: "السعر", filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
                    ),
                    IconButton(icon: Icon(Icons.add_circle, color: Colors.blue[900], size: 40), onPressed: addItem),
                  ],
                ),
                SizedBox(height: 10),
                SizedBox(width: double.infinity, height: 45, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]), icon: Icon(Icons.receipt_long), label: Text("معاينة وإصدار (${totalAmount} ريال)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), onPressed: currentItems.isEmpty ? null : () => showInvoicePreview(context))),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// --- شاشة السجل (مع زر التعديل) ---
class HistoryScreen extends StatelessWidget {
  final Function(int) onDelete;
  final Function(int) onEdit; // دالة التعديل الجديدة

  HistoryScreen({required this.onDelete, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("سجل الفواتير"), backgroundColor: Colors.white, foregroundColor: Colors.blue[900]),
      body: invoicesHistory.isEmpty ? Center(child: Text("السجل فارغ")) : ListView.builder(
        itemCount: invoicesHistory.length,
        itemBuilder: (ctx, i) {
          final inv = invoicesHistory[i];
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(backgroundColor: Colors.blue[50], child: Text("${i+1}", style: TextStyle(color: Colors.blue[900]))),
              title: Text(inv['customer'], style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(intl.DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.parse(inv['date']))),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text("${inv['total']}", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800], fontSize: 14)),
                SizedBox(width: 10),
                // زر التعديل (القلم)
                InkWell(
                  onTap: () => onEdit(i),
                  child: Container(padding: EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(5)), child: Icon(Icons.edit, size: 18, color: Colors.orange[800])),
                ),
                SizedBox(width: 8),
                // زر الحذف
                InkWell(
                  onTap: () => onDelete(i),
                  child: Container(padding: EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(5)), child: Icon(Icons.delete, size: 18, color: Colors.red)),
                ),
              ]),
              onTap: () => showDialog(context: context, builder: (c) => InvoicePreviewDialog(shopName: inv['shop'] ?? "", customerName: inv['customer'], date: DateTime.parse(inv['date']), items: inv['items'], total: inv['total'], notes: inv['notes'] ?? "", isSaved: true, onSave: () {})),
            ),
          );
        },
      ),
    );
  }
}

// --- إدارة المخزن (نفس السابق) ---
class ProductManagerScreen extends StatefulWidget {
  @override
  _ProductManagerScreenState createState() => _ProductManagerScreenState();
}
class _ProductManagerScreenState extends State<ProductManagerScreen> {
  final TextEditingController pName = TextEditingController();
  final TextEditingController pPrice = TextEditingController();
  Future<void> _saveProduct() async {
    if (pName.text.isEmpty || pPrice.text.isEmpty) return;
    setState(() { productsList.add({'name': pName.text, 'price': double.tryParse(pPrice.text) ?? 0}); pName.clear(); pPrice.clear(); });
    final prefs = await SharedPreferences.getInstance(); await prefs.setString('saved_products', json.encode(productsList));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم"), backgroundColor: Colors.green, duration: Duration(milliseconds: 500)));
  }
  Future<void> _deleteProduct(int index) async { setState(() => productsList.removeAt(index)); final prefs = await SharedPreferences.getInstance(); await prefs.setString('saved_products', json.encode(productsList)); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("إدارة المخزن"), backgroundColor: Colors.orange[800]),
      body: Column(children: [
        Container(padding: EdgeInsets.all(15), color: Colors.orange[50], child: Row(children: [Expanded(child: TextField(controller: pName, decoration: InputDecoration(hintText: "اسم الصنف", filled: true, fillColor: Colors.white))), SizedBox(width: 10), Expanded(child: TextField(controller: pPrice, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: "السعر", filled: true, fillColor: Colors.white))), IconButton(icon: Icon(Icons.save, size: 35, color: Colors.orange[800]), onPressed: _saveProduct)])),
        Expanded(child: ListView.separated(itemCount: productsList.length, separatorBuilder: (ctx, i) => Divider(), itemBuilder: (ctx, i) => ListTile(leading: CircleAvatar(child: Text("${i+1}"), backgroundColor: Colors.orange[200]), title: Text(productsList[i]['name']), subtitle: Text("${productsList[i]['price']} ريال"), trailing: IconButton(icon: Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteProduct(i)))))
      ]),
    );
  }
}

// --- المعاينة والطباعة (الأزرق) ---
class InvoicePreviewDialog extends StatelessWidget {
  final String shopName; final String customerName; final String notes; final DateTime date; final List<dynamic> items; final double total; final bool isSaved; final VoidCallback onSave;
  final ScreenshotController screenshotController = ScreenshotController();
  InvoicePreviewDialog({required this.shopName, required this.customerName, required this.date, required this.items, required this.total, required this.notes, required this.isSaved, required this.onSave});
  
  Future<void> printInvoice(BuildContext context) async {
    final font = await PdfGoogleFonts.cairoRegular(); final fontBold = await PdfGoogleFonts.cairoBold(); final doc = pw.Document();
    doc.addPage(pw.Page(pageFormat: PdfPageFormat.roll80, theme: pw.ThemeData.withFont(base: font, bold: fontBold), margin: pw.EdgeInsets.zero, build: (pw.Context context) {
      return pw.Directionality(textDirection: pw.TextDirection.rtl, child: pw.Column(children: [
        pw.Container(color: PdfColor.fromInt(0xFF0D47A1), width: double.infinity, padding: pw.EdgeInsets.all(10), child: pw.Column(children: [pw.Text(shopName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white))])),
        pw.Container(padding: pw.EdgeInsets.all(10), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("التاريخ: ${intl.DateFormat('yyyy-MM-dd').format(date)}", style: pw.TextStyle(fontSize: 9)), pw.Text("العميل: $customerName", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))])),
        pw.Table(columnWidths: {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(2)}, children: [
          pw.TableRow(decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFF0D47A1)), children: [pw.Padding(padding: pw.EdgeInsets.all(5), child: pw.Text("السعر", textAlign: pw.TextAlign.center, style: pw.TextStyle(color: PdfColors.white))), pw.Padding(padding: pw.EdgeInsets.all(5), child: pw.Text("الصنف", textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.white)))]),
          ...items.asMap().entries.map((e) => pw.TableRow(decoration: pw.BoxDecoration(color: e.key % 2 == 0 ? PdfColors.white : PdfColor.fromInt(0xFFE3F2FD)), children: [pw.Padding(padding: pw.EdgeInsets.all(5), child: pw.Text("${e.value['price']}", textAlign: pw.TextAlign.center)), pw.Padding(padding: pw.EdgeInsets.all(5), child: pw.Text(e.value['name'], textAlign: pw.TextAlign.right))])).toList(),
        ]),
        pw.Container(color: PdfColor.fromInt(0xFF0D47A1), width: double.infinity, padding: pw.EdgeInsets.all(10), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("$total ريال", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white)), pw.Text("الإجمالي:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white))])),
        if(notes.isNotEmpty) ...[pw.SizedBox(height:5), pw.Text("ملاحظة: $notes", style: pw.TextStyle(fontSize: 9))],
        pw.SizedBox(height: 5), pw.Text("شكراً لزيارتكم", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600))
      ]));
    }));
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }
  
  Future<void> shareImage() async { final Uint8List? imageBytes = await screenshotController.capture(); if (imageBytes != null) { final directory = await getTemporaryDirectory(); final imagePath = await File('${directory.path}/invoice.png').create(); await imagePath.writeAsBytes(imageBytes); await Share.shareXFiles([XFile(imagePath.path)], text: 'فاتورة'); } }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: EdgeInsets.all(10), color: Colors.blue[900], child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("معاينة", style: TextStyle(color: Colors.white)), IconButton(icon: Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))])),
      Flexible(child: SingleChildScrollView(child: Screenshot(controller: screenshotController, child: Container(color: Colors.white, padding: EdgeInsets.all(20), child: Column(children: [Text(shopName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[900])), Divider(), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("الإجمالي: $total ريال", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[900]))])]))))),
      Container(padding: EdgeInsets.all(10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_btn(Icons.share, "مشاركة", Colors.green, shareImage), _btn(Icons.print, "طباعة", Colors.blue, () => printInvoice(context)), if(!isSaved) ElevatedButton(onPressed: onSave, child: Text("حفظ"))]))
    ]));
  }
  Widget _btn(IconData i, String l, Color c, VoidCallback t) => InkWell(onTap: t, child: Column(children: [Icon(i, color: c), Text(l)]));
}