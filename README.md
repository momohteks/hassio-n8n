# n8n Home Assistant Addon

[![Version](https://img.shields.io/github/v/release/momohteks/hassio-n8n)](https://github.com/momohteks/hassio-n8n/releases)
[![License](https://img.shields.io/github/license/momohteks/hassio-n8n)](LICENSE)

Addon Home Assistant pour héberger une instance [n8n](https://n8n.io) directement dans votre installation HA.

n8n est un outil d'automatisation de workflows puissant et open-source, comparable à Zapier ou Make mais auto-hébergé.

## Fonctionnalités

- Intégration native HA via **Ingress** (accès sécurisé via le panneau HA)
- **Port webhook dédié** (8081) pour les webhooks et l'API n8n
- **Mise à jour automatique** : les nouvelles versions de n8n sont détectées et publiées automatiquement
- Support **amd64** et **aarch64** (Raspberry Pi 4/5)
- Données persistées dans `/data` (volume Home Assistant)

## Installation

1. Dans Home Assistant, aller dans **Paramètres → Modules complémentaires → Boutique**
2. Cliquer sur le menu **⋮** (trois points) → **Dépôts**
3. Ajouter l'URL : `https://github.com/momohteks/hassio-n8n`
4. Rechercher "n8n" dans la boutique et cliquer **Installer**

## Configuration

| Option | Description | Défaut |
|--------|-------------|--------|
| `webhook_url` | URL publique pour les webhooks n8n (ex: `https://votre-domaine.com:8081`) | _(vide)_ |
| `timezone` | Fuseau horaire | `Europe/Paris` |

### Ports

| Port | Usage |
|------|-------|
| `8081` | Webhooks n8n et API REST (à exposer publiquement si besoin) |

L'interface n8n est accessible via l'Ingress HA (aucun port supplémentaire nécessaire).

## Architecture

```
[Home Assistant Ingress] → nginx:5678 → n8n:5679
[Public :8081]           → nginx:8081 → n8n:5679 (webhooks)
```

## Données

Les données n8n (workflows, credentials, base de données SQLite) sont stockées dans `/data` du module complémentaire, ce qui les rend persistantes entre les redémarrages et incluses dans les sauvegardes HA.

## Mise à jour automatique

Un workflow GitHub Actions vérifie chaque jour la dernière version de n8n publiée sur npm. Si une nouvelle version est détectée, les fichiers sont mis à jour, une image Docker est construite et publiée automatiquement.

## Liens

- [n8n.io](https://n8n.io) — Site officiel n8n
- [Documentation n8n](https://docs.n8n.io)
- [Issues & Support](https://github.com/momohteks/hassio-n8n/issues)
