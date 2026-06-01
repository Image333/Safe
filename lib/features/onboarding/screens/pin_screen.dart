import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});
  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  // ── États ─────────────────────────────────────────────────────────────────
  // Phase 1 : choisir le nombre secret
  // Phase 2 : confirmer en le retapant
  bool _confirming = false;
  String? _secretNumber;         // ex: "10"
  String _input = '';            // ce que l'utilisateur tape
  String _display = '0';         // ce qu'affiche la calculatrice
  String? _error;

  // ── Logique calculatrice ──────────────────────────────────────────────────
  double? _firstOperand;
  String? _operator;
  bool _waitingForSecond = false;

  void _onDigit(String d) {
    setState(() {
      _error = null;
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
      _firstOperand = double.tryParse(_display);
      _operator = op;
      _waitingForSecond = true;
    });
  }

  void _onClear() {
    setState(() {
      _input = '';
      _display = '0';
      _firstOperand = null;
      _operator = null;
      _waitingForSecond = false;
      _error = null;
    });
  }

  void _onDelete() {
    setState(() {
      _error = null;
      if (_input.isNotEmpty) {
        _input = _input.substring(0, _input.length - 1);
        _display = _input.isEmpty ? '0' : _input;
      }
    });
  }

  void _onEqual() {
    if (_firstOperand == null || _operator == null) return;
    final second = double.tryParse(_display);
    if (second == null) return;

    double result;
    switch (_operator) {
      case '+': result = _firstOperand! + second; break;
      case '−': result = _firstOperand! - second; break;
      case '×': result = _firstOperand! * second; break;
      case '÷': result = second != 0 ? _firstOperand! / second : double.nan; break;
      default: return;
    }

    final resultStr = result == result.truncateToDouble()
        ? result.toInt().toString()
        : result.toStringAsFixed(2);

    setState(() {
      _display = resultStr;
      _input = resultStr;
      _firstOperand = null;
      _operator = null;
      _waitingForSecond = false;
    });

    // Vérification du code secret
    _checkSecret(resultStr);
  }

  void _checkSecret(String result) {
  if (!_confirming) {
    if (double.tryParse(result) != null && result != '0') {
      setState(() {
        _secretNumber = result;
        _confirming = true;
        _display = '0';
        _input = '';
        _firstOperand = null;
        _operator = null;
        _waitingForSecond = false;
      });
    } else {
      setState(() => _error = 'Choisissez un nombre différent de 0.');
    }
  } else {
    if (result == _secretNumber) {
      _showSuccess();
    } else {
      setState(() {
        _error = 'Résultat différent. Tapez une opération égale à $_secretNumber.';
        _display = '0';
        _input = '';
        _firstOperand = null;
        _operator = null;
        _waitingForSecond = false;
      });
    }
  }
}

Widget _buildHeader({
  required Key key,
  required IconData icon,
  required String title,
  required String subtitle,
  String? highlight,
}) {
  return Column(
    key: key,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: AppColors.blueLight, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: AppColors.navy, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy))),
      ]),
      const SizedBox(height: 12),

      // Explication visuelle selon la phase
      if (!_confirming) ...[
        _buildStep(
          number: '1',
          text: 'Choisissez un nombre dont vous vous souviendrez facilement.',
          example: 'Ex : 10, 42, 1995…',
        ),
        const SizedBox(height: 8),
        _buildStep(
          number: '2',
          text: 'Tapez-le directement sur la calculatrice et appuyez sur =',
          example: 'Ex : tapez 10 puis =',
        ),
        const SizedBox(height: 8),
        _buildStep(
          number: '3',
          text: 'Plus tard, pour ouvrir Safe, vous ferez n\'importe quelle opération qui donne ce résultat.',
          example: 'Ex : 5+5=  ou  2×5=  ou  20÷2=',
          isLast: true,
        ),
      ] else ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.greenLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.green.withOpacity(0.4)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.check_circle_outline, color: AppColors.green, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Votre code secret est : $_secretNumber',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.green),
              ),
              const SizedBox(height: 4),
              Text(
                'Confirmez en tapant n\'importe quelle opération dont le résultat est $_secretNumber\nEx pour 10 : 5+5=  •  2×5=  •  20÷2=',
                style: TextStyle(fontSize: 13, color: AppColors.green.withOpacity(0.85), height: 1.4),
              ),
            ])),
          ]),
        ),
      ],
    ],
  );
}

Widget _buildStep({ required String number, required String text, required String example, bool isLast = false }) {
  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Column(children: [
      Container(
        width: 24, height: 24,
        decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
        child: Center(child: Text(number, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.white))),
      ),
      if (!isLast) Container(width: 2, height: 32, color: AppColors.grayLight),
    ]),
    const SizedBox(width: 12),
    Expanded(child: Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(text, style: const TextStyle(fontSize: 13, color: AppColors.gray, height: 1.4)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.blueLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(example, style: const TextStyle(fontSize: 12, color: AppColors.blue, fontWeight: FontWeight.w500)),
        ),
        if (!isLast) const SizedBox(height: 8),
      ]),
    )),
  ]);
}

  // Remplace _showSuccess()
