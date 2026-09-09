import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../models/educational_material.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';

class UploadMaterialScreen extends StatefulWidget {
  final String myUserId;
  final String myName;
  final String? myRole;
  final Specialization? initialSpecialization;
  final Level? initialLevel;
  final Subject? initialSubject;
  final int? initialSemester;

  const UploadMaterialScreen({
    super.key,
    required this.myUserId,
    required this.myName,
    this.myRole,
    this.initialSpecialization,
    this.initialLevel,
    this.initialSubject,
    this.initialSemester,
  });

  @override
  State<UploadMaterialScreen> createState() => _UploadMaterialScreenState();
}

class _UploadMaterialScreenState extends State<UploadMaterialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _specializationController = TextEditingController();
  final _levelController = TextEditingController();
  final _subjectController = TextEditingController();

  int? _selectedSemester;
  String _selectedType = 'summary';

  File? _selectedFile;
  String? _uploadedFileUrl;
  bool _isUploading = false;
  bool _isLoadingData = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSpecialization != null) {
      _specializationController.text = widget.initialSpecialization!.name;
    }
    if (widget.initialLevel != null) {
      _levelController.text = widget.initialLevel!.name;
    }
    if (widget.initialSubject != null) {
      _subjectController.text = widget.initialSubject!.name;
    }
    if (widget.initialSemester != null) {
      _selectedSemester = widget.initialSemester;
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx'],
    );

    if (result != null) {
      final file = File(result.files.single.path!);
      
      // If we already have an uploaded file, delete it from temp first
      if (_uploadedFileUrl != null) {
        ApiService.deleteTempFile(_uploadedFileUrl!, widget.myUserId);
      }

      setState(() {
        _selectedFile = file;
        _uploadedFileUrl = null;
        _isUploading = true;
      });

      try {
        final url = await ApiService.uploadFile(file.path, widget.myUserId, type: 'file', isTemp: true);
        if (url != null) {
          setState(() => _uploadedFileUrl = url);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل رفع الملف مؤقتاً')));
          setState(() => _selectedFile = null);
        }
      } catch (e) {
        debugPrint('Upload error: $e');
        setState(() => _selectedFile = null);
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_uploadedFileUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار ملف وانتظار الرفع')));
      return;
    }
    if (_specializationController.text.isEmpty || _levelController.text.isEmpty || _subjectController.text.isEmpty || _selectedSemester == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إكمال كافة بيانات التصنيف')));
      return;
    }

    setState(() => _isUploading = true);

    try {
      final materialData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'creator_id': widget.myUserId,
        'creator_name': widget.myName,
        'creator_role': widget.myRole,
        'specialization_id': widget.initialSpecialization?.id ?? 0,
        'specialization_name': _specializationController.text.trim(),
        'level_id': widget.initialLevel?.id ?? 0,
        'level_name': _levelController.text.trim(),
        'semester_id': _selectedSemester,
        'subject_id': widget.initialSubject?.id ?? 0,
        'subject_name': _subjectController.text.trim(),
        'material_type': _selectedType,
        'file_url': _uploadedFileUrl,
        'file_size': await _selectedFile!.length(),
        'file_type': p.extension(_selectedFile!.path).replaceAll('.', ''),
        'status': 'pending', // Waiting for approval
      };

      final success = await ApiService.uploadEducationalMaterial(widget.myUserId, materialData);
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم رفع الملخص بنجاح وبانتظار مراجعة الإدارة')),
          );
          Navigator.pop(context);
        }
      } else {
        throw 'فشل حفظ بيانات الملف في السيرفر';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'إضافة ملف جديد',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
            fontSize: 16,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingData 
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('معلومات الملف'),
                  TextFormField(
                    controller: _titleController,
                    decoration: _inputDecoration('عنوان الملف (مثلاً: ملخص الوحدة الأولى)'),
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                    validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: _inputDecoration('وصف قصير'),
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle('التصنيف الدراسي'),
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _specializationController,
                          decoration: _inputDecoration('التخصص (اكتب اسم التخصص، مثلاً: تقنية معلومات)'),
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                          validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _levelController,
                                decoration: _inputDecoration('المستوى (مثلاً: الأول)'),
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                                validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _selectedSemester,
                                decoration: _inputDecoration('الفصل'),
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: AppColors.textPrimary),
                                icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                                items: const [
                                  DropdownMenuItem(value: 1, child: Text('الأول')),
                                  DropdownMenuItem(value: 2, child: Text('الثاني')),
                                ],
                                onChanged: (val) => setState(() => _selectedSemester = val),
                                validator: (v) => v == null ? 'مطلوب' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _subjectController,
                          decoration: _inputDecoration('اسم المادة (مثلاً: برمجة 1)'),
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                          validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: _inputDecoration('نوع المحتوى'),
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: AppColors.textPrimary),
                    items: const [
                      DropdownMenuItem(value: 'summary', child: Text('ملخص')),
                      DropdownMenuItem(value: 'malzam', child: Text('ملزمة')),
                      DropdownMenuItem(value: 'exam_model', child: Text('نموذج اختبار')),
                    ],
                    onChanged: (val) => setState(() => _selectedType = val!),
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('الملف المرفق'),
                  InkWell(
                    onTap: _pickFile,
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2), 
                          style: BorderStyle.solid,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.cloud_upload_rounded, size: 36, color: AppColors.primary),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedFile == null ? 'اختر ملف (PDF, DOC, PPT)' : p.basename(_selectedFile!.path),
                            style: TextStyle(
                              color: _selectedFile == null ? AppColors.textSecondary : AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          if (_selectedFile != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'انقر لتغيير الملف',
                                style: TextStyle(
                                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                                  fontSize: 12,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  _isUploading 
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : PrimaryButton(
                        text: 'رفع ونشر الملف',
                        onPressed: _submit,
                        icon: Icons.send_rounded,
                      ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 13),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
