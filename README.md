# NaiveProxy Caddy Server Docker Build

This project builds a custom Caddy image with the NaiveProxy-compatible `forwardproxy` module.

It uses:

- **Caddy v2.11.4** as the base Caddy version
- **`klzgrad/forwardproxy@v2.11.2-naive`** as the pinned NaiveProxy server module
- **Docker multi-stage build**
- **External `Caddyfile` configuration**
- Persistent Caddy data and config directories

The final image is built locally. It does **not** use a third-party NaiveProxy Docker image.

---

## 1. Project Structure

Create the following directory structure:

```text
naive-caddy/
├── docker-compose.yml
├── Dockerfile
├── Caddyfile
├── site/
│   └── index.html
├── data/
└── config/
```

---

## 2. Dockerfile

Create a file named `Dockerfile`:

```Dockerfile
# syntax=docker/dockerfile:1

ARG CADDY_VERSION=2.11.4

FROM caddy:${CADDY_VERSION}-builder AS builder

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    xcaddy build \
    --with github.com/caddyserver/forwardproxy=github.com/klzgrad/forwardproxy@v2.11.2-naive

FROM caddy:${CADDY_VERSION}-alpine

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

EXPOSE 80 443 443/udp

CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
```

### Important Notes

This Dockerfile does **not** use the host machine's Go environment.

The Go compiler and `xcaddy` run inside the Docker build container:

```Dockerfile
FROM caddy:${CADDY_VERSION}-builder AS builder
```

Therefore, the host machine only needs:

```bash
docker
docker compose
```

The host machine does **not** need:

```bash
go
xcaddy
caddy
```

---

## 3. docker-compose.yml

Create a file named `docker-compose.yml`:

```yaml
services:
  naive-caddy:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        CADDY_VERSION: "2.11.4"

    image: local/naive-caddy:v2.11.4-forwardproxy-v2.11.2-naive
    container_name: naive-caddy
    restart: unless-stopped

    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"

    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./site:/srv:ro
      - ./data:/data
      - ./config:/config

    environment:
      - TZ=Asia/Shanghai
```

### Version Meaning

The image tag:

```text
local/naive-caddy:v2.11.4-forwardproxy-v2.11.2-naive
```

means:

```text
Caddy core version:        v2.11.4
Naive forwardproxy module: v2.11.2-naive
```

This is different from third-party Docker tags such as:

```text
pocat/naiveproxy:v2.11.4
```

A third-party Docker tag may track the Caddy version, the image maintainer's own release version, or another internal versioning scheme.

It should not be assumed to equal an official `klzgrad/forwardproxy` tag.

---

## 4. Caddyfile

Create a file named `Caddyfile`.

Replace the following values before production use:

- `example.com`
- `your-email@example.com`
- `user`
- `strong_password_here`

```Caddyfile
{
    order forward_proxy before file_server

    log {
        exclude http.log.error
    }
}

:443, example.com {
    tls your-email@example.com

    encode zstd gzip

    forward_proxy {
        basic_auth user strong_password_here
        hide_ip
        hide_via
        probe_resistance
    }

    file_server {
        root /srv
    }
}
```

### Why `file_server` Is Included

The `file_server` directive allows normal HTTPS requests to receive a regular web page.

This is useful because the server should not expose an obvious proxy-only behavior when visited directly.

---

## 5. Placeholder Website

Create the file:

```text
site/index.html
```

Example content:

```html
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Welcome</title>
</head>
<body>
  <h1>It works.</h1>
</body>
</html>
```

---

## 6. Build and Start

Run the following commands inside the project directory:

```bash
docker compose build --no-cache
docker compose up -d
```

Check logs:

```bash
docker logs -f naive-caddy
```

---

## 7. Verify the Built Module

Check whether the `forwardproxy` module is included:

```bash
docker exec -it naive-caddy caddy list-modules | grep forward
```

You should see a module related to `forward_proxy` or `forwardproxy`.

---

## 8. Reload Caddyfile

After editing the external `Caddyfile`, reload Caddy without recreating the container:

```bash
docker exec naive-caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
```

If reload fails, check the syntax:

```bash
docker exec naive-caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
```

---

## 9. NaiveProxy Client Example

Example client configuration:

```json
{
  "listen": "socks://127.0.0.1:1080",
  "proxy": "https://user:strong_password_here@example.com"
}
```

If your server domain is `np.example.com`, use:

```json
{
  "listen": "socks://127.0.0.1:1080",
  "proxy": "https://user:strong_password_here@np.example.com"
}
```

---

## 10. Build Logic Explained

The build process works like this:

```text
Host machine
   ↓
Docker build starts
   ↓
Temporary builder container: caddy:2.11.4-builder
   ↓
xcaddy runs inside the builder container
   ↓
xcaddy downloads Caddy and klzgrad/forwardproxy@v2.11.2-naive
   ↓
Caddy binary is compiled inside Docker
   ↓
The compiled binary is copied into caddy:2.11.4-alpine
   ↓
Final local image is created
```

The host machine does not compile Caddy directly.

---

## 11. Updating Versions

### Update Caddy Core Version

Change this value in `docker-compose.yml`:

```yaml
args:
  CADDY_VERSION: "2.11.4"
```

And optionally update the image tag:

```yaml
image: local/naive-caddy:v2.11.4-forwardproxy-v2.11.2-naive
```

### Update Naive forwardproxy Version

Change this line in `Dockerfile`:

```Dockerfile
--with github.com/caddyserver/forwardproxy=github.com/klzgrad/forwardproxy@v2.11.2-naive
```

For example:

```Dockerfile
--with github.com/caddyserver/forwardproxy=github.com/klzgrad/forwardproxy@naive
```

However, using `@naive` tracks the latest branch code and is less reproducible.

For production, a fixed tag is safer.

---

## 12. Production Checklist

Before production deployment:

- Use a real domain name.
- Point the domain's A/AAAA record to the server IP.
- Replace the default username and password.
- Use a strong password.
- Keep ports `80` and `443` open.
- Persist `/data` and `/config`.
- Verify that HTTPS certificates are issued successfully.
- Confirm that the client can connect.
- Confirm that normal browser access returns the placeholder site.

---

## 13. Common Commands

Build image:

```bash
docker compose build --no-cache
```

Start service:

```bash
docker compose up -d
```

Stop service:

```bash
docker compose down
```

Restart service:

```bash
docker compose restart
```

View logs:

```bash
docker logs -f naive-caddy
```

Validate Caddyfile:

```bash
docker exec naive-caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
```

Reload Caddyfile:

```bash
docker exec naive-caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
```

List Caddy modules:

```bash
docker exec -it naive-caddy caddy list-modules
```

---

## 14. Summary

This setup builds a local NaiveProxy-compatible Caddy server image with:

```text
Caddy:              v2.11.4
forwardproxy naive: v2.11.2-naive
Config file:        external ./Caddyfile
Website root:       external ./site
Caddy data:         external ./data
Caddy config:       external ./config
```

It is reproducible because the Naive forwardproxy module is pinned to:

```text
github.com/klzgrad/forwardproxy@v2.11.2-naive
```

---

## References

- NaiveProxy official repository: the server uses Caddy forwardproxy with the NaiveProxy padding layer.
- Caddy official Docker image documentation: custom Caddy images can be built with modules using the builder image and `xcaddy`.
- Caddy running documentation: custom builds with plugins should use a custom Docker image, and persistent data/config directories should be kept across restarts.
