import 'package:encrypt/encrypt.dart' as enc;
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class CryptoHelper {
  static final _key = enc.Key.fromUtf8(AppConfig.encryptionKey.padRight(32).substring(0, 32));

  // الخوارزميات المدعومة
  static const int ALGO_AES = 0;
  static const int ALGO_SALSA20 = 1;
  static const int ALGO_FERNET = 2;

  static enc.Encrypter _getEncrypter(int algo) {
    switch (algo) {
      case ALGO_SALSA20:
        return enc.Encrypter(enc.Salsa20(_key));
      case ALGO_FERNET:
        return enc.Encrypter(enc.Fernet(enc.Key.fromUtf8(AppConfig.encryptionKey.padRight(32).substring(0, 32))));
      case ALGO_AES:
      default:
        return enc.Encrypter(enc.AES(_key));
    }
  }

  static int? _cachedAlgo;

  static Future<int> getSelectedAlgorithm() async {
    if (_cachedAlgo != null) return _cachedAlgo!;
    final prefs = await SharedPreferences.getInstance();
    _cachedAlgo = prefs.getInt('encryption_algorithm') ?? ALGO_AES;
    return _cachedAlgo!;
  }

  static void updateCache(int algo) {
    _cachedAlgo = algo;
  }

  static Future<String> encrypt(String text) async {
    if (text.isEmpty) return text;
    int algo = await getSelectedAlgorithm();
    return encryptWithAlgo(text, algo);
  }

  static String encryptWithAlgo(String text, int algo) {
    if (text.isEmpty) return text;
    final encrypter = _getEncrypter(algo);
    final iv = enc.IV.fromSecureRandom(16);
    
    String encryptedBase64;
    if (algo == ALGO_FERNET) {
      encryptedBase64 = encrypter.encrypt(text).base64;
    } else {
      encryptedBase64 = encrypter.encrypt(text, iv: iv).base64;
    }

    return "${iv.base64}:$encryptedBase64|$algo";
  }

  // دعم تشفير البيانات الثنائية (الملفات)
  static Uint8List encryptBytes(Uint8List data, int algo, enc.IV iv) {
    final encrypter = _getEncrypter(algo);
    if (algo == ALGO_FERNET) {
      return encrypter.encryptBytes(data).bytes;
    } else {
      return encrypter.encryptBytes(data, iv: iv).bytes;
    }
  }

  static Uint8List decryptBytes(Uint8List encryptedData, int algo, enc.IV iv) {
    final encrypter = _getEncrypter(algo);
    if (algo == ALGO_FERNET) {
      return Uint8List.fromList(encrypter.decryptBytes(enc.Encrypted(encryptedData)));
    } else {
      return Uint8List.fromList(encrypter.decryptBytes(enc.Encrypted(encryptedData), iv: iv));
    }
  }

  static String decrypt(String cipherText) {
    try {
      if (cipherText.isEmpty) return "";
      
      // إذا كان النص لا يحتوي على علامات التشفير الخاصة بنا، فقد يكون نصاً عادياً أو قديماً
      if (!cipherText.contains('|') && !cipherText.contains(':')) {
        return cipherText;
      }

      // استخراج رقم الخوارزمية من النهاية
      final mainParts = cipherText.split('|');
      if (mainParts.length < 2) return _decryptLegacy(cipherText);
      
      int algo = int.tryParse(mainParts.last) ?? ALGO_AES;
      String dataPart = mainParts.first;
      
      final dataParts = dataPart.split(':');
      // Fernet لا يحتاج IV منفصل في التنسيق الخاص بنا لأنه مدمج
      if (algo != ALGO_FERNET && dataParts.length < 2) return dataPart;

      final encrypter = _getEncrypter(algo);
      
      if (algo == ALGO_FERNET) {
        return encrypter.decrypt(enc.Encrypted.fromBase64(dataPart));
      } else {
        final iv = enc.IV.fromBase64(dataParts[0]);
        final encrypted = dataParts[1];
        return encrypter.decrypt64(encrypted, iv: iv);
      }
    } catch (e) {
      // إذا فشل فك التشفير، نعيد النص الأصلي فقد يكون غير مشفر
      return cipherText;
    }
  }

  static String _decryptLegacy(String cipherText) {
    try {
      final parts = cipherText.split(':');
      if (parts.length != 2) return cipherText;
      final encrypter = enc.Encrypter(enc.AES(_key));
      final iv = enc.IV.fromBase64(parts[0]);
      return encrypter.decrypt64(parts[1], iv: iv);
    } catch (e) {
      return cipherText;
    }
  }

  // لاستخراج النص المشفر الخام للعرض (بدون IV أو رقم الخوارزمية)
  static String getRawCipherText(String cipherText) {
    final mainParts = cipherText.split('|');
    String dataPart = mainParts.first;
    final dataParts = dataPart.split(':');
    return dataParts.length > 1 ? dataParts[1] : dataParts[0];
  }
}
