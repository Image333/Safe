
# Flutter seul ne suffit pas pour :

Écoute micro en arrière-plan fiable : Les plugins Flutter (flutter_background_service, workmanager) ont des limitations sur iOS notamment, où le système tue les processus audio non-essentiels
Wake-word detection sans déverrouillage : Nécessite des API natives bas-niveau (AVAudioEngine sur iOS, MediaRecorder sur Android)
Service vraiment persistant : Sur Android, il te faut un Foreground Service avec notification persistante. Sur iOS, tu dois utiliser les Background Modes spécifiques
Fiabilité critique : Pour une app de sécurité, tu ne peux pas te permettre que le système tue ton processus

Architecture idéale :
┌─────────────────────────────────────┐
│         FLUTTER (UI Layer)          │
│  • Interface utilisateur            │
│  • Navigation & Auth                │
│  • Config horaires/contacts         │
│  • Communication API                │
└──────────────┬──────────────────────┘
               │ Method Channel
┌──────────────┴──────────────────────┐
│    NATIVE MODULES (Service Layer)   │
│                                     │
│  iOS (Swift):                       │
│  • AVAudioEngine + Speech Framework │
│  • Background Audio Mode            │
│  • Core Location (always)           │
│  • Keychain (stockage sécurisé)     │
│                                     │
│  Android (Kotlin):                  │
│  • Foreground Service               │
│  • AudioRecord + ML Kit             │
│  • FusedLocationProvider            │
│  • EncryptedSharedPreferences       │
└─────────────────────────────────────┘

# Structure du Projet

mon_app/
├── lib/                    # Flutter
│   ├── main.dart
│   ├── services/
│   │   └── native_bridge.dart  # Communication avec natif
│   └── screens/
├── ios/
│   └── Runner/
│       ├── AppDelegate.swift
│       └── SafetyService.swift  # Ton service natif iOS
└── android/
    └── app/src/main/kotlin/
        └── SafetyService.kt     # Ton service natif Android


# Notification des proches

## Canal retenu : Telegram Bot API

- Doc : https://core.telegram.org/bots/api
- Envoi **côté serveur** (`sendMessage`) après opt-in (`/start` via deep-link)
- Pas de lookup user par téléphone / email (limitation Bot API)
- Architecture : [architecture_telegram_alerts.md](./architecture_telegram_alerts.md)

## SMS (historique / alternative non retenue pour l’alerte silencieuse)

`flutter_sms` ouvre le compose Messages (pas d’envoi silencieux) : https://pub.dev/packages/flutter_sms

Branche exploratoire : `notif_alert_imessage`.

