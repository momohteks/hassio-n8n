#!/usr/bin/env bash

# ---------------------------------------------------------------------------
# n8n-exports.sh — Environment variables for n8n
# Sourced by supervisord just before starting n8n.
# ---------------------------------------------------------------------------

# nginx listens publicly on 5678 (UI + everything) and 8081 (webhooks
# only), so n8n must NOT share port 5678 with nginx. Internal n8n port
# is 5680 (5679 is taken by the n8n 2.x Task Broker).
export N8N_PORT=5680
export N8N_PROTOCOL=http
export N8N_HOST=0.0.0.0

# Persistent data folder (HA /data volume)
export N8N_USER_FOLDER=/data

# SQLite database
export DB_TYPE=sqlite
export DB_SQLITE_DATABASE=/data/database.sqlite

# Timezone (injected by run.sh from addon options)
export GENERIC_TIMEZONE="${TIMEZONE:-Europe/Paris}"
export TZ="${TIMEZONE:-Europe/Paris}"

# Public webhook URL (if provided in addon options)
if [ -n "${WEBHOOK_URL}" ]; then
    export WEBHOOK_URL="${WEBHOOK_URL}"
fi

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
