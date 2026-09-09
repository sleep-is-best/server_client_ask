import 'package:flutter/material.dart';
import '../models/reel.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../models/message.dart';
import '../screens/chat_screen.dart';
import '../widgets/cached_image.dart';
import '../services/socket_service.dart';
import '../config.dart';
import 'reel_comment_sheet.dart';

class ReelSideBar extends StatefulWidget {
  final Reel reel;
  final String myUserId;
  final Function(bool isLiked, int likesCount)? onLikeChanged;

  const ReelSideBar({
    super.key,
    required this.reel,
    required this.myUserId,
    this.onLikeChanged,
  });

  @override
  State<ReelSideBar> createState() => _ReelSideBarState();
}

class _ReelSideBarState extends State<ReelSideBar> {
  late bool isLiked;
  late int likesCount;

  @override
  void initState() {
    super.initState();
    isLiked = widget.reel.isLiked;
    likesCount = widget.reel.likesCount;
  }

  @override
  void didUpdateWidget(ReelSideBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reel.id != widget.reel.id || 
        oldWidget.reel.isLiked != widget.reel.isLiked ||
        oldWidget.reel.likesCount != widget.reel.likesCount) {
      isLiked = widget.reel.isLiked;
      likesCount = widget.reel.likesCount;
    }
  }

  void _toggleLike() async {
    final newIsLiked = !isLiked;
    final newLikesCount = newIsLiked ? likesCount + 1 : likesCount - 1;

    setState(() {
      isLiked = newIsLiked;
      likesCount = newLikesCount;
    });
    
    // إبلاغ الشاشة الرئيسية بالتحديث
    if (widget.onLikeChanged != null) {
      widget.onLikeChanged!(newIsLiked, newLikesCount);
    }

    bool success;
    if (newIsLiked) {
      success = await ApiService.likeReel(widget.myUserId, widget.reel.id!);
    } else {
      success = await ApiService.unlikeReel(widget.myUserId, widget.reel.id!);
    }

    if (!success && mounted) {
      setState(() {
        isLiked = !isLiked;
        likesCount += isLiked ? 1 : -1;
      });
      if (widget.onLikeChanged != null) {
        widget.onLikeChanged!(isLiked, likesCount);
      }
    }
  }

  void _showShareSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ShareReelSheet(
        reel: widget.reel,
        myUserId: widget.myUserId,
      ),
    );
  }

  void _showReportDialog() {
    final TextEditingController reportController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إبلاغ عن هذا الفيديو'),
        content: TextField(
          controller: reportController,
          decoration: const InputDecoration(
            hintText: 'سبب الإبلاغ...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final reason = reportController.text.trim();
              if (reason.isNotEmpty) {
                final success = await ApiService.submitReport(
                  widget.myUserId,
                  'reel',
                  widget.reel.id!,
                  reason,
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? 'تم إرسال الإبلاغ بنجاح' : 'فشل إرسال الإبلاغ')),
                  );
                }
              }
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isGuest = widget.myUserId == 'guest';
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildActionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          label: '$likesCount',
          color: isLiked ? Colors.red : Colors.white,
          onTap: isGuest ? () {} : _toggleLike,
        ),
        const SizedBox(height: 20),
        _buildActionButton(
          icon: Icons.comment_rounded,
          label: '${widget.reel.commentsCount}',
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => ReelCommentSheet(reel: widget.reel, myUserId: widget.myUserId),
            );
          },
        ),
        const SizedBox(height: 20),
        if (!isGuest) ...[
          _buildActionButton(
            icon: Icons.share_rounded,
            label: 'مشاركة',
            onTap: _showShareSheet,
          ),
          const SizedBox(height: 20),
        ],
        if (widget.reel.userId != widget.myUserId)
          _buildActionButton(
            icon: Icons.report_problem_outlined,
            label: 'إبلاغ',
            onTap: _showReportDialog,
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color color = Colors.white,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Icon(icon, color: color, size: 35),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _ShareReelSheet extends StatefulWidget {
  final Reel reel;
  final String myUserId;

  const _ShareReelSheet({required this.reel, required this.myUserId});

  @override
  State<_ShareReelSheet> createState() => _ShareReelSheetState();
}

class _ShareReelSheetState extends State<_ShareReelSheet> {
  List<Message> _recentChats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentChats();
  }

  Future<void> _loadRecentChats() async {
    final chats = await DatabaseService().getRecentChats(widget.myUserId);
    if (mounted) {
      setState(() {
        _recentChats = chats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'مشاركة مع الأصدقاء',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_recentChats.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[700]),
                    const SizedBox(height: 16),
                    const Text('لا توجد محادثات حديثة', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo')),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: _recentChats.length,
                itemBuilder: (context, index) {
                  final chat = _recentChats[index];
                  final peerId = chat.isMe ? chat.targetId : chat.senderId;

                  return FutureBuilder<Map<String, dynamic>?>(
                    future: ApiService.getProfile(peerId),
                    builder: (context, snapshot) {
                      final profile = snapshot.data;
                      final name = profile?['name'] ?? peerId;
                      final image = profile?['profileImage'];

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: image != null ? NetworkImage(AppConfig.parseMediaUrl(image)) : null,
                          child: image == null ? Text(name[0].toUpperCase()) : null,
                        ),
                        title: Text(name, style: const TextStyle(color: Colors.white, fontFamily: 'Cairo')),
                        trailing: ElevatedButton(
                          onPressed: () => _sendReelToUser(peerId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('إرسال', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          const Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(Icons.copy, color: Colors.white),
            title: const Text('نسخ الرابط', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
            onTap: () {
              // Copy link logic
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _sendReelToUser(String targetId) async {
    final message = 'شاهد هذا الفيديو التعليمي: ${widget.reel.title}\n${widget.reel.videoUrl}';
    
    await SocketService().sendMessage(targetId, message);
    
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال الفيديو بنجاح', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
