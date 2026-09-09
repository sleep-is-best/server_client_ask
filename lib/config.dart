class AppConfig {
  // إعدادات السيرفر المركزية
  static String _serverHost = '192.168.8.185';
  static String get serverHost => _serverHost;
  static set serverHost(String value) => _serverHost = value;

  static const int serverPort = 3000;

  static String get serverUrl => 'http://$_serverHost:$serverPort';
  static set serverUrl(String value) {
    if (value.isEmpty) return;
    String cleanValue = value.trim();
    // إزالة البروتوكول إذا وجد
    cleanValue = cleanValue.replaceFirst(RegExp(r'^https?://'), '');
    
    // نأخذ فقط الآيبي ونتجاهل المنفذ إذا تم إدخاله
    if (cleanValue.contains(':')) {
      _serverHost = cleanValue.split(':')[0];
    } else {
      _serverHost = cleanValue;
    }
  }
  static String get chatServerUrl => serverUrl;
  static String get fileServerUrl => serverUrl;

  static String get imageUploadUrl => '$serverUrl/api/upload';
  static String get audioUploadUrl => '$serverUrl/api/upload';

  static String parseMediaUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (!url.startsWith('http')) return '$serverUrl$url';
    
    try {
      Uri uri = Uri.parse(url);
      return uri.replace(host: _serverHost, scheme: 'http').toString();
    } catch (e) {
      return url;
    }
  }

  static const String encryptionKey = 'my32lengthsupersecretnooneknows1';

  // WebRTC ICE Servers Configuration
  static Map<String, dynamic> iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      // يمكن إضافة TURN server هنا لضمان العمل خلف NAT المعقد
      // {
      //   'urls': 'turn:your-turn-server.com:3478',
      //   'username': 'user',
      //   'credential': 'password'
      // }
    ]
  };
}
