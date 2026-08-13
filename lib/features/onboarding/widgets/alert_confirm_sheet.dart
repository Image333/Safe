import 'package:flutter/material.dart';

import '../../../core/services/alert_message_service.dart';
import '../../../core/storage/trusted_contacts_storage.dart';
import '../../../core/theme/app_theme.dart';

/// Bottom sheet SAFE de confirmation avant ouverture de Messages.
class AlertConfirmSheet extends StatelessWidget {
  final List<TrustedContact> contacts;
  final String? audioUrl;
  final AlertMessageService _messageService;

  const AlertConfirmSheet({
    super.key,
    required this.contacts,
    this.audioUrl,
    AlertMessageService? messageService,
  }) : _messageService = messageService ?? const AlertMessageService();

  /// Affiche le sheet. Retourne `true` si l'utilisateur a confirmé l'envoi,
  /// `false` s'il a annulé, `null` si fermé autrement.
  static Future<bool?> show(
    BuildContext context, {
    required List<TrustedContact> contacts,
    String? audioUrl,
    AlertMessageService? messageService,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AlertConfirmSheet(
        contacts: contacts,
        audioUrl: audioUrl,
        messageService: messageService,
      ),
    );
  }

  bool get _hasAudioLink => audioUrl != null && audioUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final messagePreview = _messageService.buildAlertBody(audioUrl: audioUrl);
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grayMid.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.orangeL,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.orange,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Alerter vos contacts ?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              contacts.length == 1
                  ? '1 proche recevra cette alerte.'
                  : '${contacts.length} proches recevront cette alerte.',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.grayMid,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            _AudioBadge(hasAudioLink: _hasAudioLink),
            const SizedBox(height: 16),
            const Text(
              'Destinataires',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.grayMid,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: contacts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _ContactRow(contact: contacts[i]),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aperçu du message',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.grayMid,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.grayLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                messagePreview,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.gray,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Envoyer l\'alerte'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navy,
                side: const BorderSide(color: AppColors.navy),
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Annuler'),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Vous devrez confirmer l\'envoi dans Messages.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.grayMid,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioBadge extends StatelessWidget {
  final bool hasAudioLink;

  const _AudioBadge({required this.hasAudioLink});

  @override
  Widget build(BuildContext context) {
    final bg = hasAudioLink ? AppColors.greenLight : AppColors.orangeL;
    final fg = hasAudioLink ? AppColors.green : AppColors.orange;
    final icon = hasAudioLink ? Icons.link : Icons.link_off;
    final label = hasAudioLink ? 'Lien audio inclus' : 'Hors ligne — pas de lien audio';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final TrustedContact contact;

  const _ContactRow({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.blueLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.navy,
            radius: 18,
            child: Text(
              contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  contact.phone,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.grayMid,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
