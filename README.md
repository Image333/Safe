# Safe

## Documentation

- Authentification: [Documentation/architecture_auth.md](Documentation/architecture_auth.md)
- Déclenchement vocal d'urgence: [Documentation/architecture_voice_trigger.md](Documentation/architecture_voice_trigger.md)
- Alertes Telegram aux proches: [Documentation/architecture_telegram_alerts.md](Documentation/architecture_telegram_alerts.md)
- API (`/api/v1`): [Documentation/api/api.md](Documentation/api/api.md)

### Backend local (Telegram)

1. Copier `backend/api/.env.example` → `backend/api/.env` et renseigner `TELEGRAM_BOT_TOKEN` / `TELEGRAM_BOT_USERNAME`
2. Lancer MariaDB + `cd backend/api && go run .`
3. Exposer le port (ngrok) et enregistrer le webhook — voir [Documentation/api/telegram.md](Documentation/api/telegram.md)
4. App Flutter pointant vers l’API locale :
   `flutter run --dart-define=API_HOST=<IP> --dart-define=API_PORT=8080`