#!/usr/bin/env python3
"""Service API de comptes pour Global-OS (standard library only).

- Stockage : SQLite (fichier pointé par $GLOBAL_OS_DB, défaut /var/lib/global-os/accounts.db)
- Authentification : token HMAC (clé dans $GLOBAL_OS_SECRET_FILE)
- Endpoints :
    POST /users    -> crée un utilisateur (body JSON {"username","password"})
    POST /login    -> authentifie et retourne {"token"}
    GET  /users    -> liste des utilisateurs (X-Auth-Token requise, admin uniquement)
    GET  /health   -> statut

Ce service est minimaliste pour rester sans dépendance externe et s'exécute
sans privilèges (user `globalos`).
"""

import base64
import hashlib
import hmac
import json
import os
import secrets
import sqlite3
import time
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Dict, Optional, Tuple

DB_PATH = os.environ.get("GLOBAL_OS_DB", "/var/lib/global-os/accounts.db")
BIND = os.environ.get("GLOBAL_OS_BIND", "127.0.0.1:8080")
SECRET_FILE = os.environ.get("GLOBAL_OS_SECRET_FILE", "/etc/global-os/api-secret.key")
TOKEN_TTL = 3600  # 1h


def _ensure_db() -> None:
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                salt TEXT NOT NULL,
                role TEXT NOT NULL DEFAULT 'user'
            )
            """
        )
        conn.commit()


def _load_secret() -> bytes:
    with open(SECRET_FILE, "rb") as f:
        data = f.read()
    if len(data) < 32:
        raise RuntimeError("Secret key too short; regenerate /etc/global-os/api-secret.key")
    return data


def _pbkdf2(password: str, salt: str) -> str:
    dk = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 200_000)
    return base64.b64encode(dk).decode()


def _hash_password(password: str) -> Tuple[str, str]:
    salt = secrets.token_hex(16)
    return _pbkdf2(password, salt), salt


def _verify_password(password: str, hashed: str, salt: str) -> bool:
    candidate = _pbkdf2(password, salt)
    return hmac.compare_digest(candidate, hashed)


def _sign_token(username: str, role: str, secret: bytes) -> str:
    payload = f"{username}:{role}:{int(time.time())}"
    sig = hmac.new(secret, payload.encode(), hashlib.sha256).digest()
    return base64.urlsafe_b64encode(payload.encode() + b"." + sig).decode()


def _verify_token(token: str, secret: bytes) -> Optional[Dict[str, str]]:
    try:
        raw = base64.urlsafe_b64decode(token.encode())
        payload, sig = raw.rsplit(b".", 1)
        expected = hmac.new(secret, payload, hashlib.sha256).digest()
        if not hmac.compare_digest(expected, sig):
            return None
        username, role, ts_str = payload.decode().split(":")
        if int(time.time()) - int(ts_str) > TOKEN_TTL:
            return None
        return {"username": username, "role": role}
    except Exception:
        return None


class AccountStore:
    def __init__(self, path: str):
        self.path = path
        _ensure_db()

    def create_user(self, username: str, password: str, role: str = "user") -> bool:
        if not username or not password:
            return False
        hashed, salt = _hash_password(password)
        try:
            with sqlite3.connect(self.path) as conn:
                conn.execute(
                    "INSERT INTO users (username, password_hash, salt, role) VALUES (?, ?, ?, ?)",
                    (username, hashed, salt, role),
                )
                conn.commit()
            return True
        except sqlite3.IntegrityError:
            return False

    def authenticate(self, username: str, password: str) -> Optional[str]:
        with sqlite3.connect(self.path) as conn:
            cur = conn.execute(
                "SELECT password_hash, salt, role FROM users WHERE username = ?",
                (username,),
            )
            row = cur.fetchone()
        if not row:
            return None
        hashed, salt, role = row
        if _verify_password(password, hashed, salt):
            return role
        return None

    def list_users(self) -> Dict[str, str]:
        with sqlite3.connect(self.path) as conn:
            cur = conn.execute("SELECT username, role FROM users ORDER BY id")
            return {row[0]: row[1] for row in cur.fetchall()}


class RequestHandler(BaseHTTPRequestHandler):
    store = AccountStore(DB_PATH)
    secret = _load_secret()

    def _json_response(self, status: HTTPStatus, payload: Dict) -> None:
        data = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _parse_body(self) -> Dict:
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length else b""
        try:
            return json.loads(raw.decode() or "{}")
        except json.JSONDecodeError:
            return {}

    def _auth(self) -> Optional[Dict[str, str]]:
        token = self.headers.get("X-Auth-Token")
        if not token:
            return None
        return _verify_token(token, self.secret)

    def do_GET(self) -> None:  # noqa: N802 (BaseHTTPRequestHandler API)
        if self.path.startswith("/health"):
            return self._json_response(HTTPStatus.OK, {"status": "ok"})
        if self.path.startswith("/users"):
            auth = self._auth()
            if not auth or auth.get("role") != "admin":
                return self._json_response(HTTPStatus.UNAUTHORIZED, {"error": "auth required"})
            return self._json_response(HTTPStatus.OK, {"users": self.store.list_users()})
        self._json_response(HTTPStatus.NOT_FOUND, {"error": "not found"})

    def do_POST(self) -> None:  # noqa: N802
        if self.path.startswith("/users"):
            body = self._parse_body()
            created = self.store.create_user(body.get("username", "").strip(), body.get("password", ""))
            if created:
                return self._json_response(HTTPStatus.CREATED, {"status": "user created"})
            return self._json_response(HTTPStatus.BAD_REQUEST, {"error": "user exists or invalid"})

        if self.path.startswith("/login"):
            body = self._parse_body()
            role = self.store.authenticate(body.get("username", ""), body.get("password", ""))
            if not role:
                return self._json_response(HTTPStatus.UNAUTHORIZED, {"error": "invalid credentials"})
            token = _sign_token(body["username"], role, self.secret)
            return self._json_response(HTTPStatus.OK, {"token": token, "role": role})

        self._json_response(HTTPStatus.NOT_FOUND, {"error": "not found"})

    def log_message(self, fmt: str, *args) -> None:  # pragma: no cover - delegated to journalctl
        message = fmt % args
        print(f"{self.log_date_time_string()} {self.address_string()} {message}")


def main() -> None:
    host, port_str = BIND.split(":")
    server = HTTPServer((host, int(port_str)), RequestHandler)
    print(f"[global-os-account] listening on {BIND}, db={DB_PATH}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
