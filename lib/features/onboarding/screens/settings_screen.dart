import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/app_camouflage_service.dart';
import '../../../core/services/app_reset_service.dart';
import '../../../core/services/voice_trigger_service.dart';
import '../../../core/storage/camouflage_storage.dart';
import '../../../core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _camouflageStorage = CamouflageStorage();
  final _camouflageService = AppCamouflageService();
  final _voiceTriggerService = VoiceTriggerService();
  final _keywordController = TextEditingController();
  static const int _voiceDurationStepSec = 5;

  // États des paramètres
  bool _camouflageEnabled = false;
  bool _vibrationConfirm  = true;
  bool _offlineMode       = true;
  String _selectedTrigger = 'volume';
  bool _voiceTriggerArmed = false;
  int _voiceRecordingDurationSec = VoiceTriggerService.defaultRecordingDurationSec;
  String _camouflageApp   = 'meteo';

  @override
  void initState() {
    super.initState();
    _loadCamouflageSettings();
    _loadVoiceTriggerSettings();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _loadCamouflageSettings() async {
    final enabled = await _camouflageStorage.isCalculatorCamouflageEnabled();
    if (!mounted) return;
    setState(() {
      _camouflageEnabled = enabled;
      if (enabled) _camouflageApp = 'calc';
    });
  }

  Future<void> _onCamouflageChanged(bool enabled) async {
    setState(() => _camouflageEnabled = enabled);
    if (enabled) {
      setState(() => _camouflageApp = 'calc');
      await _camouflageService.enableCalculatorCamouflage();
    } else {
      await _camouflageService.disableCalculatorCamouflage();
    }
  }

  Future<void> _loadVoiceTriggerSettings() async {
    final config = await _voiceTriggerService.getConfig();
    if (!mounted) return;

    setState(() {
      _voiceTriggerArmed = config.armed;
      _voiceRecordingDurationSec = config.recordingDurationSec;
      _keywordController.text = config.keyword ?? '';
      if (_voiceTriggerArmed || (config.keyword != null && config.keyword!.isNotEmpty)) {
        _selectedTrigger = 'keyword';
      }
    });
  }

  Future<void> _onVoiceTriggerArmedChanged(bool armed) async {
    try {
      final keyword = _keywordController.text.trim();
      if (armed) {
        if (keyword.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Renseignez un mot-clé avant d\'activer.')),
          );
          return;
        }

        final granted = await _confirmAndRequestMicrophonePermission();
        if (!mounted || !granted) return;

        await _persistVoiceConfig(keyword: keyword);
        await _voiceTriggerService.arm();
      } else {
        await _voiceTriggerService.disarm();
      }

      if (!mounted) return;
      setState(() {
        _voiceTriggerArmed = armed;
        _selectedTrigger = armed ? 'keyword' : _selectedTrigger;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('StateError: ', ''))),
      );
    }
  }

  Future<void> _saveKeywordOnly() async {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le mot-clé ne peut pas être vide.')),
      );
      return;
    }

    await _persistVoiceConfig(keyword: keyword);

    if (Platform.isIOS) {
      final granted = await _ensureMicrophonePermissionForIos();
      if (!mounted) return;

      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Autorisez le micro pour utiliser le déclencheur vocal.'),
            action: SnackBarAction(
              label: 'Réglages',
              onPressed: openAppSettings,
            ),
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mot-clé enregistré.')),
    );
  }

  Future<bool> _ensureMicrophonePermissionForIos() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;

    status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> _confirmAndRequestMicrophonePermission() async {
    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Autorisation micro'),
        content: const Text(
          'Pour activer le mot-clé vocal, Safe a besoin d\'accéder au microphone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Autoriser'),
          ),
        ],
      ),
    );

    if (shouldRequest != true || !mounted) return false;

    final status = await Permission.microphone.request();
    if (status.isGranted) return true;

    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Autorisez le micro pour activer le mot-clé vocal.'),
        action: SnackBarAction(
          label: 'Réglages',
          onPressed: openAppSettings,
        ),
      ),
    );

    return false;
  }

  Future<void> _persistVoiceConfig({String? keyword}) async {
    final safeKeyword = (keyword ?? _keywordController.text).trim();
    await _voiceTriggerService.saveConfig(
      keyword: safeKeyword,
      recordingDurationSec: _voiceRecordingDurationSec,
    );

    if (_voiceTriggerArmed) {
      await _voiceTriggerService.disarm();
      await _voiceTriggerService.arm();
    }
  }

  Future<void> _setVoiceRecordingDuration(int seconds) async {
    final clamped = (seconds / _voiceDurationStepSec).round() * _voiceDurationStepSec;
    final bounded = clamped
        .clamp(
          VoiceTriggerService.minRecordingDurationSec,
          VoiceTriggerService.maxRecordingDurationSec,
        )
        .toInt();

    if (bounded == _voiceRecordingDurationSec) return;

    setState(() => _voiceRecordingDurationSec = bounded);

    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) return;

    try {
      await _persistVoiceConfig(keyword: keyword);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de mettre à jour la durée.')),
      );
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    if (remaining == 0) return '${minutes}min';
    return '${minutes}min ${remaining}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grayLight,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSection('Protection', [
                  _buildSwitchTile(
                    icon: Icons.vibration,
                    iconBg: AppColors.blueLight,
                    iconColor: AppColors.blue,
                    title: 'Confirmation haptique',
                    subtitle: 'Vibration discrète après déclenchement',
                    value: _vibrationConfirm,
                    onChanged: (v) => setState(() => _vibrationConfirm = v),
                  ),
                  _buildSwitchTile(
                    icon: Icons.wifi_off_outlined,
                    iconBg: AppColors.greenLight,
                    iconColor: AppColors.green,
                    title: 'Mode hors-ligne',
                    subtitle: 'Enregistrement local sans réseau',
                    value: _offlineMode,
                    onChanged: (v) => setState(() => _offlineMode = v),
                  ),
                ]),

                _buildSection('Déclencheur', [
                  _buildTriggerSelector(),
                  if (_selectedTrigger == 'keyword') _buildKeywordTriggerSettings(),
                ]),

                _buildSection('Camouflage', [
                  _buildSwitchTile(
                    icon: Icons.visibility_off_outlined,
                    iconBg: AppColors.purpleL,
                    iconColor: const Color(0xFF7C3AED),
                    title: 'Mode camouflage',
                    subtitle: 'L\'app se déguise en une autre application',
                    value: _camouflageEnabled,
                    onChanged: _onCamouflageChanged,
                  ),
                  if (_camouflageEnabled) _buildCamouflageSelector(),
                ]),

                _buildSection('Contacts de confiance', [
                  _buildNavTile(
                    icon: Icons.people_outline,
                    iconBg: AppColors.orangeL,
                    iconColor: AppColors.orange,
                    title: 'Gérer les contacts',
                    subtitle: '2 contacts configurés',
                    onTap: () => Navigator.pushNamed(context, AppRouter.contacts),
                  ),
                ]),

                _buildSection('Sécurité', [
                  _buildNavTile(
                    icon: Icons.history,
                    iconBg: AppColors.blueLight,
                    iconColor: AppColors.blue,
                    title: 'Historique audio',
                    subtitle: 'Consulter vos enregistrements',
                    onTap: () => Navigator.pushNamed(context, AppRouter.audioHistory),
                  ),
                  _buildNavTile(
                    icon: Icons.calculate_outlined,
                    iconBg: AppColors.blueLight,
                    iconColor: AppColors.blue,
                    title: 'Modifier le code calculatrice',
                    subtitle: 'Changer votre nombre secret',
                    onTap: () async {
                      await Navigator.pushNamed(context, AppRouter.pin);
                      _loadCamouflageSettings();
                    },
                  ),
                ]),

                _buildSection('Danger', [
                  _buildDangerTile(
                    icon: Icons.delete_outline,
                    title: 'Effacer toutes les données',
                    subtitle: 'Supprime les enregistrements et la configuration',
                    onTap: () => _showDeleteConfirm(context),
                  ),
                ]),

                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Safe v1.0.0 — Vos données restent sur votre téléphone',
                    style: TextStyle(fontSize: 12, color: AppColors.grayMid),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(8, 12, 24, 12),
      child: Row(children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.navy, size: 20),
        ),
        const Text('Paramètres', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
      ]),
    );
  }

  // ── Section container ─────────────────────────────────────────────────────
  Widget _buildSection(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 0, 8),
        child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.grayMid, letterSpacing: 1)),
      ),
      Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(children: children.asMap().entries.map((e) {
          final isLast = e.key == children.length - 1;
          return Column(children: [
            e.value,
            if (!isLast) const Divider(height: 1, indent: 60, endIndent: 16, color: Color(0xFFE5E7EB)),
          ]);
        }).toList()),
      ),
    ]);
  }

  // ── Switch tile ───────────────────────────────────────────────────────────
  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.gray)),
          Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.grayMid)),
        ])),
        Switch(value: value, onChanged: onChanged, activeColor: AppColors.navy),
      ]),
    );
  }

  // ── Nav tile ──────────────────────────────────────────────────────────────
  Widget _buildNavTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.gray)),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.grayMid)),
          ])),
          const Icon(Icons.chevron_right, color: AppColors.grayMid),
        ]),
      ),
    );
  }

  // ── Danger tile ───────────────────────────────────────────────────────────
  Widget _buildDangerTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.redLight, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppColors.red, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.red)),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.grayMid)),
          ])),
          const Icon(Icons.chevron_right, color: AppColors.grayMid),
        ]),
      ),
    );
  }

  // ── Trigger selector ──────────────────────────────────────────────────────
  Widget _buildTriggerSelector() {
    final options = [
      (value: 'volume',  icon: Icons.volume_down_outlined, label: '3× bouton volume'),
      (value: 'shake',   icon: Icons.vibration,            label: 'Secouer'),
      (value: 'keyword', icon: Icons.mic_none_outlined,    label: 'Mot-clé vocal'),
    ];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Mode de déclenchement', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.gray)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((o) {
          final selected = _selectedTrigger == o.value;
          return SizedBox(
            width: (MediaQuery.of(context).size.width - 72) / 2,
            child: GestureDetector(
            onTap: () => setState(() => _selectedTrigger = o.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected ? AppColors.blueLight : AppColors.grayLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: selected ? AppColors.blue : Colors.transparent, width: 2),
              ),
              child: Column(children: [
                Icon(o.icon, color: selected ? AppColors.blue : AppColors.grayMid, size: 22),
                const SizedBox(height: 6),
                Text(o.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? AppColors.blue : AppColors.grayMid), textAlign: TextAlign.center),
              ]),
            ),
            ),
          );
        }).toList(),
        ),
      ]),
    );
  }

  Widget _buildKeywordTriggerSettings() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.grayLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Déclencheur vocal (bêta)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fonctionne en arrière-plan. iOS nécessite le mode audio actif.',
              style: TextStyle(fontSize: 12, color: AppColors.grayMid),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keywordController,
              decoration: const InputDecoration(
                labelText: 'Mot-clé',
                hintText: 'Ex: j\'ai oublié mes clés',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Durée du clip après détection',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.gray,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [15, 30, 60, 120].map((value) {
                final selected = _voiceRecordingDurationSec == value;
                return ChoiceChip(
                  label: Text(_formatDuration(value)),
                  selected: selected,
                  onSelected: (_) => _setVoiceRecordingDuration(value),
                  selectedColor: AppColors.blueLight,
                  labelStyle: TextStyle(
                    color: selected ? AppColors.blue : AppColors.grayMid,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Slider(
              value: _voiceRecordingDurationSec.toDouble(),
              min: VoiceTriggerService.minRecordingDurationSec.toDouble(),
              max: VoiceTriggerService.maxRecordingDurationSec.toDouble(),
              divisions: (VoiceTriggerService.maxRecordingDurationSec -
                  VoiceTriggerService.minRecordingDurationSec) ~/
                  _voiceDurationStepSec,
              label: _formatDuration(_voiceRecordingDurationSec),
              activeColor: AppColors.navy,
              onChanged: (value) => _setVoiceRecordingDuration(value.round()),
            ),
            Text(
              'Actuel: ${_formatDuration(_voiceRecordingDurationSec)} (max ${_formatDuration(VoiceTriggerService.maxRecordingDurationSec)})',
              style: const TextStyle(fontSize: 12, color: AppColors.grayMid),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saveKeywordOnly,
                    child: const Text('Enregistrer le mot-clé'),
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: _voiceTriggerArmed,
                  onChanged: _onVoiceTriggerArmedChanged,
                  activeColor: AppColors.navy,
                ),
              ],
            ),
            Text(
              _voiceTriggerArmed
                  ? 'Surveillance armée • clip ${_formatDuration(_voiceRecordingDurationSec)}'
                  : 'Surveillance désactivée',
              style: TextStyle(
                fontSize: 12,
                color: _voiceTriggerArmed ? AppColors.green : AppColors.grayMid,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Camouflage selector ───────────────────────────────────────────────────
  Widget _buildCamouflageSelector() {
    final options = [
      (value: 'meteo', icon: Icons.wb_sunny_outlined, label: 'Météo'),
      (value: 'calc',  icon: Icons.calculate_outlined, label: 'Calculatrice'),
    ];
    return Column(children: [
      const Divider(height: 1, indent: 60, endIndent: 16, color: Color(0xFFE5E7EB)),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Apparence du camouflage', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.gray)),
          const SizedBox(height: 12),
          Row(children: options.map((o) {
            final selected = _camouflageApp == o.value;
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _camouflageApp = o.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(right: o.value == 'meteo' ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFF3E8FF) : AppColors.grayLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: selected ? const Color(0xFF7C3AED) : Colors.transparent, width: 2),
                ),
                child: Column(children: [
                  Icon(o.icon, color: selected ? const Color(0xFF7C3AED) : AppColors.grayMid, size: 22),
                  const SizedBox(height: 6),
                  Text(o.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? const Color(0xFF7C3AED) : AppColors.grayMid)),
                ]),
              ),
            ));
          }).toList()),
        ]),
      ),
    ]);
  }

  // ── Dialog suppression ────────────────────────────────────────────────────
  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Effacer toutes les données ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
        content: const Text('Cette action est irréversible. Tous vos enregistrements, contacts et paramètres seront supprimés.', style: TextStyle(color: AppColors.grayMid, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: AppColors.grayMid)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () async {
              Navigator.pop(context);
              await AppResetService().resetAll();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRouter.welcome,
                (_) => false,
              );
            },
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
  }

  // ── Dialog déconnexion ────────────────────────────────────────────────────
  void _showLogoutConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Se déconnecter ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
        content: const Text('Votre configuration restera sur votre téléphone.', style: TextStyle(color: AppColors.grayMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: AppColors.grayMid)),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implémenter la déconnexion réelle
              Navigator.pop(context);
            },
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
}