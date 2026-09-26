class AppConfig {
  // إعدادات السيرفر المركزية
  static String serverHost = '192.168.8.185';
  static String? currentStudentId;
  static const int serverPort = 3000;
  static const int imageServerPort = 3001; // منفذ الفيديو
  static const int audioServerPort = 3002; // منفذ الصوت

  static String get serverUrl => 'http://$serverHost:$serverPort';
  static set serverUrl(String value) {
    if (value.isEmpty) return;
    String cleanValue = value.trim();
    // إزالة البروتوكول إذا وجد
    cleanValue = cleanValue.replaceFirst(RegExp(r'^https?://'), '');
    
    // نأخذ فقط الآيبي ونتجاهل المنفذ إذا تم إدخاله
    if (cleanValue.contains(':')) {
      serverHost = cleanValue.split(':')[0];
    } else {
      serverHost = cleanValue;
    }
    // المنافذ ثابتة وتلقائية: 3000, 3001, 3002 كما هو محدد في الخادم
  }
  static String get chatServerUrl => serverUrl;
  static String get imageServerUrl => 'http://$serverHost:$imageServerPort';
  static String get audioServerUrl => 'http://$serverHost:$audioServerPort';
  static String get fileServerUrl => serverUrl;

  // مفتاح التشفير (يجب أن يكون 32 حرفاً لنظام AES-256)
  static const String encryptionKey = 'my32lengthsupersecretnooneknows1';

  // إعدادات WebRTC المتقدمة لتجاوز جدران الحماية (NAT Traversal)
  static const Map<String, dynamic> webRTCConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': '4c61bae72f1aa65a1e73c67b',
        'credential': 'j6/CvxcyR3Wx15ut'
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': '4c61bae72f1aa65a1e73c67b',
        'credential': 'j6/CvxcyR3Wx15ut'
      },
      {
        'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
        'username': '4c61bae72f1aa65a1e73c67b',
        'credential': 'j6/CvxcyR3Wx15ut'
      },
    ],
    'sdpSemantics': 'unified-plan',
    'iceCandidatePoolSize': 20,
  };
}
