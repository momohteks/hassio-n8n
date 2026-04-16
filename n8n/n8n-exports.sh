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

# Logs
export N8N_LOG_LEVEL=info
export N8N_LOG_OUTPUT=console

# Exécutions
export EXECUTIONS_MODE=regular

# ---------------------------------------------------------------------------
# Task Runners (n8n 2.x)
# ---------------------------------------------------------------------------
# En n8n 2.x les Task Runners sont obligatoires. Mode `internal` = n8n
# démarre lui-même les processus runner (JS + Python). Le Task Broker
# écoute sur 5679 (séparé de N8N_PORT pour éviter la collision).
export N8N_RUNNERS_MODE=internal
export N8N_RUNNERS_BROKER_PORT=5679
export N8N_RUNNERS_BROKER_LISTEN_ADDRESS=127.0.0.1

# Python Task Runner — quels modules le code utilisateur peut importer.
# - STDLIB_ALLOW=*  → toute la stdlib Python est accessible
# - EXTERNAL_ALLOW=(vide) → aucun paquet tiers accessible au code user
#   (seul `websockets` est installé dans le venv, utilisé en interne
#    par le runner lui-même mais bloqué pour le code utilisateur)
export N8N_RUNNERS_STDLIB_ALLOW="*"
export N8N_RUNNERS_EXTERNAL_ALLOW=""
