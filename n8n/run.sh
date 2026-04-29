#!/bin/bash
set -e

# ---------------------------------------------------------------------------
# run.sh — Addon entrypoint
# ---------------------------------------------------------------------------
# 1. Read HA addon options (/data/options.json) and export them.
# 2. Prepare /data ownership (HA mounts it as root:root at runtime).
# 3. Hand off to supervisord (nginx + n8n).
#
# No Ingress URL resolution, no .mjs patching, no JS injection — n8n is
# served plainly on port 5678 and the user is expected to put a reverse
# proxy in front of it (typically a dedicated subdomain).
# ---------------------------------------------------------------------------

# --- 1. Addon options ------------------------------------------------------
if [ -f /data/options.json ]; then
    WEBHOOK_URL=$(jq -r '.webhook_url // ""' /data/options.json)
    TIMEZONE=$(jq -r '.timezone // "Europe/Paris"' /data/options.json)
else
    WEBHOOK_URL=""
    TIMEZONE="Europe/Paris"
fi
export WEBHOOK_URL
export TIMEZONE

echo "[hassio-n8n] Timezone: ${TIMEZONE}"
[ -n "${WEBHOOK_URL}" ] && echo "[hassio-n8n] Webhook URL: ${WEBHOOK_URL}"

# --- 2. Prepare /data ------------------------------------------------------
# HA mounts /data as root:root at runtime (overriding the Dockerfile chown)
chown -R node:node /data
chmod 755 /data

# --- 3. Hand off to supervisord -------------------------------------------
exec supervisord -c /etc/supervisor/conf.d/supervisord.conf
