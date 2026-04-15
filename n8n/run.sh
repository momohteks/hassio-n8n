#!/bin/bash
set -e

# Lire les options HA depuis /data/options.json
if [ -f /data/options.json ]; then
    WEBHOOK_URL=$(jq -r '.webhook_url // ""' /data/options.json)
    TIMEZONE=$(jq -r '.timezone // "Europe/Paris"' /data/options.json)
else
    WEBHOOK_URL=""
    TIMEZONE="Europe/Paris"
fi

export WEBHOOK_URL
export TIMEZONE

echo "[INFO] Démarrage de l'addon n8n"
echo "[INFO] Fuseau horaire : ${TIMEZONE}"
if [ -n "${WEBHOOK_URL}" ]; then
    echo "[INFO] Webhook URL : ${WEBHOOK_URL}"
fi

# Lancer supervisord (gère nginx + n8n)
exec supervisord -c /etc/supervisor/conf.d/supervisord.conf
