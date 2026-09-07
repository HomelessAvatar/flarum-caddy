<p align="center">
  <h1 align="center">flarum-caddy</h1>
  <p align="center">
    <strong>Ultra-lightweight Flarum Docker image powered by Caddy 2 and PHP 8.4 (Zero Nginx)</strong>
  </p>
  <p align="center">
    <img src="https://img.shields.io/badge/Flarum-v1.8.19-e7672e.svg" alt="Flarum Version" />
    <img src="https://img.shields.io/badge/PHP-8.4-777bb4.svg" alt="PHP Version" />
    <img src="https://img.shields.io/badge/Web_Server-Caddy_2-22b8eb.svg" alt="Caddy Web Server" />
    <img src="https://img.shields.io/badge/Base-Alpine_Linux-0d597f.svg" alt="Alpine Linux" />
    <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License" />
  </p>
</p>

---

## 💡 Why flarum-caddy?

Most existing Flarum Docker images bundle **Nginx** inside the container. If your host or edge infrastructure already runs **Caddy**, this creates an unnecessary **"Caddy -> Nginx -> PHP-FPM"** double-proxy chain.

**`flarum-caddy`** eliminates Nginx completely:
- 🚀 **Pure Caddy Architecture**: Caddy 2 handles HTTP, clean URLs, and static asset caching directly inside the container, proxying to PHP-FPM via FastCGI.
- ⚡ **PHP 8.4 & Alpine**: Built on official `php:8.4-fpm-alpine` with Zend OpCache enabled.
- 🪶 **Minimal RAM Consumption**: Idles at only **~35 - 50 MB RAM** (vs 100+ MB in traditional setups).
- 🔄 **Automated Migrations**: Automatically runs `php flarum migrate` and `php flarum cache:clear` on startup.
- 🧩 **Extension Persistence**: Automatically persists extensions, assets, and storage in a single `/data` volume.
- 🌐 **Multi-Arch**: Supports both `linux/amd64` (Intel/AMD) and `linux/arm64` (Apple Silicon, Raspberry Pi, Ampere).

---

## 🚀 Quick Start (Docker Compose)

Create a `docker-compose.yml` file:

```yaml
services:
  flarum:
    image: ghcr.io/homelessavatar/flarum-caddy:1.8.19
    container_name: flarum
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      - FORUM_URL=https://forum.example.com
      - DB_HOST=mariadb
      - DB_PORT=3306
      - DB_NAME=flarum
      - DB_USER=flarum
      - DB_PASSWORD=your_secret_db_password
      - DB_PREFIX=fl_
    volumes:
      - ./data/flarum:/data
    depends_on:
      - mariadb

  mariadb:
    image: mariadb:lts
    container_name: flarum-db
    restart: unless-stopped
    environment:
      - MYSQL_ROOT_PASSWORD=your_root_password
      - MYSQL_DATABASE=flarum
      - MYSQL_USER=flarum
      - MYSQL_PASSWORD=your_secret_db_password
    volumes:
      - ./data/mariadb:/var/lib/mysql
```

Start the forum:

```bash
docker compose up -d
```

Your forum will be ready at `http://localhost:8000` (or through your reverse proxy)!

---

## 🔧 Environment Variables

| Variable | Default | Description |
| :--- | :--- | :--- |
| `FORUM_URL` / `FLARUM_BASE_URL` | `http://localhost:8000` | Full public URL of your forum (e.g. `https://forum.example.com`) |
| `DB_HOST` | `mariadb` | Database hostname or IP |
| `DB_PORT` | `3306` | Database port |
| `DB_NAME` | `flarum` | Database name |
| `DB_USER` | `flarum` | Database username |
| `DB_PASSWORD` / `DB_PASS` | *(empty)* | Database password |
| `DB_PREFIX` / `DB_PREF` | `fl_` | Table prefix in database |
| `FLARUM_DEBUG` | `false` | Enable/disable Flarum debug mode (`true`/`false`) |
| `TZ` | `UTC` | Container timezone |

---

## 💾 Volumes & Persistence

All persistent data is stored under `/data`:

- `/data/assets`: Avatars, uploaded media, and compiled CSS/JS assets.
- `/data/storage`: Flarum logs, session cache, and views.
- `/data/extensions`: Extra custom extensions.

### Installing Additional Extensions
To install community extensions via Composer at startup, create `/data/extensions/list`:
```text
fof/nightmode
fof/upload
flarum-lang/turkish
```
`flarum-caddy` will automatically run `composer require` for listed extensions when the container boots.

---

## 🛡️ Host Reverse Proxy (Caddy Example)

If you run Caddy on your host server, simply reverse-proxy to the container:

```caddy
forum.example.com {
    encode zstd gzip
    reverse_proxy 127.0.0.1:8000
}
```

---

## 🔮 Upgrading (Future Flarum 2.0 Roadmap)

When a new Flarum version (such as Flarum 2.0) is released:
1. Update `ARG FLARUM_VERSION=v2.0.0` in `Dockerfile`.
2. Push a git tag `v2.0.0`.
3. GitHub Actions will build and publish `ghcr.io/homelessavatar/flarum-caddy:2.0.0`.
4. In your compose file, change `image: ...:2.0.0` and run `docker compose pull && docker compose up -d`. Flarum will automatically migrate database tables!

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
Flarum is an open-source project licensed under the MIT License by the Flarum Foundation.
