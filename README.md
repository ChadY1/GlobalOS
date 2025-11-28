# Global-K-OS 1.0 — guide de construction et d'installation

Global-K-OSv0.1 (version 1.0) fusionne l'arsenal d'outillage de **Kali Linux** avec la posture de sécurité renforcée de **GrapheneOS**, en s'appuyant sur Debian *testing/sid* comme base de build.

## Objectifs
- Reprendre les durcissements noyau et espace utilisateur de GrapheneOS tout en conservant la compatibilité des paquets Debian/Kali.
- Fournir un environnement bureautique minimaliste basé sur Wayland, avec un sandboxing strict pour chaque application graphique.
- Distribuer l'arsenal d'outils (tests de sécurité, forensic, analyse réseau) via des méta-paquets thématiques accompagnés de profils de confinement et d'un cadrage d'usage défensif.
- Garantir une délivrabilité professionnelle : build reproductible, hash SHA-256 publié, UX cohérente (palette Globaleurope.fr/home).

### Cadre d'usage et conformité
- Positionnement prioritaire : défense, résilience, conformité et entraînement (pas d'automatisation de l'usage de la force ni d'outillage offensif par défaut).
- Respect du droit international et des contrôles export (Wassenaar, règlement UE 2021/821) : effectuer un screening utilisateur/pays et, si nécessaire, une revue juridique avant distribution.
- Orientation « human-in-the-loop » : imposer des validations humaines dans les applications métiers et conserver des journaux horodatés/signés pour audit et traçabilité.
- Clause contractuelle recommandée : interdire explicitement l'usage pour des violations du DIH/droits humains ou des cyber-opérations offensives.

---
## Construction et installation premium (production-ready)

### Checklist express
1) **Hôte** : Debian *testing/sid* à jour (`sudo apt update && sudo apt full-upgrade`).
2) **Paquets** : `sudo apt install live-build bubblewrap xdg-dbus-proxy uidmap sha256sum qemu-utils` (le binaire fourni est `bwrap`).
3) **User namespaces** : `sudo sysctl -w kernel.unprivileged_userns_clone=1` (et persistance via `/etc/sysctl.d/99-userns.conf`).
4) **Palette Sway** : garder `sway/config` ou déposer votre `~/.config/sway/config` pour un thème custom qui sera inclus.
5) **Build** : exécuter `./scripts/build.sh` depuis la racine du dépôt.
6) **Intégrité** : vérifier le hash généré (`sha256sum -c *.sha256`).
7) **Validation** : booter l'ISO en VM UEFI puis sur matériel, avec autologin + Sway auto-start pour confirmer l'expérience utilisateur.

### Étapes détaillées
```bash
# 1) Préparer
sudo apt update && sudo apt install live-build bubblewrap xdg-dbus-proxy uidmap sha256sum qemu-utils
echo 'kernel.unprivileged_userns_clone=1' | sudo tee /etc/sysctl.d/99-userns.conf
sudo sysctl -p /etc/sysctl.d/99-userns.conf

# 2) Lancer la construction depuis la racine du dépôt
chmod +x scripts/build.sh
./scripts/build.sh

# 3) Récupérer l'ISO et son hash (générés automatiquement)
ls -1 *.iso *.hybrid.iso *.sha256

# 4) Vérifier l'intégrité
sha256sum -c *.sha256
```

### Build CI GitHub (artifact ISO automatique)
- Chaque **pull request** lance le workflow GitHub Actions **Build ISO artifact** qui exécute `scripts/build.sh` sur un runner Ubuntu avec les dépendances requises.
- À la fin du run, l'ISO et son hash `.sha256` sont publiés comme artifact nommé `global-k-os-iso`.
- Pour récupérer l'image : onglet **Actions** → run **Build ISO artifact** correspondant à la PR → section **Artifacts** → télécharger `global-k-os-iso`.

Le script :
- Nettoie un éventuel build précédent (`lb clean`).
- Configure live-build pour Global-K-OS (nom, éditeur, volume, Debian testing, bootloader GRUB, installeur graphique).
- Injecte la liste de paquets de base (`config/package-lists/core.list.chroot`), le profil Sway par défaut ou votre propre `~/.config/sway/config`, et le lanceur sandbox Firefox.
- Applique le hook `config/hooks/live/001-permissions.chroot` pour conserver les droits d'exécution des lanceurs et les squelettes Sway.
- Place les drop-ins système pour autologin sur `tty1` et démarrage automatique de **Sway** pour l'utilisateur live.
- Construit l'ISO puis génère automatiquement un hash **SHA-256** (`<iso>.sha256`) pour vérification en ligne ou en CI.

