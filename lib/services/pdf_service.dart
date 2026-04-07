import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:hive_flutter/hive_flutter.dart';

class PdfService {
  
  // دالة لتنسيق الأرقام مع فواصل الآلاف
  static String _formatNum(num amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  // --- دالة التفقيط (تحويل الأرقام لنص) ---
  static String _numberToWords(double amount, String currency) {
    int number = amount.toInt();
    if (number == 0) return "صفر $currency";

    List<String> parts = [];
    List<String> units = ["", "واحد", "اثنان", "ثلاثة", "أربعة", "خمسة", "ستة", "سبعة", "ثمانية", "تسعة"];
    List<String> teens = ["عشرة", "أحد عشر", "اثنا عشر", "ثلاثة عشر", "أربعة عشر", "خمسة عشر", "ستة عشر", "سبعة عشر", "ثمانية عشر", "تسعة عشر"];
    List<String> tens = ["", "", "عشرون", "ثلاثون", "أربعون", "خمسون", "ستون", "سبعون", "ثمانون", "تسعون"];
    List<String> hundreds = ["", "مائة", "مائتان", "ثلاثمائة", "أربعمائة", "خمسمائة", "ستمائة", "سبعمائة", "ثمانمائة", "تسعمائة"];
    List<String> thousands = ["", "ألف", "ألفان", "ثلاثة آلاف", "أربعة آلاف", "خمسة آلاف", "ستة آلاف", "سبعة آلاف", "ثمانية آلاف", "تسعة آلاف"];

    if (number >= 1000) {
      int th = number ~/ 1000;
      if (th <= 9) parts.add(thousands[th]); else parts.add("$th ألف");
      number %= 1000;
    }
    if (number >= 100) {
      parts.add(hundreds[number ~/ 100]);
      number %= 100;
    }
    if (number > 0) {
      if (number < 10) parts.add(units[number]);
      else if (number < 20) parts.add(teens[number - 10]);
      else {
        String part = units[number % 10];
        if (part.isNotEmpty) part = "$part و ${tens[number ~/ 10]}";
        else part = tens[number ~/ 10];
        parts.add(part);
      }
    }
    return "${parts.join(" و ")} $currency فقط لا غير";
  }

  // --- 🌟 دالة ترتيب الشعار بشكل فخم ---
  static pw.Widget _buildLogoWidget(pw.MemoryImage? logoImage) {
    if (logoImage == null) return pw.SizedBox();
    return pw.Container(
      margin: const pw.EdgeInsets.only(left: 15),
      height: 65,
      width: 65,
      decoration: pw.BoxDecoration(
        shape: pw.BoxShape.circle, // شعار دائري احترافي
        border: pw.Border.all(color: PdfColors.blue900, width: 2), // إطار أزرق فخم
        image: pw.DecorationImage(image: logoImage, fit: pw.BoxFit.cover)
      ),
    );
  }

  // --- 🧾 كشف الحساب VIP ---
  static Future<void> generateStatement(Map client, List trans, String userNote) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();
    final box = Hive.box('tajarti_royal_v1');
    final shopName = box.get('shop_name') ?? "تجارتي برو";
    final shopPhone = box.get('shop_phone') ?? "";
    
    // ✅ تجهيز الشعار قبل بناء الصفحة لمنع التعليق!
    final customLogo = box.get('custom_logo'); 
    pw.MemoryImage? logoImage;
    if (customLogo != null && customLogo.toString().isNotEmpty) {
      try {
        logoImage = pw.MemoryImage(base64Decode(customLogo));
      } catch (e) {
        // تجاهل الخطأ لو الصورة معطوبة
      }
    }

    List<pw.TableRow> tableRows = [];
    
    tableRows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.blue900),
      children: [
        _buildHeaderCell("البيان"),
        _buildHeaderCell("له (دفعات)"),
        _buildHeaderCell("عليه (سحب)"),
        _buildHeaderCell("الرصيد"),
        _buildHeaderCell("التاريخ"),
      ]
    ));

    double runningBalance = 0;
    double totalCredit = 0;
    double totalDebit = 0;
    bool isEvenRow = false;

    for (var t in trans) {
      double amt = double.tryParse(t['amt'].toString()) ?? 0;
      bool isCredit = t['type'] == 'in';
      if (isCredit) { runningBalance -= amt; totalCredit += amt; } 
      else { runningBalance += amt; totalDebit += amt; }

      PdfColor rowColor = isEvenRow ? PdfColors.grey100 : PdfColors.white;
      isEvenRow = !isEvenRow;

      tableRows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: rowColor, border: const pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
        children: [
          _buildCell(t['note']), 
          _buildCell(isCredit ? _formatNum(amt) : "-", color: PdfColors.green700, isBold: true),
          _buildCell(!isCredit ? _formatNum(amt) : "-", color: PdfColors.red700, isBold: true),
          _buildCell(_formatNum(runningBalance), isBold: true, color: PdfColors.blue900),
          _buildCell(t['date'].toString().substring(0, 10)),
        ]
      ));
    }

    pdf.addPage(
      pw.MultiPage( 
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return [
            pw.Container(
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue900, width: 2))),
              padding: const pw.EdgeInsets.only(bottom: 15),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      _buildLogoWidget(logoImage), // ✅ عرض الشعار الأنيق
                      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                        pw.Text(shopName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                        pw.SizedBox(height: 5),
                        pw.Text("رقم الهاتف: $shopPhone", style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800)),
                      ]),
                    ]
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                    decoration: pw.BoxDecoration(color: PdfColors.blue50, borderRadius: pw.BorderRadius.circular(10), border: pw.Border.all(color: PdfColors.blue900, width: 1.5)),
                    child: pw.Text("كشف حساب", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900))
                  ),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text("التاريخ", style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800)),
                    pw.Text(DateTime.now().toString().substring(0, 10), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  ]),
                ]
              ),
            ),
            pw.SizedBox(height: 20),
            
            pw.Container(
              width: double.infinity, 
              padding: const pw.EdgeInsets.all(15), 
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50, 
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: PdfColors.blue900, width: 1)
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start, // يمين
                children: [
                  pw.Text("العميل: ${client['name']}", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.SizedBox(height: 5),
                  pw.Text("العملة: ${client['currency']}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ]
              )
            ),
            pw.SizedBox(height: 20),
            
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {0: const pw.FlexColumnWidth(2.5), 1: const pw.FlexColumnWidth(1), 2: const pw.FlexColumnWidth(1), 3: const pw.FlexColumnWidth(1.2), 4: const pw.FlexColumnWidth(1.2)},
              children: tableRows,
            ),
            pw.SizedBox(height: 20),

            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: PdfColors.blue900, width: 1.5)
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryBox("إجمالي الدفعات (له)", _formatNum(totalCredit), PdfColors.green800),
                  pw.Container(width: 1, height: 40, color: PdfColors.blue200), // خط فاصل
                  _buildSummaryBox("إجمالي المسحوبات (عليه)", _formatNum(totalDebit), PdfColors.red800),
                  pw.Container(width: 1, height: 40, color: PdfColors.blue200), // خط فاصل
                  _buildSummaryBox("الرصيد النهائي المطلـوب", _formatNum(runningBalance), PdfColors.blue900, isGrandTotal: true),
                ]
              )
            ),
            
            if (userNote.isNotEmpty) ...[
              pw.SizedBox(height: 20), 
              pw.Text("ملاحظة: $userNote", style: const pw.TextStyle(color: PdfColors.grey800))
            ],
            
            pw.SizedBox(height: 40),
            
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("توقيع المحاسب: ........................", style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800)),
                pw.Text("توقيع العميل: ........................", style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800)),
              ]
            ),
            
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Center(child: pw.Text("صُدر بواسطة نظام تجارتي برو", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))),
          ];
        }
      )
    );
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Statement_${client['name']}.pdf');
  }

  // --- 💵 سند دين (أزرق موحد وبدون جملة محرجة) ---
  static Future<void> shareTransaction(Map client, Map t) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();
    final box = Hive.box('tajarti_royal_v1');
    final shopName = box.get('shop_name') ?? "متجرنا";
    
    // ✅ تجهيز الشعار للسند
    final customLogo = box.get('custom_logo'); 
    pw.MemoryImage? logoImage;
    if (customLogo != null && customLogo.toString().isNotEmpty) {
      try {
        logoImage = pw.MemoryImage(base64Decode(customLogo));
      } catch (e) {}
    }
    
    double amount = double.tryParse(t['amt'].toString()) ?? 0;
    
    PdfColor mainColor = PdfColors.blue900;
    String receiptTitle = "سند إثبات دين";

    String currency = client['currency'] ?? "ريال";
    String words = _numberToWords(amount, currency);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5, 
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: mainColor, width: 2),
              borderRadius: pw.BorderRadius.circular(15)
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // رأس السند مع الشعار الأنيق
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        _buildLogoWidget(logoImage),
                        pw.Text(shopName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: mainColor)),
                      ]
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                      decoration: pw.BoxDecoration(color: mainColor, borderRadius: pw.BorderRadius.circular(5)),
                      child: pw.Text(receiptTitle, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white))
                    ),
                  ]
                ),
                pw.SizedBox(height: 10),
                pw.Divider(color: mainColor, thickness: 1.5),
                pw.SizedBox(height: 10),
                
                // المبلغ مع التفقيط
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: mainColor, width: 2),
                          borderRadius: pw.BorderRadius.circular(10)
                        ),
                        child: pw.Text("${_formatNum(amount)} $currency", style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: mainColor)),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(color: PdfColors.blue50, borderRadius: pw.BorderRadius.circular(5)),
                        child: pw.Text("فقط: $words", style: pw.TextStyle(fontSize: 12, color: mainColor), textAlign: pw.TextAlign.center)
                      ),
                    ]
                  )
                ),
                pw.SizedBox(height: 25),
                
                // التفاصيل
                _buildRow("مطلوب من العميل:", client['name']),
                pw.SizedBox(height: 10),
                _buildRow("وذلك عن (البيان):", t['note']), 
                pw.SizedBox(height: 10),
                _buildRow("تاريخ السند:", t['date'].toString().substring(0, 16)),
                
                pw.Spacer(),
                
                // التوقيع والباركود (بدون الجملة المحرجة)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text("توقيع المحاسب", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 20),
                        pw.Text("....................", style: const pw.TextStyle(color: PdfColors.grey)),
                      ]
                    ),
                    pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: "$shopName-$receiptTitle-$amount", width: 50, height: 50, color: mainColor),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text("توقيع العميل (المُقر)", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 20),
                        pw.Text("....................", style: const pw.TextStyle(color: PdfColors.grey)),
                      ]
                    ),
                  ]
                )
              ]
            )
          );
        }
      )
    );
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Debt_Note_${client['name']}.pdf');
  }

  // --- دوال مساعدة لترتيب الكود ---
  static pw.Widget _buildHeaderCell(String text) {
    return pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text(text, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11))));
  }
  
  static pw.Widget _buildCell(String text, {PdfColor color = PdfColors.black, bool isBold = false}) {
    return pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text(text, style: pw.TextStyle(color: color, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 10))));
  }
  
  static pw.Widget _buildRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 14)), 
        pw.SizedBox(width: 10),
        pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14))),
      ]
    );
  }

  static pw.Widget _buildSummaryBox(String title, String amount, PdfColor color, {bool isGrandTotal = false}) {
    return pw.Column(
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: isGrandTotal ? 12 : 10, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Text(amount, style: pw.TextStyle(fontSize: isGrandTotal ? 20 : 16, fontWeight: pw.FontWeight.bold, color: color)),
      ]
    );
  }
}