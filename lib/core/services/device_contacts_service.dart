import 'package:flutter_contacts/flutter_contacts.dart';

class DeviceContactEntry {
  final String name;
  final String phone;
  final String? label;

  const DeviceContactEntry({
    required this.name,
    required this.phone,
    this.label,
  });
}

class DeviceContactsService {
  static Future<bool> hasPermission() =>
      FlutterContacts.permissions.has(PermissionType.read);

  static Future<bool> requestPermission() async {
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    return status == PermissionStatus.granted || status == PermissionStatus.limited;
  }

  static Future<List<DeviceContactEntry>> loadContacts() async {
    if (!await hasPermission()) return [];

    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone},
    );

    final entries = <DeviceContactEntry>[];
    for (final contact in contacts) {
      if (contact.phones.isEmpty) continue;

      final phones = _sortPhones(contact.phones);
      for (final phone in phones) {
        final number = phone.number.trim();
        if (number.isEmpty) continue;

        entries.add(DeviceContactEntry(
          name: _contactName(contact),
          phone: number,
          label: _phoneLabel(phone.label),
        ));
      }
    }

    entries.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return entries;
  }

  static String _contactName(Contact contact) {
    final name = contact.displayName?.trim();
    return name == null || name.isEmpty ? 'Sans nom' : name;
  }

  static String? _phoneLabel(Label<PhoneLabel> label) {
    if (label.label == PhoneLabel.mobile) return null;
    if (label.label == PhoneLabel.custom) return label.customLabel;
    return label.label.name;
  }

  static List<Phone> _sortPhones(List<Phone> phones) {
    final sorted = List<Phone>.from(phones);
    sorted.sort((a, b) {
      final aMobile = a.label.label == PhoneLabel.mobile;
      final bMobile = b.label.label == PhoneLabel.mobile;
      if (aMobile != bMobile) return aMobile ? -1 : 1;
      if (a.isPrimary == true && b.isPrimary != true) return -1;
      if (b.isPrimary == true && a.isPrimary != true) return 1;
      return a.number.compareTo(b.number);
    });
    return sorted;
  }

  static String normalizePhone(String phone) =>
      phone.replaceAll(RegExp(r'\D'), '');
}
