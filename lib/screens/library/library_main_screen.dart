import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/educational_material.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/search_field.dart';
import 'levels_screen.dart';
import 'upload_material_screen.dart';

class LibraryMainScreen extends StatefulWidget {
  final String myUserId;
  final String myName;
  final String? myRole;

  const LibraryMainScreen({
    super.key,
    required this.myUserId,
    required this.myName,
    this.myRole,
  });

  @override
  State<LibraryMainScreen> createState() => _LibraryMainScreenState();
}

class _LibraryMainScreenState extends State<LibraryMainScreen> {
  List<Specialization> _specializations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSpecializations();
  }

  Future<void> _loadSpecializations() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getSpecializations();
    if (mounted) {
      setState(() {
        _specializations = data.map((e) => Specialization.fromMap(e)).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('المكتبة التعليمية', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: SearchField(hintText: 'ابحث عن ملزمة أو ملخص...'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'التخصصات الدراسية',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.textPrimary),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _specializations.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد تخصصات حالياً',
                          style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: _specializations.length,
                        itemBuilder: (context, index) {
                          final spec = _specializations[index];
                          return AppCard(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            padding: EdgeInsets.zero,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LevelsScreen(
                                    specialization: spec,
                                    myUserId: widget.myUserId,
                                    myName: widget.myName,
                                    myRole: widget.myRole,
                                  ),
                                ),
                              );
                            },
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.school_rounded, color: AppColors.primary),
                              ),
                              title: Text(
                                spec.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo', color: AppColors.textPrimary),
                              ),
                              subtitle: const Text(
                                'تصفح المستويات والمواد الدراسية',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Cairo'),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textHint),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: widget.myUserId == 'guest' 
        ? null 
        : FloatingActionButton.extended(
            onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UploadMaterialScreen(
                myUserId: widget.myUserId,
                myName: widget.myName,
                myRole: widget.myRole,
              ),
            ),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('نشر ملف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
      ),
    );
  }
}
