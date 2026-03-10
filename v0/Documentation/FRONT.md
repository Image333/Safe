# Documentation Frontend (iOS)

## Présentation

L’application iOS permet la surveillance vocale, la détection de mots-clés d’urgence, l’enregistrement audio, l’envoi automatique d’alertes par email, la gestion des contacts d’urgence, la configuration d’horaires de surveillance, et la personnalisation des paramètres utilisateur.

## Architecture technique

- **Pattern** : MVVM (Model-View-ViewModel) avec injection de dépendances.
- **Langage** : Swift 5, SwiftUI pour l’UI, Combine pour la réactivité.
- **Gestion des dépendances** : Conteneur de dépendances interne, protocoles pour l’injection.
- **Communication réseau** : API REST (JSON) avec le backend Go via `URLSession` et gestion des erreurs HTTP.
- **Sécurité** : Stockage du JWT dans le Keychain, validation des entrées utilisateur, gestion fine des permissions système.

## Structure des dossiers

- `Core/Configuration/` : Configuration globale (API endpoints, SMTP, constantes).
- `Core/Services/` : 
  - `APIService` : Gestion des requêtes HTTP (auth, CRUD contacts/mappings).
  - `VoiceMonitoringService` : Surveillance audio, détection de mots-clés (Speech framework).
  - `SMTPEmailService` : Envoi d’emails via SMTP (librairie SwiftSMTP ou équivalent).
  - `PermissionService` : Vérification et demande des permissions (micro, notifications, localisation).
  - `ScheduleManagementService` : Gestion des horaires de surveillance (UserDefaults, notifications locales).
- `Core/Protocols/` : Protocoles pour abstraction et testabilité.
- `Models/` : Modèles de données (User, Contact, Mapping, Schedule).
- `Features/` : 
  - `Authentication` : Inscription, connexion, récupération de mot de passe.
  - `Contacts` : CRUD contacts d’urgence.
  - `Mappings` : Association mot-clé/contact.
  - `Monitoring` : Activation/désactivation de la surveillance.
  - `Settings` : Gestion des préférences utilisateur.
- `Views/` : Vues SwiftUI, navigation par `NavigationStack`.
- `Assets.xcassets/` : Ressources graphiques.

## Fonctionnalités principales

- **Authentification**
  - Gestion du JWT, stockage sécurisé, rafraîchissement de session.
  - Validation côté client des champs (regex email, force du mot de passe).
- **Surveillance vocale**
  - Utilisation de `SFSpeechRecognizer` pour la reconnaissance vocale en temps réel.
  - Détection de mots-clés personnalisés, déclenchement d’enregistrement audio via `AVAudioRecorder`.
  - Gestion de la session audio (background, interruptions).
- **Envoi d’alertes**
  - Génération d’un email avec pièce jointe audio (enregistrement).
  - Utilisation de SMTP sécurisé (TLS), gestion des erreurs d’envoi.
- **Gestion des contacts**
  - CRUD via API, synchronisation locale/cache.
  - Association de contacts à des mots-clés avec priorité et mode d’envoi.
- **Programmation horaire**
  - Définition de plages horaires, activation automatique de la surveillance.
  - Notifications locales pour rappel d’activation/désactivation.
- **Paramètres utilisateur**
  - Gestion des notifications, localisation, code PIN, personnalisation de l’interface.

## Flux de données

```
User → SwiftUI View → ViewModel (Combine) → Service → API (Go) → MySQL
```
- Les ViewModels publient l’état via `@Published` et reçoivent les réponses des services via Combine.
- Les erreurs sont propagées et affichées à l’utilisateur.

## Sécurité

- **Keychain** : Stockage du JWT et des informations sensibles.
- **Permissions** : Vérification stricte avant chaque accès au micro, à la reconnaissance vocale, à la localisation.
- **Validation** : Contrôles côté client et côté serveur sur tous les champs critiques.
- **Protection des données** : Utilisation de `NSFileProtection` pour les fichiers audio.

## Lancement de l’application

1. Ouvrir le projet dans Xcode.
2. Configurer les variables d’environnement (API, SMTP) dans le fichier de configuration.
3. Lancer sur simulateur ou appareil réel (iOS 15+ recommandé).

## Bonnes pratiques

- Utiliser des protocoles pour faciliter les tests unitaires (mock des services).
- Séparer clairement logique métier et interface utilisateur.
- Logger les erreurs réseau et système pour le debug.
- Utiliser des notifications locales pour informer l’utilisateur en cas d’échec d’envoi d’alerte.

## Fichiers importants

- `SafeApp.swift` : Point d’entrée de l’application.
- `ContentView.swift` : Gestion de la navigation principale.
- `Core/Services/APIService.swift` : Service de communication avec l’API.
- `Core/Services/VoiceMonitoringService.swift` : Surveillance vocale.
- `Core/Services/SMTPEmailService.swift` : Envoi d’alertes par email.
- `Features/Authentication/` : Gestion de l’authentification.

---