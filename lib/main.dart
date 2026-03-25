import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; 
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'screens/splash_screen.dart';
import 'screens/home_page.dart';

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
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.cairoTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
      ),
      // تم تعيين شاشة البداية كأول شاشة تفتح
      home: const SplashScreen(), 
    );
  }
}

// 2️⃣ شاشة البصمة والتحقق (تم فصلها لكي تفتح بعد شاشة البداية)
class MainAuthScreen extends StatefulWidget {
  const MainAuthScreen({super.key});
  @override
  State<MainAuthScreen> createState() => _MainAuthScreenState();
}

class _MainAuthScreenState extends State<MainAuthScreen> {
  bool _isFingerprintAuthenticated = false;
  final Box box = Hive.box('tajarti_royal_v1');

  @override
  void initState() {
    super.initState();
    _checkFingerprint();
  }

  Future<void> _checkFingerprint() async {
    bool isEnabled = box.get('fingerprint_enabled', defaultValue: false);
    if (!isEnabled) {
      setState(() => _isFingerprintAuthenticated = true);
      return;
    }
    final LocalAuthentication auth = LocalAuthentication();
    try {
      bool didAuthenticate = await auth.authenticate(
        localizedReason: 'يرجى تأكيد هويتك للدخول إلى تجارتي برو', 
        options: const AuthenticationOptions(biometricOnly: false)
      );
      setState(() => _isFingerprintAuthenticated = didAuthenticate);
    } catch (e) {
      setState(() => _isFingerprintAuthenticated = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return !_isFingerprintAuthenticated 
        ? Scaffold(
            backgroundColor: const Color(0xFF1565C0),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.fingerprint, size: 80, color: Colors.white),
                  const SizedBox(height: 20),
                  const Text("تجارتي برو", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: _checkFingerprint, child: const Text("دخول"))
                ],
              ),
            ),
          )
        // إذا نجحت البصمة، يدخل للصفحة الرئيسية مباشرة
        : const Directionality(textDirection: TextDirection.rtl, child: HomePage());
  }
}