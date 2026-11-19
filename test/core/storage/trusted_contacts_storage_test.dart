import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeg/core/storage/trusted_contacts_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'trusted_contacts_v2';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('TrustedContactsStorage', () {
    test('save puis load renvoie les contacts depuis le stockage sécurisé', () async {
      final storage = TrustedContactsStorage();
      await storage.save(const [
        TrustedContact(contactId: 1, name: 'Alice', phone: '+33600000001', telegramLinked: true),
      ]);

      final contacts = await storage.load();
      expect(contacts, hasLength(1));
      expect(contacts.first.name, 'Alice');
      expect(contacts.first.telegramLinked, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_key), isNull, reason: 'aucune donnée en clair');
    });

    test('migre les contacts en clair de SharedPreferences', () async {
      final legacy = jsonEncode([
        {'name': 'Bob', 'phone': '+33600000002'},
      ]);
      SharedPreferences.setMockInitialValues({_key: legacy});

      const secure = FlutterSecureStorage();
      final storage = TrustedContactsStorage(storage: secure);

      final contacts = await storage.load();
      expect(contacts.map((c) => c.name), ['Bob']);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_key), isNull);
      expect(await secure.read(key: _key), legacy);
    });

    test('ignore les contacts incomplets et les données corrompues', () async {
      const secure = FlutterSecureStorage();
      final storage = TrustedContactsStorage(storage: secure);

      await secure.write(
        key: _key,
        value: jsonEncode([
          {'name': 'Sans numéro', 'phone': ''},
          {'name': 'Carol', 'phone': '+33600000003'},
        ]),
      );
      expect((await storage.load()).map((c) => c.name), ['Carol']);

      await secure.write(key: _key, value: 'pas du json');
      expect(await storage.load(), isEmpty);
    });

    test('clear supprime les contacts', () async {
      final storage = TrustedContactsStorage();
      await storage.save(const [TrustedContact(name: 'Dan', phone: '+33600000004')]);

      await storage.clear();
      expect(await storage.count(), 0);
    });
  });

  group('TrustedContact.fromApi', () {
    test('lit les champs renvoyés par GET /contacts', () {
      final contact = TrustedContact.fromApi({
        'contact_id': '7',
        'contact_name': 'Eve',
        'phone_number': '+33600000005',
        'invite_link': 'https://t.me/SafeAlertBot?start=abc',
        'telegram_linked': true,
      });

      expect(contact.contactId, 7);
      expect(contact.name, 'Eve');
      expect(contact.phone, '+33600000005');
      expect(contact.telegramLinked, isTrue);
    });
  });
}
