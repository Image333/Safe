# Architecture - Déclenchement vocal d'urgence

## Statut

Ce document décrit l'état réel du moteur vocal de Safe tel qu'il est codé aujourd'hui. Il est centré sur ce qui existe réellement dans l'application et le backend, sans reformuler un plan de conception non abouti.

## Objectif

Le moteur de sécurité permet d'armé un mode de surveillance qui :
- écoute un mot-clé configurable,
- détecte une phrase ou une occurrence pertinente,
- démarre un enregistrement audio,
- conserve le clip localement,
- synchronise le clip avec le backend si l'utilisateur est connecté,
- notifie les contacts Telegram liés.

## Contrainte principale

Le système doit fonctionner dans des conditions d'usage mobile réelles :
- audio en arrière-plan limité sur iOS,
- service foreground requis sur Android,
- permissions micro / speech à vérifier,
- dégradation acceptable si le moteur natif échoue.

## Vue d'ensemble

```text
Flutter UI / Settings / Home
        │
        ▼
VoiceTriggerService
  - lecture de la config
  - arm/disarm
  - orchestration du déclenchement
  - callbacks UI
  - synchronisation audio
        │
        ├── VoiceTriggerStorage
        │     persistance locale
        │
        ├── SpeechRecognitionService
        │     fallback Flutter (speech_to_text)
        │
        ├── EmergencyAudioService
        │     enregistrement audio local
        │
        ├── AudioHistoryService
        │     historique local
        │
        └── AudioSyncService
              upload MinIO + liaison alerte / audio
```

## 1. Couche Flutter

### `VoiceTriggerService`
C'est le point d'entrée du moteur vocal.

Il gère :
- `saveConfig()` : mot-clé et durée d'enregistrement,
- `arm()` / `disarm()` : activation et désactivation du mode sécurité,
- `syncStateAtAppStart()` : lecture de l'état au démarrage,
- callbacks pour l'UI (`onKeywordDetected`, `onRecordingStarted`, `onRecordingSynced`, `onError`),
- `_syncRecordedClip()` : traitement d'un clip fini.

### `VoiceTriggerStorage`
Stocke les données de configuration et l'état :
- mot-clé,
- durée d'enregistrement,
- plage horaire,
- état armé.

### `SpeechRecognitionService`
C'est le fallback Dart. Il utilise `speech_to_text` pour écouter et comparer le résultat avec le mot-clé configuré.

Il prend en charge :
- initialisation du moteur,
- démarrage / arrêt de l'écoute,
- relance automatique après erreur,
- déclenchement de l'enregistrement audio.

### `EmergencyAudioService`
Permet d'enregistrer un clip audio localement avec une durée donnée.

### `AudioHistoryService`
Gère l'historique local des clips afin que l'application puisse afficher les enregistrements.

### `AudioSyncService`
Orchestre la synchronisation :
- contrôle si l'utilisateur est authentifié,
- upload du fichier vers MinIO,
- création ou récupération d'une alerte,
- envoi `POST /alerts/:alertId/audio`.

## 2. Couche native

Le moteur natif est relié via des canaux de communication Flutter ↔ natif :
- `MethodChannel` : `safe/voice_trigger`
- `EventChannel` : `safe/voice_trigger_events`

Les événements remontés incluent :
- `keyword_detected`
- `recording_started`
- `recording_completed`
- `error`

### iOS
Le code natif iOS gère la reconnaissance audio et relaye les événements à Flutter. L'objectif est de garder la détection la plus proche du système pour limiter la latence.

### Android
Le moteur Android est également piloté par le canal natif, avec un comportement compatible foreground service.

## 3. Flux réel de fonctionnement

### Démarrage de l'app
Au lancement, le service synchronise son état local :
- mot-clé,
- durée d'enregistrement,
- plage horaire,
- mode armé / désarmé.

### Armement
Quand l'utilisateur active le mode :
1. l'app vérifie les permissions,
2. la configuration est chargée,
3. l'écoute est lancée,
4. l'état armé est sauvegardé localement.

### Écoute
Le moteur écoute selon son contexte :
- mot-clé défini,
- plage horaire respectée,
- mode armé actif.

### Détection du mot-clé
Quand le mot-clé est détecté :
- l'écoute est stoppée,
- le callback `onKeywordDetected` est déclenché,
- l'enregistrement audio démarre.

### Enregistrement
Le clip est enregistré localement par `EmergencyAudioService`.

### Synchronisation backend
Le fichier est ensuite envoyé à `AudioSyncService` :
- si pas connecté : le clip reste local,
- si connecté : upload MinIO + création d'alerte + `POST /alerts/:id/audio`.

## 4. Intégration avec les alertes

Le flux complet est :

```text
mot-clé détecté
    ↓
clip audio enregistré
    ↓
alert creation (si session active)
    ↓
notification texte aux contacts Telegram
    ↓
upload MinIO
    ↓
POST /alerts/:id/audio
    ↓
SendAudio aux contacts liés
```

Le backend reçoit ensuite l'URL du fichier, enregistre la donnée dans `audio_records` et envoie le son aux contacts Telegram liés.

## 5. Composants backend

Le backend Go gère les endpoints suivants :
- `/api/v1/alerts`
- `/api/v1/alerts/:id/audio`
- `/api/v1/me/audio`
- `/api/v1/contacts`
- `/api/v1/telegram/webhook`

Les rôles sont clairs :
- Flutter orchestre l'interaction,
- le natif gère le capteur audio,
- le backend crée les alertes et synchronise les notifications.

## 6. Points de robustesse actuels

### Ce qui est réellement en place
- moteur vocal accessible depuis le frontend,
- fallback Flutter actif,
- sync avec MinIO et backend,
- alerte Telegram liée à un contact,
- historique local des clips,
- persistance de l'état du moteur.

### Points encore à améliorer
- background audio iOS plus fiable,
- retry des uploads hors ligne,
- meilleure gestion des faux positifs,
- sécurisation plus forte des fichiers / retries.

## 7. Synthèse

Le moteur vocal de Safe est aujourd'hui un système hybride et cohérent :
- Flutter orchestre l'expérience,
- la couche native prend en charge les opérations temps réel,
- le backend sécurise l'alerte, le stockage et la notification,
- Telegram sert de canal de diffusion des alertes aux proches.

C'est la base de fonctionnement réelle de l'application de sécurité.
