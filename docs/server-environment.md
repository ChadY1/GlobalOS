# Global-OS Server Environment & Mirror Guide (2.0.0-alpha)

This guide describes how to provision the dedicated server at `195.154.119.178` (behind Cloudflare `*.global-os.net`) to host ISO artifacts, package mirrors, and the web control endpoints without pulling external dependencies at build time.

## 1. Base OS setup
- Install a minimal Debian 13 (trixie) on the dedicated server; choose only `SSH server` and `standard system utilities`.
- Create a non-root deployment user (e.g., `gkos`) with `sudo` privileges.
- Ensure outbound HTTPS access to `deb.debian.org` for initial package installation; after the mirror is seeded, builds rely solely on the local mirror.

## 2. Package mirror (apt)
1. Install the mirror tools:
   ```bash
   sudo apt-get update
   sudo apt-get install -y apt-mirror nginx
   ```
2. Configure `/etc/apt/mirror.list` to mirror only Debian 13 (trixie) main/contrib/non-free/non-free-firmware (no Contents indexes):
   ```
   set base_path    /srv/apt-mirror
   set nthreads     10
   set _tilde 0

   deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
   deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware

   clean http://deb.debian.org/debian
   ```
3. Seed the mirror:
   ```bash
   sudo apt-mirror
   sudo chown -R apt-mirror:apt-mirror /srv/apt-mirror
   ```
4. Publish via nginx (simplified vhost `/etc/nginx/sites-available/global-os-mirror`):
   ```nginx
   server {
     listen 80;
     server_name mirror.global-os.net;
     root /srv/apt-mirror/mirror/deb.debian.org/debian;
     autoindex on;
   }
   ```
   Enable and reload:
   ```bash
   sudo ln -s /etc/nginx/sites-available/global-os-mirror /etc/nginx/sites-enabled/
   sudo systemctl reload nginx
   ```
5. Point live-build at the mirror by setting `DEBIAN_MIRROR="http://mirror.global-os.net"` in `scripts/build.sh` or exporting it before running the script.

## 3. ISO/web artifact hosting
1. Create directories and permissions:
   ```bash
   sudo mkdir -p /srv/global-os/{isos,logs,site}
   sudo chown -R gkos:gkos /srv/global-os
   ```
2. Use `rsync` (already provided in `scripts/publish_to_website.sh`) to push artifacts from the build host:
   ```bash
   ./scripts/publish_to_website.sh /path/to/GlobalOS/build/GLOBAL-OS-2.0.0-alpha.iso \
     gkos@195.154.119.178:/srv/global-os/isos/
   ```
3. Serve the site with nginx:
   ```nginx
   server {
     listen 80;
     server_name global-os.net *.global-os.net;
     root /srv/global-os/site;
     index index.html;
   }
   ```
   Place generated documentation and API entry points inside `/srv/global-os/site` (a starter skeleton exists in `site/`).

## 4. Account service API (local, dependency-free)
- `web/account_service.py` provides a SQLite-backed user store with PBKDF2-HMAC password hashing and signed session tokens (no external crypto libraries).
- To run behind nginx + `uwsgi` or `gunicorn` (choose one already available in Debian repos):
  ```bash
  python3 -m venv /srv/global-os/venv
  source /srv/global-os/venv/bin/activate
  pip install gunicorn
  gunicorn -b 127.0.0.1:9000 web.account_service:app
  ```
- Proxy via nginx:
  ```nginx
  location /api/account/ {
    proxy_pass http://127.0.0.1:9000/;
  }
  ```

## 5. Cloudflare integration
- Set `A` record `global-os.net -> 195.154.119.178` and `CNAME` records (`mirror`, `api`, `dl`) to point to `global-os.net` via Cloudflare.
- Enable "Proxy" mode for caching static site content; bypass cache for `/api/` paths.
- Upload TLS certificates via Cloudflare or use an Origin certificate and terminate TLS at nginx.

## 6. Build host checklist (pre-flight)
- Enable user namespaces (as noted in `scripts/build.sh`).
- Set `DEBIAN_MIRROR=http://mirror.global-os.net` to build without third-party dependencies.
- Verify `config/apt/99disable-contents.conf` is present in both host and chroot (the build script copies it automatically).
- Run: `./scripts/build.sh`. On success, the ISO and its SHA-256 hash appear in the repo root.

## 7. Final verification
- Boot the ISO in VirtualBox/VMware/QEMU to confirm installer and live session.
- Mount the mirror from inside the live environment: `cat /etc/apt/sources.list` should show `mirror.global-os.net` entries.
- After validation, publish artifacts with `scripts/publish_to_website.sh`.
