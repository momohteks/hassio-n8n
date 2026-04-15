#!/usr/bin/with-contenv bashio

bashio::log.info "Démarrage de l'addon n8n..."

# Lire les options depuis Home Assistant
WEBHOOK_URL=$(bashio::config 'webhook_url' '')
TIMEZONE=$(bashio::config 'timezone' 'Europe/Paris')

export WEBHOOK_URL
export TIMEZONE

bashio::log.info "Fuseau horaire : ${TIMEZONE}"
if [ -n "${WEBHOOK_URL}" ]; then
    bashio::log.info "Webhook URL : ${WEBHOOK_URL}"
fi

# Lancer supervisord (gère nginx + n8n)
exec supervisord -c /etc/supervisor/conf.d/supervisord.conf
