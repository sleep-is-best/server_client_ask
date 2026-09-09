import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/reel.dart';

class ReelManagementScreen extends StatefulWidget {
  final String myUserId;
  const ReelManagementScreen({super.key, required this.myUserId});

  @override
  State<ReelManagementScreen> createState() => _ReelManagementScreenState();
}

class _ReelManagementScreenState extends State<ReelManagementScreen> {
  List<Reel> _reels = [];
  bool _isLoading = true;

  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadMoreRunning = false;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadReels();
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
      _loadMoreReels();
    }
  }

  Future<void> _loadReels() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasMore = true;
    });
    final data = await ApiService.getReels(widget.myUserId, type: 'all', page: 1);
    if (mounted) {
      setState(() {
        _reels = data.map((e) => Reel.fromMap(e)).toList();
        _isLoading = false;
        if (data.length < 10) _hasMore = false;
      });
    }
  }

  Future<void> _loadMoreReels() async {
    setState(() => _isLoadMoreRunning = true);
    _currentPage++;
    final data = await ApiService.getReels(widget.myUserId, type: 'all', page: _currentPage);
    if (mounted) {
      if (data.isNotEmpty) {
        setState(() {
          _reels.addAll(data.map((e) => Reel.fromMap(e)).toList());
          if (data.length < 10) _hasMore = false;
        });
      } else {
        setState(() => _hasMore = false);
      }
      setState(() => _isLoadMoreRunning = false);
    }
  }

  Future<void> _deleteReel(String reelId) async {
    final success = await ApiService.deleteReel(widget.myUserId, reelId);
    if (mounted) {
      if (success) {
        _loadReels();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الفيديو بنجاح')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const goldColor = Color(0xFFD4AF37);
    const darkBg = Color(0xFF0A0A0A);
    const cardBg = Color(0xFF1A1A1A);
    
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: darkBg,
        appBar: AppBar(
          title: const Text('إدارة الفيديوهات', 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: goldColor))
            : _reels.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_collection_outlined, size: 64, color: Colors.grey[800]),
                        const SizedBox(height: 16),
                        Text('لا توجد فيديوهات حالياً', 
                          style: TextStyle(color: Colors.grey[600], fontSize: 18, fontFamily: 'Cairo')
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadReels,
                    color: goldColor,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _reels.length + (_isLoadMoreRunning ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _reels.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator(color: goldColor)),
                          );
                        }
                        final reel = _reels[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: goldColor.withValues(alpha: 0.3)),
                              ),
                              child: const Icon(Icons.play_circle_fill, color: goldColor, size: 30),
                            ),
                            title: Text(
                              reel.caption,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'بواسطة: ${reel.creatorName} • ${reel.viewsCount} مشاهدة',
                              style: TextStyle(color: Colors.grey[500], fontFamily: 'Cairo', fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                              onPressed: () => _showDeleteDialog(reel),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  void _showDeleteDialog(Reel reel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('حذف الفيديو؟', style: TextStyle(color: Colors.white)),
        content: const Text('هل أنت متأكد من حذف هذا الفيديو بشكل نهائي؟', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteReel(reel.id!);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
