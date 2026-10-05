import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

const _iosOrange = Color(0xFFFF9F0A);
const _iosDigit = Color(0xFF333333);
const _iosFunction = Color(0xFFA5A5A5);
const _iosShell = Color(0xFF111111);
const _iosScreen = Color(0xFF000000);

class SafeCalculator extends StatelessWidget {
  final String display;
  final double? firstOperand;
  final String? operatorSymbol;
  final String? error;
  final bool fullscreen;
  /// Non null en mode configuration : affiche l'expression complète sur une ligne.
  final String? expression;
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
    this.fullscreen = false,
    this.expression,
    required this.onDigit,
    required this.onOperator,
    required this.onClear,
    required this.onDelete,
    required this.onEqual,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = fullscreen
            ? constraints.maxWidth
            : constraints.maxWidth.isFinite
                ? constraints.maxWidth.clamp(0.0, 430.0)
                : 430.0;

        return Center(
          child: Padding(
            padding: fullscreen
                ? EdgeInsets.zero
                : const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                minHeight: fullscreen ? constraints.maxHeight : 480,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _iosShell,
                  borderRadius: BorderRadius.circular(fullscreen ? 0 : 36),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    fullscreen ? 14 : 18,
                    fullscreen ? 8 : 18,
                    fullscreen ? 14 : 18,
                    fullscreen ? 20 : 22,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        flex: 4,
                        child: _CalculatorDisplay(
                          display: display,
                          firstOperand: firstOperand,
                          operatorSymbol: operatorSymbol,
                          error: error,
                          expression: expression,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        flex: 6,
                        child: _CalculatorKeypad(
                          onDigit: onDigit,
                          onOperator: onOperator,
                          onClear: onClear,
                          onDelete: onDelete,
                          onEqual: onEqual,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CalculatorDisplay extends StatelessWidget {
  final String display;
  final double? firstOperand;
  final String? operatorSymbol;
  final String? error;
  final String? expression;

  const _CalculatorDisplay({
    required this.display,
    required this.firstOperand,
    required this.operatorSymbol,
    required this.error,
    required this.expression,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: _iosScreen,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (expression != null)
            Text(
              expression!.isEmpty ? '0' : expression!,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w400,
                color: Color(0x99FFFFFF),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            )
          else if (operatorSymbol != null)
            Text(
              '${firstOperand?.toInt()} $operatorSymbol',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w400,
                color: Color(0x99FFFFFF),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                display,
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w300,
                  color: AppColors.white,
                  letterSpacing: -2,
                ),
                maxLines: 1,
                textAlign: TextAlign.right,
              ),
            ),
          ),
          if (error != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x33FF453A),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                error!,
                style: const TextStyle(
                  color: Color(0xFFFFB4AE),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.right,
              ),
            ),
        ],
      ),
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
        Expanded(
          child: _buildRow([
            _CalcKeySpec(label: 'AC', onTap: onClear, type: KeyType.function),
            _CalcKeySpec(label: '+/−', onTap: () {}, type: KeyType.function),
            _CalcKeySpec(label: '%', onTap: () {}, type: KeyType.function),
            _CalcKeySpec(
              label: '÷',
              onTap: () => onOperator('÷'),
              type: KeyType.operator,
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _buildRow([
            _CalcKeySpec(label: '7', onTap: () => onDigit('7')),
            _CalcKeySpec(label: '8', onTap: () => onDigit('8')),
            _CalcKeySpec(label: '9', onTap: () => onDigit('9')),
            _CalcKeySpec(
              label: '×',
              onTap: () => onOperator('×'),
              type: KeyType.operator,
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _buildRow([
            _CalcKeySpec(label: '4', onTap: () => onDigit('4')),
            _CalcKeySpec(label: '5', onTap: () => onDigit('5')),
            _CalcKeySpec(label: '6', onTap: () => onDigit('6')),
            _CalcKeySpec(
              label: '−',
              onTap: () => onOperator('−'),
              type: KeyType.operator,
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _buildRow([
            _CalcKeySpec(label: '1', onTap: () => onDigit('1')),
            _CalcKeySpec(label: '2', onTap: () => onDigit('2')),
            _CalcKeySpec(label: '3', onTap: () => onDigit('3')),
            _CalcKeySpec(
              label: '+',
              onTap: () => onOperator('+'),
              type: KeyType.operator,
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _buildRow([
            _CalcKeySpec(
              label: '0',
              onTap: () => onDigit('0'),
              flex: 2,
              alignment: Alignment.centerLeft,
              horizontalPadding: 28,
            ),
            _CalcKeySpec(label: ',', onTap: () => onDigit('.')),
            _CalcKeySpec(label: '⌫', onTap: onDelete, type: KeyType.operator),
            _CalcKeySpec(label: '=', onTap: onEqual, type: KeyType.equal),
          ]),
        ),
      ],
    );
  }

  Widget _buildRow(List<_CalcKeySpec> keys) {
    return Row(
      children: [
        for (var index = 0; index < keys.length; index++) ...[
          Expanded(
            flex: keys[index].flex,
            child: _CalcKey(
              label: keys[index].label,
              onTap: keys[index].onTap,
              type: keys[index].type,
              alignment: keys[index].alignment,
              horizontalPadding: keys[index].horizontalPadding,
            ),
          ),
          if (index != keys.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

enum KeyType { digit, operator, function, equal }

class _CalcKeySpec {
  final String label;
  final VoidCallback onTap;
  final KeyType type;
  final int flex;
  final Alignment alignment;
  final double horizontalPadding;

  const _CalcKeySpec({
    required this.label,
    required this.onTap,
    this.type = KeyType.digit,
    this.flex = 1,
    this.alignment = Alignment.center,
    this.horizontalPadding = 0,
  });
}

class _CalcKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final KeyType type;
  final Alignment alignment;
  final double horizontalPadding;

  const _CalcKey({
    required this.label,
    required this.onTap,
    this.type = KeyType.digit,
    this.alignment = Alignment.center,
    this.horizontalPadding = 0,
  });

  Color get _bg {
    switch (type) {
      case KeyType.operator:
        return _iosOrange;
      case KeyType.function:
        return _iosFunction;
      case KeyType.equal:
        return _iosOrange;
      case KeyType.digit:
        return _iosDigit;
    }
  }

  Color get _fg {
    switch (type) {
      case KeyType.operator:
        return AppColors.white;
      case KeyType.function:
        return Colors.black;
      case KeyType.equal:
        return AppColors.white;
      case KeyType.digit:
        return AppColors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: Align(
              alignment: alignment,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: label == '⌫' ? 28 : 32,
                      fontWeight: FontWeight.w400,
                      color: _fg,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
