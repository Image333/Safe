import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeg/core/services/api_service.dart';
import 'package:safeg/core/services/auth_service.dart';
import 'package:safeg/core/services/trusted_contacts_service.dart';
import 'package:safeg/core/storage/auth_storage.dart';
import 'package:safeg/core/storage/trusted_contacts_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeApi extends ApiService {
  final List<TrustedContact> remote = [];
  int createCalls = 0;

  @override
  Future<List<TrustedContact>> listContacts({required String token}) async {
    return List.from(remote);
  }

  @override
  Future<TrustedContact> createContact({
    required String token,
    required String contactName,
    required String phoneNumber,
    String? email,
  }) async {
    createCalls++;
    final created = TrustedContact(
      contactId: remote.length + 1,
      name: contactName,
      phone: phoneNumber,
      email: email,
      inviteLink: 'https://t.me/bot?start=tok',
      inviteToken: 'tok',
    );
    remote.add(created);
    return created;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeApi api;
  late TrustedContactsStorage storage;
  late TrustedContactsService service;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    api = _FakeApi();
    storage = TrustedContactsStorage();
    final authStorage = AuthStorage();
    await authStorage.saveToken('jwt');
    service = TrustedContactsService(
      storage: storage,
      api: api,
      auth: AuthService(apiService: api, authStorage: authStorage),
    );
  });

  test('load pousse les contacts locaux puis remplace par la liste API', () async {
    await storage.save(const [
      TrustedContact(name: 'Alice', phone: '+33600000001'),
    ]);

    final loaded = await service.load();

    expect(api.createCalls, 1);
    expect(loaded, hasLength(1));
    expect(loaded.first.contactId, 1);
    expect(loaded.first.inviteLink, isNotNull);
    expect((await storage.load()).first.contactId, 1);
  });

  test('load sans token ne touche pas à l\'API', () async {
    await AuthStorage().clear();
    await storage.save(const [
      TrustedContact(name: 'Bob', phone: '+33600000002'),
    ]);

    final loaded = await service.load();

    expect(api.createCalls, 0);
    expect(loaded.map((c) => c.name), ['Bob']);
  });
}
