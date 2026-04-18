#!/usr/bin/env bash

# ---------------------------------------------------------------------------
# n8n-exports.sh — Environment variables for n8n
# Sourced by supervisord just before starting n8n. Relies on run.sh having
# already resolved the ingress URL and exported N8N_PATH.
# ---------------------------------------------------------------------------

# Internal port for n8n. nginx sits in front on 5690 (ingress) and 8081
# (public webhooks/API). 5680 avoids the n8n 2.x Task Broker default (5679).
export N8N_PORT=5680
export N8N_PROTOCOL=http
export N8N_HOST=0.0.0.0

# N8N_PATH must already be exported by run.sh (resolved from the HA
# Supervisor /addons/self/info endpoint). Fallback to '/' for safety.
export N8N_PATH="${N8N_PATH:-/}"

# Persistent data folder (HA /data volume)
export N8N_USER_FOLDER=/data

# SQLite database
export DB_TYPE=sqlite
export DB_SQLITE_DATABASE=/data/database.sqlite

# Timezone (injected by run.sh)
export GENERIC_TIMEZONE="${TIMEZONE:-Europe/Paris}"
export TZ="${TIMEZONE:-Europe/Paris}"

# Public webhook URL (if provided in addon options)
if [ -n "${WEBHOOK_URL}" ]; then
    export WEBHOOK_URL="${WEBHOOK_URL}"
fi

# HA Ingress serves the UI over HTTP (even if HA itself is HTTPS), and
# cookies flagged Secure would be dropped by the browser. Disable the
# Secure flag so the auth cookie is accepted inside the ingress iframe.
export N8N_SECURE_COOKIE=false

# UI and telemetry hygiene
export N8N_HIRING_BANNER_ENABLED=false
export N8N_PERSONALIZATION_ENABLED=false
export N8N_VERSION_NOTIFICATIONS_ENABLED=false
export N8N_DIAGNOSTICS_ENABLED=false

# Logs
export N8N_LOG_LEVEL=info
export N8N_LOG_OUTPUT=console

# Executions
export EXECUTIONS_MODE=regular

# ---------------------------------------------------------------------------
# Task Runners (n8n 2.x — mandatory)
# ---------------------------------------------------------------------------
export N8N_RUNNERS_MODE=internal
export N8N_RUNNERS_BROKER_PORT=5679
export N8N_RUNNERS_BROKER_LISTEN_ADDRESS=127.0.0.1

# Python Task Runner permissions
export N8N_RUNNERS_STDLIB_ALLOW="*"
export N8N_RUNNERS_EXTERNAL_ALLOW=""
