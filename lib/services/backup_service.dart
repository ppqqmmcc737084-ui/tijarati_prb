import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

class BackupService {
  static Future<void> createBackup(BuildContext context) async {
    try {
      final box = Hive.box('tajarti_royal_v1');
      final path = box.path;
      if (path != null) {
        await Share.shareXFiles([XFile(path)], text: 'نسخة احتياطية - تجارتي برو');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    }
  }

  static Future<void> restoreBackup(BuildContext context, VoidCallback onDone) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        File file = File(result.files.single.path!);
        final appDir = await getApplicationDocumentsDirectory();
        final newPath = "${appDir.path}/tajarti_royal_v1.hive";
        await file.copy(newPath);
        await Hive.box('tajarti_royal_v1').close();
        await Hive.openBox('tajarti_royal_v1');
        onDone(); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم الاسترجاع")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل الاسترجاع")));
    }
  }
}