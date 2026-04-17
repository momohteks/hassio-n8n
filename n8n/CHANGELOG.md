# Changelog

## 2.16.1.15 — 2026-04-17

- **Still "Could not fetch node types" after 2.16.1.14**. Root-cause
  analysis found three weaknesses that could each cause the
  `GET /types/nodes.json` request to hit the SPA fallback (HTML) instead
  of the protected type route, breaking the Pinia `nodeTypes` store:
  1. n8n uses express `compression()` middleware globally
     (`abstract-server.ts:119`). Our `Accept-Encoding: ""` header didn't
     reliably suppress it — some setups still gzipped responses, which
     `sub_filter` cannot read. **Fix**: send `Accept-Encoding: identity`
     explicitly, and enable nginx `gunzip on` as a safety net so nginx
     transparently decodes any gzipped upstream body before sub_filter.
  2. Default nginx proxy buffers (8 × 4k) are too small for n8n's
     minified editor bundles (1-2 MB .mjs files). sub_filter still
     works across streaming, but large buffers reduce the chance of
     weird edge cases. **Fix**: `proxy_buffer_size 16k; proxy_buffers 16 16k;`.
  3. The runtime JS shim fell back to `window.location.pathname` when
     `window.BASE_PATH` looked unusable. If the user reloaded at a
     deep URL (`/api/hassio_ingress/<token>/workflow/new`), the shim
     used the whole pathname as the base, so
     `BASE_PATH + "types/nodes.json"` resolved to
     `/api/.../workflow/new/types/nodes.json` — SPA fallback, HTML,
     retry loop exhausts, throws "Could not fetch node types".
     **Fix**: the shim now pattern-matches HA's
     `/api/hassio_ingress/<token>/` prefix from `pathname` and uses
     just that as the base, regardless of how deep the SPA is.
- Added `X-Ingress-Prefix` response header and a `console.log` of the
  resolved `BASE_PATH` in the shim, so misconfiguration is visible from
  the browser DevTools without having to read addon logs.

## 2.16.1.14 — 2026-04-17

- **"Could not fetch node types" on first workflow**. The UI loaded fine
  after 2.16.1.13, but opening the node picker failed with dynamic-import
  errors on `.mjs` chunks pointing at `/{{BASE_PATH}}/...`.
- Root cause in n8n itself: `packages/cli/src/commands/start.ts` compiles
  the frontend at startup with the regex
  `/(index\.html)|.*\.(js|css)/` — which **does not match `.mjs`**. So
  `.mjs` files ship with the raw Vite placeholder `/{{BASE_PATH}}/`
  instead of the configured `N8N_PATH` value, and every dynamic import
  hits the wrong URL.
- Fix (nginx only, no n8n patch):
  1. Added a second `sub_filter '/{{BASE_PATH}}/' '$ingress_prefix/';`
     so the raw placeholder in `.mjs` bodies is rewritten in-flight to
     the real ingress prefix (same treatment as the static marker).
  2. Extended the `<head>`-injected JS shim to recognise the
     `/{{BASE_PATH}}/` marker too (in addition to
     `/hassio-n8n-prefix/`) when rewriting `fetch` / `XHR` / `WebSocket`
     URLs — last-line defence for any chunk sub_filter misses.
  - The shim builds the `/{{BASE_PATH}}/` string from concatenated
    pieces so the new sub_filter doesn't rewrite the shim itself.

## 2.16.1.13 — 2026-04-17

- **Hotfix**: 2.16.1.12 wouldn't boot — nginx aborted with
  `invalid variable name in /etc/nginx/nginx.conf:124`. The JS shim
  injected via `sub_filter` contained `/\/+$/` regexes, and nginx tried
  to interpolate the `$/` as a variable reference.
- Trailing-slash stripping is now done with a `while` loop instead of a
  regex with an end-anchor, so the inlined JS no longer contains any
  `$` characters.

## 2.16.1.12 — 2026-04-17

- **Ingress UI fix (round 4) — three layers of defence**. The 2.16.1.11
  narrow `sub_filter_types` list missed JS chunks that n8n's Express
  serves as `text/javascript` (not `application/javascript`), so the
  static marker `/hassio-n8n-prefix/` leaked straight into the browser
  as `ERR_ABORTED 404`. Even with the MIME list fixed, an empty or
  mismatched `X-Ingress-Path` header would still break rewriting on
  setups where an external reverse proxy fronts HA.
- Fixes:
  1. **`sub_filter_types *;`** — rewrite the marker in every response
     content type (`text/javascript`, `.mjs`, `.css`, `text/html`,
     everything).
  2. **`$ingress_prefix` map** with fallback chain:
     `X-Forwarded-Prefix` (what the browser actually sees, set by
     external reverse proxies) → `X-Ingress-Path` (HA Core native
     Ingress) → empty.
  3. **Runtime JS shim injected before `</head>`.** Runs after
     `/static/base-path.js` (where n8n defines `window.BASE_PATH`, the
     single source of truth for all its URL construction — Vue Router
     history base, Axios `baseURL`, asset loaders, template fetches).
     The shim:
     - overrides `window.BASE_PATH` with a value derived from the real
       runtime URL if base-path.js still held the raw marker (meaning
       sub_filter missed it) or a bogus empty value;
     - wraps `fetch` / `XMLHttpRequest.open` / `WebSocket` so any URL
       still starting with the marker gets rewritten client-side —
       last-line defence for chunks loaded after page init.
- Access log now prints `ingress_prefix="…"` on every request, making
  misconfigured proxy chains trivially diagnosable.

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
