import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'home_page.dart'; // تأكد أن مسار صفحتك الرئيسية صحيح هنا

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final Box box = Hive.box('tajarti_royal_v1');
  final LocalAuthentication auth = LocalAuthentication();
  
  bool isPasswordEnabled = false;
  bool isFingerprintEnabled = false;
  String savedPassword = '';
  
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSecuritySettings();
  }

  Future<void> _checkSecuritySettings() async {
    isPasswordEnabled = box.get('is_password_enabled', defaultValue: false);
    isFingerprintEnabled = box.get('is_fingerprint_enabled', defaultValue: false);
    savedPassword = box.get('app_password', defaultValue: '');

    if (!isPasswordEnabled) {
      // إذا لم يكن القفل مفعلاً، اذهب للرئيسية فوراً
      _goToHome();
      return;
    }

    setState(() {
      _isLoading = false;
    });

    if (isFingerprintEnabled) {
      _authenticateWithBiometrics();
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'الرجاء التحقق من هويتك للدخول إلى تجارتي برو',
        options: const AuthenticationOptions(
          biometricOnly: true, // يفضل أن تكون true لفرض البصمة/الوجه
          stickyAuth: true,
        ),
      );
      if (didAuthenticate) {
        _goToHome();
      }
    } catch (e) {
      print("خطأ في البصمة: $e");
      // في حالة فشل البصمة (مثلاً في محاكي الويب)، سيبقى في الشاشة لإدخال كلمة المرور يدوياً
    }
  }

  void _verifyPassword() {
    if (_passController.text == savedPassword) {
      _goToHome();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كلمة المرور غير صحيحة', textAlign: TextAlign.right), backgroundColor: Colors.red),
      );
      _passController.clear();
    }
  }

  void _goToHome() {
    // استخدم pushReplacement لكي لا يعود لشاشة القفل عند الضغط على زر الرجوع
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // شاشة تحميل بيضاء بسيطة أثناء فحص حالة القفل (في الخلفية)
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF0D256C))));
    }

    // واجهة القفل الرئيسية (تظهر فقط إذا كان القفل مفعلاً)
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // الشعار
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/images/app_icon.jpg', width: 100, height: 100, fit: BoxFit.cover),
              ),
              const SizedBox(height: 20),
              const Text('تجارتي برو', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0D256C))),
              const SizedBox(height: 40),
              
              const Text('التطبيق مقفل', style: TextStyle(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 20),
              
              TextField(
                controller: _passController,
                obscureText: true,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 6, // غالباً كلمات المرور تكون 4 أو 6 أرقام
                decoration: InputDecoration(
                  hintText: 'أدخل كلمة المرور',
                  counterText: "", // إخفاء عداد الأحرف
                  prefixIcon: const Icon(Icons.lock, color: Color(0xFF0D256C)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF0D256C))),
                ),
                onSubmitted: (_) => _verifyPassword(), // التحقق عند الضغط على زر الإدخال في الكيبورد
              ),
              const SizedBox(height: 20),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D256C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: _verifyPassword,
                  child: const Text('دخول', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
              
              if (isFingerprintEnabled)
                IconButton(
                  icon: const Icon(Icons.fingerprint, size: 50, color: Color(0xFF0D256C)),
                  onPressed: _authenticateWithBiometrics,
                ),
            ],
          ),
        ),
      ),
    );
  }
}