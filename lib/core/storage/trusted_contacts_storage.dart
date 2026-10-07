import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Contact de confiance (local + champs sync API Telegram).
class TrustedContact {
  final int? contactId;
  final String name;
  final String phone;
  final String? email;
  final String? inviteToken;
  final String? inviteLink;
  final bool telegramLinked;

  const TrustedContact({
    this.contactId,
    required this.name,
    required this.phone,
    this.email,
    this.inviteToken,
    this.inviteLink,
    this.telegramLinked = false,
  });

  TrustedContact copyWith({
    int? contactId,
    String? name,
    String? phone,
    String? email,
    String? inviteToken,
    String? inviteLink,
    bool? telegramLinked,
    bool clearEmail = false,
  }) {
    return TrustedContact(
      contactId: contactId ?? this.contactId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: clearEmail ? null : (email ?? this.email),
      inviteToken: inviteToken ?? this.inviteToken,
      inviteLink: inviteLink ?? this.inviteLink,
      telegramLinked: telegramLinked ?? this.telegramLinked,
    );
  }

  Map<String, dynamic> toJson() => {
        'contact_id': contactId,
        'name': name,
        'phone': phone,
        'email': email,
        'invite_token': inviteToken,
        'invite_link': inviteLink,
        'telegram_linked': telegramLinked,
      };

  factory TrustedContact.fromJson(Map<String, dynamic> json) {
    return TrustedContact(
      contactId: _asInt(json['contact_id'] ?? json['contactId']),
      name: (json['name'] ?? json['contact_name'] ?? '') as String,
      phone: (json['phone'] ?? json['phone_number'] ?? '') as String,
      email: json['email'] as String?,
      inviteToken: json['invite_token'] as String?,
      inviteLink: json['invite_link'] as String?,
      telegramLinked: json['telegram_linked'] == true,
    );
  }

  factory TrustedContact.fromApi(Map<String, dynamic> json) {
    return TrustedContact(
      contactId: _asInt(json['contact_id']),
      name: (json['contact_name'] ?? '') as String,
      phone: (json['phone_number'] ?? '') as String,
      email: json['email'] as String?,
      inviteToken: json['invite_token'] as String?,
      inviteLink: json['invite_link'] as String?,
      telegramLinked: json['telegram_linked'] == true,
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

class TrustedContactsStorage {
  static const _key = 'trusted_contacts_v2';

  Future<List<TrustedContact>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((e) => TrustedContact.fromJson(Map<String, dynamic>.from(e)))
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
