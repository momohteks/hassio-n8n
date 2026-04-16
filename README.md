# n8n Home Assistant Addon

[![Version](https://img.shields.io/github/v/release/momohteks/hassio-n8n)](https://github.com/momohteks/hassio-n8n/releases)
[![License](https://img.shields.io/github/license/momohteks/hassio-n8n)](LICENSE)

Home Assistant addon that runs [n8n](https://n8n.io) directly inside your HA
installation.

n8n is a powerful open-source workflow automation tool, comparable to Zapier
or Make but fully self-hosted.

## Features

- Native HA integration through **Ingress** (secure access from the HA panel)
- **Dedicated webhook port** (8081) for n8n webhooks and the REST API
- **Automatic updates** — new upstream n8n releases are detected daily and
  rebuilt automatically
- Built-in **Python and JavaScript Task Runners** (Python 3.13 + Node.js 22)
- Data persisted in `/data` (Home Assistant backup-friendly volume)

## Supported architectures

- `amd64` (x86_64)

> `aarch64` (Raspberry Pi 4/5) is temporarily disabled. See
> [`CLAUDE.md`](CLAUDE.md) for the current roadmap.

## Installation

1. In Home Assistant, open **Settings → Add-ons → Add-on Store**.
2. Click the **⋮** (three-dot) menu → **Repositories**.
3. Add the URL: `https://github.com/momohteks/hassio-n8n`
4. Search for **n8n** in the store and click **Install**.

## Configuration

| Option        | Description                                                     | Default         |
|---------------|-----------------------------------------------------------------|-----------------|
| `webhook_url` | Public URL for n8n webhooks (e.g. `https://your-domain.tld:8081`) | _(empty)_       |
| `timezone`    | Timezone used by n8n                                            | `Europe/Paris`  |

### Exposed ports

| Port   | Purpose                                                     |
|--------|-------------------------------------------------------------|
| `8081` | n8n webhooks and REST API (expose publicly if you need to)  |

The n8n UI is reached through Home Assistant Ingress — no extra port required.

## Architecture

```
[Home Assistant Ingress] → nginx:5678 → n8n:5680
[Public :8081]           → nginx:8081 → n8n:5680   (webhooks / REST API only)
                                        Task Broker (internal): 5679
```

- **nginx** listens on 5678 (HA Ingress) and 8081 (public webhooks).
- **n8n** listens internally on 5680 (moved from 5679 to avoid a collision
  with the n8n 2.x internal Task Broker, which uses 5679).
- **supervisord** manages nginx + n8n as child processes.
- On the public port (8081) only `/webhook/`, `/webhook-waiting/` and
  `/rest/` are reachable — everything else returns 403.

## Data

All n8n data (workflows, credentials, SQLite database) lives under `/data`
inside the addon, so it persists across restarts and is included in Home
Assistant backups.

## Automatic updates

A GitHub Actions workflow checks the latest n8n version published on npm
once a day. When a new version is found, the addon files are updated, a
Docker image is built and pushed to `ghcr.io`, and a GitHub Release is
created automatically.

## Links

- [n8n.io](https://n8n.io) — official n8n website
- [n8n documentation](https://docs.n8n.io)
- [Issues & support](https://github.com/momohteks/hassio-n8n/issues)
