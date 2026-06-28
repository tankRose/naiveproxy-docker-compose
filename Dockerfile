# syntax=docker/dockerfile:1

ARG CADDY_VERSION=${CADDY_VERSION}
ARG FORWARDPROXY_VERSION=${FORWARDPROXY_VERSION}

FROM caddy:${CADDY_VERSION}-builder AS builder
ARG FORWARDPROXY_VERSION=${FORWARDPROXY_VERSION}

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    echo "FORWARDPROXY_VERSION=${FORWARDPROXY_VERSION}" && \
    xcaddy build \
    --with github.com/caddyserver/forwardproxy=github.com/klzgrad/forwardproxy@${FORWARDPROXY_VERSION}

FROM caddy:${CADDY_VERSION}-alpine

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

EXPOSE 80 443 443/udp

CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]