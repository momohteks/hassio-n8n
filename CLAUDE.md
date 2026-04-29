# hassio-n8n — Home Assistant Addon pour n8n

## Vue d'ensemble

Addon Home Assistant qui héberge une instance n8n via **nginx + supervisord**.
Repo : https://github.com/momohteks/hassio-n8n

## Architecture (depuis 2.17.8.5 — HA Ingress retiré)

```
[Reverse proxy externe / sous-domaine]
   → nginx:5678  →  n8n:5678   (UI + REST API + webhooks)
   → nginx:8081  →  n8n:5678   (webhooks publics, sans UI, 403 sur /)
                                Task Broker (interne n8n 2.x) → 5679
```

- **HA Ingress désactivé** : n8n 2.x ne supporte pas correctement d'être
  servi sous un sous-chemin (cf
  [n8n-io/n8n#19437](https://github.com/n8n-io/n8n/issues/19437),
  citation maintainer Tomi : *"N8N_PATH is not fully supported in the
  app (...) we are possibly going to remove the path option from v2"*).
  L'utilisateur configure son propre reverse proxy (Nginx Proxy
  Manager, Traefik…) qui pointe un sous-domaine dédié vers
  `http://<IP-HA>:5678`.
- **nginx** = simple reverse proxy. Pas de `sub_filter`, pas de
  réécriture, pas de shim JS, pas de short-circuit healthz, pas de
  `<base href>` injection, pas de patching `.mjs` ou `auth.service.js`.
- **n8n** tourne sur son port standard 5678 (Task Broker sur 5679).
- **supervisord** gère les deux processus (nginx + n8n).
- Les données persistent dans `/data` (volume HA).

## Fichiers clés

| Fichier | Rôle |
|---------|------|
| `n8n/config.yaml` | Config addon HA — version mise à jour automatiquement |
| `n8n/Dockerfile` | Image multi-arch — `ARG N8N_VERSION` mis à jour automatiquement |
| `n8n/build.yaml` | Images de base HA par architecture |
| `n8n/n8n-exports.sh` | Toutes les variables d'environnement n8n |
| `n8n/nginx.conf` | Proxy UI (5678) et webhooks publics (8081) vers n8n (5678 interne) |
| `n8n/supervisord.conf` | Gestion processus nginx + n8n |
| `n8n/run.sh` | Entrypoint du container |
| `.github/workflows/update-n8n.yml` | Détecte nouvelles versions n8n (cron quotidien) |
| `.github/workflows/publish-release.yml` | Build & push images Docker ghcr.io sur nouveau tag |

## Images Docker

- `ghcr.io/momohteks/hassio-n8n-amd64:{version}`
- `ghcr.io/momohteks/hassio-n8n-aarch64:{version}`

## Versionnement

Format **4-digits** : `{n8n_major}.{n8n_minor}.{n8n_patch}.{addon_build}`

Exemple : `2.16.1.4` = n8n 2.16.1, build #4 de l'addon.

- Les **3 premiers digits** suivent la version n8n upstream (dans `n8n/Dockerfile` → `ARG N8N_VERSION`)
- Le **4ème digit** est le numéro de build addon (dans `n8n/config.yaml` → `version:`)
  - Reset à `1` quand n8n est mis à jour
  - Incrémenté à chaque rebuild manuel (correction de config, Dockerfile, etc.)

## Mise à jour automatique (`.github/workflows/update-n8n.yml`)

Deux modes, un seul workflow :

**Mode `auto` (cron quotidien 6h UTC)**
1. `npm view n8n version` → récupère la dernière version upstream
2. Compare aux 3 premiers digits de `config.yaml`
3. Si différent : version = `{nouveau_n8n}.1`, update config+Dockerfile+CHANGELOG+tag

**Mode `rebuild_only` (déclenchement manuel depuis l'onglet Actions)**
1. Pas de check npm
2. Incrémente uniquement le 4ème digit : `2.16.1.4` → `2.16.1.5`
3. Dockerfile inchangé, config.yaml bumpée + tag

Le push du tag `v{X.Y.Z.B}` déclenche `publish-release.yml` qui :
- Extrait le digit n8n (3 premiers) comme `N8N_VERSION` build arg
- Build/push multi-arch sur `ghcr.io/momohteks/hassio-n8n-{arch}:{X.Y.Z.B}`
- Tague aussi `:{X.Y.Z}` (flottant) et `:latest`
- Crée une GitHub Release

## Permissions GitHub Actions requises

Dans le repo GitHub :
- **Settings → Actions → General → Workflow permissions** : "Read and write permissions"
- **Settings → Packages** : ghcr.io activé (automatique si permissions write)

## Développement local

```bash
# Build test (amd64)
cd n8n/
docker build \
  --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base:3.20 \
  -t hassio-n8n-test .

# Run local
docker run -p 5678:5678 -p 8081:8081 -v $(pwd)/data:/data hassio-n8n-test
```

## Ajouter dans Home Assistant

1. HA → Paramètres → Modules complémentaires → Boutique → ⋮ → Dépôts
2. Ajouter : `https://github.com/momohteks/hassio-n8n`
3. Installer l'addon, puis configurer un reverse proxy externe (NPM,
   Traefik, Caddy…) qui pointe un sous-domaine vers `http://<IP-HA>:5678`
   pour accéder à l'UI. L'addon n'est plus accessible via le panneau
   Ingress de HA depuis la 2.17.8.5.

## Architectures supportées

- `amd64` (x86_64)
- ~~`aarch64`~~ **temporairement désactivé** jusqu'à nouvel ordre
  (config.yaml, build.yaml et workflow publish-release mis à jour).
  Pour réactiver : rétablir `aarch64` dans `n8n/config.yaml` + `n8n/build.yaml`
  et la ligne correspondante dans la matrice `.github/workflows/publish-release.yml`.

## Historique des fixes appliqués (pour référence)

### v2.16.1.9 — Icône addon + fix Ingress UI

- **Icône** : `n8n/icon.png` (180×180 depuis `apple-touch-icon.png` de
  n8n.io) + `n8n/logo.png` (horizontal depuis `n8n-io/n8n/assets/`).
- **Page blanche Ingress** résolue via `sub_filter` nginx sur le port
  5678. Le préfixe dynamique HA (`$http_x_ingress_path`) est injecté :
  - Attributs HTML (`href`, `src`, `action`).
  - Chemins absolus dans les bundles JS/JSON (`/rest/`, `/assets/`,
    `/webhook/`, `/webhook-test/`, `/webhook-waiting/`, `/types/`,
    `/static/`, `/push`, `/form/`).
  - Balise `<base href="$prefix/">` injectée dans `<head>` pour les
    URLs relatives.
  - Compression amont désactivée (`Accept-Encoding ""`) pour que
    `sub_filter` puisse opérer sur les réponses en clair.
  - `Content-Security-Policy` masqué pour ne pas bloquer la réécriture.
  - Map `$connection_upgrade` pour un handling WebSocket propre.

### v2.16.1.7 — Python Task Runner + désactivation aarch64

- **Python Task Runner** : base image basculée sur `python:3.13-slim`
  (requis par le runner). Node.js 22 installé via NodeSource. Source du
  runner Python clonée depuis le tag `n8n@${N8N_VERSION}` et installée à
  l'emplacement exact que cherche n8n en internal mode :
  `/usr/local/lib/node_modules/@n8n/task-runner-python/.venv/bin/python`.
  Venv provisionné avec `websockets>=15.0.1`.
- **Env vars dépréciées** nettoyées : `N8N_RUNNERS_ENABLED` et
  `EXECUTIONS_PROCESS` supprimées.
- **Nouvelles env vars** : `N8N_RUNNERS_STDLIB_ALLOW=*` (toute la stdlib
  accessible depuis le code utilisateur Python).
- **aarch64** désactivé dans `config.yaml`, `build.yaml` et la matrice
  du workflow `publish-release.yml`.
- **README** basculé en anglais (public cible GitHub international).
