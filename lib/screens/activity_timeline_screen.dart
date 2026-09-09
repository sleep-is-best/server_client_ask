import 'package:flutter/material.dart';
import '../services/api_service.dart';

import 'package:intl/intl.dart';

class ActivityTimelineScreen extends StatefulWidget {
  final String studentId;
  const ActivityTimelineScreen({super.key, required this.studentId});

  @override
  State<ActivityTimelineScreen> createState() => _ActivityTimelineScreenState();
}

class _ActivityTimelineScreenState extends State<ActivityTimelineScreen> {
  bool _isLoading = true;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getReputationHistory(widget.studentId);
      setState(() {
        _history = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل النشاط والسمعة', style: TextStyle(fontFamily: 'Cairo')),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
            ? const Center(child: Text('لا يوجد سجل نشاط بعد'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final item = _history[index];
                  final points = item['points'] ?? 0;
                  final isPositive = points >= 0;
                  final date = DateTime.parse(item['timestamp']);
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isPositive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                        child: Icon(
                          isPositive ? Icons.add : Icons.remove,
                          color: isPositive ? Colors.green : Colors.red,
                        ),
                      ),
                      title: Text(item['reason'] ?? '', style: const TextStyle(fontFamily: 'Cairo')),
                      subtitle: Text(DateFormat('yyyy/MM/dd HH:mm').format(date)),
                      trailing: Text(
                        '${isPositive ? "+" : ""}$points',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isPositive ? Colors.green : Colors.red,
                          fontSize: 16
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
