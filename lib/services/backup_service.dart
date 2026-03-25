import 'package:flutter/material.dart';

class BackupService {
  // ☁️ 1. دالة إنشاء النسخة
  static Future<void> createBackup(BuildContext context) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("النسخ الاحتياطي ☁️"),
        content: const Text("تطبيقك متصل بنظام Firebase السحابي.\n\nجميع بياناتك (العملاء، الديون، المخزون) يتم حفظها تلقائياً وبشكل فوري في سحابتك الآمنة عند توفر الإنترنت.\n\nلا داعي للنسخ اليدوي!"),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("حسناً، شكراً"),
          )
        ],
      ),
    );
  }

  // 🔄 2. دالة استرجاع النسخة (لا حاجة لها حالياً لأن فايربيز يسترجع تلقائياً)
  static Future<void> restoreBackup(BuildContext context, VoidCallback onRestore) async {
    // تم التعطيل لأن المزامنة تتم تلقائياً عبر فايربيز
  }
}