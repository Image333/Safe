import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class SafeCalculator extends StatelessWidget {
  final String display;
  final double? firstOperand;
  final String? operatorSymbol;
  final String? error;
  final ValueChanged<String> onDigit;
  final ValueChanged<String> onOperator;
  final VoidCallback onClear;
  final VoidCallback onDelete;
  final VoidCallback onEqual;

  const SafeCalculator({
    super.key,
    required this.display,
    required this.firstOperand,
    required this.operatorSymbol,
    required this.error,
    required this.onDigit,
    required this.onOperator,
    required this.onClear,
    required this.onDelete,
    required this.onEqual,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (operatorSymbol != null)
                  Text(
                    '${firstOperand?.toInt()} $operatorSymbol',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.white.withOpacity(0.5),
                    ),
                  ),
                Text(
                  display,
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w300,
                    color: AppColors.white,
                    letterSpacing: -1,
                  ),
                ),
                if (error != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: AppColors.redLight,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _CalculatorKeypad(
            onDigit: onDigit,
            onOperator: onOperator,
            onClear: onClear,
            onDelete: onDelete,
            onEqual: onEqual,
          ),
        ),
      ],
    );
  }
}

class _CalculatorKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final ValueChanged<String> onOperator;
  final VoidCallback onClear;
  final VoidCallback onDelete;
  final VoidCallback onEqual;

  const _CalculatorKeypad({
    required this.onDigit,
    required this.onOperator,
    required this.onClear,
    required this.onDelete,
    required this.onEqual,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRow([
          _CalcKey(label: 'AC', onTap: onClear, type: KeyType.function),
          _CalcKey(label: '⌫', onTap: onDelete, type: KeyType.function),
          _CalcKey(
            label: '÷',
            onTap: () => onOperator('÷'),
            type: KeyType.operator,
          ),
          _CalcKey(
            label: '×',
            onTap: () => onOperator('×'),
            type: KeyType.operator,
          ),
        ]),
        _buildRow([
          _CalcKey(label: '7', onTap: () => onDigit('7')),
          _CalcKey(label: '8', onTap: () => onDigit('8')),
          _CalcKey(label: '9', onTap: () => onDigit('9')),
          _CalcKey(
            label: '−',
            onTap: () => onOperator('−'),
            type: KeyType.operator,
          ),
        ]),
        _buildRow([
          _CalcKey(label: '4', onTap: () => onDigit('4')),
          _CalcKey(label: '5', onTap: () => onDigit('5')),
          _CalcKey(label: '6', onTap: () => onDigit('6')),
          _CalcKey(
            label: '+',
            onTap: () => onOperator('+'),
            type: KeyType.operator,
          ),
        ]),
        _buildRow([
          _CalcKey(label: '1', onTap: () => onDigit('1')),
          _CalcKey(label: '2', onTap: () => onDigit('2')),
          _CalcKey(label: '3', onTap: () => onDigit('3')),
          _CalcKey(label: '=', onTap: onEqual, type: KeyType.equal),
        ]),
        _buildRow([
          _CalcKey(label: '0', onTap: () => onDigit('0'), wide: true),
          _CalcKey(label: '.', onTap: () {}),
          _CalcKey(label: '=', onTap: onEqual, type: KeyType.equal),
        ]),
      ],
    );
  }

  Widget _buildRow(List<_CalcKey> keys) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: keys
            .map(
              (k) => Expanded(
                flex: k.wide ? 2 : 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: k,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

enum KeyType { digit, operator, function, equal }

class _CalcKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final KeyType type;
  final bool wide;

  const _CalcKey({
    required this.label,
    required this.onTap,
    this.type = KeyType.digit,
    this.wide = false,
  });

  Color get _bg {
    switch (type) {
      case KeyType.operator:
        return AppColors.blue;
      case KeyType.function:
        return AppColors.grayLight;
      case KeyType.equal:
        return AppColors.navy;
      case KeyType.digit:
        return AppColors.white;
    }
  }

  Color get _fg {
    switch (type) {
      case KeyType.operator:
        return AppColors.white;
      case KeyType.function:
        return AppColors.gray;
      case KeyType.equal:
        return AppColors.white;
      case KeyType.digit:
        return AppColors.navy;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(14),
          border: type == KeyType.digit
              ? Border.all(color: const Color(0xFFE5E7EB))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: _fg,
            ),
          ),
        ),
      ),
    );
  }
}
