import 'package:flutter/material.dart';
import 'dart:async';
import 'auth_screen.dart'; // ✅ تم استيراد شاشة القفل هنا

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // ✅ الانتقال بعد 3 ثوانٍ لشاشة القفل لفحص الأمان
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthScreen()), 
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🌟 كود الشعار بالشكل الجديد 🌟
            ClipRRect(
              borderRadius: BorderRadius.circular(24), 
              child: Image.asset(
                'assets/images/app_icon.png', 
                width: 160, 
                height: 160, 
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 20),
            // اسم التطبيق تحت الشعار
            const Text(
              'تجارتي برو',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D256C), 
              ),
            ),
          ],
        ),
      ),
    );
  }
}