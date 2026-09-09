import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ReportsManagementScreen extends StatefulWidget {
  final String myUserId;
  const ReportsManagementScreen({super.key, required this.myUserId});

  @override
  State<ReportsManagementScreen> createState() => _ReportsManagementScreenState();
}

class _ReportsManagementScreenState extends State<ReportsManagementScreen> {
  List<dynamic> reports = [];
  bool isLoading = true;

  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadMoreRunning = false;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadReports();
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
      _loadMoreReports();
    }
  }

  Future<void> _loadReports() async {
    setState(() {
      isLoading = true;
      _currentPage = 1;
      _hasMore = true;
    });
    final data = await ApiService.getReports(widget.myUserId, page: 1);
    if (mounted) {
      setState(() {
        reports = data;
        isLoading = false;
        if (data.length < 20) _hasMore = false;
      });
    }
  }

  Future<void> _loadMoreReports() async {
    setState(() => _isLoadMoreRunning = true);
    _currentPage++;
    final data = await ApiService.getReports(widget.myUserId, page: _currentPage);
    if (mounted) {
      if (data.isNotEmpty) {
        setState(() {
          reports.addAll(data);
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
          title: const Text('إدارة البلاغات', 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: goldColor))
            : reports.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.report_off_rounded, size: 64, color: Colors.grey[800]),
                        const SizedBox(height: 16),
                        Text('لا توجد بلاغات حالياً', 
                          style: TextStyle(color: Colors.grey[600], fontSize: 18, fontFamily: 'Cairo')
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadReports,
                    color: goldColor,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: reports.length + (_isLoadMoreRunning ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == reports.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator(color: goldColor)),
                          );
                        }
                        final report = reports[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Text(
                              _translateTargetType(report['targetType']),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  report['reason'] ?? 'بدون سبب محدد',
                                  style: TextStyle(color: Colors.grey[400], fontFamily: 'Cairo', fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      report['createdAt'] ?? '',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 11, fontFamily: 'Cairo'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: _buildStatusBadge(report['status']),
                            onTap: () => _showReportDetails(report),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  String _translateTargetType(String? type) {
    switch (type) {
      case 'reel': return 'فيديو (ريلز)';
      case 'question': return 'سؤال';
      case 'comment': return 'تعليق';
      case 'student': return 'مستخدم';
      default: return 'بلاغ غير معروف';
    }
  }

  void _showReportDetails(dynamic report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تفاصيل البلاغ',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 20),
              _detailItem('النوع:', _translateTargetType(report['targetType'])),
              _detailItem('السبب:', report['reason'] ?? 'N/A'),
              _detailItem('المُبلغ:', report['reporterName'] ?? 'غير معروف'),
              _detailItem('تاريخ البلاغ:', report['createdAt'] ?? 'N/A'),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final success = await ApiService.resolveReport(widget.myUserId, report['id']);
                        if (mounted) {
                          if (success) {
                            Navigator.pop(context);
                            _loadReports();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حل البلاغ')));
                          }
                        }
                      },
                      child: const Text('تمييز كمحلول', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[900],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final success = await ApiService.deleteReportedContent(widget.myUserId, report['id']);
                        if (mounted) {
                          if (success) {
                            Navigator.pop(context);
                            _loadReports();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف المحتوى')));
                          }
                        }
                      },
                      child: const Text('حذف المحتوى', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
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

  Widget _detailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'))),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey;
    String label = 'غير محدد';
    
    if (status == 'pending') {
      color = Colors.orange;
      label = 'قيد الانتظار';
    } else if (status == 'resolved') {
      color = Colors.green;
      label = 'تم الحل';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
      ),
    );
  }
}
