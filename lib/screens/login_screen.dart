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
  final TextEditingController _nameController = TextEditingController(); // ✅ حقل الاسم الجديد
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final Box box = Hive.box('tajarti_royal_v1');
  
  bool isLoginMode = true; 
  bool isLoading = false;

  // 🔵 1. دالة تسجيل الدخول عبر جوجل
  Future<void> _signInWithGoogle() async {
    setState(() => isLoading = true);
    try {
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();

      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();
      if (googleUser == null) {
        setState(() => isLoading = false);
        return; 
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);

      UserCredential userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      
      String uid = userCred.user!.uid;
      String name = userCred.user!.displayName ?? 'مستخدم جوجل';
      
      box.put('user_uid', uid); 
      box.put('shop_name', name); // حفظ الاسم في الذاكرة

      // ✅ حفظ بيانات المستخدم في السحابة لتعرف من سجل
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': name,
        'email': userCred.user!.email,
        'login_method': 'google',
        'last_login': DateTime.now().toString(),
      }, SetOptions(merge: true));

      await _syncDataFromCloud(uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مرحباً بك! تم الربط بنجاح 🎉'), backgroundColor: Colors.green));
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
      
      // جلب اسم المتجر من السحابة إذا كان موجود
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if(userDoc.exists && userDoc.data()!['name'] != null){
         box.put('shop_name', userDoc.data()!['name']);
      }

      await _syncDataFromCloud(uid);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الدخول واستعادة بياناتك! 🎉'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      // ✅ تنبيهات عربية مخصصة للمستخدم
      String msg = 'خطأ في تسجيل الدخول';
      if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
        msg = 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 3. دالة إنشاء حساب جديد
  Future<void> _signUp() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء تعبئة جميع الحقول!'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => isLoading = true);
    try {
      UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      String uid = userCred.user!.uid;
      String shopName = _nameController.text.trim();

      box.put('user_uid', uid); 
      box.put('shop_name', shopName); // حفظ الاسم محلياً
      
      // ✅ حفظ بيانات العميل الجديد في قاعدة البيانات
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': shopName,
        'email': _emailController.text.trim(),
        'login_method': 'email',
        'created_at': DateTime.now().toString(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء الحساب السحابي بنجاح! ☁️'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      // ✅ منع التكرار ومعالجة الأخطاء
      String msg = 'خطأ في إنشاء الحساب';
      if (e.code == 'email-already-in-use') {
        msg = 'هذا الإيميل مسجل بالفعل! الرجاء اختيار "تسجيل الدخول".';
      } else if (e.code == 'weak-password') {
        msg = 'كلمة المرور ضعيفة جداً، استخدم 6 أحرف/أرقام على الأقل.';
      } else if (e.code == 'invalid-email') {
        msg = 'صيغة البريد الإلكتروني غير صحيحة.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 🔑 4. دالة استعادة كلمة المرور (جديدة)
  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال بريدك الإلكتروني أولاً في الحقل المخصص.'), backgroundColor: Colors.orange));
      return;
    }
    
    setState(() => isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني.'), backgroundColor: Colors.green));
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'حدث خطأ أثناء الإرسال.';
      if (e.code == 'user-not-found') {
        msg = 'لا يوجد حساب مسجل بهذا البريد الإلكتروني.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 5. دالة المزامنة
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
                child: Image.asset('assets/images/app_icon.png', width: 100, height: 100, fit: BoxFit.cover),
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
              
              // ✅ حقل الاسم (يظهر فقط في حالة إنشاء الحساب)
              if (!isLoginMode) ...[
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: 'اسمك أو اسم المتجر', prefixIcon: const Icon(Icons.store, color: Color(0xFF0D256C)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                ),
                const SizedBox(height: 15),
              ],

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
              
              // 🔑 زر استعادة كلمة المرور (يظهر فقط في حالة تسجيل الدخول)
              if (isLoginMode) 
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _resetPassword,
                    child: const Text("نسيت كلمة المرور؟", style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ),
                ),
                
              const SizedBox(height: 20),
              
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
                      // 🔵 زر جوجل (مع صورة PNG مدعومة)
                      SizedBox(
                        width: double.infinity, height: 55,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          icon: Image.network('https://cdn-icons-png.flaticon.com/512/300/300221.png', width: 24), // صورة آمنة
                          label: const Text('المتابعة عبر حساب جوجل', style: TextStyle(color: Colors.black87, fontSize: 16)),
                          onPressed: _signInWithGoogle,
                        ),
                      ),
                    ],
                  ),
                  
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => setState(() {
                  isLoginMode = !isLoginMode;
                  _nameController.clear(); // تفريغ الحقول عند التبديل
                  _passwordController.clear();
                }),
                child: Text(isLoginMode ? "ليس لديك حساب؟ أنشئ حساباً الآن" : "لديك حساب بالفعل؟ سجل دخولك", style: const TextStyle(color: Color(0xFF0D256C), fontSize: 16, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }
}