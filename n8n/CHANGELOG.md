# Changelog

## 2.16.1.5 — 2026-04-16

- Fix : désactivation des Task Runners (`N8N_RUNNERS_ENABLED=false`)
  Le Task Broker interne de n8n 2.x tentait de se lier au port 5679
  déjà utilisé par le process n8n principal → collision au démarrage
  (`n8n Task Broker's port 5679 is already in use`).
  Les workflows s'exécutent désormais dans le process main (comportement
  n8n 1.x), ce qui convient à un usage home/self-hosted.

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
