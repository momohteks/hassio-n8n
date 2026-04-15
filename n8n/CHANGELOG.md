# Changelog

## 2.16.1.4 — 2026-04-15

- Fix : `chown /data` au runtime pour que n8n (user `node`) puisse écrire
  (le volume `/data` est monté en root par HA, écrasant le chown du Dockerfile)
- Introduction du versionnement 4-digits : `{n8n_version}.{addon_build}`
- Suppression de tini (redondant avec supervisord)
- Séparation des couches RUN (build-deps vs runtime-deps) pour éviter
  que `apt purge --auto-remove` supprime supervisord

## 2.16.1 — 2026-04-15

- Version initiale de l'addon
- Support n8n 2.16.1
- Intégration Home Assistant Ingress
- Port webhooks dédié (8081)
- Support amd64 et aarch64
- Mise à jour automatique via GitHub Actions
