ARG BUILD_FROM
FROM ${BUILD_FROM}

# n8n version — mis à jour automatiquement par GitHub Actions
ARG N8N_VERSION=2.16.1

# Labels
LABEL \
    io.hass.name="n8n" \
    io.hass.description="n8n Workflow Automation" \
    io.hass.type="addon" \
    io.hass.version="${N8N_VERSION}"

# Installer les dépendances système
# Les images base HA sont Alpine Linux
RUN apk add --no-cache \
    nodejs \
    npm \
    nginx \
    supervisor \
    tzdata \
    bash \
    curl \
    jq \
    && npm install -g --omit=dev n8n@${N8N_VERSION} \
    && npm cache clean --force \
    && rm -rf /tmp/* /var/cache/apk/*

# Copier les fichiers de configuration
COPY nginx.conf /etc/nginx/nginx.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY n8n-exports.sh /n8n-exports.sh
COPY run.sh /run.sh

# Rendre les scripts exécutables
RUN chmod +x /n8n-exports.sh /run.sh

# Répertoire de données n8n
RUN mkdir -p /data

# Ports exposés
EXPOSE 5678 8081

CMD ["/run.sh"]
