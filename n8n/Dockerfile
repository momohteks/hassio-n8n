# Base : python:3.13-slim (Debian, glibc)
# - Python 3.13 requis par le Python Task Runner de n8n 2.x
# - glibc → compatible avec les prebuilds natifs n8n (isolated-vm, sqlite3, etc.)
ARG N8N_VERSION=2.17.8
FROM python:3.13-slim

ARG N8N_VERSION

LABEL \
    io.hass.name="n8n" \
    io.hass.description="n8n Workflow Automation" \
    io.hass.type="addon" \
    io.hass.version="${N8N_VERSION}"

# ---------------------------------------------------------------------------
# Étape 1 — Installer Node.js 22, build deps, n8n, Python Task Runner
# ---------------------------------------------------------------------------
# Le Python Task Runner (internal mode) est attendu par n8n à l'emplacement
# $(npm root -g)/@n8n/task-runner-python/.venv/bin/python
# (path résolu depuis __dirname du CLI n8n + ../../../@n8n/task-runner-python).
# NodeSource installe Node avec prefix /usr, donc npm root -g = /usr/lib/
# node_modules (PAS /usr/local/lib/node_modules).
# On clone la source du runner depuis le tag n8n@${N8N_VERSION} puis on
# provisionne un venv Python 3.13 avec la seule dépendance : websockets.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        gnupg \
        python3-venv \
        python3-dev \
        make \
        g++ \
        git \
    # Node.js 22 depuis NodeSource
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    # n8n via npm
    && npm install -g --omit=dev --unsafe-perm n8n@${N8N_VERSION} \
    && npm cache clean --force \
    # Python Task Runner : récupération de la source au bon tag
    && git clone --depth 1 --branch "n8n@${N8N_VERSION}" \
           https://github.com/n8n-io/n8n.git /tmp/n8n-src \
       || git clone --depth 1 https://github.com/n8n-io/n8n.git /tmp/n8n-src \
    # Installation à l'emplacement EXACT attendu par n8n (résolu via npm)
    && NPM_ROOT="$(npm root -g)" \
    && echo "[build] npm root -g = ${NPM_ROOT}" \
    && mkdir -p "${NPM_ROOT}/@n8n/task-runner-python" \
    && cp -r /tmp/n8n-src/packages/@n8n/task-runner-python/src \
             /tmp/n8n-src/packages/@n8n/task-runner-python/pyproject.toml \
             "${NPM_ROOT}/@n8n/task-runner-python/" \
    # Venv avec la Python 3.13 native du base image
    && python3 -m venv "${NPM_ROOT}/@n8n/task-runner-python/.venv" \
    && "${NPM_ROOT}/@n8n/task-runner-python/.venv/bin/pip" \
           install --no-cache-dir "websockets>=15.0.1" \
    # Vérification en dur : le python du venv doit exister
    && test -x "${NPM_ROOT}/@n8n/task-runner-python/.venv/bin/python" \
    && echo "[build] Python Task Runner venv OK at ${NPM_ROOT}/@n8n/task-runner-python/.venv" \
    # Nettoyage build deps (on ne peut PAS purger python3-venv/dev car le venv en dépend)
    && rm -rf /tmp/n8n-src \
    && apt-get purge -y --auto-remove make g++ git gnupg python3-dev \
    && rm -rf /var/lib/apt/lists/* /tmp/* /root/.npm /root/.cache

# ---------------------------------------------------------------------------
# Étape 2 — Dépendances runtime (nginx, supervisor, etc.)
# ---------------------------------------------------------------------------
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        nginx \
        supervisor \
        jq \
        curl \
        tzdata \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Utilisateur non-root pour n8n (l'image python:3.13-slim ne l'a pas)
# ---------------------------------------------------------------------------
RUN groupadd -g 1000 node \
    && useradd -u 1000 -g node -m -s /bin/bash node \
    && mkdir -p /data \
    && chown -R node:node /data

# ---------------------------------------------------------------------------
# Configs + entrypoint
# ---------------------------------------------------------------------------
COPY nginx.conf /etc/nginx/nginx.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY n8n-exports.sh /n8n-exports.sh
COPY run.sh /run.sh
COPY base-path-fix.html /base-path-fix.html

RUN chmod +x /n8n-exports.sh /run.sh

EXPOSE 5690 8081

CMD ["/run.sh"]
