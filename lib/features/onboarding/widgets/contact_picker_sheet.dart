import 'package:flutter/material.dart';
import '../../../core/services/device_contacts_service.dart';
import '../../../core/theme/app_theme.dart';

class ContactPickerSheet extends StatefulWidget {
  final List<DeviceContactEntry> entries;
  final Set<String> excludedPhones;

  const ContactPickerSheet({
    super.key,
    required this.entries,
    this.excludedPhones = const {},
  });

  @override
  State<ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<ContactPickerSheet> {
  final _searchController = TextEditingController();
  final Set<int> _selectedIndices = {};
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DeviceContactEntry> get _availableEntries {
    return widget.entries
        .where((e) => !widget.excludedPhones.contains(DeviceContactsService.normalizePhone(e.phone)))
        .toList();
  }

  List<DeviceContactEntry> get _filteredEntries {
    if (_query.isEmpty) return _availableEntries;
    final q = _query.toLowerCase();
    return _availableEntries.where((e) {
      return e.name.toLowerCase().contains(q) ||
          e.phone.contains(q) ||
          (e.label?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _confirm() {
    final filtered = _filteredEntries;
    final selected = _selectedIndices.map((i) => filtered[i]).toList();
    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEntries;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.grayLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Choisir des contacts',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy),
            ),
            const SizedBox(height: 6),
            Text(
              '${_availableEntries.length} contact${_availableEntries.length > 1 ? 's' : ''} disponible${_availableEntries.length > 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 14, color: AppColors.grayMid),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() {
                _query = value.trim();
                _selectedIndices.clear();
              }),
              decoration: InputDecoration(
                hintText: 'Rechercher un nom ou un numéro',
                prefixIcon: const Icon(Icons.search, color: AppColors.navy),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.navy, width: 2),
                ),
                filled: true,
                fillColor: AppColors.grayLight,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        _query.isEmpty ? 'Aucun contact disponible' : 'Aucun résultat pour « $_query »',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: AppColors.grayMid),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final entry = filtered[i];
                        final selected = _selectedIndices.contains(i);
                        return InkWell(
                          onTap: () => _toggleSelection(i),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.blueLight : AppColors.grayLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? AppColors.blue : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.navy,
                                  radius: 18,
                                  child: Text(
                                    entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.navy,
                                        ),
                                      ),
                                      Text(
                                        entry.label != null
                                            ? '${entry.phone} · ${entry.label}'
                                            : entry.phone,
                                        style: const TextStyle(fontSize: 13, color: AppColors.grayMid),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  selected ? Icons.check_circle : Icons.circle_outlined,
                                  color: selected ? AppColors.blue : AppColors.grayMid,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _selectedIndices.isEmpty ? null : _confirm,
              child: Text(
                _selectedIndices.isEmpty
                    ? 'Ajouter'
                    : 'Ajouter (${_selectedIndices.length})',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
