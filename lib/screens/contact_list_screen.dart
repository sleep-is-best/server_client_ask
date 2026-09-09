import 'package:flutter/material.dart';
import 'package:fast_contacts/fast_contacts.dart';
import '../services/contact_service.dart';
import 'chat_screen.dart';

class ContactListScreen extends StatefulWidget {
  final String myUserId;
  const ContactListScreen({super.key, required this.myUserId});

  @override
  State<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final contacts = await ContactService.getContacts();
    if (mounted) {
      setState(() {
        _contacts = contacts;
        _filteredContacts = contacts;
        _isLoading = false;
      });
    }
  }

  void _filterContacts(String query) {
    setState(() {
      _filteredContacts = _contacts
          .where((contact) =>
              contact.displayName.toLowerCase().contains(query.toLowerCase()) ||
              contact.phones.any((phone) => phone.number.contains(query)))
          .toList();
    });
  }

  void _showAddManualNumber() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة رقم يدوياً'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: 'أدخل رقم الهاتف (مثلاً: 07xxxxxxxx)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              String phoneNumber = controller.text.trim();
              if (phoneNumber.isNotEmpty) {
                Navigator.pop(context);
                String? normalized = ContactService.normalizePhoneNumber(phoneNumber);
                if (normalized != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        userId: widget.myUserId,
                        targetUserId: normalized,
                      ),
                    ),
                  );
                } else {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('رقم الهاتف غير صالح')),
                  );
                }
              }
            },
            child: const Text('بدء الدردشة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('جهة اتصال جديدة'),
            Text(
              '${_contacts.length} جهة اتصال',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: ContactSearchDelegate(
                  contacts: _contacts,
                  myUserId: widget.myUserId,
                ),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : ListView.builder(
              itemCount: _filteredContacts.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFD4AF37),
                      child: Icon(Icons.group, color: Colors.black),
                    ),
                    title: const Text('مجموعة جديدة', style: TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('قريباً: إنشاء المجموعات')),
                      );
                    },
                  );
                }
                if (index == 1) {
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFD4AF37),
                      child: Icon(Icons.person_add, color: Colors.black),
                    ),
                    title: const Text('رقم هاتف جديد', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('بدء محادثة برقم غير مسجل'),
                    trailing: const Icon(Icons.dialpad, color: Color(0xFFD4AF37)),
                    onTap: _showAddManualNumber,
                  );
                }

                final contact = _filteredContacts[index - 2];
                final phone = contact.phones.isNotEmpty ? contact.phones.first.number : 'لا يوجد رقم';
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey.shade400,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(contact.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(phone),
                  onTap: () {
                    if (contact.phones.isNotEmpty) {
                      String? normalized = ContactService.normalizePhoneNumber(phone);
                      if (normalized != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              userId: widget.myUserId,
                              targetUserId: normalized,
                            ),
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('جهة الاتصال هذه لا تملك رقم هاتف')),
                      );
                    }
                  },
                );
              },
            ),
    );
  }
}

class ContactSearchDelegate extends SearchDelegate {
  final List<Contact> contacts;
  final String myUserId;

  ContactSearchDelegate({required this.contacts, required this.myUserId});

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList(context);
  }

  Widget _buildList(BuildContext context) {
    final filtered = contacts
        .where((c) =>
            c.displayName.toLowerCase().contains(query.toLowerCase()) ||
            c.phones.any((p) => p.number.contains(query)))
        .toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final contact = filtered[index];
        final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
        return ListTile(
          title: Text(contact.displayName),
          subtitle: Text(phone),
          onTap: () {
            String? normalized = ContactService.normalizePhoneNumber(phone);
            if (normalized != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    userId: myUserId,
                    targetUserId: normalized,
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}
