import 'dart:io';
import 'package:flutter/material.dart';
import '../models/question.dart';
import '../services/api_service.dart';
import '../config.dart';

class DesktopQuestionCard extends StatefulWidget {
  final Question question;
  final VoidCallback? onAnswer;
  final VoidCallback onProfileTap;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final String? myUserId;

  const DesktopQuestionCard({
    super.key,
    required this.question,
    this.onAnswer,
    required this.onProfileTap,
    required this.onTap,
    this.onDelete,
    this.myUserId,
  });

  @override
  State<DesktopQuestionCard> createState() => _DesktopQuestionCardState();
}

class _DesktopQuestionCardState extends State<DesktopQuestionCard> {
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final data = await ApiService.getProfile(widget.question.userId);
    if (mounted) {
      setState(() => _userData = data);
    }
  }

  String _getRoleName(String role) {
    switch (role) {
      case 'admin': return 'المدير العام';
      case 'assistant_admin': return 'مساعد مدير';
      case 'doctor': return 'دكتور';
      case 'teacher': return 'أستاذ';
      case 'premium_member': return 'عضو مميز';
      default: return 'عضو';
    }
  }

  Color _getRoleColor(String role, ColorScheme colorScheme) {
    switch (role) {
      case 'admin':
      case 'assistant_admin':
        return const Color(0xFFD4AF37);
      case 'doctor':
        return Colors.deepPurple;
      case 'teacher':
        return Colors.orange;
      case 'premium_member':
        return colorScheme.tertiary;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: widget.onProfileTap,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                        backgroundImage: _userData?['profileImage'] != null ? NetworkImage(AppConfig.parseMediaUrl(_userData!['profileImage'])) : null,
                        child: _userData?['profileImage'] == null ? Text((_userData?['name'] ?? 'م').substring(0, 1).toUpperCase(),
                          style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)) : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _userData?['name'] ?? 'جارٍ التحميل...',
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                color: colorScheme.onSurface,
                                fontSize: 16,
                                fontFamily: 'Cairo'
                              )
                            ),
                            if (_userData?['role'] != null && _userData?['role'] != 'member') ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getRoleColor(_userData!['role'], colorScheme).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _getRoleColor(_userData!['role'], colorScheme).withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  _getRoleName(_userData!['role']),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _getRoleColor(_userData!['role'], colorScheme),
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${widget.question.timestamp.day}/${widget.question.timestamp.month} • ${widget.question.points} نقطة مكافأة • ${widget.question.answerCount} إجابة',
                          style: TextStyle(
                            fontSize: 11, 
                            color: colorScheme.secondary, 
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo'
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.myUserId == widget.question.userId)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('حذف السؤال؟'),
                            content: const Text('هل أنت متأكد من حذف هذا السؤال؟ لا يمكن التراجع عن هذا الإجراء.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  widget.onDelete?.call();
                                }, 
                                child: const Text('حذف', style: TextStyle(color: Colors.red))
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  else
                    Icon(Icons.more_horiz_rounded, color: colorScheme.onSurface.withValues(alpha: 0.3)),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                widget.question.content,
                style: TextStyle(
                  fontSize: 16, 
                  height: 1.6, 
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                  fontFamily: 'Cairo'
                ),
              ),
              if (widget.question.mediaUrls != null && widget.question.mediaUrls!.isNotEmpty) ...[
                const SizedBox(height: 20),
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.question.mediaUrls!.length,
                    itemBuilder: (context, index) {
                      final url = widget.question.mediaUrls![index];
                      return Container(
                        margin: const EdgeInsets.only(right: 16),
                        width: 320,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            color: colorScheme.onSurface.withValues(alpha: 0.05),
                            child: url.startsWith('http')
                                ? Image.network(
                                    AppConfig.parseMediaUrl(url),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: Colors.red)),
                                  )
                                : Image.file(
                                    File(url),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: Colors.red)),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Divider(height: 1, color: colorScheme.onSurface.withValues(alpha: 0.05)),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (widget.myUserId != 'guest' && widget.onAnswer != null) ...[
                    _buildActionButton(Icons.add_comment_rounded, 'تقديم إجابة', widget.onAnswer!, colorScheme.primary, colorScheme),
                    const SizedBox(width: 30),
                  ],
                  _buildActionButton(Icons.alternate_email_rounded, 'تواصل', widget.onProfileTap, colorScheme.secondary, colorScheme),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_upward_rounded, size: 18, color: colorScheme.tertiary),
                        const SizedBox(width: 6),
                        Text(
                          'تصويت', 
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            color: colorScheme.tertiary, 
                            fontSize: 13,
                            fontFamily: 'Cairo'
                          )
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap, Color color, ColorScheme colorScheme) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              label, 
              style: TextStyle(
                color: color, 
                fontWeight: FontWeight.bold,
                fontSize: 14,
                fontFamily: 'Cairo'
              )
            ),
          ],
        ),
      ),
    );
  }
}
