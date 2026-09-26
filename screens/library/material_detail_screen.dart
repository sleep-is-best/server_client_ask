import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../models/educational_material.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/primary_button.dart';

class MaterialDetailScreen extends StatefulWidget {
  final EducationalMaterial material;
  final String myUserId;

  const MaterialDetailScreen({
    super.key,
    required this.material,
    required this.myUserId,
  });

  @override
  State<MaterialDetailScreen> createState() => _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends State<MaterialDetailScreen> {
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _reportView();
    _checkIfDownloaded();
  }

  Future<void> _reportView() async {
    if (widget.material.id != null) {
      await ApiService.reportMaterialView(widget.material.id!);
    }
  }

  Future<void> _checkIfDownloaded() async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = widget.material.fileUrl.split('/').last;
    final filePath = '${directory.path}/$fileName';
    if (await File(filePath).exists()) {
      setState(() {
        _localPath = filePath;
      });
    }
  }

  Future<void> _downloadFile() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      final response = await http.Client().send(http.Request('GET', Uri.parse(widget.material.fileUrl)));
      final contentLength = response.contentLength ?? 0;
      
      final directory = await getApplicationDocumentsDirectory();
      final fileName = widget.material.fileUrl.split('/').last;
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      List<int> bytes = [];
      response.stream.listen(
        (List<int> newBytes) {
          bytes.addAll(newBytes);
          setState(() {
            _downloadProgress = bytes.length / contentLength;
          });
        },
        onDone: () async {
          await file.writeAsBytes(bytes);
          setState(() {
            _isDownloading = false;
            _localPath = filePath;
          });
          if (widget.material.id != null) {
            await ApiService.reportMaterialDownload(widget.material.id!);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحميل الملف بنجاح')),
          );
        },
        onError: (e) {
          setState(() => _isDownloading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في التحميل: $e')),
          );
        },
        cancelOnError: true,
      );
    } catch (e) {
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    }
  }

  Future<void> _openFile() async {
    final path = _localPath;
    if (path != null) {
      await OpenFilex.open(path);
    } else {
      _downloadFile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final material = widget.material;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'تفاصيل الملف',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.primary),
            onPressed: () {
              Share.share('تحقق من هذا الملف التعليمي: ${material.title}\n${material.fileUrl}');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Material Info Card
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 55,
                        height: 55,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.description_rounded, color: AppColors.primary, size: 32),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              material.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            Text(
                              material.subjectName,
                              style: const TextStyle(
                                color: AppColors.secondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(color: AppColors.divider),
                  ),
                  Text(
                    material.description,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: AppColors.textPrimary,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildInfoRow(Icons.calendar_today_outlined, 'تاريخ النشر', DateFormat('yyyy/MM/dd').format(material.createdAt)),
                  _buildInfoRow(Icons.file_present_outlined, 'حجم الملف', '${(material.fileSize / (1024 * 1024)).toStringAsFixed(2)} MB'),
                  _buildInfoRow(Icons.category_outlined, 'نوع الملف', _getTypeLabel(material.materialType)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Creator Card
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  UserAvatar(
                    name: material.creatorName,
                    imageUrl: material.creatorProfileImage,
                    radius: 25,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'بواسطة',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        Text(
                          material.creatorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (material.creatorRole != null) _buildRoleBadge(material.creatorRole!),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Action Buttons
            if (_isDownloading)
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _downloadProgress,
                      minHeight: 8,
                      color: AppColors.primary,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'جاري التحميل... ${(_downloadProgress * 100).toInt()}%',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      text: _localPath != null ? 'قراءة الملف' : 'تحميل الملف',
                      onPressed: _openFile,
                      icon: _localPath != null ? Icons.menu_book_rounded : Icons.file_download_rounded,
                    ),
                  ),
                  if (_localPath != null) ...[
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: IconButton(
                        onPressed: () => _downloadFile(),
                        icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                        tooltip: 'إعادة التحميل',
                      ),
                    ),
                  ],
                ],
              ),
            
            const SizedBox(height: 40),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'تنبيه: جميع الحقوق محفوظة لأصحابها. هذا الملف للمنفعة التعليمية فقط.',
                        style: TextStyle(
                          color: AppColors.textSecondary.withOpacity(0.8),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.textPrimary,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'summary': return 'ملخص';
      case 'malzam': return 'ملزمة';
      case 'exam_model': return 'نموذج اختبار';
      default: return 'ملف';
    }
  }

  Widget _buildRoleBadge(String role) {
    String label = 'طالب';
    Color color = AppColors.textSecondary;
    if (role == 'teacher') { label = 'أستاذ'; color = Colors.orange; }
    else if (role == 'doctor') { label = 'دكتور'; color = Colors.deepPurple; }
    else if (role == 'admin') { label = 'مدير'; color = AppColors.accent; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }
}
