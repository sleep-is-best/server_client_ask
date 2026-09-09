import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/app_colors.dart';
import '../widgets/app_card.dart';

class StorageManagementScreen extends StatefulWidget {
  const StorageManagementScreen({super.key});

  @override
  State<StorageManagementScreen> createState() => _StorageManagementScreenState();
}

class _StorageManagementScreenState extends State<StorageManagementScreen> {
  double _cacheSize = 0;
  double _documentsSize = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateStorage();
  }

  Future<void> _calculateStorage() async {
    setState(() => _isLoading = true);
    
    final tempDir = await getTemporaryDirectory();
    final docsDir = await getApplicationDocumentsDirectory();

    final tempSize = await _getDirSize(tempDir);
    final docsSize = await _getDirSize(docsDir);

    if (mounted) {
      setState(() {
        _cacheSize = tempSize / (1024 * 1024);
        _documentsSize = docsSize / (1024 * 1024);
        _isLoading = false;
      });
    }
  }

  Future<int> _getDirSize(Directory dir) async {
    int totalSize = 0;
    try {
      if (await dir.exists()) {
        await for (var entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
    } catch (e) {
      print('Error calculating directory size: $e');
    }
    return totalSize;
  }

  Future<void> _clearCache() async {
    final tempDir = await getTemporaryDirectory();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
      await tempDir.create();
    }
    await _calculateStorage();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم مسح التخزين المؤقت بنجاح')),
      );
    }
  }

  Future<void> _clearDownloads() async {
    final docsDir = await getApplicationDocumentsDirectory();
    if (await docsDir.exists()) {
      await for (var entity in docsDir.list()) {
        if (entity is File) {
          await entity.delete();
        }
      }
    }
    await _calculateStorage();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم مسح الملفات المحملة بنجاح')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'إدارة مساحة التخزين',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildStorageItem(
                    title: 'التخزين المؤقت (Cache)',
                    description: 'ملفات الصور والفيديوهات التي تم عرضها مؤخراً لتسريع التصفح.',
                    size: _cacheSize,
                    icon: Icons.cached_rounded,
                    onClear: _clearCache,
                  ),
                  const SizedBox(height: 20),
                  _buildStorageItem(
                    title: 'الملفات المحملة',
                    description: 'الملفات التعليمية التي قمت بتحميلها للقراءة دون اتصال.',
                    size: _documentsSize,
                    icon: Icons.file_download_done_rounded,
                    onClear: _clearDownloads,
                  ),
                  const SizedBox(height: 40),
                  const AppCard(
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primary),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'ملاحظة: مسح البيانات سيؤدي إلى إعادة تحميلها عند الحاجة إليها مرة أخرى.',
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStorageItem({
    required String title,
    required String description,
    required double size,
    required IconData icon,
    required VoidCallback onClear,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const Spacer(),
              Text(
                '${size.toStringAsFixed(2)} MB',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Cairo',
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('تأكيد المسح', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
                    content: const Text('هل أنت متأكد من مسح هذه البيانات؟', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onClear();
                        },
                        child: const Text('مسح الآن', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('مسح البيانات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
