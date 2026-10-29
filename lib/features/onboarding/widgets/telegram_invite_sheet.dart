import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/storage/trusted_contacts_storage.dart';
import '../../../core/theme/app_theme.dart';

/// Bottom sheet : copier le lien d'invitation Telegram + UI email préparée (désactivée).
class TelegramInviteSheet extends StatefulWidget {
  final TrustedContact contact;
  final String inviteLink;

  const TelegramInviteSheet({
    super.key,
    required this.contact,
    required this.inviteLink,
  });

  static Future<void> show(
    BuildContext context, {
    required TrustedContact contact,
    required String inviteLink,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TelegramInviteSheet(
        contact: contact,
        inviteLink: inviteLink,
      ),
    );
  }

  @override
  State<TelegramInviteSheet> createState() => _TelegramInviteSheetState();
}

class _TelegramInviteSheetState extends State<TelegramInviteSheet> {
  late final TextEditingController _emailController;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.contact.email ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.inviteLink));
    if (!mounted) return;
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lien d\'invitation copié')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grayLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Inviter sur Telegram',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Envoyez ce lien à ${widget.contact.name}. Après ouverture et « Démarrer », le contact recevra vos alertes.',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.grayMid,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.grayLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.inviteLink,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.navy,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _copyLink,
              icon: Icon(_copied ? Icons.check : Icons.copy_outlined),
              label: Text(_copied ? 'Copié' : 'Copier le lien'),
            ),
            const SizedBox(height: 28),
            const Text(
              'Envoyer par email',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Bientôt disponible. Vous pourrez renseigner l\'email ici et envoyer l\'invitation automatiquement.',
              style: TextStyle(fontSize: 13, color: AppColors.grayMid, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              enabled: false,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email du proche',
                prefixIcon: const Icon(Icons.email_outlined, color: AppColors.grayMid),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.grayLight,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Envoyer par email (bientôt)'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
