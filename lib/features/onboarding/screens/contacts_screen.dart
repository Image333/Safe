import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/device_contacts_service.dart';
import '../../../core/services/trusted_contacts_service.dart';
import '../../../core/storage/trusted_contacts_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../widgets/contact_picker_sheet.dart';
import '../widgets/telegram_invite_sheet.dart';

enum ContactsScreenMode { onboarding, settings }

class ContactsScreen extends StatefulWidget {
  final ContactsScreenMode mode;

  const ContactsScreen({super.key, this.mode = ContactsScreenMode.onboarding});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TrustedContactsService _contactsService = TrustedContactsService();
  final List<TrustedContact> _contacts = [];
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _loading = true;
  bool _showImportButton = true;
  List<DeviceContactEntry> _deviceContacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _checkExistingDeviceContacts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final list = await _contactsService.load();
    if (!mounted) return;
    setState(() {
      _contacts
        ..clear()
        ..addAll(list);
      _loading = false;
    });
  }

  Set<String> get _addedPhones =>
      _contacts.map((c) => DeviceContactsService.normalizePhone(c.phone)).toSet();

  Future<void> _checkExistingDeviceContacts() async {
    if (!await DeviceContactsService.hasPermission()) return;

    final entries = await DeviceContactsService.loadContacts();
    if (!mounted) return;

    setState(() {
      _deviceContacts = entries;
      _showImportButton = entries.isNotEmpty;
    });
  }

  Future<void> _addContact({String? name, String? phone, String? email}) async {
    final contactName = (name ?? _nameController.text).trim();
    final contactPhone = (phone ?? _phoneController.text).trim();
    final contactEmail = (email ?? _emailController.text).trim();
    if (contactName.isEmpty || contactPhone.isEmpty) return;

    final normalized = DeviceContactsService.normalizePhone(contactPhone);
    if (_addedPhones.contains(normalized)) return;

    try {
      final created = await _contactsService.add(
        name: contactName,
        phone: contactPhone,
        email: contactEmail.isEmpty ? null : contactEmail,
      );
      if (!mounted) return;
      setState(() {
        _contacts.add(created);
        _nameController.clear();
        _phoneController.clear();
        _emailController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : 'Impossible d\'ajouter le contact';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _addContactsFromDevice(List<DeviceContactEntry> entries) async {
    final addedPhones = Set<String>.from(_addedPhones);
    for (final entry in entries) {
      final normalized = DeviceContactsService.normalizePhone(entry.phone);
      if (addedPhones.contains(normalized)) continue;
      try {
        final created = await _contactsService.add(
          name: entry.name,
          phone: entry.phone,
        );
        _contacts.add(created);
        addedPhones.add(normalized);
      } catch (_) {
        // Ignore individual failures on batch import
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _removeContact(int index) async {
    final contact = _contacts[index];
    await _contactsService.remove(contact);
    if (!mounted) return;
    setState(() => _contacts.removeAt(index));
  }

  Future<void> _inviteTelegram(TrustedContact contact) async {
    try {
      final synced = await _contactsService.ensureSynced(contact);
      final link = synced.inviteLink;
      if (link == null || link.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lien d\'invitation indisponible')),
        );
        return;
      }
      final idx = _contacts.indexWhere(
        (c) =>
            (synced.contactId != null && c.contactId == synced.contactId) ||
            (c.phone == contact.phone && c.name == contact.name),
      );
      if (idx >= 0) {
        setState(() => _contacts[idx] = synced);
      }
      if (!mounted) return;
      await TelegramInviteSheet.show(
        context,
        contact: synced,
        inviteLink: link,
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException
          ? _inviteErrorMessage(e)
          : 'Impossible de générer le lien';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  String _inviteErrorMessage(ApiException e) {
    if (e.statusCode == 404) {
      return 'API contacts indisponible (404). Utilisez l\'API locale (port 8080) '
          'ou déployez la dernière version du backend.';
    }
    if (e.statusCode == 401) {
      return 'Connectez-vous pour générer le lien d\'invitation.';
    }
    return e.message;
  }

  Future<void> _importFromDevice() async {
    if (!await DeviceContactsService.hasPermission()) {
      final granted = await DeviceContactsService.requestPermission();
      if (!granted) {
        if (mounted) {
          setState(() => _showImportButton = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Accès aux contacts refusé. Vous pouvez ajouter un contact manuellement.'),
            ),
          );
        }
        return;
      }
    }

    final entries = await DeviceContactsService.loadContacts();
    if (!mounted) return;

    if (entries.isEmpty) {
      setState(() {
        _deviceContacts = [];
        _showImportButton = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun contact avec numéro trouvé sur cet appareil.')),
      );
      return;
    }

    setState(() {
      _deviceContacts = entries;
      _showImportButton = true;
    });

    final selected = await showModalBottomSheet<List<DeviceContactEntry>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ContactPickerSheet(
        entries: entries,
        excludedPhones: _addedPhones,
      ),
    );

    if (selected != null && selected.isNotEmpty) {
      await _addContactsFromDevice(selected);
    }
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Ajouter un contact', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 20),
            _InputField(controller: _nameController, label: 'Prénom et nom', icon: Icons.person_outline),
            const SizedBox(height: 14),
            _InputField(
              controller: _phoneController,
              label: 'Numéro de téléphone',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 14),
            _InputField(
              controller: _emailController,
              label: 'Email (optionnel)',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await _addContact();
                if (mounted) Navigator.of(context).pop();
              },
              child: const Text('Ajouter'),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  bool get _isSettings => widget.mode == ContactsScreenMode.settings;

  void _onPrimaryAction() {
    if (_isSettings) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushNamed(context, AppRouter.trigger);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSettings
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Contacts de confiance',
                style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w600),
              ),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!_isSettings) ...[
              const SizedBox(height: 24),
              _buildProgress(2),
              const SizedBox(height: 32),
              const Text(
                'Contacts de confiance',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              const SizedBox(height: 8),
            ] else
              const SizedBox(height: 8),
            const Text(
              'Ces personnes recevront une alerte Telegram dès que vous déclencherez Safe. Invitez-les avec le lien dédié.',
              style: TextStyle(fontSize: 15, color: AppColors.grayMid, height: 1.5),
            ),
            const SizedBox(height: 28),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadContacts,
                      child: _contacts.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.35,
                                  child: _buildEmpty(),
                                ),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _contacts.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) => _ContactTile(
                                contact: _contacts[i],
                                onDelete: () => _removeContact(i),
                                onInvite: () => _inviteTelegram(_contacts[i]),
                              ),
                            ),
                    ),
            ),
            const SizedBox(height: 16),
            if (_showImportButton)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  onPressed: _importFromDevice,
                  icon: const Icon(Icons.contacts_outlined),
                  label: Text(
                    _deviceContacts.isEmpty
                        ? 'Choisir dans mes contacts'
                        : 'Choisir dans mes contacts (${_deviceContacts.length})',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.blue,
                    side: const BorderSide(color: AppColors.blue),
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _showAddSheet,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un contact'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navy,
                side: const BorderSide(color: AppColors.navy),
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isSettings
                  ? _onPrimaryAction
                  : (_contacts.isEmpty ? null : _onPrimaryAction),
              child: Text(_isSettings ? 'Terminé' : 'Continuer'),
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(color: AppColors.grayLight, borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.people_outline, size: 40, color: AppColors.grayMid),
        ),
        const SizedBox(height: 16),
        const Text('Aucun contact ajouté', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.gray)),
        const SizedBox(height: 6),
        Text(
          _showImportButton
              ? 'Choisissez dans vos contacts\nou ajoutez-en un manuellement.'
              : _isSettings
                  ? 'Ajoutez au moins un contact\nde confiance.'
                  : 'Ajoutez au moins un contact\npour continuer.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.grayMid),
        ),
      ]),
    );
  }

  Widget _buildProgress(int step) {
    return Row(children: List.generate(4, (i) => Expanded(
      child: Container(
        height: 4,
        margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
        decoration: BoxDecoration(
          color: i < step ? AppColors.navy : AppColors.grayLight,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    )));
  }
}

class _ContactTile extends StatelessWidget {
  final TrustedContact contact;
  final VoidCallback onDelete;
  final VoidCallback onInvite;

  const _ContactTile({
    required this.contact,
    required this.onDelete,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    final linked = contact.telegramLinked;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.blueLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: AppColors.navy,
              radius: 20,
              child: Text(
                contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(contact.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.navy)),
              Text(contact.phone, style: const TextStyle(fontSize: 13, color: AppColors.grayMid)),
              if (contact.email != null && contact.email!.isNotEmpty)
                Text(contact.email!, style: const TextStyle(fontSize: 12, color: AppColors.grayMid)),
            ])),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: AppColors.grayMid, size: 20),
            ),
          ]),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: linked ? AppColors.green.withOpacity(0.15) : AppColors.grayLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  linked ? 'Telegram lié' : 'À inviter',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: linked ? AppColors.green : AppColors.grayMid,
                  ),
                ),
              ),
              const Spacer(),
              if (!linked)
                TextButton.icon(
                  onPressed: onInvite,
                  icon: const Icon(Icons.link_outlined, size: 18),
                  label: const Text('Inviter'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;

  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.inputFormatters = const [],
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.navy),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.navy, width: 2),
        ),
        filled: true,
        fillColor: AppColors.grayLight,
      ),
    );
  }
}
