# Structure du Projet 
# Structure Complète du Projet

```
group-1057642_pli/
│
├── API/                              # API Backend (Go)
│   ├── go.mod                        # Dépendances Go
│   ├── go.sum                        # Checksums des dépendances
│   ├── main.go                       # Point d'entrée de l'API
│   └── routes/                       # Routes de l'API
│       ├── auth.go                   # Routes d'authentification
│       ├── contact.go                # Routes de gestion des contacts
│       ├── helloworld.go             # Route de test
│       ├── register.go               # Route d'inscription
│       └── user.go                   # Routes de gestion utilisateur
│
│
├── Safe/                             # Application iOS (Swift)
│   ├── Safe/                         # Code source principal
│   │   ├── API/                      # Interface API iOS
│   │   │   └── server.go             # Configuration serveur local
│   │   │
│   │   ├── AppIcon-Calculator@2x.png # Icônes alternatives
│   │   ├── AppIcon-Calculator@3x.png
│   │   ├── AppIcon-Notes@2x.png
│   │   ├── AppIcon-Notes@3x.png
│   │   │
│   │   ├── Assets.xcassets/          # Ressources visuelles
│   │   │   ├── AccentColor.colorset/
│   │   │   ├── AppIcon-Calculator-Preview.imageset/
│   │   │   ├── AppIcon-Notes-Preview.imageset/
│   │   │   ├── AppIcon-Preview.imageset/
│   │   │   ├── AppIcon.appiconset/
│   │   │   └── Contents.json
│   │   │
│   │   ├── ContentView.swift         # Vue principale de l'app
│   │   │
│   │   ├── Core/                     # Architecture centrale
│   │   │   ├── Configuration/
│   │   │   │   └── AppConfig.swift   # Configuration de l'application
│   │   │   │
│   │   │   ├── DI/                   # Injection de dépendances
│   │   │   │   └── DependencyContainer.swift
│   │   │   │
│   │   │   ├── Protocols/            # Interfaces et protocoles
│   │   │   │   └── VoiceMonitoringProtocols.swift
│   │   │   │
│   │   │   └── Services/             # Services métier
│   │   │       ├── APIService.swift              # Service communication API
│   │   │       ├── AppIconService.swift          # Gestion icônes app
│   │   │       ├── AudioEngineService.swift      # Moteur audio
│   │   │       ├── AudioPlaybackService.swift    # Lecture audio
│   │   │       ├── AudioRecordingServiceAdapter.swift # Adaptateur enregistrement
│   │   │       ├── AuthManager.swift             # Gestionnaire authentification
│   │   │       ├── BackgroundTaskService.swift   # Tâches arrière-plan
│   │   │       ├── CompilationTest.swift         # Tests de compilation
│   │   │       ├── FileManagementService.swift   # Gestion fichiers
│   │   │       ├── KeywordDetectionService.swift # Détection mots-clés
│   │   │       ├── NotificationService.swift     # Service notifications
│   │   │       ├── PermissionService.swift       # Gestion permissions
│   │   │       ├── PermissionTest.swift          # Tests permissions
│   │   │       ├── ScheduleManagementService.swift # Gestion programmation
│   │   │       ├── SpeechRecognitionService.swift # Reconnaissance vocale
│   │   │       ├── VoiceMonitoringCoordinator.swift # Coordinateur surveillance
│   │   │       └── VoiceMonitoringService.swift  # Service principal surveillance
│   │   │
│   │   ├── DebugIcons.swift          # Outils debug pour icônes
│   │   │
│   │   ├── Features/                 # Fonctionnalités par domaine
│   │   │   ├── Permissions/          # Gestion des permissions
│   │   │   │   ├── PermissionsManager.swift
│   │   │   │   └── PermissionsView.swift
│   │   │   │
│   │   │   ├── Schedule/             # Programmation horaires
│   │   │   │   ├── ScheduleManager.swift
│   │   │   │   └── ScheduleView.swift
│   │   │   │
│   │   │   └── VoiceMonitoring/      # Surveillance vocale
│   │   │       ├── AudioRecordingManager.swift
│   │   │       ├── ContinuousListeningManager.swift
│   │   │       ├── SpeechRecognitionManager.swift
│   │   │       └── VoiceMonitoringView.swift
│   │   │
│   │   ├── IconSystemTest.swift      # Tests système d'icônes
│   │   ├── Info.plist               # Configuration iOS
│   │   │
│   │   ├── Models/                   # Modèles de données
│   │   │   └── Contact.swift         # Modèle contact d'urgence
│   │   │
│   │   ├── Preview Content/          # Contenu pour prévisualisations
│   │   │   └── Preview Assets.xcassets/
│   │   │
│   │   ├── Resources/                # Ressources additionnelles
│   │   │   └── IconPreviews/         # Aperçus d'icônes
│   │   │       ├── AppIcon-Calculator.png
│   │   │       ├── AppIcon-Notes.png
│   │   │       └── AppIcon.png
│   │   │
│   │   ├── SafeApp.swift             # Point d'entrée de l'application
│   │   ├── SafetyTests.swift         # Tests de sécurité
│   │   ├── ScheduleConfigurationDemo.swift # Démo configuration horaires
│   │   │
│   │   └── Views/                    # Vues de l'interface utilisateur
│   │       ├── AudioPlayerControlsView.swift # Contrôles lecteur audio
│   │       │
│   │       ├── Authentication/       # Vues d'authentification
│   │       │   ├── AuthTestView.swift
│   │       │   ├── AuthenticationView.swift
│   │       │   ├── ForgotPasswordView.swift
│   │       │   ├── LoginView.swift
│   │       │   └── RegisterView.swift
│   │       │
│   │       ├── ContactView.swift     # Vue gestion contacts
│   │       ├── HomeView.swift        # Vue d'accueil
│   │       ├── NetworkTestView.swift # Vue test réseau
│   │       ├── QuickMonitoringToggle.swift # Toggle surveillance rapide
│   │       │
│   │       └── Settings/             # Vues de paramètres
│   │           ├── AboutView.swift            # À propos de l'app
│   │           ├── AppIconDiagnosticView.swift # Diagnostic icônes
│   │           ├── AppIconSettingsView.swift  # Paramètres icônes
│   │           ├── EmergencyContactsSettingsView.swift # Contacts d'urgence
│   │           ├── HelpView.swift             # Aide
│   │           ├── KeywordSettingsView.swift  # Paramètres mots-clés
│   │           ├── PINSettingsView.swift      # Paramètres code PIN
│   │           └── SettingsView.swift         # Vue principale paramètres
│   │
│   ├── Safe.xcodeproj/               # Projet Xcode
│   │   ├── project.pbxproj           # Configuration projet
│   │   ├── project.xcworkspace/      # Workspace Xcode
│   │   └── xcuserdata/               # Données utilisateur Xcode
│   │
│   ├── SafeTests/                    # Tests unitaires
│   │   └── SafeTests.swift
│   │
│   ├── SafeUITests/                  # Tests d'interface
│   │   ├── SafeUITests.swift
│   │   └── SafeUITestsLaunchTests.swift
│   │
│   ├── go.mod                        # Dépendances Go (pour serveur local)
│   └── go.sum                        # Checksums Go
│
└── 
```

