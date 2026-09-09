import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AdminLogsScreen extends StatefulWidget {
  final String myUserId;
  const AdminLogsScreen({super.key, required this.myUserId});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
  List<dynamic> logs = [];
  bool isLoading = true;

  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadMoreRunning = false;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadLogs();
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
      _loadMoreLogs();
    }
  }

  Future<void> _loadLogs() async {
    setState(() {
      isLoading = true;
      _currentPage = 1;
      _hasMore = true;
    });
    final data = await ApiService.getAdminLogs(widget.myUserId, page: 1);
    if (mounted) {
      setState(() {
        logs = data; // Usually logs are already sorted by time on server
        isLoading = false;
        if (data.length < 20) _hasMore = false;
      });
    }
  }

  Future<void> _loadMoreLogs() async {
    setState(() => _isLoadMoreRunning = true);
    _currentPage++;
    final data = await ApiService.getAdminLogs(widget.myUserId, page: _currentPage);
    if (mounted) {
      if (data.isNotEmpty) {
        setState(() {
          logs.addAll(data);
          if (data.length < 20) _hasMore = false;
        });
      } else {
        setState(() => _hasMore = false);
      }
      setState(() => _isLoadMoreRunning = false);
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
          title: const Text('سجل العمليات', 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: goldColor))
            : logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey[800]),
                        const SizedBox(height: 16),
                        Text('السجل فارغ حالياً', 
                          style: TextStyle(color: Colors.grey[600], fontSize: 18, fontFamily: 'Cairo')
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadLogs,
                    color: goldColor,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: logs.length + (_isLoadMoreRunning ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == logs.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator(color: goldColor)),
                          );
                        }
                        final log = logs[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: goldColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.history_edu_rounded, color: goldColor, size: 20),
                            ),
                            title: Text(
                              log['action'] ?? 'عملية غير معروفة',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14),
                            ),
                            subtitle: Text(
                              'بواسطة: ${log['adminId']} • الهدف: ${log['targetId']}',
                              style: TextStyle(color: Colors.grey[500], fontFamily: 'Cairo', fontSize: 12),
                            ),
                            trailing: Text(
                              log['timestamp'].toString().length > 10 
                                ? log['timestamp'].toString().substring(0, 10) 
                                : log['timestamp'].toString(),
                              style: TextStyle(color: Colors.grey[600], fontSize: 10, fontFamily: 'Cairo'),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
