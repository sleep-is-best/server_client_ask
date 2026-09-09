import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import 'contact_list_screen.dart';
import 'chat_screen.dart';
import '../models/message.dart';
import '../services/database_service.dart';
import '../services/contact_service.dart';
import '../utils/crypto_helper.dart';

class MainNavigationScreen extends StatefulWidget {
  final String myUserId;
  const MainNavigationScreen({super.key, required this.myUserId});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Luxury Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Color(0xFFD4AF37)), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert, color: Color(0xFFD4AF37)), onPressed: () {}),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFD4AF37),
          indicatorWeight: 3,
          labelColor: const Color(0xFFD4AF37),
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'الدردشات'),
            Tab(text: 'المكالمات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatList(),
          _buildCallLogs(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ContactListScreen(myUserId: widget.myUserId),
            ),
          );
        },
        backgroundColor: const Color(0xFFD4AF37),
        child: const Icon(Icons.chat, color: Colors.black),
      ),
    );
  }

  Widget _buildCallLogs() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _dbService.getCallLogs(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final logs = snapshot.data!;
        if (logs.isEmpty) {
          return const Center(child: Text('لا توجد مكالمات مؤخراً'));
        }
        return ListView.builder(
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            final isOut = log['callerId'] == widget.myUserId;
            final peerId = isOut ? log['receiverId'] : log['callerId'];
            
            return FutureBuilder<String?>(
              future: ContactService.getContactName(peerId),
              builder: (context, nameSnap) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey.shade200,
                    child: const Icon(Icons.person, color: Colors.black),
                  ),
                  title: Text(nameSnap.data ?? peerId, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Row(
                    children: [
                      Icon(
                        isOut ? Icons.call_made : Icons.call_received,
                        size: 14,
                        color: log['status'] == 'missed' ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 5),
                      Text(_formatTime(DateTime.parse(log['timestamp']))),
                    ],
                  ),
                  trailing: Icon(
                    log['type'] == 'video' ? Icons.videocam : Icons.call,
                    color: const Color(0xFF2196F3),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChatList() {
    return StreamBuilder<List<Message>>(
      stream: Stream.periodic(const Duration(seconds: 2)).asyncMap((_) => _dbService.getRecentChats(widget.myUserId)),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final chats = snapshot.data!;
        if (chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text('لا توجد دردشات بعد', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final lastMsg = chats[index];
            final peerId = lastMsg.isMe ? lastMsg.targetId : lastMsg.senderId;
            
            return FutureBuilder<String?>(
              future: ContactService.getContactName(peerId),
              builder: (context, nameSnapshot) {
                final displayName = nameSnapshot.data ?? peerId;
                String previewText = "";
                try {
                  previewText = CryptoHelper.decrypt(lastMsg.text);
                } catch (e) {
                  previewText = lastMsg.text;
                }

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey.shade300,
                    radius: 25,
                    child: const Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text(
                    previewText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatTime(lastMsg.timestamp),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      if (lastMsg.status != MessageStatus.read && !lastMsg.isMe)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF25D366),
                            shape: BoxShape.circle,
                          ),
                          child: const Text('1', style: TextStyle(color: Colors.white, fontSize: 10)),
                        ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          userId: widget.myUserId,
                          targetUserId: peerId,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (time.day == now.day && time.month == now.month && time.year == now.year) {
      return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
    }
    return "${time.day}/${time.month}";
  }
}
