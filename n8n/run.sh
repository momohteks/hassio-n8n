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

# --- 3b. Inject window.BASE_PATH shim into index.html ---------------------
# In the Home Assistant Android companion WebView, n8n's own
# /static/base-path.js sets window.BASE_PATH = "/" at DOMContentLoaded
# instead of the real ingress prefix, so every /rest/* XHR 404s and the
# user sees "Error connecting to n8n". Regular browsers are unaffected.
# Fix: inject a small <script> into <head> that installs a getter/setter
# on window.BASE_PATH before any n8n script runs, pinning the value to
# the ingress prefix parsed from location.pathname. See base-path-fix.html.
# Idempotent across restarts via the .hassio_orig backup pattern.
BASE_PATH_FIX=/base-path-fix.html
INDEX_HTML="${EDITOR_DIST}/index.html"
if [ -f "${INDEX_HTML}" ] && [ -f "${BASE_PATH_FIX}" ]; then
    if [ ! -f "${INDEX_HTML}.hassio_orig" ]; then
        cp -p "${INDEX_HTML}" "${INDEX_HTML}.hassio_orig"
    fi
    cp -p "${INDEX_HTML}.hassio_orig" "${INDEX_HTML}"
    # sed `r` inserts file contents AFTER the matched line. Works as long
    # as <head> is on its own line (it is in n8n's built index.html).
    sed -i "/<head[^>]*>/r ${BASE_PATH_FIX}" "${INDEX_HTML}"
    echo "[hassio-n8n] Injected window.BASE_PATH shim into index.html"
else
    echo "[hassio-n8n] WARNING: index.html or base-path-fix.html missing — shim NOT injected"
fi

# --- 3c. Neutralize n8n's browser-id auth check ----------------------------
# Symptom: after opening a workflow, closing it, and reopening the same (or
# another) workflow from the list, the editor shows a blank "My workflow"
# canvas instead of the requested workflow's content. Root cause confirmed
# live from the addon nginx access log:
#   browserId check failed on /rest/workflows/:workflowId
#   "GET /rest/workflows/<id> HTTP/1.1" 400 5
# In `packages/cli/src/auth/auth.service.ts`, validateBrowserId compares the
# JWT's hashed browserId against the one sent in the X-Browser-Id header.
# Under HA Ingress (iframe, sometimes re-creating execution contexts on
# router re-entry), the header occasionally arrives missing or stale; n8n
# throws AuthError('Unauthorized'), the frontend reads the 400 as "workflow
# not found", and redirects to /workflow/<newId>?new=true — the blank
# canvas the user sees.
# Fix: turn validateBrowserId into a no-op. Safe in the single-user HA
# addon context — the JWT itself still authenticates; we only skip the
# secondary per-browser binding. Idempotent via the .hassio_orig backup.
AUTH_SERVICE_JS="$(node -e "try{process.stdout.write(require.resolve('n8n/dist/auth/auth.service.js'))}catch(e){}" 2>/dev/null)"
if [ -z "${AUTH_SERVICE_JS}" ]; then
    AUTH_SERVICE_JS="$(npm root -g 2>/dev/null)/n8n/dist/auth/auth.service.js"
fi
if [ -f "${AUTH_SERVICE_JS}" ]; then
    if [ ! -f "${AUTH_SERVICE_JS}.hassio_orig" ]; then
        cp -p "${AUTH_SERVICE_JS}" "${AUTH_SERVICE_JS}.hassio_orig"
    fi
    cp -p "${AUTH_SERVICE_JS}.hassio_orig" "${AUTH_SERVICE_JS}"
    node -e "
      const fs = require('fs');
      const p = process.argv[1];
      let s = fs.readFileSync(p, 'utf8');
      const re = /validateBrowserId\s*\([^)]*\)\s*\{/;
      if (re.test(s)) {
        s = s.replace(re, m => m + ' return; /* hassio-n8n: browser-id check disabled */');
        fs.writeFileSync(p, s);
        console.log('[hassio-n8n] Patched validateBrowserId in ' + p);
      } else {
        console.log('[hassio-n8n] WARNING: validateBrowserId signature not found in ' + p);
      }
    " "${AUTH_SERVICE_JS}"
else
    echo "[hassio-n8n] WARNING: auth.service.js not found — browser-id patch skipped"
fi

# --- 4. Prepare /data and hand off to supervisord -------------------------
# HA mounts /data as root:root at runtime (overriding the Dockerfile chown)
chown -R node:node /data
chmod 755 /data

exec supervisord -c /etc/supervisor/conf.d/supervisord.conf
