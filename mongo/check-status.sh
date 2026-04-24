#!/usr/bin/env bash
# =============================================================
# check-status.sh — Script de vérification du conteneur MongoDB
# À exécuter depuis la machine HÔTE.
# Usage : ./check-status.sh [nom_du_conteneur]
# =============================================================

set -euo pipefail

# -------------------------------------------------------------
# CONFIGURATION
# Charge les variables depuis .env si le fichier existe,
# sinon utilise des valeurs par défaut.
# -------------------------------------------------------------
if [ -f ".env" ]; then
  # shellcheck disable=SC1091
  source .env
fi

CONTAINER_NAME="${1:-${CONTAINER_NAME:-mongo-blog}}"
MONGO_USER="${MONGO_INITDB_ROOT_USERNAME:-admin}"
MONGO_PASS="${MONGO_INITDB_ROOT_PASSWORD:-changeme_strong_password}"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Compteur d'erreurs
ERRORS=0

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     CHECK-STATUS — Vérification MongoDB Blog     ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Conteneur ciblé : ${YELLOW}${CONTAINER_NAME}${NC}"
echo ""

# -------------------------------------------------------------
# VÉRIFICATION 0 : Le conteneur est-il en cours d'exécution ?
# -------------------------------------------------------------
echo -e "${BLUE}[0/3] Vérification de l'état du conteneur...${NC}"

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo -e "  ${RED}✗ ERREUR : Le conteneur '${CONTAINER_NAME}' n'est pas en cours d'exécution.${NC}"
  echo -e "  ${YELLOW}  → Lancez-le avec : docker run --name ${CONTAINER_NAME} --env-file .env -p 27017:27017 -d votre-image:1.0.0${NC}"
  exit 1
fi

echo -e "  ${GREEN}✓ Le conteneur '${CONTAINER_NAME}' est en cours d'exécution.${NC}"
echo ""

# -------------------------------------------------------------
# VÉRIFICATION 1 : L'utilisateur n'est PAS root
# On exécute 'whoami' à l'intérieur du conteneur.
# Si le résultat est "root", c'est une ERREUR de sécurité.
# -------------------------------------------------------------
echo -e "${BLUE}[1/3] Vérification de l'utilisateur du processus...${NC}"

CURRENT_USER=$(docker exec "${CONTAINER_NAME}" whoami 2>/dev/null || echo "ERREUR")

if [ "${CURRENT_USER}" = "ERREUR" ]; then
  echo -e "  ${RED}✗ ERREUR : Impossible d'exécuter 'whoami' dans le conteneur.${NC}"
  ERRORS=$((ERRORS + 1))
elif [ "${CURRENT_USER}" = "root" ]; then
  echo -e "  ${RED}✗ ERREUR DE SÉCURITÉ : Le processus tourne en tant que ROOT !${NC}"
  echo -e "  ${RED}  → Le Dockerfile doit spécifier USER mongodb (non-root).${NC}"
  ERRORS=$((ERRORS + 1))
else
  echo -e "  ${GREEN}✓ Utilisateur actuel : '${CURRENT_USER}' (non-root) — Conforme ✓${NC}"
fi
echo ""

# -------------------------------------------------------------
# VÉRIFICATION 2 : La base blog_db répond-elle ?
# On exécute mongosh à l'intérieur du conteneur pour tester
# la connectivité et compter les documents dans posts.
# -------------------------------------------------------------
echo -e "${BLUE}[2/3] Vérification de la base de données blog_db...${NC}"

MONGO_CHECK=$(docker exec "${CONTAINER_NAME}" mongosh \
  --username "${MONGO_USER}" \
  --password "${MONGO_PASS}" \
  --authenticationDatabase admin \
  --quiet \
  --eval "
    try {
      const mydb = db.getSiblingDB('blog_db');
      const count = mydb.posts.countDocuments();
      print('COUNT:' + count);
    } catch(e) {
      print('ERROR:' + e.message);
    }
  " 2>/dev/null || echo "CONNECTION_FAILED")

if echo "${MONGO_CHECK}" | grep -q "CONNECTION_FAILED"; then
  echo -e "  ${RED}✗ ERREUR : Impossible de se connecter à MongoDB.${NC}"
  echo -e "  ${RED}  → Vérifiez que le conteneur est bien démarré et les credentials.${NC}"
  ERRORS=$((ERRORS + 1))
elif echo "${MONGO_CHECK}" | grep -q "ERROR:"; then
  ERROR_MSG=$(echo "${MONGO_CHECK}" | grep "ERROR:" | sed 's/ERROR://')
  echo -e "  ${RED}✗ ERREUR MongoDB : ${ERROR_MSG}${NC}"
  ERRORS=$((ERRORS + 1))
else
  COUNT=$(echo "${MONGO_CHECK}" | grep "COUNT:" | sed 's/COUNT://')
  if [ -z "${COUNT}" ] || [ "${COUNT}" -eq 0 ]; then
    echo -e "  ${RED}✗ ERREUR : La collection 'posts' est vide ou inaccessible.${NC}"
    ERRORS=$((ERRORS + 1))
  else
    echo -e "  ${GREEN}✓ blog_db répond correctement.${NC}"
    echo -e "  ${GREEN}✓ Collection 'posts' : ${COUNT} document(s) trouvé(s).${NC}"
  fi
fi
echo ""

# -------------------------------------------------------------
# VÉRIFICATION 3 : Affichage des données (find())
# On fait un find() sur les posts pour prouver l'accessibilité.
# -------------------------------------------------------------
echo -e "${BLUE}[3/3] Récupération des articles (find())...${NC}"

docker exec "${CONTAINER_NAME}" mongosh \
  --username "${MONGO_USER}" \
  --password "${MONGO_PASS}" \
  --authenticationDatabase admin \
  --quiet \
  --eval "
    const db = db.getSiblingDB('blog_db');
    const posts = db.posts.find({}, {titre: 1, auteur: 1, vues: 1, _id: 0}).toArray();
    posts.forEach((p, i) => {
      print('  [' + (i+1) + '] ' + p.titre + ' — par ' + p.auteur + ' (' + p.vues + ' vues)');
    });
  " 2>/dev/null || {
    echo -e "  ${RED}✗ ERREUR : Impossible d'effectuer le find().${NC}"
    ERRORS=$((ERRORS + 1))
  }

echo ""

# -------------------------------------------------------------
# RÉSULTAT FINAL
# -------------------------------------------------------------
echo -e "${BLUE}══════════════════════════════════════════════════${NC}"

if [ "${ERRORS}" -eq 0 ]; then
  echo -e "${GREEN}  ✅ SUCCÈS — Tous les contrôles sont conformes.${NC}"
  echo -e "${GREEN}  Le conteneur MongoDB est opérationnel et sécurisé.${NC}"
  exit 0
else
  echo -e "${RED}  ❌ ÉCHEC — ${ERRORS} erreur(s) détectée(s).${NC}"
  echo -e "${RED}  Consultez les messages ci-dessus pour corriger.${NC}"
  exit 1
fi