## Communication API ↔ iOS

### Backend (Go API)
- **Base URL**: Routes définies dans `API/routes/`
- **Authentification**: `auth.go`, `register.go`
- **Gestion utilisateurs**: `user.go`
- **Contacts d'urgence**: `contact.go`

### Frontend (iOS)
- **Service API**: `Core/Services/APIService.swift`
- **Authentification**: `Core/Services/AuthManager.swift`
- **Interface Auth**: `Views/Authentication/`
- **Tests réseau**: `Views/NetworkTestView.swift`

### Flux de Données
```
iOS Views → Core/Services → API Backend → Database
iOS Views ← Core/Services ← API Backend ← Database
```

## Architecture Actuelle

### Services Principaux
- **VoiceMonitoringService**: Coordination surveillance vocale
- **AudioEngineService**: Gestion moteur audio
- **SpeechRecognitionService**: Reconnaissance vocale
- **NotificationService**: Gestion notifications
- **BackgroundTaskService**: Tâches en arrière-plan

### Fonctionnalités Implémentées
- ✅ Surveillance vocale continue
- ✅ Détection de mots-clés
- ✅ Gestion des permissions
- ✅ Programmation horaires
- ✅ Authentification utilisateur
- ✅ Paramètres personnalisables
- ✅ Contacts d'urgence




https://www.canva.com/design/DAGqiJXOXfg/yw6l9D-it_cgYGw3rL5_Wg/edit?utm_content=DAGqiJXOXfg&utm_campaign=designshare&utm_medium=link2&utm_source=sharebutton
