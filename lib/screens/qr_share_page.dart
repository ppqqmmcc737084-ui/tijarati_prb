import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class QrSharePage extends StatefulWidget {
  final String shopName;
  final String clientName;
  final double netBalance;
  final String currency;
  final String clientId;
  final String ownerUid;

  const QrSharePage({
    super.key,
    required this.shopName,
    required this.clientName,
    required this.netBalance,
    required this.currency,
    required this.clientId,
    required this.ownerUid,
  });

  @override
  State<QrSharePage> createState() => _QrSharePageState();
}

class _QrSharePageState extends State<QrSharePage> {
  // ✅ متحكم لالتقاط الشاشة (Screenshot Controller)
  final ScreenshotController screenshotController = ScreenshotController();
  bool isCapturing = false;

  // ✅ الدالة السحرية لالتقاط الكرت ومشاركته كصورة في الواتساب
  void _shareRoyalCard() async {
    setState(() => isCapturing = true); // إخفاء الأزرار مؤقتاً أثناء التصوير
    
    // التقاط الصورة
    final imageBytes = await screenshotController.capture(delay: const Duration(milliseconds: 10));
    
    setState(() => isCapturing = false); // إرجاع الأزرار

    if (imageBytes != null) {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = await File('${directory.path}/royal_card.png').create();
      await imagePath.writeAsBytes(imageBytes);

      // مشاركة الصورة عبر الواتساب أو أي تطبيق آخر
      await Share.shareXFiles(
        [XFile(imagePath.path)], 
        text: "كشف حساب من ${widget.shopName} - العميل: ${widget.clientName}",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // الرابط اللي بينقرأ من الباركود (نقدر نعدله مستقبلاً ليكون رابط دفع)
    String qrData = "المتجر: ${widget.shopName}\nالعميل: ${widget.clientName}\nالمطلوب: ${intl.NumberFormat("#,##0").format(widget.netBalance)} ${widget.currency}";

    return Scaffold(
      backgroundColor: const Color(0xFF0D256C), // خلفية زرقاء ملكية
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('طلب سداد ملكي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              
              // 📸 تغليف الكرت بأداة التقاط الشاشة
              Screenshot(
                controller: screenshotController,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
                    ],
                  ),
                  child: Column(
                    children: [
                      // 🌟 الهيدر الذهبي الفخم
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFFFD700)]), // تدرج ذهبي
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.account_balance, color: Color(0xFF0D256C), size: 40),
                            const SizedBox(height: 5),
                            Text(
                              widget.shopName,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0D256C)),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      Text('إلى العميل المكرم / ${widget.clientName}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                      const SizedBox(height: 10),
                      
                      // 💰 المبلغ الكبير
                      const Text('المبلغ المطلوب سداده', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
                      Text(
                        '${intl.NumberFormat("#,##0").format(widget.netBalance)} ${widget.currency}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: widget.netBalance > 0 ? const Color(0xFFD81B60) : Colors.green,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // 🔲 الباركود الذكي
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFFFD700), width: 3), // إطار ذهبي للباركود
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 180.0,
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0D256C),
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text('امسح الرمز أعلاه لتأكيد السداد', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 20),
                      
                      // الفوتر (تذييل الكرت)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                        ),
                        child: const Center(child: Text('تم الإصدار عبر تطبيق تجارتي برو', style: TextStyle(color: Colors.grey, fontSize: 10))),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              
              // 📤 زر المشاركة (يختفي وقت التقاط الصورة عشان ما يخرب شكل الكرت)
              if (!isCapturing) 
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700), // لون ذهبي
                    foregroundColor: const Color(0xFF0D256C),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: _shareRoyalCard,
                  icon: const Icon(Icons.share, size: 24),
                  label: const Text('مشاركة الكرت عبر واتساب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}