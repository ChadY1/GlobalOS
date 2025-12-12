# Global-OS 4.0 — infrastructure web globale

Ce document décrit l'architecture technique pour `global-os.net` et ses sous-domaines ainsi que le raccordement au pipeline ISO.

## Découpage DNS et sous-domaines
- `global-os.net` : page d'accueil, téléchargement public de l'ISO stable et alpha, redirection vers la documentation.
- `api.global-os.net` : API comptes et portail d'administration (REST JSON).
- `build.global-os.net` : dépôt des artefacts CI (ISO + hash SHA-256), synchronisés après chaque build réussi.
- `docs.global-os.net` : documentation statique (guides d'installation, VirtualBox, API, changelog).
- `mirror.global-os.net` : miroir téléchargeable (rsync/https) des paquets additionnels internes et des profils de sandbox.

## Topologie de déploiement (vue haute)
```
Internet
   |
[Cloudflare/HAProxy TLS termination]
   |
[nginx reverse proxy] -- route /api -> account_service
   |-- / -> site statique (site/)
   |-- /docs -> docs buildés (mkdocs/hugo ou simple rsync)
   |-- /artifacts -> ISO + .sha256 produits par scripts/build.sh
```

### Rôles et ports
- **nginx** : 443 (TLS), sert le site statique et reverse-proxy vers l'API (localhost:8080).
- **Account service** : `web/account_service.py` écoute sur 8080, REST JSON, stockage SQLite local.
- **Artifacts** : exposés en lecture seule (`/var/www/global-os/artifacts`). Chaque ISO est accompagnée de son hash `.sha256`.

## Pipeline de publication ISO
1. `./scripts/build.sh` produit l'ISO et `<iso>.sha256`.
2. `./scripts/publish_to_website.sh` envoie via `rsync` :
   - `Global-K-OS*.iso` et `*.sha256` vers `build.global-os.net:/var/www/global-os/artifacts/`.
   - le site statique `site/` et la doc `docs/` vers `global-os.net:/var/www/global-os/`.
3. Le reverse-proxy rafraîchit automatiquement les index (`nginx` sert directement le contenu mis à jour).

## Comptes et authentification
- Comptes gérés par le service `web/account_service.py` (standard library uniquement, pas de dépendance externe).
- Passwords : PBKDF2-HMAC-SHA256 avec salt unique par utilisateur, stockage en base SQLite (`/var/lib/global-os/accounts.db`).
- Flux API :
  - `POST /users` : crée un compte (body JSON `{"username":"", "password":""}`).
  - `POST /login` : authentifie et retourne un token signé HMAC (clé dans `/etc/global-os/api-secret.key`).
  - `GET /users` : liste des comptes (protégé par token admin).
- Les logs HTTP sont envoyés vers `stdout` (journalisation systemd), rotation laissée à `logrotate`.

## Exigences système
- Distribution hôte : Debian 12+ ou Ubuntu 22.04+.
- Paquets : `nginx`, `rsync`, `python3`, `sqlite3`, `coreutils`, `openssh-client` (pour la publication distante).
- Ports ouverts : 443 (externes), 8080 (interne API), 22 (SSH pour la synchro).

## Déploiement rapide
```bash
# 1) Installer dépendances
sudo apt update && sudo apt install nginx python3 sqlite3 rsync openssh-client

# 2) Déployer le site statique et la doc
sudo mkdir -p /var/www/global-os/{artifacts,docs,site}
sudo rsync -av site/ /var/www/global-os/site/
sudo rsync -av docs/ /var/www/global-os/docs/

# 3) Déployer l'API comptes
sudo mkdir -p /var/lib/global-os
sudo cp web/account_service.py /usr/local/bin/global-os-account-service
sudo useradd -r -s /usr/sbin/nologin globalos || true
sudo chown -R globalos:globalos /var/lib/global-os

# 4) Créer l'unit systemd (api.global-os.net)
cat <<'UNIT' | sudo tee /etc/systemd/system/global-os-account.service
[Unit]
Description=Global-OS account API
After=network.target

[Service]
User=globalos
Group=globalos
Environment=GLOBAL_OS_DB=/var/lib/global-os/accounts.db
Environment=GLOBAL_OS_BIND=0.0.0.0:8080
Environment=GLOBAL_OS_SECRET_FILE=/etc/global-os/api-secret.key
ExecStart=/usr/bin/env python3 /usr/local/bin/global-os-account-service
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT

# 5) Générer la clé HMAC
sudo mkdir -p /etc/global-os
sudo dd if=/dev/urandom bs=32 count=1 | sudo tee /etc/global-os/api-secret.key >/dev/null
sudo chmod 600 /etc/global-os/api-secret.key

# 6) Activer/ démarrer
sudo systemctl daemon-reload
sudo systemctl enable --now global-os-account.service

# 7) Configurer nginx (exemple server block)
cat <<'NGINX' | sudo tee /etc/nginx/sites-available/global-os
server {
    listen 443 ssl;
    server_name global-os.net *.global-os.net;

    root /var/www/global-os/site;
    index index.html;

    location /docs/ {
        alias /var/www/global-os/docs/;
    }

    location /artifacts/ {
        alias /var/www/global-os/artifacts/;
        autoindex on;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
NGINX

sudo ln -sf /etc/nginx/sites-available/global-os /etc/nginx/sites-enabled/global-os
sudo nginx -t && sudo systemctl reload nginx
```

## Surveiller et mettre à jour
- `systemctl status global-os-account.service` pour l'API comptes.
- `journalctl -u global-os-account.service -f` pour les logs en direct.
- `rsync -av --delete site/ global-os.net:/var/www/global-os/site/` pour pousser une nouvelle version du site.

## Sécurité minimale
- Séparer les certificats TLS via un gestionnaire (Let's Encrypt/ACME) en dehors de ce dépôt.
- Restreindre `/api` aux administrateurs via ACL réseau ou authentification forte (token HMAC + IP allowlist).
- Sauvegarder `/var/lib/global-os/accounts.db` régulièrement et chiffrer les sauvegardes.
