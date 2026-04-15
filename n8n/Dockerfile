# Utilise l'image officielle n8n comme base — inclut n8n + node + toutes les dépendances natives compilées
ARG N8N_VERSION=2.16.1
FROM docker.n8n.io/n8nio/n8n:${N8N_VERSION}

ARG N8N_VERSION

LABEL \
    io.hass.name="n8n" \
    io.hass.description="n8n Workflow Automation" \
    io.hass.type="addon" \
    io.hass.version="${N8N_VERSION}"

USER root

# Ajouter nginx + supervisord + utilitaires
# L'image officielle n8n est Debian-based → apt-get
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        nginx \
        supervisor \
        jq \
        curl \
        tzdata \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copier les fichiers de configuration
COPY nginx.conf /etc/nginx/nginx.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY n8n-exports.sh /n8n-exports.sh
COPY run.sh /run.sh

# Préparer les répertoires et permissions
# nginx sur Debian tourne sous www-data ; n8n sous node ; /data est pour n8n
RUN chmod +x /n8n-exports.sh /run.sh \
    && mkdir -p /data \
    && chown -R node:node /data

EXPOSE 5678 8081

ENTRYPOINT []
CMD ["/run.sh"]
