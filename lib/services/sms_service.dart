import 'dart:convert';
import 'package:http/http.dart' as http;

class SmsService {
  // ⚠️ تنبيه: هنا تضع بيانات حسابك الذي ستشتريه من شركة الرسائل
  static const String apiKey = "ضع_الـ_API_KEY_هنا"; 
  static const String userName = "ضع_اسم_المستخدم_هنا"; 
  static const String senderName = "TajartiPro"; // اسم المرسل الذي سيظهر للعميل

  // دالة إرسال الرسالة
  static Future<bool> sendSms({required String phone, required String message}) async {
    try {
      // رابط الشركة (مثال: شركة مسجات)
      final url = Uri.parse('https://www.msegat.com/gw/sendsms.php');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "userName": userName,
          "apiKey": apiKey,
          "numbers": phone, // رقم العميل
          "userSender": senderName,
          "msg": message // نص الرسالة
        }),
      );

      if (response.statusCode == 200) {
        print("✅ الساحر: تم إرسال الرسالة بنجاح!");
        return true;
      } else {
        print("❌ الساحر: فشل الإرسال. كود الخطأ: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("❌ الساحر: حدث خطأ في الاتصال بالإنترنت: $e");
      return false;
    }
  }
}