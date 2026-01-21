import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // ✅ مهم لحل مشكلة الماوس
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'screens/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('tajarti_royal_v1');
  runApp(const TajartiApp());
}

// ✅ هذا الكلاس هو الحل السحري للماوس
class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse, // السماح للماوس بالسحب
  };
}

class TajartiApp extends StatefulWidget {
  const TajartiApp({super.key});
  @override
  State<TajartiApp> createState() => _TajartiAppState();
}

class _TajartiAppState extends State<TajartiApp> {
  bool _isAuthenticated = false;
  final Box box = Hive.box('tajarti_royal_v1');

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    bool isEnabled = box.get('fingerprint_enabled', defaultValue: false);
    if (!isEnabled) {
      setState(() => _isAuthenticated = true);
      return;
    }
    final LocalAuthentication auth = LocalAuthentication();
    try {
      bool didAuthenticate = await auth.authenticate(localizedReason: 'يرجى تسجيل الدخول', options: const AuthenticationOptions(biometricOnly: false));
      setState(() => _isAuthenticated = didAuthenticate);
    } catch (e) {
      setState(() => _isAuthenticated = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'تجارتي برو',
      scrollBehavior: MyCustomScrollBehavior(), // ✅ تفعيل سحب الماوس هنا
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.cairoTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
      ),
      home: _isAuthenticated 
          ? const Directionality(textDirection: TextDirection.rtl, child: HomePage())
          : Scaffold(
              backgroundColor: const Color(0xFF1565C0),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.fingerprint, size: 80, color: Colors.white),
                    const SizedBox(height: 20),
                    const Text("تجارتي برو", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    ElevatedButton(onPressed: _checkAuth, child: const Text("دخول"))
                  ],
                ),
              ),
            ),
    );
  }
}