import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('سياسة الخصوصية', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              '1. جمع المعلومات',
              'نحن نجمع المعلومات التي تقدمها لنا مباشرة عند إنشاء حساب، مثل اسمك ورقم هاتفك وصورتك الشخصية. كما نقوم بجمع المحتوى الذي تنشره مثل الأسئلة والإجابات.',
            ),
            _buildSection(
              '2. استخدام المعلومات',
              'نستخدم المعلومات التي نجمعها لتوفير خدماتنا وتحسينها، وللتواصل معك، ولضمان سلامة وأمان منصتنا التعليمية.',
            ),
            _buildSection(
              '3. حماية البيانات',
              'نحن نستخدم تقنيات تشفير متقدمة (مثل AES-256) لحماية رسائلك وبياناتك الشخصية من الوصول غير المصرح به.',
            ),
            _buildSection(
              '4. مشاركة المعلومات',
              'نحن لا نبيع بياناتك الشخصية لأطراف ثالثة. يتم مشاركة معلوماتك فقط مع المستخدمين الآخرين كما هو موضح في وظائف التطبيق (مثل ظهور اسمك مع أسئلتك).',
            ),
            const SizedBox(height: 40),
            const Center(
              child: Text(
                'آخر تحديث: يناير 2024',
                style: TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Cairo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: AppColors.textPrimary,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}
