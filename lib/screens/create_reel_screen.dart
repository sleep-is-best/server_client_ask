import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../services/api_service.dart';

class CreateReelScreen extends StatefulWidget {
  final String myUserId;
  const CreateReelScreen({super.key, required this.myUserId});

  @override
  State<CreateReelScreen> createState() => _CreateReelScreenState();
}

class _CreateReelScreenState extends State<CreateReelScreen> {
  File? _videoFile;
  String? _uploadedVideoUrl;
  VideoPlayerController? _videoController;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _hashtagsController = TextEditingController();
  bool _isUploading = false;

  Future<void> _pickVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    
    if (video != null) {
      // If we already had an uploaded video, delete it
      if (_uploadedVideoUrl != null) {
        ApiService.deleteTempFile(_uploadedVideoUrl!, widget.myUserId);
      }

      setState(() {
        _videoFile = File(video.path);
        _uploadedVideoUrl = null;
        _isUploading = true;
        _videoController = VideoPlayerController.file(_videoFile!)
          ..initialize().then((_) {
            setState(() {});
            _videoController!.play();
            _videoController!.setLooping(true);
          });
      });

      try {
        final url = await ApiService.uploadFile(_videoFile!.path, widget.myUserId, type: 'video', isTemp: true);
        if (mounted) {
          if (url != null) {
            setState(() => _uploadedVideoUrl = url);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل رفع الفيديو مؤقتاً')));
          }
        }
      } catch (e) {
        debugPrint('Reel upload error: $e');
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _uploadReel() async {
    if (_uploadedVideoUrl == null || _titleController.text.isEmpty || _captionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار فيديو (والانتظار للرفع) وإضافة عنوان ووصف')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Post reel metadata
      final success = await ApiService.postReel(widget.myUserId, {
        'video_url': _uploadedVideoUrl,
        'title': _titleController.text,
        'caption': _captionController.text,
        'reference': _referenceController.text,
        'hashtags': _hashtagsController.text.split(' ').where((s) => s.isNotEmpty).toList(),
        'duration': _videoController?.value.duration.inSeconds ?? 0,
      });

      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم نشر الفيديو بنجاح!')),
        );
      }
    } catch (e) {
      debugPrint('Metadata post error: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _titleController.dispose();
    _captionController.dispose();
    _referenceController.dispose();
    _hashtagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const goldColor = Color(0xFFD4AF37);
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('فيديو جديد', style: TextStyle(color: Colors.white)),
        actions: [
          if (!_isUploading)
            TextButton(
              onPressed: _uploadReel,
              child: const Text('نشر', style: TextStyle(color: goldColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: _isUploading
          ? const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: goldColor),
                SizedBox(height: 20),
                Text('جاري النشر...', style: TextStyle(color: Colors.white)),
              ],
            ))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: _pickVideo,
                    child: Container(
                      height: 300,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: _videoController != null && _videoController!.value.isInitialized
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: AspectRatio(
                                aspectRatio: _videoController!.value.aspectRatio,
                                child: VideoPlayer(_videoController!),
                              ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.video_library, size: 50, color: Colors.white54),
                                SizedBox(height: 10),
                                Text('اضغط لاختيار فيديو', style: TextStyle(color: Colors.white54)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'عنوان الفيديو',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _captionController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'اكتب وصفاً للفيديو...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _referenceController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'المرجع (اختياري)',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _hashtagsController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'أضف وسوم (مثال: #تعليم #برمجة)',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
