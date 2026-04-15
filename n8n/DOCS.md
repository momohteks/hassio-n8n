# Documentation — n8n Addon pour Home Assistant

## Présentation

[n8n](https://n8n.io) est un outil d'automatisation de workflows open-source et auto-hébergé. Il vous permet de connecter vos applications et services pour créer des automatisations puissantes, avec une interface visuelle de type "node-based".

## Configuration

### Options disponibles

#### `webhook_url` (optionnel)

URL publique à laquelle n8n est accessible depuis Internet. Nécessaire si vous souhaitez recevoir des webhooks depuis des services externes (GitHub, Stripe, etc.).

**Exemple :** `https://mon-domaine.duckdns.org:8081`

Si vous utilisez un reverse proxy (Nginx Proxy Manager, Traefik), renseignez l'URL publique de votre proxy.

#### `timezone`

Fuseau horaire utilisé par n8n pour les planifications (cron).

**Défaut :** `Europe/Paris`

**Exemples :** `Europe/Paris`, `America/New_York`, `Asia/Tokyo`

## Ports

| Port | Usage | Exposition |
|------|-------|------------|
| Ingress HA | Interface web n8n | Via le panneau HA uniquement |
| `8081` | Webhooks et API REST | À exposer publiquement si besoin |

## Accès à l'interface

L'interface n8n est accessible directement depuis le panneau Home Assistant via le bouton **"OUVRIR L'INTERFACE WEB"** dans la page de l'addon.

## Webhooks

Pour recevoir des webhooks depuis l'extérieur, vous devez :

1. Renseigner l'option `webhook_url` avec votre URL publique
2. Ouvrir/rediriger le port `8081` sur votre routeur vers votre serveur HA
3. Ou configurer un reverse proxy qui achemine vers le port `8081`

Dans vos workflows n8n, l'URL de webhook sera automatiquement basée sur `webhook_url`.

## Données et sauvegardes

Toutes les données n8n (workflows, credentials, base de données) sont stockées dans le volume de données de l'addon. Elles sont **incluses automatiquement** dans les sauvegardes Home Assistant.

## Mise à jour

L'addon est mis à jour automatiquement à chaque nouvelle version de n8n. Vous recevrez une notification dans HA lorsqu'une mise à jour est disponible.

## Support

- [Issues GitHub](https://github.com/momohteks/hassio-n8n/issues)
- [Documentation n8n](https://docs.n8n.io)
- [Forum n8n](https://community.n8n.io)
