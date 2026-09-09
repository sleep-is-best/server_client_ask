import 'package:flutter/material.dart';
import '../models/reel.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import 'user_avatar.dart';

class ReelInfoOverlay extends StatefulWidget {
  final Reel reel;
  final String myUserId;

  const ReelInfoOverlay({
    super.key,
    required this.reel,
    required this.myUserId,
  });

  @override
  State<ReelInfoOverlay> createState() => _ReelInfoOverlayState();
}

class _ReelInfoOverlayState extends State<ReelInfoOverlay> {
  late bool isFollowing;

  @override
  void initState() {
    super.initState();
    isFollowing = widget.reel.isFollowing;
  }

  void _toggleFollow() async {
    setState(() {
      isFollowing = !isFollowing;
    });

    bool success;
    if (isFollowing) {
      success = await ApiService.followUser(widget.myUserId, widget.reel.creatorId);
    } else {
      success = await ApiService.unfollowUser(widget.myUserId, widget.reel.creatorId);
    }

    if (!success) {
      setState(() {
        isFollowing = !isFollowing;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.reel.title != null && widget.reel.title!.isNotEmpty) ...[
          Text(
            widget.reel.title!,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              shadows: [Shadow(blurRadius: 10, color: Colors.black45, offset: Offset(0, 2))],
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            UserAvatar(
              name: widget.reel.creatorName ?? widget.reel.userId,
              imageUrl: widget.reel.creatorProfileImage,
              radius: 18,
              showBorder: true,
            ),
            const SizedBox(width: 12),
            Text(
              widget.reel.creatorName ?? widget.reel.userId,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                shadows: [Shadow(blurRadius: 5, color: Colors.black45)],
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          widget.reel.caption,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.4,
            shadows: [Shadow(blurRadius: 5, color: Colors.black45)],
            fontFamily: 'Cairo',
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        if (widget.reel.reference != null && widget.reel.reference!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  widget.reel.reference!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}
