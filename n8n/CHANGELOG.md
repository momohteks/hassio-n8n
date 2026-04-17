# Changelog

## 2.16.1.11 — 2026-04-17

- **Ingress UI fix (round 3)**: 2.16.1.10 inverted the backend rewrite.
  The console reported many `Failed to load module script: Expected
  JavaScript but got text/html` errors, which is the SPA-fallback
  signature — n8n's catch-all route returning `index.html` for paths it
  couldn't match.
- Root cause: n8n's Express server mounts **every** route at `/` (static
  files, `/rest`, `/rest/push`, …) regardless of `N8N_PATH`. Verified
  in `packages/cli/src/server.ts`:
  - `this.app.use('/', express.static(staticCacheDir, cacheOptions));`
  - `this.app.get('/\${this.restEndpoint}/...')`
  - `push.setupPushHandler(restEndpoint, app);`
  `N8N_PATH` only affects the `{{BASE_PATH}}` placeholder replacement
  inside frontend bundles — it does not prefix backend routes.
- Fix: removed the incoming `rewrite ^/(.*)$ /hassio-n8n-prefix/$1` from
  both nginx server blocks (5678 Ingress + 8081 public). The proxy now
  passes paths through unchanged, which matches n8n's root-mounted
  routes. `N8N_PATH` + `sub_filter` still handle the frontend prefix
  injection in the response body.

## 2.16.1.10 — 2026-04-17

- **Ingress UI connectivity fix** (real solution): the previous
  `sub_filter`-per-path approach in 2.16.1.9 missed URLs hidden inside
  Vite-minified JS (template literals, computed concatenations), so
  `GET /rest/settings` and `/assets/en-*.js` still hit the root domain
  and returned 404 ("Error connecting to n8n").
- Switched to n8n's native sub-path mechanism using a static placeholder:
  - `N8N_PATH=/hassio-n8n-prefix/` — n8n replaces the Vite `{{BASE_PATH}}`
    placeholder with this marker in every HTML/JS/CSS file at startup,
    so **every** asset URL now carries it (including the ones
    `sub_filter` was missing before).
  - nginx `rewrite ^/(.*)$ /hassio-n8n-prefix/$1 break;` re-adds the
    marker to every incoming request before proxying to n8n (HA Ingress
    strips its dynamic prefix on the way in).
  - A single `sub_filter '/hassio-n8n-prefix/' '$http_x_ingress_path/'`
    rewrites the marker back to the real HA Ingress prefix in every
    response, so the browser's fetches match what HA serves.
  - `proxy_redirect /hassio-n8n-prefix/ $http_x_ingress_path/` handles
    3xx Location headers the same way.
- Removed all per-path sub_filters (`"/rest/"`, `"/assets/"`, etc.) —
  one global marker rewrite replaces them all and is robust to JS
  minification.
- Public port 8081 (webhooks / REST API) also re-adds the static prefix
  before proxying, so the backend routes match.

## 2.16.1.9 — 2026-04-17

- **Addon icon**: added `n8n/icon.png` (180×180, sourced from n8n.io's
  `apple-touch-icon.png`) and `n8n/logo.png` (458×124, from
  `n8n-io/n8n/assets/n8n-logo.png`). Home Assistant picks them up
  automatically.
- **Blank UI page via HA Ingress**: fixed by rewriting the absolute URLs
  emitted by n8n on the fly, using the dynamic prefix HA sends in the
  `X-Ingress-Path` header.
  - `gzip off` + `Accept-Encoding ""` on the upstream so `sub_filter` can
    operate on plain responses.
  - Rewrites HTML attributes `href="/..."`, `src="/..."`, `action="/..."`.
  - Rewrites n8n-specific paths inside JS/JSON bundles: `"/rest/"`,
    `"/assets/"`, `"/webhook/"`, `"/webhook-test/"`, `"/webhook-waiting/"`,
    `"/types/"`, `"/static/"`, `"/push"`, `"/form/"`.
  - Injects a `<base href="$prefix/">` tag inside `<head>` so relative
    URLs resolve under the Ingress prefix.
  - `proxy_hide_header Content-Security-Policy` so the injected `<base>`
    is not blocked by n8n's CSP.
  - `X-Forwarded-Prefix` passed to n8n in case a future version picks it
    up natively.
