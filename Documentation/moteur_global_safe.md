# Moteur complet de Safe

## Objectif

Ce document décrit le moteur global de l'application Safe : depuis l'activation du mode sécurité jusqu'à l'envoi d'une alerte avec enregistrement audio, notification Telegram et stockage des données.

Il ne s'agit pas d'un plan de conception, mais d'une explication du comportement réel du système en place.

## 1. Vue d'ensemble

```text
Utilisateur
   │
   ▼
Flutter app
   ├── AuthService / ApiService
   ├── VoiceTriggerService
   ├── VolumeTriggerService
   ├── AudioSyncService
   ├── TrustedContactsService
   └── local storage
   │
   ├── native bridge (MethodChannel / EventChannel)
   ▼
iOS / Android native
   - écoute audio
   - speech recognition
   - recording local
   - foreground service
   │
   ▼
Backend Go (Fiber)
   - users
   - contacts
   - alerts
   - audio
   - Telegram webhook
   │
   ▼
MariaDB + MinIO
   - métadonnées / alertes / audio records
   - fichiers audio
   │
   ▼
Telegram Bot API
   - messages texte
   - fichiers audio
```

## 2. Authentification

La première couche du moteur est l'authentification utilisateur.

L'application stocke le JWT dans un stockage sécurisé, puis chaque requête dite sensible est envoyée avec le header d'authentification.

### Composants
- `AuthService` : orchestrateur de l'auth
- `AuthStorage` : stockage sécurisé du token
- `ApiService` : client HTTP pour les endpoints backend

### Flux
1. formulaire login / register,
2. appel API `/login` ou `/users`,
3. réception d'un JWT,
4. stockage local du token,
5. usage du token sur les endpoints protégés.

## 3. Contacts de confiance

La sécurité de Safe repose aussi sur la gestion des contacts à prévenir.

### Rôle
Les contacts permettent au backend de fan-out une alerte à plusieurs destinataires.

### Flux
1. création d'un contact via l'API,
2. génération d'un `invite_token`,
3. envoi du lien Telegram au contact,
4. lien du `chat_id` via le webhook `/telegram/webhook`,
5. contact devenu `telegram_linked`.

Une fois lié, le backend peut envoyer des messages texte et des fichiers audio au contact.

## 4. Le mode sécurité

Le mode sécurité est l'état général de l'app lorsqu'un utilisateur décide de se protéger.

Ce mode active :
- l'écoute du mot-clé,
- le déclenchement de secours par volume,
- l'enregistrement de preuves audio,
- la création d'alerte lors d'un événement détecté.

L'état est persisté localement pour récupérer la configuration au redémarrage.

## 5. Déclenchement vocal

### Point central
Le point d'entrée principal est `VoiceTriggerService`.

### Rôle
Il gère :
- la configuration du mot-clé,
- la durée d'enregistrement,
- l'armement / désarmement,
- la détection d'un mot-clé,
- la création de fichiers audio,
- la synchronisation vers le backend.

### Fallback
Si le moteur natif ne répond pas ou n'est pas disponible, le fallback `SpeechRecognitionService` prend le relais via `speech_to_text`.

### Flux complet
1. le service est armé,
2. il écoute le mot-clé,
3. le mot-clé est détecté,
4. un enregistrement audio démarre,
5. le clip est enregistré localement,
6. `AudioSyncService` traite le fichier.

## 6. Déclenchement par volume

Safe dispose aussi d'un déclenchement mécanique : la triple pression sur le bouton volume.

### Service
`VolumeTriggerService` écoute les changements de volume et compte les pressions.

### Flux
1. le bouton volume est actionné trois fois dans une fenêtre courte,
2. le service détecte la triple pression,
3. il démarre un enregistrement de secours,
4. il déclenche la même logique d'alerte / sync que le déclenchement vocal.

Cette logique est utile comme mécanisme de secours et de test rapide.

## 7. Enregistrement audio

