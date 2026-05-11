# Architecture Multi-Services Docker

Déploiement d'une architecture multi-services orchestrant simultanément une base de données SQL (MySQL) et NoSQL (MongoDB) de manière orchestrée et résiliente.

## Docker Hub

## Structure du projet

.
├── mongo/                        # Service MongoDB personnalisé
│   ├── Dockerfile                # Image non-root avec validation de schéma
│   ├── init-mongo.js             # Init blog_db + 5 posts + JSON Schema
│   ├── check-status.sh           # Script de vérification MongoDB
│   └── README.md
├── sql/                          # Service MySQL
│   └── scripts/
│       ├── migrate-v001.sql      # Création base ynov_ci
│       ├── migrate-v002.sql      # Création table utilisateur
│       └── migrate-v003.sql      # Insertion 5 utilisateurs
├── api/                          # Service FastAPI
│   ├── Dockerfile
│   └── server.py                 # Routes /users (MySQL) et /posts (MongoDB)
├── docker-compose.yml            # Orchestration des 5 services
├── .env.example                  # Modèle de variables d'environnement
├── .dockerignore
├── .gitignore
└── README.md

---

## INSTRUCTION DE LANCEMENT

### 1. Cloner le dépôt

```bash
git clone https://github.com/marcreimen/mongo-blog-docker.git
cd mongo-blog-docker
```

### 2. Configurer les variables d'environnement

```bash
cp .env.example .env
# Éditez .env et changez les mots de passe !
```

### 3. Lancer la stack complète

```bash
docker compose -f docker-compose.yml up --detach --build
```

---

## Architecture

| Service | Image | Port | Rôle |
|---|---|---|---|
| `db_mongo` | Image personnalisée | — | Base NoSQL MongoDB |
| `db_mysql` | `mysql:8.0` | — | Base SQL MySQL |
| `admin_mongo` | `mongo-express` | 8081 | Interface web MongoDB |
| `admin_mysql` | `adminer` | 8080 | Interface web MySQL |
| `api` | FastAPI custom | 8000 | API hybride SQL + NoSQL |

---

## Interfaces disponibles

| Interface | URL |
|---|---|
| API FastAPI | http://localhost:8000 |
| Documentation API | http://localhost:8000/docs |
| Adminer (MySQL) | http://localhost:8080 |
| Mongo Express | http://localhost:8081 |

### Connexion Adminer (MySQL)
| Champ | Valeur |
|---|---|
| Système | `MySQL` |
| Serveur | `db_mysql` |
| Utilisateur | `root` |
| Mot de passe | voir `.env` |
| Base de données | `ynov_ci` |

### Connexion Mongo Express (MongoDB)

Mongo Express utilise deux niveaux d'authentification** :

1. Authentification de l'interface web** (formulaire de login) :
| Champ       | Valeur |
| Utilisateur | `admin` |
| Mot de passe | voir `ME_CONFIG_BASICAUTH_PASSWORD` dans `.env` |

2. Connexion à MongoDB** (gérée automatiquement via les variables d'environnement)

---

## Routes API

| Route | Méthode | Source | Description |
|---|---|---|---|
| `/users` | GET | MySQL | Retourne les utilisateurs |
| `/posts` | GET | MongoDB | Retourne les articles du blog |

---

## Sécurité

| Critère | Implémentation |
|---|---|
| Image MongoDB légère | `mongo:7.0.0-jammy` |
| Utilisateur non-root | `USER mongodb` dans le Dockerfile |
| Pas de secrets en dur | Variables d'environnement via `.env` |
| Validation de schéma | JSON Schema Validator sur `posts` |
| Isolation réseau | Bases de données sur réseau interne uniquement |
| Persistance | Volumes nommés `mongo_data` et `mysql_data` |

---

## Healthchecks

| Service | Test métier |
|---|---|
| `db_mongo` | Vérifie que `blog_db` contient exactement 5 posts |
| `db_mysql` | Vérifie que `utilisateur` contient exactement 5 entrées |
| `api` | Interroge `/users` et `/posts` simultanément |

---

## Test du validateur de schéma MongoDB

```javascript
// Dans mongosh — insertion invalide → rejetée
db.posts.insertOne({ titre: "Test", auteur: "Test", vues: "pas_un_nombre" })
// → MongoServerError: Document failed validation
```

---

## Commandes utiles

```bash
# Voir l'état des conteneurs
docker ps

# Voir les logs d'un service
docker logs fastapi
docker logs db_mongo
docker logs db_mysql

# Stopper la stack
docker compose -f docker-compose.yml down

# Stopper et supprimer les volumes
docker compose -f docker-compose.yml down -v
```

---

## 🔄 Pipeline CI/CD

Le projet dispose de deux pipelines GitHub Actions.

### `build_test.yml` — Build & Scan basique
Déclenché à chaque push sur `main`.

| Step | Description |
|---|---|
| Build image API | Construit l'image FastAPI |
| Build image Mongo | Construit l'image MongoDB personnalisée |
| Docker Scout (API) | Scan CVE critical + high (sans bloquer) |
| Docker Scout (Mongo) | Scan CVE critical + high (sans bloquer) |

### `main.yml` — Pipeline CI/CD complet
Déclenché à chaque push sur `main`.

#### Job 1 — Build & Scan
| Step | Description |
|---|---|
| Build image API | Construit l'image FastAPI |
| Docker Scout | Bloque si vulnérabilité **critical** détectée |
| Trivy | Scan de `mysql:8.0` — affiche sans bloquer |

#### Job 2 — Tests d'intégration
| Step | Description |
|---|---|
| Génération `.env` | Créé à la volée depuis les secrets GitHub |
| Deploy stack | Lance `docker compose up` |
| Script de santé | Attend que les 5 services soient `healthy` (24 tentatives x 10s) |
| Test `/users` | Vérifie que la route MySQL retourne 200 |
| Test `/posts` | Vérifie que la route MongoDB retourne 200 |

#### Job 3 — Publication
| Step | Description |
|---|---|
| Push Docker Hub | Publie `marcreimen/mongo-blog:latest` uniquement si Job 2 réussit |

### Secrets requis

| Secret | Description |
|---|---|
| `DOCKER_USERNAME` | Nom d'utilisateur Docker Hub |
| `DOCKER_TOKEN` | Access Token Docker Hub |
| `MONGO_INITDB_ROOT_PASSWORD` | Mot de passe MongoDB |
| `MYSQL_ROOT_PASSWORD` | Mot de passe MySQL |
