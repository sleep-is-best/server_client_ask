import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/user_avatar.dart';
import '../widgets/question_card.dart';
import '../models/question.dart';
import 'user_profile_screen.dart';
import 'question_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final String myUserId;
  final String initialQuery;
  
  const SearchScreen({super.key, required this.myUserId, this.initialQuery = ''});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedType = 'all';
  List<dynamic> _results = [];
  bool _isLoading = false;

  final Map<String, String> _types = {
    'all': 'الكل',
    'students': 'طلاب',
    'questions': 'أسئلة',
    'reels': 'ريلز',
    'materials': 'ملفات',
  };

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    if (widget.initialQuery.isNotEmpty) {
      _performSearch();
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.search(query, type: _selectedType);
      if (mounted) {
        setState(() {
          _results = response['results'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء البحث: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: widget.initialQuery.isEmpty,
          decoration: const InputDecoration(
            hintText: 'ابحث عن أي شيء...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 18),
          onSubmitted: (_) => _performSearch(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _performSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTypeFilter(),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_results.isEmpty && _searchController.text.isNotEmpty)
            const Expanded(child: Center(child: Text('لا توجد نتائج')))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final item = _results[index];
                  return _buildResultItem(item);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _types.entries.map((e) {
          final isSelected = _selectedType == e.key;
          return Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: ChoiceChip(
              label: Text(e.value),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedType = e.key);
                  _performSearch();
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResultItem(Map<String, dynamic> item) {
    final type = item['resultType'];

    switch (type) {
      case 'student':
        return ListTile(
          leading: UserAvatar(name: item['name'], imageUrl: item['profileImage']),
          title: Text(item['name']),
          subtitle: Text('نقاط: ${item['points'] ?? 0}'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfileScreen(
                  myUserId: widget.myUserId,
                  userId: item['studentId'],
                ),
              ),
            );
          },
        );
      case 'question':
        final q = Question.fromMap(item);
        return QuestionCard(
          question: q,
          onTap: () {
             Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QuestionDetailScreen(
                  question: q,
                  myUserId: widget.myUserId,
                ),
              ),
            );
          },
        );
      case 'reel':
        return ListTile(
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              image: item['thumbnail'] != null 
                ? DecorationImage(image: NetworkImage(item['thumbnail']), fit: BoxFit.cover)
                : null,
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white),
          ),
          title: Text(item['title'] ?? 'فيديو'),
          subtitle: Text(item['caption'] ?? ''),
          onTap: () {
            // Navigate to reels screen focused on this reel
          },
        );
      case 'material':
        return ListTile(
          leading: const Icon(Icons.description, color: AppColors.primary),
          title: Text(item['title'] ?? ''),
          subtitle: Text('${item['subject_name']} - ${item['material_type']}'),
          onTap: () {
            // Navigate to material detail
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