void _showSuccess() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Icône animée
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.elasticOut,
            builder: (_, value, child) => Transform.scale(scale: value, child: child),
            child: Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(color: AppColors.greenLight, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: AppColors.green, size: 40),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Code enregistré !',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy),
          ),
          const SizedBox(height: 10),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: AppColors.grayMid, height: 1.6),
              children: [
                const TextSpan(text: 'Pour ouvrir Safe, tapez n\'importe quelle opération égale à '),
                TextSpan(
                  text: _secretNumber,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
                const TextSpan(text: ' dans la calculatrice.\n\nEx : '),
                TextSpan(
                  text: _buildExample(),
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.blue),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // ferme la dialog
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRouter.home,
                (_) => false, // vide tout le stack de navigation
              );
            },
            child: const Text('Accéder à Safe'),
          ),
        ]),
      ),
    ),
  );
}

// Génère un exemple d'opération selon le nombre secret
String _buildExample() {
  final n = int.tryParse(_secretNumber ?? '0') ?? 0;
  if (n == 0) return '0+0=';
  if (n % 2 == 0) return '${n ~/ 2}+${n ~/ 2}=';
  return '${n + 1}-1=';
}

  // ── UI ────────────────────────────────────────────────────────────────────
  // Remplace build() entièrement
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height
                - MediaQuery.of(context).padding.top
                - MediaQuery.of(context).padding.bottom,
          ),
          child: IntrinsicHeight(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 24),
                  _buildProgress(4),
                  const SizedBox(height: 28),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _confirming
                      ? _buildHeader(
                          key: const ValueKey('confirm'),
                          icon: Icons.calculate_outlined,
                          title: 'Confirmez votre code',
                          subtitle: 'Tapez n\'importe quelle opération dont le résultat est $_secretNumber',
                          highlight: _secretNumber,
                        )
                      : _buildHeader(
                          key: const ValueKey('choose'),
                          icon: Icons.lock_outline,
                          title: 'Choisissez votre code secret',
                          subtitle: 'Entrez un nombre puis appuyez sur =\nCe nombre sera votre code d\'accès à Safe.',
                        ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              // Écran calculatrice
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
                      if (_operator != null)
                        Text(
                          '${_firstOperand?.toInt()} $_operator',
                          style: TextStyle(fontSize: 18, color: AppColors.white.withOpacity(0.5)),
                        ),
                      Text(
                        _display,
                        style: const TextStyle(
                          fontSize: 56, fontWeight: FontWeight.w300,
                          color: AppColors.white, letterSpacing: -1,
                        ),
                      ),
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_error!, style: const TextStyle(color: AppColors.redLight, fontSize: 12), textAlign: TextAlign.right),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Clavier
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildKeypad(),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ),
    ),
  );
}


  Widget _buildKeypad() {
    // Ligne 1 : AC, +/-, ÷, ×
    // Ligne 2-4 : chiffres + opérateurs
    // Ligne 5 : 0, ., =
    return Column(children: [
      _buildRow([
        _CalcKey(label: 'AC', onTap: _onClear, type: KeyType.function),
        _CalcKey(label: '⌫',  onTap: _onDelete, type: KeyType.function),
        _CalcKey(label: '÷',  onTap: () => _onOperator('÷'), type: KeyType.operator),
        _CalcKey(label: '×',  onTap: () => _onOperator('×'), type: KeyType.operator),
      ]),
      _buildRow([
        _CalcKey(label: '7', onTap: () => _onDigit('7')),
        _CalcKey(label: '8', onTap: () => _onDigit('8')),
        _CalcKey(label: '9', onTap: () => _onDigit('9')),
        _CalcKey(label: '−', onTap: () => _onOperator('−'), type: KeyType.operator),
      ]),
      _buildRow([
        _CalcKey(label: '4', onTap: () => _onDigit('4')),
        _CalcKey(label: '5', onTap: () => _onDigit('5')),
        _CalcKey(label: '6', onTap: () => _onDigit('6')),
        _CalcKey(label: '+', onTap: () => _onOperator('+'), type: KeyType.operator),
      ]),
      _buildRow([
        _CalcKey(label: '1', onTap: () => _onDigit('1')),
        _CalcKey(label: '2', onTap: () => _onDigit('2')),
        _CalcKey(label: '3', onTap: () => _onDigit('3')),
        _CalcKey(label: '=', onTap: _onEqual, type: KeyType.equal),
      ]),
      _buildRow([
        _CalcKey(label: '0', onTap: () => _onDigit('0'), wide: true),
        _CalcKey(label: '.', onTap: () {}),
        _CalcKey(label: '=', onTap: _onEqual, type: KeyType.equal),
      ], hasWide: true),
    ]);
  }

  Widget _buildRow(List<_CalcKey> keys, { bool hasWide = false }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: keys.map((k) => Expanded(
        flex: k.wide ? 2 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: k,
        ),
      )).toList()),
    );
  }

  Widget _buildProgress(int active) {
    const total = 4;
    return Row(children: List.generate(total, (i) => Expanded(
      child: Container(
        height: 4,
        margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
        decoration: BoxDecoration(
          color: i < active ? AppColors.navy : AppColors.grayLight,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    )));
  }
}

// ── Touche calculatrice ───────────────────────────────────────────────────────
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
      case KeyType.operator:  return AppColors.blue;
      case KeyType.function:  return AppColors.grayLight;
      case KeyType.equal:     return AppColors.navy;
      case KeyType.digit:     return AppColors.white;
    }
  }

  Color get _fg {
    switch (type) {
      case KeyType.operator:  return AppColors.white;
      case KeyType.function:  return AppColors.gray;
      case KeyType.equal:     return AppColors.white;
      case KeyType.digit:     return AppColors.navy;
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Center(
          child: Text(label, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: _fg)),
        ),
      ),
    );
  }
}