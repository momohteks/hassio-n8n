# Documentation — n8n Addon for Home Assistant

## Overview

[n8n](https://n8n.io) is an open-source, self-hosted workflow
automation tool. It lets you connect your apps and services into
powerful automations through a visual node-based editor.

> ⚠️ **Starting with version 2.18.5.3 this addon no longer uses HA Ingress.**
> n8n 2.x does not properly support being served under a sub-path —
> the n8n maintainers themselves have stated this and are planning to
> remove the option entirely (see
> [n8n-io/n8n#19437](https://github.com/n8n-io/n8n/issues/19437)).
> The UI is now exposed on port **5678**, and you need a reverse proxy
> (Nginx Proxy Manager, Traefik, Caddy…) to publish it on a dedicated
> subdomain.

## Configuration

### Available options

#### `webhook_url` (optional)

Public URL at which n8n is reachable from the Internet. Required if
you want to receive webhooks from external services (GitHub, Stripe,
etc.).

**Examples:** `https://n8n.example.com`,
`https://webhooks.example.com`

#### `timezone`

Timezone used by n8n for scheduling (cron triggers).

**Default:** `Europe/Paris`

**Examples:** `Europe/Paris`, `America/New_York`, `Asia/Tokyo`

## Ports

| Port | Purpose | Recommended exposure |
|------|---------|----------------------|
| `5678` | n8n UI + REST API + webhooks | Reverse proxy on a dedicated subdomain (`n8n.example.com`) |
| `8081` | Webhooks and REST API only (no UI) | Direct port or reverse proxy if you want webhooks isolated |

## Accessing the UI

1. Configure your reverse proxy so a subdomain (for example
   `n8n.example.com`) points to `http://<HA-IP>:5678`.
2. Open that subdomain in your browser.
3. On first connection, n8n will prompt you to create an admin
   account.

### Nginx Proxy Manager example

- **Domain Names:** `n8n.example.com`
- **Scheme:** `http`
- **Forward Hostname / IP:** your HA IP (e.g. `192.168.1.10`)
- **Forward Port:** `5678`
- **Cache Assets:** ❌ off
- **Block Common Exploits:** ✅
- **Websockets Support:** ✅
- **SSL:** Let's Encrypt + Force SSL + HTTP/2

### Caddy example

```
n8n.example.com {
    reverse_proxy 192.168.1.10:5678
}
```

### Traefik example

Configure Traefik with the same IP/port (`5678`) using your usual
labels or dynamic configuration.

## Webhooks

Two options depending on your setup:

1. **Everything via the UI subdomain** (simplest): let your reverse
   proxy route `n8n.example.com/webhook/...` to port 5678. Set
   `webhook_url: https://n8n.example.com`.
2. **Webhooks isolated on a separate endpoint**: expose port 8081
   (plain HTTP or via a second subdomain like
   `webhooks.example.com`) — the UI will be refused (403) on this
   port. Useful for differentiated firewall policies.

In your n8n workflows, webhook URLs are derived automatically from
`webhook_url`.

## Data and backups

All n8n data (workflows, credentials, SQLite database) lives in the
addon's data volume. It is **automatically included** in Home
Assistant backups.

## Migrating from an older (Ingress-based) version

If you upgrade from a version older than 2.18.5.3:

1. Your workflows and credentials are preserved (the SQLite database
   stays at `/data`).
2. The "Open web UI" button on the HA addon page no longer works (it
   used to point at Ingress) — open the subdomain you configured
   instead.
3. The n8n session may require a fresh login (the auth cookie is on
   a different domain now).

## Updates

The addon is automatically updated on every new n8n release. You will
see a notification in HA when a new version is available.

## Support

- [GitHub issues](https://github.com/momohteks/hassio-n8n/issues)
- [n8n documentation](https://docs.n8n.io)
- [n8n forum](https://community.n8n.io)
