import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TrustedContact {
  final String name;
  final String phone;

  const TrustedContact({required this.name, required this.phone});

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};

  factory TrustedContact.fromJson(Map<String, dynamic> json) {
    return TrustedContact(
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
    );
  }
}

class TrustedContactsStorage {
  static const _key = 'trusted_contacts';

  Future<List<TrustedContact>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(TrustedContact.fromJson)
          .where((c) => c.name.isNotEmpty && c.phone.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<TrustedContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(contacts.map((c) => c.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  Future<int> count() async {
    final contacts = await load();
    return contacts.length;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
