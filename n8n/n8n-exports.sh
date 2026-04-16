#!/usr/bin/env bash

# ---------------------------------------------------------------------------
# n8n-exports.sh — Variables d'environnement pour n8n
# Appelé par supervisord avant le démarrage de n8n
# ---------------------------------------------------------------------------

# Port interne n8n (nginx est en façade sur 5678 et 8081)
# NB : on utilise 5680 pour éviter la collision avec le Task Broker interne
# de n8n 2.x (qui écoute par défaut sur 5679).
export N8N_PORT=5680
export N8N_PROTOCOL=http
export N8N_HOST=0.0.0.0

# Dossier de données persistées (volume HA /data)
export N8N_USER_FOLDER=/data

# Base de données SQLite
export DB_TYPE=sqlite
export DB_SQLITE_DATABASE=/data/database.sqlite

# Fuseau horaire (injecté par run.sh)
export GENERIC_TIMEZONE="${TIMEZONE:-Europe/Paris}"
export TZ="${TIMEZONE:-Europe/Paris}"

# URL de base pour les webhooks
if [ -n "${WEBHOOK_URL}" ]; then
    export WEBHOOK_URL="${WEBHOOK_URL}"
fi

# Sécurité et UI
export N8N_HIRING_BANNER_ENABLED=false
export N8N_PERSONALIZATION_ENABLED=false
export N8N_VERSION_NOTIFICATIONS_ENABLED=false
export N8N_DIAGNOSTICS_ENABLED=false
export N8N_DISABLE_PRODUCTION_MAIN_PROCESS=false

# Logs
export N8N_LOG_LEVEL=info
export N8N_LOG_OUTPUT=console

# Exécuteurs
export EXECUTIONS_MODE=regular
export EXECUTIONS_PROCESS=main

# Task Runners (n8n 2.x)
# Dans n8n 2.x, les Task Runners sont obligatoires et le Task Broker
# écoute par défaut sur 5679. On les laisse activés et on s'assure que
# N8N_PORT (5680) ne rentre pas en collision.
# On fixe explicitement le port du broker pour le traçage.
export N8N_RUNNERS_ENABLED=true
export N8N_RUNNERS_MODE=internal
export N8N_RUNNERS_BROKER_PORT=5679
export N8N_RUNNERS_BROKER_LISTEN_ADDRESS=127.0.0.1
