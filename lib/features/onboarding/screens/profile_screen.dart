import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';

enum RiskProfile { conjugale, pro, public }

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  RiskProfile? _selected;

  final _profiles = [
    (
      value: RiskProfile.conjugale,
      icon: Icons.home_outlined,
      title: 'Violences conjugales',
      subtitle: 'Protection dans le cadre familial ou intime',
      color: AppColors.red,
      bgColor: AppColors.redLight,
    ),
    (
      value: RiskProfile.pro,
      icon: Icons.work_outline,
      title: 'Harcèlement professionnel',
      subtitle: 'Protection dans le cadre du travail',
      color: AppColors.blue,
      bgColor: AppColors.blueLight,
    ),
    (
      value: RiskProfile.public,
      icon: Icons.location_on_outlined,
      title: 'Espace public',
      subtitle: 'Transports, rue, soirée…',
      color: AppColors.green,
      bgColor: AppColors.greenLight,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _buildProgress(1),
              const SizedBox(height: 32),
              const Text('Votre situation', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.navy)),
              const SizedBox(height: 8),
              const Text('Choisissez le profil qui correspond le mieux à votre situation. Vous pourrez le modifier à tout moment.', style: TextStyle(fontSize: 15, color: AppColors.grayMid, height: 1.5)),
              const SizedBox(height: 32),
              ...(_profiles.map((p) => _ProfileCard(
                icon: p.icon, title: p.title, subtitle: p.subtitle,
                color: p.color, bgColor: p.bgColor,
                selected: _selected == p.value,
                onTap: () => setState(() => _selected = p.value),
              ))),
              const Spacer(),
              ElevatedButton(
                onPressed: _selected == null ? null : () => Navigator.pushNamed(context, AppRouter.contacts),
                child: const Text('Continuer'),
              ),
              const SizedBox(height: 32),
            ],
          ),
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

class _ProfileCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color, bgColor;
  final bool selected;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.icon, required this.title, required this.subtitle,
    required this.color, required this.bgColor,
    required this.selected, required this.onTap,
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
          color: selected ? bgColor : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))] : [],
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: selected ? color : AppColors.gray)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.grayMid)),
          ])),
          if (selected) Icon(Icons.check_circle, color: color, size: 22),
        ]),
      ),
    );
  }
}