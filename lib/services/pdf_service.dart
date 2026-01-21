import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:hive_flutter/hive_flutter.dart';

class PdfService {
  
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

  // --- كشف الحساب ---
  static Future<void> generateStatement(Map client, List trans, String userNote) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();
    final box = Hive.box('tajarti_royal_v1');
    final shopName = box.get('shop_name') ?? "تجارتي برو";
    final shopPhone = box.get('shop_phone') ?? "";

    List<pw.TableRow> tableRows = [];
    
    tableRows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.blue900),
      children: [
        _buildHeaderCell("البيان"),
        _buildHeaderCell("له"),
        _buildHeaderCell("عليه"),
        _buildHeaderCell("الرصيد"),
        _buildHeaderCell("التاريخ"),
      ]
    ));

    double runningBalance = 0;
    double totalCredit = 0;
    double totalDebit = 0;

    for (var t in trans) {
      double amt = double.tryParse(t['amt'].toString()) ?? 0;
      bool isCredit = t['type'] == 'in';
      if (isCredit) { runningBalance -= amt; totalCredit += amt; } 
      else { runningBalance += amt; totalDebit += amt; }

      tableRows.add(pw.TableRow(
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
        children: [
          _buildCell(t['note']), 
          _buildCell(isCredit ? amt.toStringAsFixed(0) : "-", color: PdfColors.blue900, isBold: true),
          _buildCell(!isCredit ? amt.toStringAsFixed(0) : "-", color: PdfColors.red900, isBold: true),
          _buildCell(runningBalance.toStringAsFixed(0), isBold: true),
          _buildCell(t['date'].toString().substring(0, 10)),
        ]
      ));
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Container(
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue900, width: 2))),
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(shopName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.Text("هاتف: $shopPhone", style: const pw.TextStyle(fontSize: 12)),
                    ]),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                      decoration: pw.BoxDecoration(color: PdfColors.blue50, borderRadius: pw.BorderRadius.circular(8), border: pw.Border.all(color: PdfColors.blue900)),
                      child: pw.Text("تجارتي برو", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900))
                    ),
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                      pw.Text("كشف حساب", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                      pw.Text("التاريخ: ${DateTime.now().toString().substring(0, 10)}"),
                    ]),
                  ]
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Container(width: double.infinity, padding: const pw.EdgeInsets.all(8), color: PdfColors.blue50,
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text("العميل: ${client['name']}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text("العملة: ${client['currency']}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ])
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(1), 2: const pw.FlexColumnWidth(1), 3: const pw.FlexColumnWidth(1.2), 4: const pw.FlexColumnWidth(1.2)},
                children: tableRows,
              ),
              pw.Container(
                color: PdfColors.blue100,
                child: pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.blue900, width: 0.5),
                  columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(1), 2: const pw.FlexColumnWidth(1), 3: const pw.FlexColumnWidth(1.2), 4: const pw.FlexColumnWidth(1.2)},
                  children: [
                    pw.TableRow(children: [
                        _buildCell("الإجمالي النهائي", isBold: true),
                        _buildCell(totalCredit.toStringAsFixed(0), color: PdfColors.green900, isBold: true),
                        _buildCell(totalDebit.toStringAsFixed(0), color: PdfColors.red900, isBold: true),
                        _buildCell(runningBalance.toStringAsFixed(0), color: PdfColors.blue900, isBold: true),
                        _buildCell(""),
                    ])
                  ]
                )
              ),
              if (userNote.isNotEmpty) ...[pw.SizedBox(height: 20), pw.Text("ملاحظة: $userNote")],
              pw.Spacer(),
              pw.Divider(),
              pw.Center(child: pw.Text("نظام تجارتي برو", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey))),
            ]
          );
        }
      )
    );
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'statement_${client['name']}.pdf');
  }

  // --- سند القبض (مع التفقيط الكامل) ---
  static Future<void> shareTransaction(Map client, Map t) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();
    final box = Hive.box('tajarti_royal_v1');
    final shopName = box.get('shop_name') ?? "متجرنا";
    
    double amount = double.tryParse(t['amt'].toString()) ?? 0;
    String currency = client['currency'] ?? "ريال";
    String words = _numberToWords(amount, currency);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.teal, width: 3),
              borderRadius: pw.BorderRadius.circular(15)
            ),
            child: pw.Column(
              children: [
                pw.Text(shopName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                pw.Divider(color: PdfColors.teal),
                pw.Text("سند قيد إلكتروني", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 15),
                pw.Text("${amount.toInt()}", style: pw.TextStyle(fontSize: 42, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 5),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(color: PdfColors.teal50, borderRadius: pw.BorderRadius.circular(5)),
                  child: pw.Text(words, style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center)
                ),
                pw.SizedBox(height: 20),
                _buildRow("العميل:", client['name']),
                _buildRow("التاريخ:", t['date'].toString().substring(0, 16)),
                _buildRow("البيان:", t['note']), 
                pw.Spacer(),
                pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: "$shopName-$amount", width: 40, height: 40, color: PdfColors.teal),
              ]
            )
          );
        }
      )
    );
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'receipt.pdf');
  }

  static pw.Widget _buildHeaderCell(String text) {
    return pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text(text, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10))));
  }
  static pw.Widget _buildCell(String text, {PdfColor color = PdfColors.black, bool isBold = false}) {
    return pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text(text, style: pw.TextStyle(color: color, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 9))));
  }
  static pw.Widget _buildRow(String label, String value) {
    return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700)), pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]));
  }
}