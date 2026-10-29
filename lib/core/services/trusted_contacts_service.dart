import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../storage/trusted_contacts_storage.dart';

/// Synchronise les contacts locaux avec l'API (invite Telegram, CRUD).
class TrustedContactsService {
  final TrustedContactsStorage _storage;
  final ApiService _api;
  final AuthService _auth;

  TrustedContactsService({
    TrustedContactsStorage? storage,
    ApiService? api,
    AuthService? auth,
  })  : _storage = storage ?? TrustedContactsStorage(),
        _api = api ?? ApiService(),
        _auth = auth ?? AuthService();

  Future<List<TrustedContact>> loadLocal() => _storage.load();

  Future<void> saveLocal(List<TrustedContact> contacts) =>
      _storage.save(contacts);

  /// Charge depuis l'API si connecté, sinon le cache local.
  Future<List<TrustedContact>> load() async {
    final token = await _auth.getToken();
    if (token == null || token.isEmpty) {
      return _storage.load();
    }
    try {
      final remote = await _api.listContacts(token: token);
      await _storage.save(remote);
      return remote;
    } catch (_) {
      return _storage.load();
    }
  }

  /// Crée un contact : API si auth, sinon local uniquement.
  Future<TrustedContact> add({
    required String name,
    required String phone,
    String? email,
  }) async {
    final token = await _auth.getToken();
    if (token != null && token.isNotEmpty) {
      final created = await _api.createContact(
        token: token,
        contactName: name,
        phoneNumber: phone,
        email: email,
      );
      final list = await _storage.load();
      list.add(created);
      await _storage.save(list);
      return created;
    }

    final local = TrustedContact(
      name: name,
      phone: phone,
      email: (email == null || email.trim().isEmpty) ? null : email.trim(),
    );
    final list = await _storage.load();
    list.add(local);
    await _storage.save(list);
    return local;
  }

  Future<void> remove(TrustedContact contact) async {
    final token = await _auth.getToken();
    if (token != null &&
        token.isNotEmpty &&
        contact.contactId != null &&
        contact.contactId! > 0) {
      try {
        await _api.deleteContact(token: token, contactId: contact.contactId!);
      } catch (_) {
        // On retire quand même du cache local.
      }
    }
    final list = await _storage.load();
    list.removeWhere((c) {
      if (contact.contactId != null && c.contactId != null) {
        return c.contactId == contact.contactId;
      }
      return c.phone == contact.phone && c.name == contact.name;
    });
    await _storage.save(list);
  }

  /// Pousse un contact local vers l'API pour obtenir invite_link.
  Future<TrustedContact> ensureSynced(TrustedContact contact) async {
    if (contact.inviteLink != null &&
        contact.inviteLink!.isNotEmpty &&
        contact.contactId != null) {
      return contact;
    }

    final token = await _auth.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException(
        'Connectez-vous pour générer le lien d\'invitation Telegram.',
      );
    }

    if (contact.contactId != null && contact.contactId! > 0) {
      final remote = await _api.getContact(
        token: token,
        contactId: contact.contactId!,
      );
      await _replaceLocal(remote);
      return remote;
    }

    final created = await _api.createContact(
      token: token,
      contactName: contact.name,
      phoneNumber: contact.phone,
      email: contact.email,
    );
    final list = await _storage.load();
    final idx = list.indexWhere(
      (c) => c.phone == contact.phone && c.name == contact.name,
    );
    if (idx >= 0) {
      list[idx] = created;
    } else {
      list.add(created);
    }
    await _storage.save(list);
    return created;
  }

  Future<void> _replaceLocal(TrustedContact remote) async {
    final list = await _storage.load();
    final idx = list.indexWhere((c) => c.contactId == remote.contactId);
    if (idx >= 0) {
      list[idx] = remote;
    } else {
      list.add(remote);
    }
    await _storage.save(list);
  }

  Future<int> count() => _storage.count();
}
