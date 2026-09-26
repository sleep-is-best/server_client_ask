import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fast_contacts/fast_contacts.dart';
import '../services/contact_service.dart';
import '../utils/app_colors.dart';
import '../widgets/user_avatar.dart';
import '../widgets/app_card.dart';
import '../widgets/primary_button.dart';
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

  void _showLuxurySnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showAddManualNumber() {
    if (widget.myUserId == 'guest') {
      _showLuxurySnackBar('عذراً، يجب تسجيل الدخول لبدء محادثة');
      return;
    }
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'محادثة جديدة',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'أدخل رقم الهاتف للبدء بالتواصل الآمن',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo'),
              decoration: InputDecoration(
                hintText: 'رقم الهاتف (مثلاً: 777123456)',
                hintStyle: const TextStyle(color: AppColors.textHint, fontFamily: 'Cairo'),
                prefixIcon: const Icon(Icons.phone_rounded, color: AppColors.primary),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                filled: true,
                fillColor: AppColors.background,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          ),
          PrimaryButton(
            width: 120,
            text: 'بدء الآن',
            onPressed: () {
              String phoneNumber = controller.text.trim();
              if (phoneNumber.isNotEmpty) {
                Navigator.pop(dialogContext);
                String? normalized = ContactService.normalizePhoneNumber(phoneNumber);
                if (normalized != null && mounted) {
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
                   if (mounted) _showLuxurySnackBar('رقم الهاتف غير صالح');
                }
              }
            },
          ),
        ],
      ),
    );
  }


  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: Column(
          children: [
            const Text(
              'جهات الاتصال',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.textPrimary,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${_contacts.length} جهة اتصال',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 24),
            onPressed: () {
              HapticFeedback.mediumImpact();
              showSearch(
                context: context,
                delegate: ContactSearchDelegate(
                  contacts: _contacts,
                  myUserId: widget.myUserId,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: _filteredContacts.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return AppCard(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    color: AppColors.primary.withOpacity(0.05),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    onTap: widget.myUserId == 'guest' ? null : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('قريباً: إنشاء المجموعات التعليمية', style: TextStyle(fontFamily: 'Cairo')),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.group_add_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'مجموعة دراسية جديدة',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary, fontFamily: 'Cairo'),
                              ),
                              Text(
                                'تواصل وتعاون مع زملائك في الدراسة',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Cairo'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (index == 1) {
                  return AppCard(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    color: AppColors.secondary.withOpacity(0.05),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    onTap: _showAddManualNumber,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: AppColors.secondary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'بدء محادثة مباشرة',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.secondary, fontFamily: 'Cairo'),
                              ),
                              Text(
                                'تواصل مع مستخدم جديد عبر الرقم',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Cairo'),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.dialpad_rounded, color: AppColors.secondary, size: 20),
                      ],
                    ),
                  );
                }

                final contact = _filteredContacts[index - 2];
                final phone = contact.phones.isNotEmpty ? contact.phones.first.number : 'لا يوجد رقم';
                
                return AppCard(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: EdgeInsets.zero,
                  onTap: widget.myUserId == 'guest' ? null : () {
                    HapticFeedback.lightImpact();
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
                      _showLuxurySnackBar('جهة الاتصال هذه لا تملك رقم هاتف');
                    }
                  },
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: UserAvatar(
                      name: contact.displayName,
                      radius: 24,
                    ),
                    title: Text(
                      contact.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    subtitle: Text(
                      phone,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, letterSpacing: 1),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppColors.primary),
                    ),
                  ),
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
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primary),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo'),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear_rounded, color: AppColors.primary),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary, size: 20),
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

    return Container(
      color: AppColors.background,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final contact = filtered[index];
          final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
          return AppCard(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: EdgeInsets.zero,
            onTap: myUserId == 'guest' ? null : () {
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
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: UserAvatar(name: contact.displayName, radius: 24),
              title: Text(
                contact.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                  fontFamily: 'Cairo',
                ),
              ),
              subtitle: Text(
                phone,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, letterSpacing: 1),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary),
            ),
          );
        },
      ),
    );
  }
}
