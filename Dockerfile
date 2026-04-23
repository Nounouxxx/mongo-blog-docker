FROM mongo:7.0.0-jammy

LABEL maintainer="votre-email@example.com"
LABEL description="Image MongoDB personnalisée avec blog_db"
LABEL version="1.0.0"

ENV MONGO_INITDB_DATABASE=blog_db

COPY init-mongo.js /docker-entrypoint-initdb.d/init-mongo.js

RUN chmod 444 /docker-entrypoint-initdb.d/init-mongo.js

USER mongodb

EXPOSE 27017

VOLUME ["/data/db"]

CMD ["mongod", "--bind_ip_all", "--auth"]