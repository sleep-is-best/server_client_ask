import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/app_colors.dart';
import '../widgets/primary_button.dart';
import '../services/api_service.dart';
import '../config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileEditScreen extends StatefulWidget {
  final Map<String, dynamic> studentData;
  const ProfileEditScreen({super.key, required this.studentData});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;
  bool _isLoading = false;
  String? _profileImage;
  String? _backgroundImage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.studentData['name']);
    _phoneController = TextEditingController(text: widget.studentData['phone']);
    _bioController = TextEditingController(text: widget.studentData['bio'] ?? '');
    _profileImage = widget.studentData['profileImage'];
    _backgroundImage = widget.studentData['backgroundImage'];
  }

  Future<void> _pickAndUploadImage(bool isProfile) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() => _isLoading = true);
      final String? url = await ApiService.uploadFile(image.path, widget.studentData['studentId']);
      if (url != null) {
        final updatedData = await ApiService.updateProfile({
          'studentId': widget.studentData['studentId'],
          isProfile ? 'profileImage' : 'backgroundImage': url,
        });
        if (updatedData != null) {
          setState(() {
            if (isProfile) {
              _profileImage = url;
            } else {
              _backgroundImage = url;
            }
          });
        }
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_bioController.text.length > 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('النبذة التعريفية يجب ألا تتجاوز 200 حرف')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final updatedData = await ApiService.updateProfile({
      'studentId': widget.studentData['studentId'],
      'name': _nameController.text,
      'phone': _phoneController.text,
      'bio': _bioController.text,
    });

    if (updatedData != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', _nameController.text);
      await prefs.setString('user_phone', _phoneController.text);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث الملف الشخصي بنجاح')),
        );
        Navigator.pop(context, updatedData);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل في تحديث الملف الشخصي')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('تعديل الملف الشخصي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Background Image
                GestureDetector(
                  onTap: () => _pickAndUploadImage(false),
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 50),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      image: _backgroundImage != null ? DecorationImage(
                        image: NetworkImage(AppConfig.parseMediaUrl(_backgroundImage!)),
                        fit: BoxFit.cover,
                      ) : null,
                    ),
                    child: _backgroundImage == null 
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 40, color: AppColors.primary.withValues(alpha: 0.5)),
                            const SizedBox(height: 8),
                            Text('إضافة صورة غلاف', style: TextStyle(color: AppColors.primary.withValues(alpha: 0.5), fontFamily: 'Cairo', fontSize: 12)),
                          ],
                        ) 
                      : null,
                  ),
                ),
                // Profile Image
                GestureDetector(
                  onTap: () => _pickAndUploadImage(true),
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
                        child: CircleAvatar(
                          radius: 55,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                          backgroundImage: _profileImage != null ? NetworkImage(AppConfig.parseMediaUrl(_profileImage!)) : null,
                          child: _profileImage == null ? const Icon(Icons.person, size: 50, color: AppColors.primary) : null,
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('الاسم الكامل'),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                    decoration: _inputDecoration('أدخل اسمك الكامل', Icons.person_outline),
                  ),
                  const SizedBox(height: 20),
                  _buildLabel('نبذة عني'),
                  TextField(
                    controller: _bioController,
                    maxLines: 3,
                    maxLength: 200,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                    decoration: _inputDecoration('اكتب نبذة قصيرة عن نفسك...', Icons.info_outline),
                  ),
                  const SizedBox(height: 40),
                  _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : PrimaryButton(
                        text: 'حفظ التعديلات',
                        onPressed: _saveProfile,
                      ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: AppColors.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