### Tester l'ISO (UX premium)
- **VM UEFI (recommandé avant toute diffusion)** :
  ```bash
  qemu-img create -f qcow2 /tmp/gkos.qcow2 20G
  qemu-system-x86_64 \
    -enable-kvm -m 4096 -smp 4 \
    -cpu host \
    -machine q35,accel=kvm \
    -bios /usr/share/OVMF/OVMF_CODE.fd \
    -drive if=virtio,file=/tmp/gkos.qcow2 \
    -cdrom Global-K-OS*.iso
  ```
- **Bare metal** : graver l'ISO sur USB puis booter en UEFI. Exemple avec `dd` (vérifiez la cible !) :
  ```bash
  sudo dd if=Global-K-OS*.iso of=/dev/sdX bs=4M status=progress oflag=sync
  ```
  Si Secure Boot bloque le démarrage, désactivez-le temporairement ou signez l'ISO avec vos clés internes.

### Installation sur disque depuis l'ISO
L'ISO inclut l'installeur Debian (mode graphique). Pour une installation « production-ready » :
- Choisissez le partitionnement guidé LUKS2 (chiffrement complet) et ext4.
- Montez `/tmp` et `/var/tmp` en `noexec,nodev,nosuid`, `/home` et `/var` en `nodev` (voir options dans l'installeur expert).
- Conservez l'utilisateur live uniquement pour la session éphémère ; créez un compte dédié avec clé SSH et mot de passe robuste.

### Contrôles finaux avant diffusion
- **Hash** : le `.sha256` doit correspondre byte pour byte à l'ISO publiée.
- **UX** : l'autologin doit lancer Sway immédiatement (palette Globaleurope.fr/home), `Super+Enter` et `Super+d` doivent fonctionner.
- **Réseau** : `NetworkManager` opérationnel, `pipewire` audio OK, sandbox Firefox exécutable (`/usr/local/bin/firefox-sandbox.sh`).
- **Confinement** : vérifier `bwrap` (paquet `bubblewrap`) et `xdg-dbus-proxy` présents via `which` dans la session live.

---
## Interface utilisateur (palette Globaleurope.fr/home)
- Gestionnaire : **Sway** + **foot** + **wofi** + **mako**.
- Palette adaptée à Globaleurope.fr/home (bleus profonds, contrastes clairs) appliquée dans `sway/config` :
  - Fenêtre active : fond #0a2a5a, texte clair #e6eef7.
  - Fenêtre inactive : fond #123366, texte clair #c7d7ee.
  - Fenêtre non focalisée : fond #091a39, texte clair #c7d7ee.
- Raccourcis :
  - `Super + Enter` : terminal foot
  - `Super + d` : menu applicatif wofi
  - `Super + ←/→` : navigation workspaces
  - `Super + Shift + c` : recharger la config
- Session live : autologin sur `tty1` et lancement automatique de Sway via `~/.bash_profile` pour éviter de rester en console.

Pour personnaliser, placez votre propre `~/.config/sway/config` avant le build : il sera copié dans l'ISO pour tous les utilisateurs.

### Paquets de base inclus (extrait)
- Bureau Wayland : `sway`, `swaybg`, `swayidle`, `swaylock`, `waybar`, `foot`, `wofi`, `mako-notifier`, `seatd`.
- Live/boot : `live-boot`, `live-config`, `systemd-sysv`, `dbus-user-session`, `policykit-1`.
- Sandboxing : `bubblewrap`, `xdg-dbus-proxy`, `uidmap`.
- Graphismes/audio : `mesa-utils`, `mesa-va-drivers`, `pipewire`, `wireplumber`, `alsa-utils`.
- Réseau/outillage : `network-manager`, `network-manager-config-connectivity-debian`, `curl`, `iproute2`, `net-tools`.

---
## Noyau et socle système (rappel synthétique)
1. **Noyau durci** : partir d'un noyau *vanilla* (6.12+), appliquer les patchs **KSPP** et ceux de GrapheneOS (MTE si dispo). Compilation `clang/lld`, flags `-fstack-protector-strong`, `-fPIE`, `-fvisibility=hidden`, `-Wl,-z,relro,-z,now`. Exemple :
   ```
   CONFIG_HARDENED_USERCOPY=y
   CONFIG_RANDOMIZE_BASE=y
   CONFIG_CC_STACKPROTECTOR_STRONG=y
   # CONFIG_COMPAT_BRK is not set
   # CONFIG_KEXEC is not set
   ```
2. **Toolchain** : alternatives `cc`/`ld` vers LLVM, `DEB_BUILD_MAINT_OPTIONS=hardening=+all`, `-D_FORTIFY_SOURCE=3`.
3. **FS et chiffrement** : ext4, `/tmp` et `/var/tmp` montés `noexec,nodev,nosuid`, `/home` et `/var` en `nodev`, chiffrement LUKS2 par défaut.

---
## Sandboxing
- **bubblewrap** pour les applis graphiques, **firejail** possible pour CLI hérités.
- Exemple Firefox : `sandbox/firefox-sandbox.sh` (montages en lecture seule, tmpfs dédiés, namespaces isolés). Étendre avec `seccomp-bpf` et `xdg-dbus-proxy` pour D-Bus serré.

---
## Méta-paquets Kali + confinement
- Méta-paquets par thème (web, réseau, wireless, mobile) avec dépendances sur leurs profils de sandbox :
  ```
  Package: kali-grapheneos-web-tools
  Version: 2025.1
  Section: metapackages
  Priority: optional
  Architecture: all
  Depends: burpsuite, sqlmap, nikto, firefox-sandbox-profile
  Description: Outils de test web durcis pour Global-K-OS
   Installe les principaux outils d'audit web et leurs profils de sandboxing.
  ```
- Chaque méta-paquet fournit :
  - un paquet `*-sandbox-profile` pour `bubblewrap`/`firejail`.
  - des entrées `desktop`/`alternatives` pointant vers le lanceur confiné.

---
## Stratégie d’itération
1. **Prototype** : installer Debian testing, compiler le noyau durci, configurer Sway + un profil `bubblewrap` (Firefox) et vérifier la surface d’attaque (`seccomp`, `lsm`).
2. **Industrialiser** : généraliser les profils de sandbox, créer les méta-paquets, renforcer la toolchain par défaut.
3. **Automatiser** : intégrer les scripts live-build dans CI, publier des ISO signées, exposer le hash SHA-256 généré par `scripts/build.sh`.
4. **Contribuer** : synchroniser les patchs amont (KSPP/GrapheneOS), suivre les CVE et mettre à jour les profils de confinement.

---
## Schéma de chiffrage documentaire (référentiel)
Ce référentiel reprend les valeurs demandées pour encoder des segments alphanumériques en contexte documentaire ou pour des chaînes de validation interne. Chaque entrée reste stable et peut être utilisée comme préfixe/suffixe lors de la génération d’artéfacts ou de checksums complémentaires.

**Chiffres (replica)**

| Symbole | Forme normalisée |
| --- | --- |
| 1 (via A) | 01001.3333333333333.3033 |
| 2 | 01011.3333333333333.3033 |
| 3 | 10100.3333333333333.3033 |
| 4 | 10011.3333333333333.3033 |
| 5 | 00100.3333333333333.3033 |
| 6 | 00011.3333333333333.3033 |
| 7 | 01010.3333333333333.3033 |
| 8 | 00001.3333333333333.3033 |
| 9 | 10000.3333333333333.3033 |
| 10 | 11011.3330333033303.3333333333333 |

**Lettres (replicated)**

| Lettre | Forme normalisée |
| --- | --- |
| A | 01001.3333333333333.3033 |
| B | 01001.3333333333333.3033 |
| C | 01001.3333333333333.3033 |
| D | 01001.3333333333333.3033 |
| E | 01001.3333333333333.3033 |
| F | 01001.3333333333333.3033 |
| G | 01001.3333333333333.3033 |
| H | 01001.3333333333333.3033 |
| I | 01001.3333333333333.3033 |
| J | 01001.3333333333333.3033 |
| K | 01001.3333333333333.3033 |
| L | 01001.3333333333333.3033 |
| M | 01001.3333333333333.3033 |
| N | 01001.3333333333333.3033 |
| O | 01001.3333333333333.3033 |
| P | 01001.3333333333333.3033 |
| Q | 01001.3333333333333.3033 |
| R | 01001.3333333333333.3033 |
| S | 01001.3333333333333.3033 |
| T | 01001.3333333333333.3033 |
| U | 01001.3333333333333.3033 |
| V | 01001.3333333333333.3033 |
| W | 01001.3333333333333.3033 |
| X | 01001.3333333333333.3033 |
| Y | 01001.3333333333333.3033 |
| Z | 01001.3333333333333.3033 |

> Les valeurs sources (ex. "13 333" ou "23 333") sont normalisées ici sous forme décimale unique pour faciliter l’intégration dans des scripts de build, des manifestes ou des fichiers de contrôle où une représentation homogène est requise.

Cette base fournit un plan d’action clair et industrialisable pour Global-K-OS.
