# Changelog

## 2.18.5.1 — 2026-04-29

- Nouvelle version n8n : 2.17.8 → 2.18.5


## 2.17.8.4 — 2026-04-28

- **Fix 3 reworked**: replace `XMLHttpRequest` constructor with a
  wrapper that, for `/rest/workflows/<id>` and `/rest/active-workflows`
  GETs, emulates the XHR API on top of `fetch()` (verified to always
  return 200 in the same tab/session) and delegates to the native XHR
  for every other request. The 2.17.8.3 cache-buster approach failed
  in production: the bug reproduces even with `?_hsb=<rand>` appended.
  Routing the affected calls through `fetch()` sidesteps whatever
  inside n8n's XHR pipeline produces the spurious 400 octet-stream
  response. axios sees a normal 200 + JSON, the workflow loads.


## 2.17.8.3 — 2026-04-28

- **Frontend cache-buster — final fix for the "reopen workflow shows
  blank canvas" bug.** The 2.17.8.2 nginx hardening (no-store, ETag
  hidden, `If-None-Match` stripped) was correct but insufficient: the
  bug reproduces even with conditional-GET impossible. The exact root
  cause inside n8n's middleware stack remains unidentified, but a
  single distinguishing factor reliably masks it: any unique query
  parameter on the URL. The same axios call with `?_=<ts>` returns
  200 with full data; without it, a second visit returns 400 +
  `application/octet-stream` + 5-byte body, and the frontend treats
  the 400 as "workflow not found" → redirect to
  `/workflow/<newAutoId>?new=true`.
- **`base-path-fix.html` — Fix 3**: wrap `XMLHttpRequest.prototype.open`
  to append `?_hsb=<base36-time><rand>` to every GET on
  `/rest/workflows/<id>` and `/rest/active-workflows`. Each request is
  unique → whatever cache/state corruption was producing the 400 can no
  longer match. n8n's express ignores unknown query parameters, so
  workflow semantics are unaffected. /rest/push (SSE), /rest/login,
  binary-data and the rest of the API are untouched. Confirmed
  experimentally: identical headers + same XHR but with cache-buster
  always return 200 + the workflow JSON.
- The 2.17.8.2 nginx `/rest/*` block is kept as defense-in-depth (any
  future cache-related regression is still neutralized).


## 2.17.8.2 — 2026-04-28

- **Definitive fix for the "reopen workflow shows blank canvas" bug.**
  The 2.17.7.3 browser-id bypass was correct but insufficient — the bug
  reproduces even with `validateBrowserId` neutralized. Captured live in
  DevTools: the second axios GET on `/rest/workflows/<id>` (same tab,
  same cookies, same headers as the working first GET) returns
    `HTTP/1.1 400 / content-type: application/octet-stream / 5-byte body`
  while a manual `fetch()` to the same URL from the same tab returns
  `200 + JSON`. The frontend reads the 400 as "workflow not found" and
  redirects to `/workflow/<newAutoId>?new=true`.
- Root cause is a conditional-GET race: the browser caches the first
  response (with ETag), sends `If-None-Match` on the second axios call,
  and one of n8n's response middlewares emits a corrupted 400
  octet-stream during revalidation. HA's PWA service worker scope on
  the parent domain makes the failure mode more frequent.
- **`nginx.conf`**: a new `location ~ ^/rest/` block on the Ingress
  listener (port 5690) short-circuits conditional-GET entirely:
  `If-None-Match` / `If-Modified-Since` are stripped before proxying,
  `ETag` and `Last-Modified` are hidden on the response, and
  `Cache-Control: no-store, no-cache, must-revalidate, max-age=0`
  is forced on every `/rest/*` reply. n8n therefore always returns
  full responses, the browser never revalidates, and the SW cannot
  intercept. WebSocket upgrade for `/rest/push` is preserved.
- The 2.17.7.3 `validateBrowserId` no-op patch in `run.sh` is kept —
  it's correct (verified: `/rest/active-workflows` no longer 400s on
  browser-id mismatch) and complements the nginx fix.
