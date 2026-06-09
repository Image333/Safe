import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/router/app_router.dart';
import '../../../core/storage/secret_pin_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/safe_calculator.dart';

enum PinScreenMode { config, unlock }

class PinScreen extends StatefulWidget {
  final PinScreenMode mode;

  const PinScreen({super.key, this.mode = PinScreenMode.config});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  static const _suggestions = ['7', '10', '13', '42', '100', '1994', '2000'];

  final _numberController = TextEditingController();
  final _pinStorage = SecretPinStorage();

  bool _confirming = false;
  bool _loadingUnlock = true;
  String? _secretNumber;
  String _input = '';
  String _display = '0';
  String _expression = '';
  String? _error;

  double? _firstOperand;
  String? _operator;
  bool _waitingForSecond = false;

  bool get _isUnlock => widget.mode == PinScreenMode.unlock;

  bool get _showsExpression => _confirming || _isUnlock;

  bool get _isValidNumberInput {
    final value = _numberController.text.trim();
    final n = int.tryParse(value);
    return n != null && n > 0;
  }

  @override
  void initState() {
    super.initState();
    _numberController.addListener(() => setState(() {}));
    if (_isUnlock) {
      _loadStoredSecret();
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _loadStoredSecret() async {
    final stored = await _pinStorage.getSecret();
    if (!mounted) return;
    setState(() {
      _secretNumber = stored;
      _loadingUnlock = false;
    });
  }

  void _onContinueToConfirm() {
    if (!_isValidNumberInput) return;
    setState(() {
      _secretNumber = _numberController.text.trim();
      _confirming = true;
      _error = null;
      _onClear();
    });
  }

  void _onDigit(String d) {
    setState(() {
      _error = null;
      if (_showsExpression) _updateExpressionOnDigit(d);
      if (_waitingForSecond) {
        _input = d;
        _display = d;
        _waitingForSecond = false;
      } else {
        if (_display == '0') {
          _input = d;
          _display = d;
        } else {
          _input += d;
          _display = _input;
        }
      }
    });
  }

  void _onOperator(String op) {
    setState(() {
      if (_showsExpression) _expression = '$_display $op';
      _firstOperand = double.tryParse(_display);
      _operator = op;
      _waitingForSecond = true;
    });
  }

  void _onClear() {
    setState(() {
      _input = '';
      _display = '0';
      _expression = '';
      _firstOperand = null;
      _operator = null;
      _waitingForSecond = false;
      _error = null;
    });
  }

  void _onDelete() {
    setState(() {
      _error = null;
      if (_showsExpression && _expression.isNotEmpty) {
        _expression = _expression.substring(0, _expression.length - 1);
      }
      if (_input.isNotEmpty) {
        _input = _input.substring(0, _input.length - 1);
        _display = _input.isEmpty ? '0' : _input;
      }
    });
  }

  void _updateExpressionOnDigit(String d) {
    if (_expression.contains('=')) {
      _expression = d;
      return;
    }
    if (_waitingForSecond) {
      _expression = '$_expression $d';
      return;
    }
    if (_display == '0') {
      _expression = d;
      return;
    }
    _expression += d;
  }

  void _onEqual() {
    String resultStr;

    if (_firstOperand != null && _operator != null) {
      final second = double.tryParse(_display);
      if (second == null) return;

      double result;
      switch (_operator) {
        case '+':
          result = _firstOperand! + second;
          break;
        case '−':
          result = _firstOperand! - second;
          break;
        case '×':
          result = _firstOperand! * second;
          break;
        case '÷':
          result = second != 0 ? _firstOperand! / second : double.nan;
          break;
        default:
          return;
      }
      resultStr = result == result.truncateToDouble()
          ? result.toInt().toString()
          : result.toStringAsFixed(2);
    } else {
      if (_display == '0' || _display.isEmpty) return;
      resultStr = _display;
    }

    setState(() {
      if (_showsExpression) _expression = '$_expression = $resultStr';
      _display = resultStr;
      _input = resultStr;
      _firstOperand = null;
      _operator = null;
      _waitingForSecond = false;
    });

    _checkSecret(resultStr);
  }

  Future<void> _checkSecret(String result) async {
    if (_isUnlock) {
      if (result == _secretNumber) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRouter.home,
          (_) => false,
        );
      } else {
        setState(() {
          _error = null;
          _display = '0';
          _input = '';
          _expression = '';
          _firstOperand = null;
          _operator = null;
          _waitingForSecond = false;
        });
      }
      return;
    }

    if (result == _secretNumber) {
      await _pinStorage.saveSecret(_secretNumber!);
      if (!mounted) return;
      _showSuccess();
    } else {
      setState(() {
        _error =
            'Résultat différent. Tapez une opération égale à $_secretNumber.';
        _display = '0';
        _input = '';
        _expression = '';
        _firstOperand = null;
        _operator = null;
        _waitingForSecond = false;
      });
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              builder: (_, value, child) =>
                  Transform.scale(scale: value, child: child),
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.greenLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: AppColors.green, size: 40),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Code enregistré !',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 10),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.grayMid,
                  height: 1.6,
                ),
                children: [
                  const TextSpan(
                    text:
                        'Pour ouvrir Safe, tapez n\'importe quelle opération égale à ',
                  ),
                  TextSpan(
                    text: _secretNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
                  ),
                  const TextSpan(text: ' dans la calculatrice.\n\nEx : '),
                  TextSpan(
                    text: _buildExample(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRouter.home,
                  (_) => false,
                );
              },
              child: const Text('Accéder à Safe'),
            ),
          ]),
        ),
      ),
    );
  }

  String _buildExample() {
    final n = int.tryParse(_secretNumber ?? '0') ?? 0;
    if (n == 0) return '0+0=';
    if (n % 2 == 0) return '${n ~/ 2}+${n ~/ 2}=';
    return '${n + 1}-1=';
  }

  @override
  Widget build(BuildContext context) {
    if (_isUnlock) {
      return _buildUnlockScreen();
    }
    return _buildConfigScreen();
  }

  Widget _buildUnlockScreen() {
    if (_loadingUnlock) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.navy)),
      );
    }

    if (_secretNumber == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Aucun code secret configuré.',
                  style: TextStyle(fontSize: 16, color: AppColors.gray),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRouter.welcome,
                    (_) => false,
                  ),
                  child: const Text('Configurer Safe'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: SafeCalculator(
          display: _display,
          firstOperand: _firstOperand,
          operatorSymbol: _operator,
          expression: _expression,
          error: _error,
          onDigit: _onDigit,
          onOperator: _onOperator,
          onClear: _onClear,
          onDelete: _onDelete,
          onEqual: _onEqual,
        ),
      ),
    );
  }

  Widget _buildConfigScreen() {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildProgress(4),
                      const SizedBox(height: 28),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _confirming
                            ? _buildConfirmHeader(
                                key: const ValueKey('confirm'),
                              )
                            : _buildChooseHeader(
                                key: const ValueKey('choose'),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_confirming)
                  Expanded(
                    child: SafeCalculator(
                      display: _display,
                      firstOperand: _firstOperand,
                      operatorSymbol: _operator,
                      expression: _expression,
                      error: _error,
                      onDigit: _onDigit,
                      onOperator: _onOperator,
                      onClear: _onClear,
                      onDelete: _onDelete,
                      onEqual: _onEqual,
                    ),
                  )
                else
                  Expanded(child: _buildNumberPicker()),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChooseHeader({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.blueLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lock_outline, color: AppColors.navy, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Choisissez votre code secret',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        const Text(
          'Entrez un nombre entier que vous retiendrez facilement. '
          'Plus tard, vous l\'entrerez via une opération sur la calculatrice.',
          style: TextStyle(fontSize: 14, color: AppColors.gray, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildConfirmHeader({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.blueLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calculate_outlined,
              color: AppColors.navy,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Confirmez votre code',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.blueLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.blue.withOpacity(0.3)),
          ),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.gray,
                height: 1.5,
              ),
              children: [
                const TextSpan(
                  text: 'Tapez une opération dont le résultat est ',
                ),
                TextSpan(
                  text: _secretNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberPicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _numberController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Votre nombre secret',
              hintText: 'Ex : 42',
              prefixIcon: const Icon(Icons.tag, color: AppColors.navy, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.navy, width: 2),
              ),
              filled: true,
              fillColor: AppColors.grayLight,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Suggestions',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.grayMid,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((n) {
              final selected = _numberController.text == n;
              return ChoiceChip(
                label: Text(n),
                selected: selected,
                onSelected: (_) {
                  setState(() => _numberController.text = n);
                },
                selectedColor: AppColors.blueLight,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.navy : AppColors.gray,
                ),
                side: BorderSide(
                  color: selected ? AppColors.blue : AppColors.grayLight,
                ),
              );
            }).toList(),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _isValidNumberInput ? _onContinueToConfirm : null,
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress(int active) {
    const total = 4;
    return Row(
      children: List.generate(
        total,
        (i) => Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            decoration: BoxDecoration(
              color: i < active ? AppColors.navy : AppColors.grayLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
