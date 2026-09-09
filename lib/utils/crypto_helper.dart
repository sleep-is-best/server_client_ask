import 'package:encrypt/encrypt.dart' as enc;
import 'dart:typed_data';

class CryptoHelper {
  static final _key = enc.Key.fromUtf8('my32lengthsupersecretnooneknows1');
  static final _encrypter = enc.Encrypter(enc.AES(_key));

  static String encryptText(String text) {
    if (text.isEmpty) return text;
    final iv = enc.IV.fromSecureRandom(16);
    final encrypted = _encrypter.encrypt(text, iv: iv);
    // ندمج IV مع النص المشفر لسهولة النقل
    return "${iv.base64}:${encrypted.base64}";
  }

  static String decryptText(String? cipherText) {
    try {
      if (cipherText == null || cipherText.isEmpty) return cipherText ?? "";
      final parts = cipherText.split(':');
      if (parts.length != 2) return decryptOld(cipherText); 

      final iv = enc.IV.fromBase64(parts[0]);
      final encryptedText = parts[1];
      return _encrypter.decrypt64(encryptedText, iv: iv);
    } catch (e) {
      print("Decryption Error: $e");
      return "[Error]";
    }
  }

  static String decryptOld(String cipherText) {
    try {
      final iv = enc.IV.fromLength(16);
      return _encrypter.decrypt64(cipherText, iv: iv);
    } catch (e) {
      return "[خطأ]";
    }
  }
  
  static String encrypt(String text) => encryptText(text);
  static String decrypt(String text) => decryptText(text);

  // تشفير الملفات (Bytes)
  static List<int> encryptBytes(List<int> bytes) {
    final iv = enc.IV.fromSecureRandom(16);
    final encrypted = _encrypter.encryptBytes(bytes, iv: iv);
    // ندمج الـ IV في بداية البيانات المشفرة
    return iv.bytes + encrypted.bytes;
  }

  static List<int> decryptBytes(List<int> encryptedBytes) {
    try {
      final iv = enc.IV(Uint8List.fromList(encryptedBytes.sublist(0, 16)));
      final data = Uint8List.fromList(encryptedBytes.sublist(16));
      return _encrypter.decryptBytes(enc.Encrypted(data), iv: iv);
    } catch (e) {
      print("File Decryption Error: $e");
      return [];
    }
  }
}