- Also bumps n8n upstream from 2.17.7 to 2.17.8.


## 2.17.8.1 — 2026-04-28

- Nouvelle version n8n : 2.17.7 → 2.17.8


## 2.17.7.3 — 2026-04-24

- **Fix: reopening a workflow shows a blank "My workflow" canvas.**
  Reproduction: open a workflow → return to the workflows list → reopen
  the same (or another) workflow — the editor lands on an empty new
  canvas instead of the requested workflow. Root cause confirmed from
  the addon's nginx access log:
    `browserId check failed on /rest/workflows/:workflowId`
    `"GET /rest/workflows/<id> HTTP/1.1" 400 5`
  n8n's `validateBrowserId` middleware (in
  `packages/cli/src/auth/auth.service.ts`) compares the JWT's hashed
  `browserId` against the `browser-id` header on every non-skip
  endpoint. Under HA Ingress (iframe, router re-entry on the same
  route), the header occasionally arrives missing or stale; n8n throws
  `AuthError('Unauthorized')`, the frontend reads the 400 as "workflow
  not found" and redirects to `/workflow/<newAutoId>?new=true` — the
  blank canvas the user sees. The 2.17.7.2 `<base href>` shim fixed a
  different first-open symptom but did not address this re-open bug.
- **`run.sh`**: adds a new startup step that neutralizes
  `validateBrowserId` in the compiled `auth.service.js` by prepending
  `return;` as the first statement of the method (idempotent via the
  `.hassio_orig` backup pattern). Safe in the single-user HA addon
  context — the JWT itself still authenticates each request; we only
  skip the secondary per-browser binding that assumes a stable
  non-iframed browser context.


## 2.17.7.2 — 2026-04-24

- **Fix: blank workflow canvas on n8n 2.17.7 (`Error: Could not resolve
  undefined` in `useInjectWorkflowId-*.js`).** n8n 2.17 no longer emits
  a `<base>` tag in `index.html`, so `document.baseURI` follows the
  current Vue Router URL. When the user opens a workflow, `baseURI`
  points at `/api/hassio_ingress/<token>/workflow/<id>` and every
  dynamic `import('./assets/X.js')` resolves to
  `/api/hassio_ingress/<token>/workflow/assets/X.js` — a path n8n's
  SPA catch-all answers with `index.html` (`text/html`, 30 kB). Vue
  parses the HTML as an ES module, `inject()` receives an `undefined`
  key, the NodeView component throws during setup, and the canvas
  stays blank. Diagnosed live via DevTools: the same asset URL fetched
  with an absolute prefix returned `817 B text/javascript`, confirming
  the server was fine and only URL resolution was broken.
- **`base-path-fix.html`**: extended the injected shim to also install
  a `<base href="/api/hassio_ingress/<token>/">` as the very first
  child of `<head>`. This pins `document.baseURI` to the ingress
  prefix root regardless of subsequent Vue Router navigations, so
  relative imports, modulepreload, and CSS `url()` all resolve to the
  real `/assets/*` files. The existing `window.BASE_PATH` getter/
  setter pin (Android WebView fix) is unchanged.
- No other tweaks were removed: the healthz short-circuit (2.17.3.4),
  `.mjs` patching, Supervisor-API-driven `N8N_PATH`, SSE push backend
  and `N8N_SECURE_COOKIE=false` are all still required.


## 2.17.7.1 — 2026-04-24

- Nouvelle version n8n : 2.17.5 → 2.17.7


## 2.17.5.1 — 2026-04-23

- Nouvelle version n8n : 2.17.3 → 2.17.5


## 2.17.3.4 — 2026-04-23