Le service `EmergencyAudioService` est utilisé pour enregistrer des fichiers audio.

### Ce qu'il fait
- crée un fichier audio sur le terminal de l'utilisateur,
- fixe une durée de capture,
- retourne le chemin du fichier enregistré,
- permet à l'historique local de l'afficher ensuite.

### Historique
`AudioHistoryService` gère la liste des enregistrements déjà capturés pour que l'utilisateur puisse les consulter.

## 8. Synchronisation vers le backend

Une fois le clip enregistré, `AudioSyncService` prend le relais.

### Flux
1. vérifier si l'utilisateur est connecté,
2. obtenir le token JWT,
3. uploader le fichier sur MinIO,
4. créer ou récupérer une alerte,
5. envoyer le payload de métadonnées à `POST /alerts/:alertId/audio`.

### Cas de non-authentification
Si l'utilisateur n'est pas connecté ou que la session est absente :
- le clip reste local,
- la synchronisation est ignorée,
- l'historique local reste disponible.

## 9. Backend Go

Le backend est un service API Fiber qui expose les routes de :
- users,
- contacts,
- alerts,
- audio,
- Telegram webhook.

### Rôle
- valider les requêtes,
- contrôler l'accès via JWT,
- gérer la persistance dans MariaDB,
- héberger la logique de notifications,
- envoyer des messages Telegram.

## 10. Alerte et notifications

Quand une alerte est créée, le backend :
1. enregistre un événement dans la table `alerts`,
2. récupère les contacts liés,
3. envoie un message texte aux destinataires Telegram,
4. prépare le contexte pour l'envoi audio une fois le clip disponible.

### Réponse backend
La réponse contient :
- `alert_id`,
- `notifications[]` avec le statut de chaque contact.

## 11. Audio + Telegram

Quand le clip est uploadé et associé à l'alerte, le backend appelle la fonction de notification audio.

### Flux
1. `blob_url` disponible depuis MinIO,
2. `POST /alerts/:id/audio` reçu par le backend,
3. insert dans `audio_records`,
4. boucle sur les contacts Telegram liés,
5. `sendAudio` via le bot Telegram.

Cela permet d'envoyer à chaque proche un message texte puis le son correspondant.

## 12. Webhook Telegram

Le webhook est public et permet de lier un contact de confiance après qu'il ouvre le bot Telegram.

### Cas possibles
- `/start <invite_token>`
- partage de numéro de téléphone
- lien avec un contact SAFE existant

### Rôle
Le webhook met à jour la relation entre :
- le contact de confiance,
- le `chat_id` Telegram,
- l'utilisateur SAFE.

## 13. Stockage

### Local
Le terminal conserve :
- état du déclenchement,
- configuration du mot-clé,
- dossiers audio,
- historique des clips enregistrés.

### Distant
Le backend conserve :
- utilisateurs,
- contacts,
- alertes,
- enregistrements audio liés,
- liens Telegram et métadonnées.

Les fichiers audio eux sont stockés dans MinIO/S3.

## 14. Flux complet d'une alerte

```text
1. L'utilisateur active le mode sécurité
2. le déclenchement vocal ou volume se produit
3. le moteur enregistre le clip localement
4. le service vérifie si l'utilisateur est connecté
5. le fichier est uploadé sur MinIO
6. une alerte est créée / récupérée
7. le backend associe le clip à l'alerte
8. le backend envoie le texte Telegram aux proches
9. le backend envoie le fichier audio aux proches
10. l'utilisateur peut réécouter le clip dans l'historique
```

## 15. Conclusion

Le moteur complet de Safe repose sur une logique simple mais solide :
- le client détecte l'événement,
- le natif garde la réactivité audio,
- le backend centralise l'alerte et les notifications,
- Telegram sert de canal de diffusion vers les proches,
- MinIO sert de support de stockage pour les preuves audio.

C'est donc un système cohérent de sécurité personnelle mobile, capable de transformer un événement de détection en alerte complète avec preuve audio.
