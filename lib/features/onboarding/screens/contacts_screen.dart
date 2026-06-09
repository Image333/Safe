import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/device_contacts_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../widgets/contact_picker_sheet.dart';

class Contact {
  final String name;
  final String phone;
  Contact({required this.name, required this.phone});
}

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});
  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final List<Contact> _contacts = [];
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _showImportButton = true;
  List<DeviceContactEntry> _deviceContacts = [];

  @override
  void initState() {
    super.initState();
    _checkExistingDeviceContacts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
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

  void _addContact({String? name, String? phone}) {
    final contactName = (name ?? _nameController.text).trim();
    final contactPhone = (phone ?? _phoneController.text).trim();
    if (contactName.isEmpty || contactPhone.isEmpty) return;

    final normalized = DeviceContactsService.normalizePhone(contactPhone);
    if (_addedPhones.contains(normalized)) return;

    setState(() {
      _contacts.add(Contact(name: contactName, phone: contactPhone));
      _nameController.clear();
      _phoneController.clear();
    });
  }

  void _addContactsFromDevice(List<DeviceContactEntry> entries) {
    final addedPhones = Set<String>.from(_addedPhones);
    var added = false;
    for (final entry in entries) {
      final normalized = DeviceContactsService.normalizePhone(entry.phone);
      if (addedPhones.contains(normalized)) continue;
      _contacts.add(Contact(name: entry.name, phone: entry.phone));
      addedPhones.add(normalized);
      added = true;
    }
    if (added) setState(() {});
  }

  void _removeContact(int index) {
    setState(() => _contacts.removeAt(index));
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
      _addContactsFromDevice(selected);
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
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _addContact();
                Navigator.of(context).pop();
              },
              child: const Text('Ajouter'),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 24),
            _buildProgress(2),
            const SizedBox(height: 32),
            const Text('Contacts de confiance', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 8),
            const Text('Ces personnes recevront une alerte avec votre position dès que vous déclencherez Safe.', style: TextStyle(fontSize: 15, color: AppColors.grayMid, height: 1.5)),
            const SizedBox(height: 28),
            Expanded(
              child: _contacts.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      itemCount: _contacts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _ContactTile(
                        contact: _contacts[i],
                        onDelete: () => _removeContact(i),
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
              onPressed: _contacts.isEmpty ? null : () => Navigator.pushNamed(context, AppRouter.trigger),
              child: const Text('Continuer'),
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
  final Contact contact;
  final VoidCallback onDelete;
  const _ContactTile({required this.contact, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.blueLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.blue.withOpacity(0.3)),
      ),
      child: Row(children: [
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
        ])),
        IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, color: AppColors.grayMid, size: 20),
        ),
      ]),
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
