
## Documentation Backend API

### Vue d'ensemble

Cette documentation décrit l'API présente dans le dossier `API/`. Elle présente la configuration minimale, la manière de lancer le service et les endpoints principaux (auth, users, contact, recordings, health, hello).

---

**Environnement**

- Variables importantes (fichier `API/.env` attendu) :
	- `MARIADB_USER`, `MARIADB_PASSWORD`, `MARIADB_DATABASE`, `MARIADB_ADDRESS`, `MARIADB_PORT`
	- `JWT_SECRET` : secret utilisé pour signer les tokens JWT (doit être configuré en production)

**Dépendances / runtime**

- Langage : Go (module dans `API/go.mod`)
- Serveur web : Fiber

---

### Lancer le serveur (local)

1. Placer les variables d'environnement dans `API/.env` (ou exporter dans l'environnement).
2. Depuis `API/` :

```bash
go run main.go
```

Le serveur écoute par défaut sur le port `:3002` et expose une route de santé `/health`.

---

### Endpoints :
- [auth](./endpoints/auth.md)
- [contact](./endpoints/contact.md)
- [hello](./endpoints/hello.md)
- [recordings](./endpoints/recordings.md)
- [users](./endpoints/users.md)
