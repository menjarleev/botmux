---
name: botmux-docker-runtime
description: Provision a persistent BotMux Docker environment, install selected agent CLI backends, and update BotMux while retaining tmux processes. Use for Docker setup and lifecycle work, not ordinary bot conversations.
---

Read [AI setup instructions](../../docker/AI-SETUP.md) and the linked runtime
README from this repository before operating. Follow the operator's chosen host,
backends and login method. This skill does not authorize migration of existing
bots, public exposure or outbound test messages on its own.

The image contains tools, while BotMux is installed into persistent HOME at
startup. Multiple bots may share one container. Daily upgrades use
`botmux-runtime update EXACT_VERSION`; do not recreate the container to upgrade
BotMux. A base-image/container replacement still ends running tasks.

Discover existing deployment state before creating a new instance. Keep each
container group's volumes and admin credentials separate. Handle interactive
backend authentication with the operator and distinguish installation, login,
and live Lark acceptance. Report actual tests and unresolved steps without
printing credentials or token-bearing login links.