- **WebSockets**: proper upgrade handling via a
  `map $http_upgrade $connection_upgrade`, so the n8n real-time push
  connections are not broken by the Ingress proxy block.

## 2.16.1.8 — 2026-04-17

- Python Task Runner fix (round 2): the venv was being installed under
  `/usr/local/lib/node_modules/`, but NodeSource installs global modules
  under `/usr/lib/node_modules/` (prefix `/usr` rather than `/usr/local`).
  The venv is now provisioned at the exact path resolved by `npm root -g`
  (= `/usr/lib/node_modules/@n8n/task-runner-python/.venv/`), which is
  what n8n looks up through `__dirname + '../../../@n8n/...'`.
- Added a `test -x` guard at the end of the install step so the build
  fails early if the venv is not provisioned correctly.

## 2.16.1.7 — 2026-04-16

- **Python Task Runner** now working in `internal` mode:
  - Switched the base image to `python:3.13-slim` (required Python
    version for the runner).
  - Node.js 22 installed on top via NodeSource.
  - Python runner source pulled from the `n8n@${N8N_VERSION}` tag and
    installed at the path n8n expects:
    `/usr/local/lib/node_modules/@n8n/task-runner-python/.venv/bin/python`.
  - Venv provisioned with `websockets>=15.0.1` as the only dependency.
  - `N8N_RUNNERS_STDLIB_ALLOW=*` → the full Python standard library is
    available to workflows.
- Cleaned up deprecated env vars: `N8N_RUNNERS_ENABLED` and
  `EXECUTIONS_PROCESS` removed.
- **aarch64 temporarily disabled** in `config.yaml`, `build.yaml` and
  the GitHub Actions matrix. Only `amd64` is published until further
  notice.
- README translated to English (target audience = international GitHub
  users).

## 2.16.1.6 — 2026-04-16

- Task Broker fix (real solution): in n8n 2.x Task Runners are
  mandatory and the Task Broker listens on 5679. n8n itself is moved
  to port 5680 while the broker keeps 5679, which resolves the
  collision.
- `nginx.conf`: upstream now points at `127.0.0.1:5680`.
- `N8N_RUNNERS_ENABLED` kept `true` (per n8n 2.x); the broker port is
  pinned explicitly via `N8N_RUNNERS_BROKER_PORT=5679` and
  `N8N_RUNNERS_BROKER_LISTEN_ADDRESS=127.0.0.1`.

## 2.16.1.5 — 2026-04-16

- Attempted fix: Task Runners disabled via `N8N_RUNNERS_ENABLED=false`.
  The n8n 2.x internal Task Broker tried to bind to port 5679, already
  in use by the main n8n process, causing a startup crash
  (`n8n Task Broker's port 5679 is already in use`). Workflows were
  meant to run inside the main process (n8n 1.x behaviour), which is
  acceptable for a self-hosted home setup.
  *(Superseded by 2.16.1.6 — this env var is no longer honoured in
  n8n 2.x.)*

## 2.16.1.4 — 2026-04-15

- Fix: runtime `chown /data` so n8n (running as `node`) can write to it
  (HA mounts `/data` as root, which overrides the Dockerfile `chown`).
- Introduced the 4-digit versioning scheme:
  `{n8n_version}.{addon_build}`.
- Removed tini (redundant with supervisord).
- Split the RUN layers (build-deps vs runtime-deps) to prevent
  `apt purge --auto-remove` from taking supervisord out with it.

## 2.16.1 — 2026-04-15

- Initial addon release.
- n8n 2.16.1 support.
- Home Assistant Ingress integration.
- Dedicated webhook port (8081).
- amd64 + aarch64 support.
- Automatic updates via GitHub Actions.
