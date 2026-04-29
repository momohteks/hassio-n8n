# Documentation — n8n Addon pour Home Assistant

## Présentation

[n8n](https://n8n.io) est un outil d'automatisation de workflows
open-source et auto-hébergé. Il vous permet de connecter vos
applications et services pour créer des automatisations puissantes,
avec une interface visuelle de type "node-based".

> ⚠️ **À partir de la version 2.17.8.5, cet addon n'utilise plus HA Ingress.**
> n8n 2.x ne supporte pas correctement d'être servi sous un sous-chemin
> (l'intégration officielle a été désactivée par les mainteneurs n8n —
> voir [n8n-io/n8n#19437](https://github.com/n8n-io/n8n/issues/19437)).
> L'interface est désormais exposée sur le port **5678** ; il vous faut
> un reverse proxy (Nginx Proxy Manager, Traefik, Caddy…) pour la
> publier sur un sous-domaine dédié.

## Configuration

### Options disponibles

#### `webhook_url` (optionnel)

URL publique à laquelle n8n est accessible depuis Internet. Nécessaire
si vous souhaitez recevoir des webhooks depuis des services externes
(GitHub, Stripe, etc.).

**Exemple :** `https://n8n.mon-domaine.fr` ou
`https://webhooks.mon-domaine.fr`

#### `timezone`

Fuseau horaire utilisé par n8n pour les planifications (cron).

**Défaut :** `Europe/Paris`

**Exemples :** `Europe/Paris`, `America/New_York`, `Asia/Tokyo`

## Ports

| Port | Usage | Exposition recommandée |
|------|-------|------------------------|
| `5678` | Interface n8n + REST API + webhooks | Reverse proxy sur sous-domaine dédié (`n8n.example.com`) |
| `8081` | Webhooks et REST API uniquement (sans UI) | Port direct ou reverse proxy si vous voulez isoler les webhooks |

## Accès à l'interface

1. Configurez votre reverse proxy pour qu'un sous-domaine (par exemple
   `n8n.example.com`) pointe vers `http://<IP-HA>:5678`.
2. Ouvrez l'interface depuis ce sous-domaine dans votre navigateur.
3. À la première connexion, n8n vous propose de créer un compte
   administrateur.

### Exemple Nginx Proxy Manager

- **Domain Names** : `n8n.example.com`
- **Scheme** : `http`
- **Forward Hostname / IP** : IP de votre HA (ex. `192.168.1.10`)
- **Forward Port** : `5678`
- **Cache Assets** : ❌ off
- **Block Common Exploits** : ✅
- **Websockets Support** : ✅
- **SSL** : Let's Encrypt + Force SSL + HTTP/2

### Exemple Caddy

```
n8n.example.com {
    reverse_proxy 192.168.1.10:5678
}
```

### Exemple Traefik (label sur l'addon)

À configurer côté Traefik avec la même IP/port (`5678`).

## Webhooks

Deux possibilités selon votre architecture :

1. **Tout via le sous-domaine UI** (le plus simple) : laissez le
   reverse proxy router `n8n.example.com/webhook/...` vers le port
   5678. Renseignez `webhook_url: https://n8n.example.com`.
2. **Webhooks publics isolés** : exposez le port 8081 (HTTP plain ou
   via un autre sous-domaine `webhooks.example.com`) — l'UI restera
   refusée (403) sur ce port. Utile pour appliquer des politiques de
   firewall différenciées.

Dans vos workflows n8n, l'URL des webhooks sera dérivée
automatiquement de `webhook_url`.

## Données et sauvegardes

Toutes les données n8n (workflows, credentials, base de données) sont
stockées dans le volume de données de l'addon. Elles sont **incluses
automatiquement** dans les sauvegardes Home Assistant.

## Migration depuis une version antérieure (Ingress)

Si vous mettez à jour depuis une version antérieure à 2.17.8.5 :

1. Vos workflows et credentials sont conservés (la base SQLite reste
   dans `/data`).
2. Le bouton "Ouvrir l'interface" du panneau HA ne fonctionnera plus
   (il pointait vers Ingress) : passez par votre sous-domaine.
3. La session de connexion n8n peut nécessiter une nouvelle
   authentification (cookie sur un domaine différent).

## Mise à jour

L'addon est mis à jour automatiquement à chaque nouvelle version de
n8n. Vous recevrez une notification dans HA lorsqu'une mise à jour est
disponible.

## Support

- [Issues GitHub](https://github.com/momohteks/hassio-n8n/issues)
- [Documentation n8n](https://docs.n8n.io)
- [Forum n8n](https://community.n8n.io)
