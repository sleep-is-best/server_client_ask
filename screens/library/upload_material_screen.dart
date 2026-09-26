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

  List<Specialization> _specializations = [];
  List<Level> _levels = [];
  List<Subject> _subjects = [];

  Specialization? _selectedSpecialization;
  Level? _selectedLevel;
  int? _selectedSemester;
  Subject? _selectedSubject;
  String _selectedType = 'summary';

  File? _selectedFile;
  bool _isUploading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final specsData = await ApiService.getSpecializations();
    if (mounted) {
      setState(() {
        _specializations = specsData.map((e) => Specialization.fromMap(e)).toList();
        
        if (widget.initialSpecialization != null) {
          _selectedSpecialization = _specializations.firstWhere((s) => s.id == widget.initialSpecialization!.id);
          _loadLevels(_selectedSpecialization!.id);
        }
        _isLoadingData = false;
      });
    }
  }

  Future<void> _loadLevels(int specId) async {
    final levelsData = await ApiService.getLevels(specId);
    if (mounted) {
      setState(() {
        _levels = levelsData.map((e) => Level.fromMap(e)).toList();
        if (widget.initialLevel != null) {
          _selectedLevel = _levels.firstWhere((l) => l.id == widget.initialLevel!.id);
          if (widget.initialSemester != null) {
            _selectedSemester = widget.initialSemester;
            _loadSubjects(_selectedLevel!.id, _selectedSemester!);
          }
        }
      });
    }
  }

  Future<void> _loadSubjects(int levelId, int semesterId) async {
    final subjectsData = await ApiService.getSubjects(levelId, semesterId);
    if (mounted) {
      setState(() {
        _subjects = subjectsData.map((e) => Subject.fromMap(e)).toList();
        if (widget.initialSubject != null) {
          _selectedSubject = _subjects.firstWhere((s) => s.id == widget.initialSubject!.id);
        }
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx'],
    );

    if (result != null && mounted) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار ملف')));
      return;
    }
    if (_selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار المادة')));
      return;
    }

    if (mounted) setState(() => _isUploading = true);

    try {
      final fileUrl = await ApiService.uploadFile(
        _selectedFile!.path,
        widget.myUserId,
        type: 'file',
      );
      if (fileUrl == null) throw 'فشل رفع الملف';

      final materialData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'creator_id': widget.myUserId,
        'creator_name': widget.myName,
        'creator_role': widget.myRole,
        'specialization_id': _selectedSpecialization!.id,
        'level_id': _selectedLevel!.id,
        'semester_id': _selectedSemester,
        'subject_id': _selectedSubject!.id,
        'subject_name': _selectedSubject!.name,
        'material_type': _selectedType,
        'file_url': fileUrl,
        'file_size': await _selectedFile!.length(),
        'file_type': p.extension(_selectedFile!.path).replaceAll('.', ''),
        'status': (widget.myRole == 'admin' || widget.myRole == 'doctor' || widget.myRole == 'teacher') ? 'approved' : 'pending',
      };

      final success = await ApiService.uploadEducationalMaterial(widget.myUserId, materialData);
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(materialData['status'] == 'approved' ? 'تم النشر بنجاح' : 'تم الرفع، بانتظار مراجعة الإدارة')),
          );
          Navigator.pop(context);
        }
      } else {
        throw 'فشل حفظ بيانات الملف';
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
                        DropdownButtonFormField<Specialization>(
                          initialValue: _selectedSpecialization,
                          decoration: _inputDecoration('التخصص'),
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: AppColors.textPrimary),
                          items: _specializations.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedSpecialization = val;
                              _selectedLevel = null;
                              _selectedSemester = null;
                              _selectedSubject = null;
                              _levels = [];
                              _subjects = [];
                            });
                            if (val != null) _loadLevels(val.id);
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<Level>(
                                initialValue: _selectedLevel,
                                decoration: _inputDecoration('المستوى'),
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: AppColors.textPrimary),
                                items: _levels.map((l) => DropdownMenuItem(value: l, child: Text(l.name))).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedLevel = val;
                                    _selectedSemester = null;
                                    _selectedSubject = null;
                                    _subjects = [];
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: _selectedSemester,
                                decoration: _inputDecoration('الفصل'),
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: AppColors.textPrimary),
                                items: const [
                                  DropdownMenuItem(value: 1, child: Text('الأول')),
                                  DropdownMenuItem(value: 2, child: Text('الثاني')),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _selectedSemester = val;
                                    _selectedSubject = null;
                                    _subjects = [];
                                  });
                                  if (_selectedLevel != null && val != null) {
                                    _loadSubjects(_selectedLevel!.id, val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<Subject>(
                          initialValue: _selectedSubject,
                          decoration: _inputDecoration('المادة'),
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: AppColors.textPrimary),
                          items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                          onChanged: (val) => setState(() => _selectedSubject = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedType,
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
                        color: AppColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2), 
                          style: BorderStyle.solid,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
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
                                  color: AppColors.textSecondary.withOpacity(0.6),
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
        borderSide: BorderSide(color: AppColors.primary.withOpacity(0.1)),
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