- **Fix: workflow loads once then becomes an empty canvas on reload
  (under n8n 2.17).** n8n 2.17 added a frontend backend-health poll in
  `useBackendStatus.ts` that calls `{BASE_PATH}healthz` continuously.
  n8n itself only serves `/healthz` at the server *root*, not under
  `N8N_PATH`, so under HA Ingress the poll lands on
  `/api/hassio_ingress/<token>/healthz` — a prefixed URL n8n does not
  route — and is answered with `400 Bad Request`. The editor reads the
  400 as "backend down", clears the Pinia workflow store, and falls
  back to the empty-canvas template. This matches the observed
  "workflow loads once, then blank on every reload" behaviour exactly.
- **`nginx.conf` (port 5690)**: added a `location ~ /healthz$` block
  that answers every healthz probe directly with
  `200 {"status":"ok"}` and `Cache-Control: no-store`, without
  proxying to n8n. The poll always succeeds and the frontend keeps
  the workflow store intact.
- Diagnostics note: earlier investigation mis-attributed the bug to a
  Service Worker scope/cache corruption (because the initial DevTools
  screenshots showed `/rest/*` responses tagged `(from service
  worker)` with a stub `400 "1"` body). Follow-up diagnostics on a SW-
  free browser confirmed the SW was innocent and the 400 comes from
  n8n itself on the prefixed `healthz` path. No SW workarounds are
  shipped.

## 2.17.3.1 — 2026-04-22

- Nouvelle version n8n : 2.16.2 → 2.17.3


## 2.16.2.6 — 2026-04-22

- **Production cleanup of the HA mobile app `BASE_PATH` fix.** The
  shim validated in v2.16.2.5 works — every `/rest/*` XHR now resolves
  against the correct ingress prefix and the app loads normally inside
  the Home Assistant Android companion. This build strips all the
  diagnostic scaffolding that surrounded the fix:
  - `debug-inject.html` renamed to `base-path-fix.html` and reduced
    to the `window.BASE_PATH` getter/setter shim only (~25 lines).
    The `Image()`-queue transport, `boot`/`boot2`…`boot5` snapshots,
    `window.onerror`, `unhandledrejection`, `fetch()` and
    `XMLHttpRequest` hooks are all gone.
  - `/__hassio_debug` sink and the `hassio_debug` log format removed
    from `nginx.conf`.
  - `run.sh` no longer dumps `BASE_PATH` references from
    `index.html`; injection logic is unchanged.
  No behavioural change for users — same fix, no telemetry noise.

## 2.16.2.5 — 2026-04-22

- **Fix HA mobile app "Error connecting to n8n".** v2.16.2.4's
  telemetry confirmed the root cause: inside the Home Assistant
  Android companion app's WebView, n8n's own startup code sets
  `window.BASE_PATH = "/"` at DOMContentLoaded (ignoring the
  ingress-prefixed value baked into the bundles). Every `/rest/*`
  XHR then resolves against the page origin (HA) instead of the
  ingress-proxied addon and returns 404 — hence the error screen.
  Regular browsers don't exhibit this behaviour.

  Fix: the injected telemetry snippet now installs a
  getter/setter on `window.BASE_PATH` **before any other script
  runs**, pinning it to the ingress URL extracted from
  `location.pathname`. Subsequent attempts to set it to `"/"` are
  silently rejected; any richer value is accepted.

  Also: `run.sh` now logs every `BASE_PATH` reference it finds in
  the patched `index.html`, so we can see what n8n actually writes.

## 2.16.2.4 — 2026-04-22

- **Diagnostic transport fix.** v2.16.2.3 revealed that the Android
  WebView inside the HA companion app silently drops every
  `navigator.sendBeacon()` call after the first one — only the initial
  `boot` event reached the server. Switch the debug telemetry to a
  serialised `new Image().src` queue (50 ms between calls, with a
  cache-buster query param) so every event lands. Add `boot3` on
  `load`, and delayed `boot4`/`boot5` snapshots (2 s / 5 s after
  boot) to catch any late-set `window.BASE_PATH`.

## 2.16.2.3 — 2026-04-22

