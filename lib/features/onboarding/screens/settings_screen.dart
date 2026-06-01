import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // États des paramètres
  bool _camouflageEnabled = false;
  bool _vibrationConfirm  = true;
  bool _offlineMode       = true;
  String _selectedTrigger = 'volume';
  String _camouflageApp   = 'meteo';

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
                ]),

                _buildSection('Camouflage', [
                  _buildSwitchTile(
                    icon: Icons.visibility_off_outlined,
                    iconBg: AppColors.purpleL,
                    iconColor: const Color(0xFF7C3AED),
                    title: 'Mode camouflage',
                    subtitle: 'L\'app se déguise en une autre application',
                    value: _camouflageEnabled,
                    onChanged: (v) => setState(() => _camouflageEnabled = v),
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
                    icon: Icons.calculate_outlined,
                    iconBg: AppColors.blueLight,
                    iconColor: AppColors.blue,
                    title: 'Modifier le code calculatrice',
                    subtitle: 'Changer votre nombre secret',
                    onTap: () => Navigator.pushNamed(context, AppRouter.pin),
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
    ];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Mode de déclenchement', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.gray)),
        const SizedBox(height: 12),
        Row(children: options.map((o) {
          final selected = _selectedTrigger == o.value;
          return Expanded(child: GestureDetector(
            onTap: () => setState(() => _selectedTrigger = o.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: o.value == 'volume' ? 8 : 0),
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
          ));
        }).toList()),
      ]),
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
            onPressed: () {
              Navigator.pop(context);
              // TODO : effacer flutter_secure_storage + shared_preferences
            },
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
  }
}