import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; 
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'screens/splash_screen.dart'; // تأكد أن المسار صحيح حسب مجلداتك

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCIDPe4cgaP3AHzmrdFExSSnOO-bahHh2Y",
      appId: "1:756437740410:web:e3b54ea505494ad991c4c3",
      messagingSenderId: "756437740410",
      projectId: "tijarati-pro",
      authDomain: "tijarati-pro.firebaseapp.com",
      storageBucket: "tijarati-pro.firebasestorage.app",
      measurementId: "G-WRVRHTLFZB",
    ),
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  await Hive.initFlutter();
  await Hive.openBox('tajarti_royal_v1');
  
  runApp(const TajartiApp());
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse, 
  };
}

// 1️⃣ التطبيق الرئيسي يبدأ من شاشة البداية (Splash Screen)
class TajartiApp extends StatelessWidget {
  const TajartiApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'تجارتي برو',
      scrollBehavior: MyCustomScrollBehavior(), 
      
      // ✅ الكود السحري: هذا السطر يجبر التطبيق بالكامل (القائمة، البطاقات، الواجهة) ليكون من اليمين لليسار
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.cairoTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
      ),
      // التطبيق يفتح شاشة البداية أولاً، وهي بدورها ستفحص البصمة عبر AuthScreen
      home: const SplashScreen(), 
    );
  }
}