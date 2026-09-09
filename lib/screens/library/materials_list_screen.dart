import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/educational_material.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_card.dart';
import 'material_detail_screen.dart';
import 'upload_material_screen.dart';

class MaterialsListScreen extends StatefulWidget {
  final Specialization specialization;
  final Level level;
  final int semesterId;
  final Subject subject;
  final String myUserId;
  final String myName;
  final String? myRole;

  const MaterialsListScreen({
    super.key,
    required this.specialization,
    required this.level,
    required this.semesterId,
    required this.subject,
    required this.myUserId,
    required this.myName,
    this.myRole,
  });

  @override
  State<MaterialsListScreen> createState() => _MaterialsListScreenState();
}

class _MaterialsListScreenState extends State<MaterialsListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _types = ['summary', 'malzam', 'exam_model'];
  final List<String> _typeLabels = ['📄 الملخصات', '📚 الملازم', '📝 نماذج الاختبارات'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.subject.name,
          style: const TextStyle(
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontFamily: 'Cairo', fontSize: 13),
          tabs: _typeLabels.map((label) => Tab(text: label)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _types.map((type) => MaterialListView(
          subjectId: widget.subject.id,
          subjectName: widget.subject.name,
          type: type,
          myUserId: widget.myUserId,
        )).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UploadMaterialScreen(
                myUserId: widget.myUserId,
                myName: widget.myName,
                myRole: widget.myRole,
                initialSpecialization: widget.specialization,
                initialLevel: widget.level,
                initialSemester: widget.semesterId,
                initialSubject: widget.subject,
              ),
            ),
          );
        },
        backgroundColor: AppColors.primary,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}

class MaterialListView extends StatefulWidget {
  final int subjectId;
  final String subjectName;
  final String type;
  final String myUserId;

  const MaterialListView({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.type,
    required this.myUserId,
  });

  @override
  State<MaterialListView> createState() => _MaterialListViewState();
}

class _MaterialListViewState extends State<MaterialListView> {
  List<EducationalMaterial> _materials = [];
  bool _isLoading = true;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    final data = await ApiService.getMaterials(
      subjectId: widget.subjectId,
      subjectName: widget.subjectName,
      type: widget.type,
      page: _page,
    );
    if (mounted) {
      setState(() {
        _materials = data.map((e) => EducationalMaterial.fromMap(e)).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_materials.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'لا توجد ملفات في هذا القسم حالياً',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'Cairo',
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _materials.length,
      itemBuilder: (context, index) {
        final material = _materials[index];
        return _buildMaterialCard(material);
      },
    );
  }

  Widget _buildMaterialCard(EducationalMaterial material) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.zero,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MaterialDetailScreen(
              material: material,
              myUserId: widget.myUserId,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 65,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.description_rounded, color: AppColors.primary, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    material.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      fontFamily: 'Cairo',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        material.creatorName,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      if (material.creatorRole != null && material.creatorRole != 'member') ...[
                        const SizedBox(width: 8),
                        _buildRoleBadge(material.creatorRole!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.remove_red_eye_outlined, size: 14, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      Text(
                        '${material.viewsCount}',
                        style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7), fontSize: 11),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.file_download_outlined, size: 14, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      Text(
                        '${material.downloadsCount}',
                        style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7), fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    String label = 'طالب';
    Color color = AppColors.textSecondary;
    if (role == 'teacher') { label = 'أستاذ'; color = Colors.orange; }
    else if (role == 'doctor') { label = 'دكتور'; color = Colors.deepPurple; }
    else if (role == 'admin') { label = 'مدير'; color = AppColors.accent; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
      ),
    );
  }
}
