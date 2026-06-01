import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';

enum TriggerType { volume, shake, keyword }

class TriggerScreen extends StatefulWidget {
  const TriggerScreen({super.key});
  @override
  State<TriggerScreen> createState() => _TriggerScreenState();
}

class _TriggerScreenState extends State<TriggerScreen> {
  TriggerType? _selected;

  final _triggers = [
    (
      value: TriggerType.volume,
      icon: Icons.volume_down_outlined,
      title: 'Appui 3x bouton volume',
      subtitle: 'Discret et accessible en toutes circonstances',
      badge: 'Recommandé',
      badgeColor: AppColors.green,
      badgeBg: AppColors.greenLight,
    ),
    (
      value: TriggerType.shake,
      icon: Icons.vibration,
      title: 'Secouer le téléphone',
      subtitle: 'Mouvement rapide pour déclencher l\'alerte',
      badge: null,
      badgeColor: AppColors.blue,
      badgeBg: AppColors.blueLight,
    ),
    (
      value: TriggerType.keyword,
      icon: Icons.mic_none_outlined,
      title: 'Mot-clé vocal',
      subtitle: 'Prononcez un mot secret pour déclencher',
      badge: 'Bientôt',
      badgeColor: AppColors.grayMid,
      badgeBg: AppColors.grayLight,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 24),
            _buildProgress(3),
            const SizedBox(height: 32),
            const Text('Déclencheur d\'alerte', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 8),
            const Text('Comment voulez-vous déclencher l\'alerte discrètement ? Vous pourrez le modifier dans les paramètres.', style: TextStyle(fontSize: 15, color: AppColors.grayMid, height: 1.5)),
            const SizedBox(height: 32),
            ...(_triggers.map((t) => _TriggerCard(
              icon: t.icon,
              title: t.title,
              subtitle: t.subtitle,
              badge: t.badge,
              badgeColor: t.badgeColor,
              badgeBg: t.badgeBg,
              selected: _selected == t.value,
              disabled: t.value == TriggerType.keyword,
              onTap: t.value == TriggerType.keyword
                  ? null
                  : () => setState(() => _selected = t.value),
            ))),
            if (_selected == TriggerType.volume) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.green.withOpacity(0.4)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: AppColors.green, size: 18),
                  SizedBox(width: 10),
                  Expanded(child: Text('Appuyez 3 fois rapidement sur le bouton volume bas pour déclencher.', style: TextStyle(fontSize: 13, color: AppColors.green))),
                ]),
              ),
            ],
            const Spacer(),
            ElevatedButton(
              onPressed: _selected == null ? null : () => Navigator.pushNamed(context, AppRouter.pin),
              child: const Text('Continuer'),
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
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

class _TriggerCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final String? badge;
  final Color badgeColor, badgeBg;
  final bool selected, disabled;
  final VoidCallback? onTap;

  const _TriggerCard({
    required this.icon, required this.title, required this.subtitle,
    this.badge, required this.badgeColor, required this.badgeBg,
    required this.selected, this.disabled = false, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: disabled ? AppColors.grayLight : (selected ? badgeBg : AppColors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? badgeColor : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: disabled ? AppColors.grayLight : badgeBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: disabled ? AppColors.grayMid : badgeColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title, style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600,
                color: disabled ? AppColors.grayMid : (selected ? badgeColor : AppColors.gray),
              ))),
              if (badge != null) Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: disabled ? AppColors.grayLight : badgeBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withOpacity(0.4)),
                ),
                child: Text(badge!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: badgeColor)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.grayMid)),
          ])),
          if (selected) Icon(Icons.check_circle, color: badgeColor, size: 22),
        ]),
      ),
    );
  }
}