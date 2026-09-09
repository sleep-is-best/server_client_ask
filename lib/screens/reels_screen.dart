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

class _ReelsScreenState extends State<ReelsScreen> {
  late PageController _pageController;
  List<Reel> _reels = [];
  bool _isLoading = true;
  int _currentPage = 1;
  late int _focusedIndex;
  String _feedType = 'feed'; // 'feed' (For You) or 'following'

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
    List<Reel> newReels = data.map((e) => Reel.fromMap(e)).toList();

    // محاكاة خوارزمية بسيطة عبر خلط النتائج إذا كانت الصفحة الأولى
    if (_currentPage == 1 && _feedType == 'feed') {
      newReels.shuffle();
    }

    if (mounted) {
      setState(() {
        _reels.addAll(newReels);
        _isLoading = false;
        if (newReels.isNotEmpty) _currentPage++;
      });
    }
  }

  void _updateReelState(int index, bool isLiked, int likesCount) {
    if (index < _reels.length) {
      setState(() {
        _reels[index] = _reels[index].copyWith(
          isLiked: isLiked,
          likesCount: likesCount,
        );
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
    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButton: widget.myUserId != 'guest'
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CreateReelScreen(myUserId: widget.myUserId)),
                );
              },
              backgroundColor: AppColors.primary,
              elevation: 4,
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
            )
          : null,
      body: Stack(
        children: [
          // Feed
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _reels.length,
            onPageChanged: (index) {
              setState(() => _focusedIndex = index);
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
                  // Overlays
                  Positioned(
                    right: 15,
                    bottom: 20,
                    child: ReelSideBar(
                      reel: reel,
                      myUserId: widget.myUserId,
                      onLikeChanged: (isLiked, count) => _updateReelState(index, isLiked, count),
                    ),
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
          
          // Top Tabs
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTab('متابعة', 'following'),
                const SizedBox(width: 20),
                _buildTab('لك', 'feed'),
              ],
            ),
          ),
          
          if (_isLoading && _reels.isEmpty)
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            
          // Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 5,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, String type) {
    final bool isActive = _feedType == type;
    return GestureDetector(
      onTap: () {
        if (_feedType != type) {
          setState(() {
            _feedType = type;
            _isLoading = true;
          });
          _loadReels(refresh: true);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white60,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
          ),
          if (isActive)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 2,
              width: 20,
              color: Colors.white,
            ),
        ],
      ),
    );
  }
}
