# hassio-n8n — Home Assistant Addon for n8n

## Overview

A Home Assistant addon that hosts an n8n instance via **nginx +
supervisord**. Repo: https://github.com/momohteks/hassio-n8n

## Architecture (since 2.18.5.3 — HA Ingress dropped)

```
[External reverse proxy / dedicated subdomain]
   → nginx:5678  →  n8n:5680   (UI + REST API + webhooks)
   → nginx:8081  →  n8n:5680   (public webhooks only, 403 on /)
                                Task Broker (n8n 2.x internal) → 5679
```

- **HA Ingress is intentionally disabled.** n8n 2.x does not properly
  support being served under a sub-path (see
  [n8n-io/n8n#19437](https://github.com/n8n-io/n8n/issues/19437),
  upstream maintainer Tomi: *"N8N_PATH is not fully supported in the
  app (...) we are possibly going to remove the path option from
  v2"*). The user runs their own reverse proxy (Nginx Proxy Manager,
  Traefik…) pointing a dedicated subdomain at `http://<HA-IP>:5678`.
- **nginx** = simple reverse proxy. No `sub_filter`, no rewrites, no
  JS shim, no healthz short-circuit, no `<base href>` injection, no
  `.mjs` or `auth.service.js` patching.
- **n8n** listens on internal port 5680 (Task Broker uses 5679).
  nginx listens publicly on 5678 and forwards there.
- **supervisord** runs both processes (nginx + n8n).
- Data persists in `/data` (HA volume).

## Key files

| File | Role |
|------|------|
| `n8n/config.yaml` | HA addon manifest — version is auto-bumped |
| `n8n/Dockerfile` | Multi-arch image — `ARG N8N_VERSION` is auto-bumped |
| `n8n/build.yaml` | HA base images per architecture |
| `n8n/n8n-exports.sh` | All n8n environment variables |
| `n8n/nginx.conf` | UI proxy (5678) and public webhooks proxy (8081) → n8n (5680 internal) |
| `n8n/supervisord.conf` | Process supervision (nginx + n8n) |
| `n8n/run.sh` | Container entrypoint |
| `.github/workflows/update-n8n.yml` | Detects new n8n versions (daily cron) |
| `.github/workflows/publish-release.yml` | Builds & pushes ghcr.io images on tag push |

## Docker images

- `ghcr.io/momohteks/hassio-n8n-amd64:{version}`
- `ghcr.io/momohteks/hassio-n8n-aarch64:{version}`

## Versioning

**4-digit format**: `{n8n_major}.{n8n_minor}.{n8n_patch}.{addon_build}`

Example: `2.18.5.3` = n8n 2.18.5, addon build #3.

- The **first 3 digits** track the upstream n8n version (in
  `n8n/Dockerfile` → `ARG N8N_VERSION`).
- The **4th digit** is the addon build number (in `n8n/config.yaml`
  → `version:`).
  - Reset to `1` whenever n8n is bumped.
  - Incremented for any addon-only rebuild (config or Dockerfile fix).

## Auto-update (`.github/workflows/update-n8n.yml`)

Two modes, one workflow:

**`auto` mode (daily cron at 6:00 UTC)**
1. `npm view n8n version` → fetch the latest upstream release.
2. Compare against the first 3 digits of `config.yaml`.
3. If different: set version to `{new_n8n}.1`, update config + Dockerfile
   + CHANGELOG, tag.

**`rebuild_only` mode (manual trigger from the Actions tab)**
1. No npm check.
2. Bump only the 4th digit: `2.18.5.3` → `2.18.5.4`.
3. Dockerfile unchanged, config.yaml bumped + tag.

Pushing tag `v{X.Y.Z.B}` triggers `publish-release.yml` which:
- Extracts the n8n digits (first 3) as the `N8N_VERSION` build arg.
- Builds and pushes multi-arch images on
  `ghcr.io/momohteks/hassio-n8n-{arch}:{X.Y.Z.B}`.
- Also tags `:{X.Y.Z}` (floating) and `:latest`.
- Creates a GitHub Release.

## Required GitHub Actions permissions

In the GitHub repo settings:
- **Settings → Actions → General → Workflow permissions:**
  "Read and write permissions".
- **Settings → Packages:** ghcr.io enabled (automatic if write
  permissions are on).

## Local development

```bash
# Build (amd64)
cd n8n/
docker build \
  --build-arg N8N_VERSION=2.18.5 \
  -t hassio-n8n-test .

# Run locally
docker run -p 5678:5678 -p 8081:8081 -v $(pwd)/data:/data hassio-n8n-test
```

## Adding to Home Assistant

1. HA → Settings → Add-ons → Store → ⋮ → Repositories
2. Add: `https://github.com/momohteks/hassio-n8n`
3. Install the addon. Then configure an external reverse proxy (NPM,
   Traefik, Caddy…) to forward a subdomain to `http://<HA-IP>:5678`.
   Since 2.18.5.3 the addon is no longer reachable through HA's
   Ingress panel.

## Supported architectures

- `amd64` (x86_64)
- `aarch64` (ARM64)

## Documentation policy

The repo is publicly hosted on GitHub for an international audience.
**All code, docs, comments, commit messages, and CHANGELOG entries
must be in English.** No French content anywhere in the repo.

## Notable historical fixes (for reference only — most no longer apply)

### v2.18.5.3 — Drop HA Ingress (current architecture)

- Removed the entire HA Ingress integration. n8n 2.x's `N8N_PATH`
  support is incomplete; multiple workarounds at the nginx and
  frontend layers (browser-id bypass, conditional-GET strip,
  cache-buster, full XHR-to-fetch wrapper) failed to mask the
  resulting 400 octet-stream bug on `/rest/workflows/<id>` reliably.
  Following the upstream maintainers' recommendation, the addon now
  ships a plain reverse proxy on port 5678 and the user puts their own
  reverse proxy in front.

### v2.16.1.7 — Python Task Runner + aarch64 disabled

- **Python Task Runner**: switched the base image to
  `python:3.13-slim` (required by the runner). Node.js 22 installed
  via NodeSource. The Python runner source is cloned at the matching
  `n8n@${N8N_VERSION}` tag and installed at the exact path n8n looks
  for in internal mode:
  `/usr/local/lib/node_modules/@n8n/task-runner-python/.venv/bin/python`.
  The venv is provisioned with `websockets>=15.0.1`.
- **Deprecated env vars** removed: `N8N_RUNNERS_ENABLED` and
  `EXECUTIONS_PROCESS`.
- **New env vars**: `N8N_RUNNERS_STDLIB_ALLOW=*` (full Python stdlib
  available from user code).
- **aarch64** disabled in `config.yaml`, `build.yaml`, and the
  `publish-release.yml` matrix.
