FROM python:3.11-slim

WORKDIR /app

# Copie du fichier serveur
COPY server.py .

# Installation des dépendances
RUN pip install mysql-connector-python fastapi uvicorn

# Exposition du port de l'API
EXPOSE 8000

# Commande de démarrage de l'API
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]