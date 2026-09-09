import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../services/api_service.dart';
import '../config.dart';
import 'desktop_main_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isRegisterMode = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _handleAuth() async {
    if (_phoneController.text.isEmpty) return;
    setState(() => _isLoading = true);

    Map<String, dynamic>? student;
    if (_isRegisterMode) {
      student = await ApiService.register(_nameController.text, _phoneController.text);
    } else {
      student = await ApiService.login(phone: _phoneController.text);
    }

    setState(() => _isLoading = false);

    if (student != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('student_id', student['studentId']);
      await prefs.setString('user_name', student['name']);
      await prefs.setString('user_phone', student['phone']);
      
      FlutterBackgroundService().invoke('setUserId', {'userId': student['studentId']});
      _proceed(student['studentId']);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isRegisterMode ? 'فشل التسجيل' : 'الطالب غير موجود')),
      );
    }
  }

  void _proceed(String id) {
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (_) => DesktopMainLayout(myUserId: id))
    );
  }

  void _showIpDialog() {
    // عرض الـ IP الحالي فقط بدون المنفذ لتجنب التشوير
    final controller = TextEditingController(text: AppConfig.serverHost);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعدادات الاتصال بالسيرفر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('أدخل عنوان IP السيرفر فقط:', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'مثال: 192.168.1.100',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lan),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 10),
            const Text(
              'ملاحظة: سيتم استخدام المنافذ التلقائية (3000, 3001, 3002)',
              style: TextStyle(fontSize: 11, color: Colors.blueGrey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              String ip = controller.text.trim();
              if (ip.isNotEmpty) {
                // Prepend http:// if missing
                if (!ip.startsWith('http://') && !ip.startsWith('https://')) {
                  ip = 'http://$ip';
                }
                // Append :3000 if no port is specified
                if (!ip.contains(':', 6)) { // Starting from 6 to skip http://
                   ip = '$ip:3000';
                }

                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('server_url', ip);
                AppConfig.serverUrl = ip;
                FlutterBackgroundService().invoke('updateConfig', {'serverUrl': ip});
                setState(() {});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تحديث عنوان السيرفر بنجاح')),
                );
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.settings, color: Colors.grey),
                    onPressed: _showIpDialog,
                  ),
                ),
                const Icon(Icons.school_rounded, size: 80, color: Color(0xFF4A6572)),
                const SizedBox(height: 24),
                Text(
                  _isRegisterMode ? 'إنشاء حساب جديد' : 'تسجيل الدخول للمنصة',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                if (_isRegisterMode) ...[
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.person)),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone)),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleAuth,
                    child: _isLoading ? const CircularProgressIndicator() : Text(_isRegisterMode ? 'تسجيل' : 'دخول'),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _isRegisterMode = !_isRegisterMode),
                  child: Text(_isRegisterMode ? 'لديك حساب؟ سجل دخول' : 'ليس لديك حساب؟ أنشئ واحد الآن'),
                ),
                const Divider(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _proceed('guest'),
                    icon: const Icon(Icons.person_outline),
                    label: const Text('الدخول كضيف'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
