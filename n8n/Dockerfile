# Base: python:3.13-slim (Debian, glibc)
#   - Python 3.13 is required by the n8n 2.x Python Task Runner
#   - glibc keeps n8n's native prebuilds happy (isolated-vm, sqlite3, etc.)
ARG N8N_VERSION=2.18.7
FROM python:3.13-slim

ARG N8N_VERSION

LABEL \
    io.hass.name="n8n" \
    io.hass.description="n8n Workflow Automation" \
    io.hass.type="addon" \
    io.hass.version="${N8N_VERSION}"

# ---------------------------------------------------------------------------
# Stage 1 — Install Node.js 22, build deps, n8n, Python Task Runner
# ---------------------------------------------------------------------------
# n8n's Python Task Runner (internal mode) is loaded from
#   $(npm root -g)/@n8n/task-runner-python/.venv/bin/python
# (path resolved from the n8n CLI's __dirname + ../../../@n8n/task-runner-python).
# NodeSource installs Node with prefix /usr, so `npm root -g` is
#   /usr/lib/node_modules    (NOT /usr/local/lib/node_modules)
# We clone the runner source at tag n8n@${N8N_VERSION} and provision a
# Python 3.13 venv whose only dependency is `websockets`.
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
    # Node.js 22 from NodeSource
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    # n8n via npm
    && npm install -g --omit=dev --unsafe-perm n8n@${N8N_VERSION} \
    && npm cache clean --force \
    # Python Task Runner: pull the runner source at the matching tag
    && git clone --depth 1 --branch "n8n@${N8N_VERSION}" \
           https://github.com/n8n-io/n8n.git /tmp/n8n-src \
       || git clone --depth 1 https://github.com/n8n-io/n8n.git /tmp/n8n-src \
    # Drop it at the EXACT path n8n looks for (resolved via npm)
    && NPM_ROOT="$(npm root -g)" \
    && echo "[build] npm root -g = ${NPM_ROOT}" \
    && mkdir -p "${NPM_ROOT}/@n8n/task-runner-python" \
    && cp -r /tmp/n8n-src/packages/@n8n/task-runner-python/src \
             /tmp/n8n-src/packages/@n8n/task-runner-python/pyproject.toml \
             "${NPM_ROOT}/@n8n/task-runner-python/" \
    # venv on the base image's native Python 3.13
    && python3 -m venv "${NPM_ROOT}/@n8n/task-runner-python/.venv" \
    && "${NPM_ROOT}/@n8n/task-runner-python/.venv/bin/pip" \
           install --no-cache-dir "websockets>=15.0.1" \
    # Hard sanity check: the venv python must exist and be executable
    && test -x "${NPM_ROOT}/@n8n/task-runner-python/.venv/bin/python" \
    && echo "[build] Python Task Runner venv OK at ${NPM_ROOT}/@n8n/task-runner-python/.venv" \
    # Build deps cleanup (cannot purge python3-venv/dev — the venv depends on them)
    && rm -rf /tmp/n8n-src \
    && apt-get purge -y --auto-remove make g++ git gnupg python3-dev \
    && rm -rf /var/lib/apt/lists/* /tmp/* /root/.npm /root/.cache

# ---------------------------------------------------------------------------
# Stage 2 — Runtime dependencies (nginx, supervisor, etc.)
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
# Non-root user for n8n (the python:3.13-slim base image doesn't ship one)
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

RUN chmod +x /n8n-exports.sh /run.sh

EXPOSE 5678 8081

CMD ["/run.sh"]
