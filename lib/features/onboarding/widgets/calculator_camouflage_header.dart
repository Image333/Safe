import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class CalculatorCamouflageHeader extends StatelessWidget {
  final VoidCallback? onLongPress;

  const CalculatorCamouflageHeader({super.key, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.calculate_rounded,
                color: AppColors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Calculatrice',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w400,
                color: Color(0xFF111111),
                letterSpacing: -0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
