import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class CalculatorCamouflageHeader extends StatelessWidget {
  const CalculatorCamouflageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A3C),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.calculate_rounded,
              color: AppColors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Calculatrice',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w400,
              color: AppColors.navy,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
