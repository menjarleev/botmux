# Docker runtime for Issue #1. Agent CLIs are installed after setup.
ARG BUN_VERSION=1.4.3
FROM oven/bun:${BUN_VERSION}-debian AS bun-runtime

FROM node:22-bookworm-slim AS build
COPY --from=bun-runtime /usr/local/bin/bun /usr/local/bin/bun
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential python3 git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
ENV ELECTRON_SKIP_BINARY_DOWNLOAD=1 \
    NODE_OPTIONS=--max-old-space-size=6144
WORKDIR /build
COPY . .
RUN bun install --frozen-lockfile
RUN bun run build
ARG BOTMUX_VERSION=0.0.0-docker
RUN BOTMUX_VERIFY_BAKED_VERSION="$BOTMUX_VERSION" \
    bun scripts/build-bun-binary.mjs --out /out/botmux \
    && node -e 'require("fs").copyFileSync(require.resolve("@napi-rs/canvas-linux-" + process.arch + "-gnu"), "/out/canvas.node")'

FROM node:22-bookworm-slim AS runtime
COPY --from=bun-runtime /usr/local/bin/bun /usr/local/bin/bun
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash ca-certificates curl git tmux tini python3 python3-venv \
    build-essential fonts-noto-cjk fonts-noto-color-emoji fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /home/node/.botmux /home/node/.local/bin /workspace \
    && chown -R node:node /home/node /workspace
COPY --from=build /out/botmux /usr/local/bin/botmux
COPY --from=build /out/canvas.node /opt/botmux/canvas.node
COPY --chmod=755 docker/entrypoint.sh /usr/local/bin/botmux-container
ENV HOME=/home/node \
    NPM_CONFIG_PREFIX=/home/node/.local \
    BUN_INSTALL=/home/node/.bun \
    PATH=/home/node/.local/bin:/home/node/.bun/bin:/home/node/.botmux/bin:$PATH \
    TERM=xterm-256color \
    NAPI_RS_NATIVE_LIBRARY_PATH=/opt/botmux/canvas.node
USER node
WORKDIR /workspace
EXPOSE 7891 8800
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/botmux-container"]
CMD ["serve"]
