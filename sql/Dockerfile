FROM mysql:8.0

# Copie des scripts SQL dans le dossier d'initialisation automatique
# MySQL les exécute dans l'ordre alphabétique au premier démarrage
COPY scripts/ /docker-entrypoint-initdb.d/