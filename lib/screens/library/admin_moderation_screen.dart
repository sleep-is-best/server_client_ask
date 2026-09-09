import 'package:flutter/material.dart';
import '../../models/educational_material.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import 'material_detail_screen.dart';

class AdminModerationScreen extends StatefulWidget {
  final String adminId;

  const AdminModerationScreen({super.key, required this.adminId});

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen> {
  List<EducationalMaterial> _pendingMaterials = [];
  bool _isLoading = true;

  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadMoreRunning = false;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadPending();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadMoreRunning &&
        _hasMore) {
      _loadMorePending();
    }
  }

  Future<void> _loadPending() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasMore = true;
    });
    final data = await ApiService.getPendingMaterials(widget.adminId, page: 1);
    if (mounted) {
      setState(() {
        _pendingMaterials = data.map((e) => EducationalMaterial.fromMap(e)).toList();
        _isLoading = false;
        if (data.length < 20) _hasMore = false;
      });
    }
  }

  Future<void> _loadMorePending() async {
    setState(() => _isLoadMoreRunning = true);
    _currentPage++;
    final data = await ApiService.getPendingMaterials(widget.adminId, page: _currentPage);
    if (mounted) {
      if (data.isNotEmpty) {
        setState(() {
          _pendingMaterials.addAll(data.map((e) => EducationalMaterial.fromMap(e)).toList());
          if (data.length < 20) _hasMore = false;
        });
      } else {
        setState(() => _hasMore = false);
      }
      setState(() => _isLoadMoreRunning = false);
    }
  }

  Future<void> _updateStatus(EducationalMaterial material, String status) async {
    String? reason;
    if (status == 'rejected') {
      reason = await _showReasonDialog();
      if (reason == null) return;
    }

    final success = await ApiService.updateMaterialStatus(
      widget.adminId,
      material.id!,
      status,
      reason: reason,
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status == 'approved' ? 'تمت الموافقة' : 'تم الرفض')),
      );
      _loadPending();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'مراجعة الملفات',
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
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          actions: [
            IconButton(
              onPressed: _loadPending,
              icon: const Icon(Icons.refresh, color: AppColors.primary),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _pendingMaterials.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.library_add_check_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        const Text(
                          'لا توجد ملفات قيد الانتظار',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontFamily: 'Cairo',
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingMaterials.length + (_isLoadMoreRunning ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _pendingMaterials.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                        );
                      }
                      final material = _pendingMaterials[index];
                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.description_rounded, color: AppColors.primary),
                              ),
                              title: Text(
                                material.title,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                              subtitle: Text(
                                'بواسطة: ${material.creatorName} • ${material.subjectName}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MaterialDetailScreen(
                                      material: material,
                                      myUserId: widget.adminId,
                                    ),
                                  ),
                                );
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _updateStatus(material, 'rejected'),
                                    icon: const Icon(Icons.close, color: AppColors.error, size: 18),
                                    label: const Text(
                                      'رفض',
                                      style: TextStyle(color: AppColors.error, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: () => _updateStatus(material, 'approved'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.success,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.check, size: 18),
                                    label: const Text(
                                      'موافقة',
                                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Future<String?> _showReasonDialog() async {
    String reason = '';
    return showDialog<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'سبب الرفض',
            style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          content: TextField(
            style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo'),
            onChanged: (v) => reason = v,
            decoration: InputDecoration(
              hintText: 'اكتب السبب هنا...',
              hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6), fontFamily: 'Cairo'),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.divider)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo'))
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, reason),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('تأكيد الرفض', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
