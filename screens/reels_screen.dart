import 'package:flutter/material.dart';
import '../models/reel.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/reel_video_player.dart';
import '../widgets/reel_side_bar.dart';
import '../widgets/reel_info_overlay.dart';
import 'create_reel_screen.dart';

class ReelsScreen extends StatefulWidget {
  final String myUserId;
  final List<Reel>? initialReels;
  final int initialIndex;

  const ReelsScreen({
    super.key,
    required this.myUserId,
    this.initialReels,
    this.initialIndex = 0,
  });

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> with AutomaticKeepAliveClientMixin {
  late PageController _pageController;
  List<Reel> _reels = [];
  bool _isLoading = true;
  int _currentPage = 1;
  late int _focusedIndex;
  String _feedType = 'feed'; // 'feed' (For You) or 'following'

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _focusedIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    if (widget.initialReels != null && widget.initialReels!.isNotEmpty) {
      _reels = List.from(widget.initialReels!);
      _isLoading = false;
      // If we have initial reels, we might still want to load more if we're near the end
    } else {
      _loadReels();
    }
  }

  Future<void> _loadReels({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _reels.clear();
    }
    
    final data = await ApiService.getReels(widget.myUserId, page: _currentPage, type: _feedType);
    final List<Reel> newReels = data.map((e) => Reel.fromMap(e)).toList();

    if (mounted) {
      setState(() {
        _reels.addAll(newReels);
        _isLoading = false;
        if (newReels.isNotEmpty) _currentPage++;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        floatingActionButton: widget.myUserId != 'guest'
            ? FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CreateReelScreen(myUserId: widget.myUserId)),
                  );
                },
                backgroundColor: AppColors.primary,
                elevation: 6,
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                label: const Text(
                  'إضافة ريل',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              )
            : null,
        body: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _reels.length,
              onPageChanged: (index) {
                if (mounted) setState(() => _focusedIndex = index);
                if (index >= _reels.length - 2) {
                  _loadReels();
                }
              },
              itemBuilder: (context, index) {
                final reel = _reels[index];
                return Stack(
                  children: [
                    ReelVideoPlayer(
                      reel: reel,
                      myUserId: widget.myUserId,
                      isVisible: _focusedIndex == index,
                    ),
                    Positioned(
                      right: 15,
                      bottom: 20,
                      child: ReelSideBar(reel: reel, myUserId: widget.myUserId),
                    ),
                    Positioned(
                      left: 15,
                      bottom: 20,
                      right: 80,
                      child: ReelInfoOverlay(reel: reel, myUserId: widget.myUserId),
                    ),
                  ],
                );
              },
            ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTab('متابعة', 'following'),
                            const SizedBox(width: 18),
                            _buildTab('لك', 'feed'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (_isLoading && _reels.isEmpty)
              const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, String type) {
    final bool isActive = _feedType == type;
    return GestureDetector(
      onTap: () {
        if (_feedType != type) {
          if (mounted) {
            setState(() {
              _feedType = type;
              _isLoading = true;
            });
          }
          _loadReels(refresh: true);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isActive ? AppColors.primary : Colors.white60,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 15,
              fontFamily: 'Cairo',
            ),
          ),
          if (isActive)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 2,
              width: 24,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
        ],
      ),
    );
  }
}
