# Architecture - Déclenchement vocal d'urgence (15 secondes)

## Objectif

Mettre en place un mode **armé** qui:
- écoute en continu un mot-clé choisi par l'utilisateur,
- fonctionne en arrière-plan,
- déclenche un enregistrement audio de 15 secondes après détection,
- reste compatible iOS (écran verrouillé) et Android.

## Contraintes produit et plateforme

- iOS ne permet pas de réveiller librement une app suspendue/tuée pour démarrer le micro.
- Le fonctionnement écran verrouillé iOS nécessite une session audio active + mode background `audio`.
- L'utilisateur doit activer explicitement le mode armé et consentir à l'usage micro.
- Les indicateurs système d'utilisation micro restent visibles.

## Architecture proposée

### 1) Flutter (orchestration)

- `VoiceTriggerStorage`: persistance de la config (mot-clé, durée, état armé).
- `VoiceTriggerService`: API métier (`saveConfig`, `arm`, `disarm`, `syncStateAtAppStart`).
- Bridge natif via `MethodChannel`: `safe/voice_trigger`.

### 2) Natif iOS/Android (audio temps réel)

- Démarrage d'une écoute continue à faible latence.
- Détection wake-word locale (on-device) via moteur dédié.
- Au match: découpage d'un clip de 15 secondes.
- Retour d'événements vers Flutter (détection, début/fin enregistrement, erreurs).

### 3) Backend (phase 2)

- Endpoint upload audio chiffré.
- Retry + queue locale si hors-ligne.
- Politique de rétention (suppression auto).

## Contrat MethodChannel (v1)

Canal: `safe/voice_trigger`

### Appels Flutter -> Natif

- `startListening`
  - payload:
    - `keyword: String`
    - `recordingDurationSec: int`
- `stopListening`

### Événements Natif -> Flutter (EventChannel recommandé)

- `listening_started`
- `keyword_detected`
- `recording_started`
- `recording_completed` (avec `filePath`)
- `error` (avec `code`, `message`)

## Plan d'exécution conseillé

### Phase 0 - Base projet (fait)

- Storage et service Flutter créés.
- Permissions déclarées iOS/Android.
- Bridge `MethodChannel` iOS + Android branché (`safe/voice_trigger`).
- Android: foreground service de base avec notification persistante.

### Phase 1 - POC iOS local

- Implémenter le canal natif dans `AppDelegate.swift`.
- Configurer `AVAudioSession` (`playAndRecord` + options adaptées).
- Détection wake-word + enregistrement 15s.
- Vérifier comportement lock screen.

### Phase 2 - POC Android local

- Service foreground + notification persistante.
- Détection wake-word + enregistrement 15s.

### Phase 3 - Intégration produit

- Écran de réglages:
  - saisie du mot-clé,
  - bouton armer/désarmer,
  - test de déclenchement.
- Journal local minimal (horodatage, succès/erreur).

### Phase 4 - Robustesse

- Chiffrement local des clips.
- Upload différé + retry.
- Télémétrie technique (CPU, batterie, taux de faux positifs).

## Critères d'acceptation minimum (MVP)

- Mode armé activable/désactivable depuis l'app.
- Détection mot-clé < 1.5 s en médiane.
- Enregistrement clip 15 s stable sur 10 déclenchements consécutifs.
- iOS: fonctionnement en arrière-plan écran verrouillé tant que l'app est active en mode armé.
- Aucun crash si la couche native est indisponible.

## Risques et mitigations

- **Batterie élevée**: réduire fréquence/complexité du moteur wake-word.
- **Faux positifs**: seuil + double validation courte.
- **Rejet App Store**: écran de consentement clair, finalité explicite, politique de confidentialité.
