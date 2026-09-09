import 'package:fast_contacts/fast_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactService {
  static Future<List<Contact>> getContacts() async {
    bool permissionStatus = await Permission.contacts.isGranted;
    if (!permissionStatus) {
      final status = await Permission.contacts.request();
      if (!status.isGranted) {
        return [];
      }
    }
    return await FastContacts.getAllContacts();
  }

  static String? normalizePhoneNumber(String phone) {
    // Remove all non-digit characters except +
    String normalized = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    // If it starts with 00, replace with +
    if (normalized.startsWith('00')) {
      normalized = '+' + normalized.substring(2);
    }
    
    // Basic normalization: if it's a local number (e.g., 01...) you might want to add country code
    // but for now we just return the cleaned string.
    return normalized.isNotEmpty ? normalized : null;
  }

  static Future<String?> getContactName(String phoneNumber) async {
    final contacts = await getContacts();
    for (var contact in contacts) {
      for (var phone in contact.phones) {
        if (normalizePhoneNumber(phone.number) == normalizePhoneNumber(phoneNumber)) {
          return contact.displayName;
        }
      }
    }
    return null;
  }
}
