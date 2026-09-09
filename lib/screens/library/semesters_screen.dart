import 'package:flutter/material.dart';
import '../../models/educational_material.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_card.dart';
import 'subjects_screen.dart';

class SemestersScreen extends StatelessWidget {
  final Specialization specialization;
  final Level level;
  final String myUserId;
  final String myName;
  final String? myRole;

  const SemestersScreen({
    super.key,
    required this.specialization,
    required this.level,
    required this.myUserId,
    required this.myName,
    this.myRole,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          '${specialization.name} - ${level.name}',
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildSemesterCard(context, 'الترم الأول', 1),
            const SizedBox(height: 20),
            _buildSemesterCard(context, 'الترم الثاني', 2),
          ],
        ),
      ),
    );
  }

  Widget _buildSemesterCard(BuildContext context, String title, int semesterId) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubjectsScreen(
              specialization: specialization,
              level: level,
              semesterId: semesterId,
              semesterName: title,
              myUserId: myUserId,
              myName: myName,
              myRole: myRole,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surface,
              AppColors.primary.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'تصفح المواد الدراسية',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
