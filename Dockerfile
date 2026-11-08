# Refs #1, #3: a persistent runtime, not a bundled BotMux release.
ARG BUN_VERSION=1.4.3
FROM oven/bun:${BUN_VERSION}-debian AS bun-runtime

FROM node:22-bookworm-slim
COPY --from=bun-runtime /usr/local/bin/bun /usr/local/bin/bun
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash ca-certificates curl git tmux tini python3 python3-venv \
    build-essential util-linux unzip \
    fonts-noto-cjk fonts-noto-color-emoji fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /home/node/.botmux /home/node/.local/bin /workspace \
    && chown -R node:node /home/node /workspace
COPY --chmod=755 docker/entrypoint.sh /usr/local/bin/botmux-container
COPY --chmod=755 docker/runtime.mjs /usr/local/bin/botmux-runtime
ENV HOME=/home/node \
    NPM_CONFIG_PREFIX=/home/node/.local \
    BUN_INSTALL=/home/node/.bun \
    BOTMUX_VERSION=3.58.0 \
    PATH=/home/node/.local/share/botmux/current/bin:/home/node/.local/bin:/home/node/.bun/bin:/home/node/.botmux/bin:$PATH \
    TERM=xterm-256color
USER node
WORKDIR /workspace
EXPOSE 7891 8800
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/botmux-container"]
CMD ["serve"]
