import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

enum AuthMode { login, register }

class AuthBottomSheet extends StatefulWidget {
  const AuthBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AuthBottomSheet(),
    );
  }

  @override
  State<AuthBottomSheet> createState() => _AuthBottomSheetState();
}

class _AuthBottomSheetState extends State<AuthBottomSheet>
    with SingleTickerProviderStateMixin {
  AuthMode _mode = AuthMode.login;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _slideController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _switchMode(AuthMode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _passwordController.clear();
      _confirmController.clear();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _loading = true; _error = null; });

    // Simule un appel API — à brancher sur Cognito en Année 2
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;
    setState(() => _loading = false);

    // TODO : vrai appel Cognito
    // Pour l'instant on simule un succès
    _showSuccess();
  }

  void _showSuccess() {
    Navigator.pop(context); // ferme le bottom sheet
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(children: [
          const Icon(Icons.check_circle, color: AppColors.white),
          const SizedBox(width: 10),
          Text(
            _mode == AuthMode.login ? 'Connecté avec succès' : 'Compte créé avec succès',
            style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SlideTransition(
      position: _slideAnim,
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottom),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Poignée
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.grayLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Titre + icône
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.blueLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_outline, color: AppColors.navy, size: 24),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _mode == AuthMode.login ? 'Se connecter' : 'Créer un compte',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              Text(
                _mode == AuthMode.login
                  ? 'Retrouvez votre configuration'
                  : 'Sauvegardez votre configuration',
                style: const TextStyle(fontSize: 13, color: AppColors.grayMid),
              ),
            ]),
          ]),
          const SizedBox(height: 20),

          // Toggle login / register
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.grayLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              _buildToggleBtn(AuthMode.login, 'Se connecter'),
              _buildToggleBtn(AuthMode.register, 'Créer un compte'),
            ]),
          ),
          const SizedBox(height: 20),

          // Formulaire
          Form(
            key: _formKey,
            child: Column(children: [
              // Email
              _buildField(
                controller: _emailController,
                label: 'Adresse email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email requis';
                  if (!v.contains('@')) return 'Email invalide';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Mot de passe
              _buildField(
                controller: _passwordController,
                label: 'Mot de passe',
                icon: Icons.lock_outline,
                obscure: _obscurePassword,
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: AppColors.grayMid, size: 20,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Mot de passe requis';
                  if (v.length < 8) return 'Minimum 8 caractères';
                  return null;
                },
              ),

              // Confirmation (uniquement en mode register)
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: _mode == AuthMode.register
                  ? Column(children: [
                      const SizedBox(height: 12),
                      _buildField(
                        controller: _confirmController,
                        label: 'Confirmer le mot de passe',
                        icon: Icons.lock_outline,
                        obscure: _obscureConfirm,
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppColors.grayMid, size: 20,
                          ),
                        ),
                        validator: (v) {
                          if (v != _passwordController.text) return 'Les mots de passe ne correspondent pas';
                          return null;
                        },
                      ),
                    ])
                  : const SizedBox.shrink(),
              ),
            ]),
          ),

          // Message d'erreur
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.redLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: AppColors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.red))),
              ]),
            ),
          ],

          const SizedBox(height: 20),

          // Bouton submit
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
              ? const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                )
              : Text(_mode == AuthMode.login ? 'Se connecter' : 'Créer mon compte'),
          ),

          // Mot de passe oublié (login uniquement)
          if (_mode == AuthMode.login) ...[
            const SizedBox(height: 12),
            Center(
              child: GestureDetector(
                onTap: () {
                  // TODO : reset password
                },
                child: const Text(
                  'Mot de passe oublié ?',
                  style: TextStyle(fontSize: 13, color: AppColors.blue, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],

          // Note confidentialité
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.grayLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, color: AppColors.grayMid, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Votre compte permet de sauvegarder votre configuration. Vos enregistrements restent chiffrés et ne sont jamais partagés.',
                style: TextStyle(fontSize: 12, color: AppColors.grayMid, height: 1.4),
              )),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildToggleBtn(AuthMode mode, String label) {
    final selected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
              ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2))]
              : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.navy : AppColors.grayMid,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.navy, size: 20),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.navy, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.red),
        ),
        filled: true,
        fillColor: AppColors.grayLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}