FROM python:3.11-slim

WORKDIR /app

# Copie du fichier serveur
COPY server.py .

# Installation des dépendances MySQL + MongoDB + FastAPI
RUN pip install mysql-connector-python fastapi uvicorn pymongo

# Exposition du port de l'API
EXPOSE 8000

# Commande de démarrage
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]