- **Enhanced diagnostic telemetry.** v2.16.2.2 confirmed the smoking gun:
  an XHR is made to `/rest/settings` without the ingress prefix, so it
  resolves against the page origin (Home Assistant) and 404s before
  reaching the addon's nginx. This build enriches the `[hassio-debug]`
  telemetry to pinpoint the root cause:
  - `boot` event now reports `BP` (`window.BASE_PATH`), `bURI`
    (`document.baseURI`), and `base` (the `<base href>` attribute).
  - A second `boot2` event is emitted on `DOMContentLoaded` to catch
    late-initialised values.
  - `fetch`/XHR events now include `ru` (`responseURL`) to see the
    effective URL after resolution.
  Still no functional change; this is purely observational.

## 2.16.2.2 — 2026-04-21

- **Diagnostic build** for the HA mobile app connection error. Earlier
  investigation showed the UI loads 100 % of its assets but then never
  issues any `/rest/*` call in the HA mobile app — failure is purely
  client-side and invisible in the nginx access log. This build injects
  a small JS telemetry snippet into `index.html` that hooks
  `window.onerror`, `unhandledrejection`, `fetch()` and
  `XMLHttpRequest`, then beacons each event to `/__hassio_debug`. An
  nginx `log_format` prints the payload to the addon log prefixed with
  `[hassio-debug]`. No functional change for clients that already work.

## 2.16.2.1 — 2026-04-20

- Nouvelle version n8n : 2.16.1 → 2.16.2


## 2.16.1.17 — 2026-04-18

- **Fix: HA mobile app connection error.** The UI would load but
  immediately show "Error connecting to n8n / Could not connect to
  server" inside the Home Assistant mobile app (both on LAN Wi-Fi and
  5G), while working fine in regular mobile browsers. Root cause: the
  mobile app's WebView breaks the WebSocket upgrade used by n8n's push
  channel when it goes through the Ingress proxy chain.
- Switched the push backend from WebSocket to SSE via
  `N8N_PUSH_BACKEND=sse` in `n8n-exports.sh`. SSE uses plain HTTP
  long-polling, which survives the WebView proxy layer. SSE is also
  fully supported in desktop browsers, so this is a universal change
  with no regression on any other client.

## 2.16.1.16 — 2026-04-18

- **Full architecture rewrite** of the HA Ingress integration. Abandoned
  the static-marker + `sub_filter` + runtime JS shim approach (2.16.1.9
  through 2.16.1.15) — it kept losing whack-a-mole against edge cases
  (compression, `.mjs` chunks, deep-reload URLs). Inspired by
  [Rbillon59/hass-n8n](https://github.com/Rbillon59/hass-n8n).
- New approach:
  1. `hassio_api: true` + `ingress_stream: true` in `config.yaml`.
  2. On startup, `run.sh` calls the HA Supervisor endpoint
     `GET /addons/self/info` and reads `.data.ingress_url`. That URL is
     exported as `N8N_PATH` before n8n starts.
  3. n8n's native startup compile step then replaces the
     `/{{BASE_PATH}}/` placeholder in every `.css`/`.js`/`index.html`
     file with the real ingress URL — so the frontend bundles are
     already correct by the time the browser loads them.
  4. `run.sh` also runs the same `sed` replacement on every `.mjs`
     file under the editor-ui dist (keeping a `.hassio_orig` backup
     for idempotency). n8n's own compile step misses `.mjs` files
     because its glob is `'**/*.{css,js}'` — this was the real root
     cause of "Could not fetch node types".
  5. nginx is now a **plain HTTP reverse proxy** — no `sub_filter`, no
     `gunzip`, no `gzip off`, no `X-Ingress-Path` mapping, no
     `<head>`-injected JS shim. Just `proxy_pass` with WebSocket
     upgrade headers.
- Ingress port moved from 5678 → 5690 to match the upstream reference
  setup and to keep the internal n8n port free.
- `N8N_SECURE_COOKIE=false` — required since HA Ingress serves the UI
  over plain HTTP inside the iframe, and `Secure` cookies would be
  dropped by the browser.

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
