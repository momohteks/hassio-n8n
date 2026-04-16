#!/usr/bin/env bash

# ---------------------------------------------------------------------------
# n8n-exports.sh — Variables d'environnement pour n8n
# Appelé par supervisord avant le démarrage de n8n
# ---------------------------------------------------------------------------

# Port interne n8n (nginx est en façade sur 5678 et 8081)
export N8N_PORT=5679
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
# Désactivés : le Task Broker interne tentait sinon de se lier au même port
# que N8N_PORT (5679) et provoquait une collision au démarrage.
# Les workflows tournent alors directement dans le process principal,
# ce qui convient parfaitement à un usage home/self-hosted.
export N8N_RUNNERS_ENABLED=false
