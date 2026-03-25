import 'package:flutter/material.dart';
import 'dart:async';
// ⚠️ ملاحظة: تأكد من تعديل هذا المسار إذا كانت شاشتك الرئيسية في ملف آخر
import '../main.dart'; 

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    
    // 🎬 حركة أنيميشن لظهور الشعار والاسم بنعومة (تستغرق ثانيتين)
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    // ⏱️ الانتظار 3 ثواني ثم الانتقال للشاشة الرئيسية
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          // ⚠️ استبدل HomeScreen() باسم شاشتك الرئيسية أو شاشة البصمة الخاصة بك
        builder: (_) => const MainAuthScreen(),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0), // 🔵 الخلفية الزرقاء الملكية الفخمة
      body: Stack(
        children: [
          // 🛡️ الشعار البارز في المنتصف مع تأثير الظل
          Center(
            child: FadeTransition(
              opacity: _animation,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(35),
                  boxShadow: [
                    // تأثير الظل 3D لجعل الشعار يبدو كأنه يطفو
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                      offset: const Offset(0, 15),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(35),
                  child: Image.asset(
                    'assets/images/app_icon.jpg', // ✅ المسار الصحيح المحدث لصورتك
                    width: 160,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          
          // ✍️ اسم التطبيق في الأسفل بخط عريض وواضح
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 60.0),
              child: FadeTransition(
                opacity: _animation,
                child: const Text(
                  "تجارتي برو",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2.0, // مسافة جمالية بين الحروف
                    shadows: [
                      Shadow(
                        color: Colors.black45,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}