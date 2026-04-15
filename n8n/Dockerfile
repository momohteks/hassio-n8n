# Base : node:22-slim (Debian, glibc) — compatible avec les prebuilds natifs
# (isolated-vm, sqlite3, etc.) pour amd64 ET arm64
ARG N8N_VERSION=2.16.1
FROM node:22-slim

ARG N8N_VERSION

LABEL \
    io.hass.name="n8n" \
    io.hass.description="n8n Workflow Automation" \
    io.hass.type="addon" \
    io.hass.version="${N8N_VERSION}"

# Étape 1 : installer les build deps + n8n + retirer les build deps
# (séparé du runtime pour que --auto-remove ne supprime pas supervisor/nginx)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3 make g++ git ca-certificates \
    && npm install -g --omit=dev --unsafe-perm n8n@${N8N_VERSION} \
    && npm cache clean --force \
    && apt-get purge -y --auto-remove python3 make g++ git \
    && rm -rf /var/lib/apt/lists/* /tmp/* /root/.npm /root/.cache

# Étape 2 : installer les dépendances runtime qui doivent rester dans l'image
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        nginx \
        supervisor \
        jq \
        curl \
        tzdata \
        ca-certificates \
        tini \
    && rm -rf /var/lib/apt/lists/*

# Créer l'utilisateur node et préparer les répertoires
RUN mkdir -p /data \
    && chown -R node:node /data

# Copier les fichiers de configuration
COPY nginx.conf /etc/nginx/nginx.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY n8n-exports.sh /n8n-exports.sh
COPY run.sh /run.sh

RUN chmod +x /n8n-exports.sh /run.sh

EXPOSE 5678 8081

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/run.sh"]
