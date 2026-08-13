import 'package:flutter_sms/flutter_sms.dart';

/// Ouvre l'app Messages avec un compose prérempli (pas d'envoi silencieux).
class AlertMessageService {
  const AlertMessageService();

  Future<bool> canSend() => canSendSMS();

  String buildAlertBody({String? audioUrl}) {
    final buffer = StringBuffer(
      'Alerte SAFE : une situation d\'urgence a été déclenchée.',
    );
    if (audioUrl != null && audioUrl.isNotEmpty) {
      buffer.write('\n\nÉcoutez l\'enregistrement audio : $audioUrl');
    } else {
      buffer.write(
        '\n\nL\'enregistrement audio n\'a pas pu être partagé (hors ligne ou non synchronisé).',
      );
    }
    return buffer.toString();
  }

  /// Ouvre le compose Messages pour les destinataires donnés.
  /// Retourne un message d'erreur si l'ouverture échoue, sinon null.
  Future<String?> notifyTrustedContacts({
    required List<String> phones,
    String? audioUrl,
  }) async {
    final recipients = phones
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (recipients.isEmpty) {
      return 'Aucun contact de confiance configuré.';
    }

    final available = await canSend();
    if (!available) {
      return 'L\'envoi de messages n\'est pas disponible sur cet appareil.';
    }

    try {
      await sendSMS(
        message: buildAlertBody(audioUrl: audioUrl),
        recipients: recipients,
        sendDirect: false,
      );
      return null;
    } catch (e) {
      return 'Impossible d\'ouvrir Messages : $e';
    }
  }
}
