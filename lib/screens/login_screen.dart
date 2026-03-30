import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final Box box = Hive.box('tajarti_royal_v1');
  
  bool isLoginMode = true; 
  bool isLoading = false;

  // 🔵 1. دالة تسجيل الدخول عبر جوجل (محدثة للإصدار 7.0+ الجديد)
  Future<void> _signInWithGoogle() async {
    setState(() => isLoading = true);
    try {
      final googleSignIn = GoogleSignIn.instance;
      
      // 1. تهيئة مكتبة جوجل (أمر إجباري في التحديث الجديد)
      await googleSignIn.initialize();

      // 2. بدء عملية اختيار حساب جوجل
      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();
      if (googleUser == null) {
        setState(() => isLoading = false);
        return; // المستخدم ألغى العملية
      }

      // 3. الحصول على تفاصيل المصادقة (idToken فقط حسب التحديث الجديد)
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 4. إنشاء بيانات اعتماد لفايربيس 
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // 5. تسجيل الدخول في فايربيس
      UserCredential userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      
      String uid = userCred.user!.uid;
      box.put('user_uid', uid); 
      box.put('user_name', userCred.user!.displayName); 

      // 6. مزامنة البيانات فوراً من السحابة
      await _syncDataFromCloud(uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مرحباً بك! تم الربط عبر جوجل بنجاح 🎉'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      print("Google Auth Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل الربط مع جوجل، تأكد من الإعدادات'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 2. دالة تسجيل الدخول العادي (إيميل وباسورد)
  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
    setState(() => isLoading = true);
    try {
      UserCredential userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      String uid = userCred.user!.uid;
      box.put('user_uid', uid); 
      await _syncDataFromCloud(uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استعادة حسابك وبياناتك بنجاح! 🎉'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'خطأ في تسجيل الدخول'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 3. دالة إنشاء حساب جديد
  Future<void> _signUp() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
    setState(() => isLoading = true);
    try {
      UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      String uid = userCred.user!.uid;
      box.put('user_uid', uid); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء الحساب السحابي بنجاح! ☁️'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'خطأ في إنشاء الحساب'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 4. دالة المزامنة
  Future<void> _syncDataFromCloud(String uid) async {
    try {
      var snapshot = await FirebaseFirestore.instance.collection('users').doc(uid).collection('clients').get();
      for (var doc in snapshot.docs) {
        box.put(doc.id, doc.data()); 
      }
    } catch (e) {
      print("Sync Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D256C),
        title: Text(isLoginMode ? "تسجيل الدخول" : "إنشاء حساب سحابي", style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset('assets/images/app_icon.png', width: 120, height: 120, fit: BoxFit.cover),
              ),
              const SizedBox(height: 20),
              const Text('تجارتي برو', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0D256C))),
              const SizedBox(height: 10),
              Text(
                isLoginMode ? 'استعد بياناتك وعملائك من السحابة' : 'أنشئ حساباً لحماية بياناتك من الضياع',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: const Icon(Icons.email, color: Color(0xFF0D256C)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'كلمة المرور', prefixIcon: const Icon(Icons.lock, color: Color(0xFF0D256C)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
              ),
              const SizedBox(height: 30),
              
              isLoading 
                ? const CircularProgressIndicator(color: Color(0xFF0D256C))
                : Column(
                    children: [
                      SizedBox(
                        width: double.infinity, height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D256C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                          onPressed: isLoginMode ? _login : _signUp,
                          child: Text(isLoginMode ? 'تسجيل الدخول' : 'إنشاء حساب جديد', style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 15),
                      // 🔵 زر جوجل
                      SizedBox(
                        width: double.infinity, height: 55,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          icon: Image.network('https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg', width: 24),
                          label: const Text('المتابعة عبر حساب جوجل', style: TextStyle(color: Colors.black87, fontSize: 16)),
                          onPressed: _signInWithGoogle,
                        ),
                      ),
                    ],
                  ),
                  
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => setState(() => isLoginMode = !isLoginMode),
                child: Text(isLoginMode ? "ليس لديك حساب؟ أنشئ حساباً الآن" : "لديك حساب بالفعل؟ سجل دخولك", style: const TextStyle(color: Color(0xFF0D256C), fontSize: 16, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }
}