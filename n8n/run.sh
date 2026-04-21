#!/bin/bash
set -e

# ---------------------------------------------------------------------------
# run.sh — Addon entrypoint
# ---------------------------------------------------------------------------
# 1. Read HA addon options (/data/options.json)
# 2. Resolve the real HA Ingress URL via the Supervisor API
#    (/addons/self/info -> .data.ingress_url). This is the ONE thing that
#    makes n8n's frontend assets work behind HA Ingress: n8n replaces the
#    /{{BASE_PATH}}/ placeholder in its .js/.css/.html bundles with this
#    path at startup, so the browser requests match what HA serves.
# 3. Pre-process the editor-ui dist so .mjs files — which n8n's native
#    compile step misses (glob is '**/*.{css,js}') — also get their
#    /{{BASE_PATH}}/ placeholder replaced.
# 4. Hand off to supervisord (nginx + n8n).
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

# --- 2. Ingress URL from Supervisor ---------------------------------------
INGRESS_URL="/"
if [ -n "${SUPERVISOR_TOKEN}" ]; then
    ADDON_INFO=$(curl -fsS -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
                       http://supervisor/addons/self/info 2>/dev/null || echo '{}')
    RESOLVED=$(echo "${ADDON_INFO}" | jq -r '.data.ingress_url // empty')
    if [ -n "${RESOLVED}" ] && [ "${RESOLVED}" != "null" ]; then
        INGRESS_URL="${RESOLVED}"
    else
        echo "[hassio-n8n] WARNING: could not resolve ingress_url from Supervisor, falling back to '/'"
    fi
else
    echo "[hassio-n8n] WARNING: SUPERVISOR_TOKEN not set, falling back to '/'"
fi

# Ensure trailing slash (n8n's replaceStream replaces '/{{BASE_PATH}}/'
# — a trailing-slash-delimited marker — so N8N_PATH must also end with /)
case "${INGRESS_URL}" in
    */) ;;
    *)  INGRESS_URL="${INGRESS_URL}/" ;;
esac
export N8N_PATH="${INGRESS_URL}"
echo "[hassio-n8n] N8N_PATH: ${N8N_PATH}"

# --- 3. Patch .mjs files in the editor-ui dist -----------------------------
# n8n 2.x's start.ts compile step does:
#   const files = await glob('**/*.{css,js}', { cwd: EDITOR_UI_DIST_DIR });
# which misses .mjs chunks, so they ship with literal /{{BASE_PATH}}/
# placeholders and every dynamic import under the ingress prefix 404s
# (the "Could not fetch node types" error). We do the same replacement
# ourselves on .mjs files. Backup each file on first run so the patch is
# idempotent across restarts (ingress token is stable but we don't rely
# on it).
EDITOR_DIST="$(npm root -g 2>/dev/null)/n8n/node_modules/n8n-editor-ui/dist"
if [ ! -d "${EDITOR_DIST}" ]; then
    # Fallback: resolve it the same way n8n does
    EDITOR_DIST="$(node -e "try{process.stdout.write(require('path').join(require('path').dirname(require.resolve('n8n-editor-ui')), 'dist'))}catch(e){}" 2>/dev/null)"
fi

if [ -n "${EDITOR_DIST}" ] && [ -d "${EDITOR_DIST}" ]; then
    echo "[hassio-n8n] Patching .mjs files under ${EDITOR_DIST}"
    count=0
    while IFS= read -r -d '' f; do
        [ -z "$f" ] && continue
        if [ ! -f "${f}.hassio_orig" ]; then
            cp -p "$f" "${f}.hassio_orig"
        fi
        cp -p "${f}.hassio_orig" "$f"
        # Use a non-/ delimiter since N8N_PATH contains slashes
        sed -i "s|/{{BASE_PATH}}/|${N8N_PATH}|g" "$f"
        count=$((count + 1))
    done < <(find "${EDITOR_DIST}" -type f -name "*.mjs" -print0)
    echo "[hassio-n8n] Patched ${count} .mjs files"
else
    echo "[hassio-n8n] WARNING: editor-ui dist dir not found — .mjs files will not be patched"
fi

# --- 3b. Inject debug telemetry into index.html ---------------------------
# Diagnostic build: the HA mobile app WebView loads all assets fine but
# never issues any /rest/* call — the failure is client-side, invisible
# in nginx logs. This injects a small JS snippet into index.html that
# hooks window.onerror, unhandledrejection, fetch() and XMLHttpRequest,
# and beacons each event to /__hassio_debug (handled by nginx). Results
# show up in the addon log with the prefix "[hassio-debug]".
# Idempotent across restarts via the .hassio_orig backup pattern.
DEBUG_SNIPPET=/debug-inject.html
INDEX_HTML="${EDITOR_DIST}/index.html"
if [ -f "${INDEX_HTML}" ] && [ -f "${DEBUG_SNIPPET}" ]; then
    if [ ! -f "${INDEX_HTML}.hassio_orig" ]; then
        cp -p "${INDEX_HTML}" "${INDEX_HTML}.hassio_orig"
    fi
    cp -p "${INDEX_HTML}.hassio_orig" "${INDEX_HTML}"
    # sed `r` inserts file contents AFTER the matched line. Works as long
    # as <head> is on its own line (it is in n8n's built index.html).
    sed -i "/<head[^>]*>/r ${DEBUG_SNIPPET}" "${INDEX_HTML}"
    echo "[hassio-n8n] Injected debug telemetry into index.html"
    # Dump every line of index.html that mentions BASE_PATH so we can
    # see what n8n actually writes into the page at runtime.
    echo "[hassio-n8n] index.html BASE_PATH references:"
    grep -n "BASE_PATH" "${INDEX_HTML}" | head -20 | while read -r line; do
        echo "[hassio-n8n]   ${line}"
    done || true
else
    echo "[hassio-n8n] WARNING: index.html or debug snippet missing — telemetry NOT injected"
fi

# --- 4. Prepare /data and hand off to supervisord -------------------------
# HA mounts /data as root:root at runtime (overriding the Dockerfile chown)
chown -R node:node /data
chmod 755 /data

exec supervisord -c /etc/supervisor/conf.d/supervisord.conf
