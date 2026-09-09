import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/primary_button.dart';
import 'login_screen.dart';
import 'privacy_policy_screen.dart';
import 'about_us_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String myUserId;
  const SettingsScreen({super.key, required this.myUserId});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الإعدادات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('التفضيلات'),
          AppCard(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildSwitchTile(
                  title: 'التنبيهات',
                  subtitle: 'تفعيل إشعارات التطبيق',
                  icon: Icons.notifications_active_outlined,
                  value: _notificationsEnabled,
                  onChanged: (val) => setState(() => _notificationsEnabled = val),
                ),
                const Divider(height: 1, indent: 56),
                _buildSwitchTile(
                  title: 'الوضع الليلي',
                  subtitle: 'تغيير سمة التطبيق',
                  icon: Icons.dark_mode_outlined,
                  value: _darkMode,
                  onChanged: (val) => setState(() => _darkMode = val),
                ),
              ],
            ),
          ),
          if (widget.myUserId != 'guest') ...[
            _buildSectionHeader('الحساب والأمان'),
            AppCard(
              margin: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildActionTile(
                    title: 'تغيير كلمة المرور',
                    icon: Icons.lock_outline_rounded,
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildActionTile(
                    title: 'الخصوصية',
                    icon: Icons.privacy_tip_outlined,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          _buildSectionHeader('الدعم'),
          AppCard(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildActionTile(
                  title: 'عن التطبيق',
                  icon: Icons.info_outline_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AboutUsScreen()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                _buildActionTile(
                  title: 'تواصل معنا',
                  icon: Icons.headset_mic_outlined,
                  onTap: () async {
                    final Uri emailLaunchUri = Uri(
                      scheme: 'mailto',
                      path: 'support@example.com',
                      queryParameters: {
                        'subject': 'دعم تطبيق EA_mr - ${widget.myUserId}',
                      },
                    );
                    if (await canLaunchUrl(emailLaunchUri)) {
                      await launchUrl(emailLaunchUri);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          PrimaryButton(
            text: widget.myUserId == 'guest' ? 'تسجيل الدخول' : 'تسجيل الخروج',
            color: widget.myUserId == 'guest' ? AppColors.primary : AppColors.error,
            onPressed: widget.myUserId == 'guest' 
              ? () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                )
              : _showLogoutDialog,
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'الإصدار 1.0.0',
              style: TextStyle(color: AppColors.textHint, fontSize: 12, fontFamily: 'Cairo'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Cairo')),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.textHint.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textHint),
      onTap: onTap,
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
        content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('خروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
