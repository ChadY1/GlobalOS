# Global-K-OS 1.0 — guide de construction et d'installation

Global-K-OSv0.1 (version 1.0) fusionne l'arsenal offensif de **Kali Linux** avec la posture de sécurité renforcée de **GrapheneOS**, en s'appuyant sur Debian *testing/sid* comme base de build.

## Objectifs
- Reprendre les durcissements noyau et espace utilisateur de GrapheneOS tout en conservant la compatibilité des paquets Debian/Kali.
- Fournir un environnement bureautique minimaliste basé sur Wayland, avec un sandboxing strict pour chaque application graphique.
- Distribuer l'arsenal d'outils offensifs via des méta-paquets thématiques accompagnés de profils de confinement.
- Garantir une délivrabilité professionnelle : build reproductible, hash SHA-256 publié, UX cohérente (palette Globaleurope.fr/home).

---
## Construction rapide de l'ISO (production-ready)

### Prérequis hôte
- Debian *testing/sid*
- Paquets : `live-build`, `bubblewrap`, `xdg-dbus-proxy`, `uidmap`, `sha256sum`
- User namespaces activés : `kernel.unprivileged_userns_clone=1`
  - Temporaire : `sudo sysctl -w kernel.unprivileged_userns_clone=1`
  - Persistant : `echo 'kernel.unprivileged_userns_clone=1' | sudo tee /etc/sysctl.d/99-userns.conf`

### Étapes
```bash
# 1) Préparer le script
chmod +x scripts/build.sh

# 2) Lancer la construction depuis la racine du dépôt
./scripts/build.sh

# 3) Récupérer l'ISO et son hash
ls -1 *.iso *.hybrid.iso *.sha256
```

Le script :
- Nettoie un éventuel build précédent (`lb clean`).
- Configure live-build pour Global-K-OS (nom, éditeur, volume, Debian testing, bootloader GRUB, installeur graphique).
- Injecte la liste de paquets de base (`config/package-lists/core.list.chroot`), le profil Sway par défaut ou votre propre `~/.config/sway/config`, et le lanceur sandbox Firefox.
- Applique le hook `config/hooks/live/001-permissions.chroot` pour conserver les droits d'exécution des lanceurs et les squelettes Sway.
- Construit l'ISO puis génère automatiquement un hash **SHA-256** (`<iso>.sha256`) pour vérification en ligne ou en CI.

### Vérifier le hash
```bash
sha256sum -c *.sha256
```
Le checksum doit correspondre exactement au fichier `.sha256` généré. Publiez ce hash avec l'ISO pour une validation côté utilisateurs ou pipeline CI/CD.

### Tester l'ISO
- **VM** : booter l'ISO avec UEFI activé (ex. QEMU/virt-manager, VirtualBox, VMware).
- **Bare metal** : clé USB gravée via `dd` ou `balenaEtcher` avec Secure Boot désactivé si nécessaire.

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

Pour personnaliser, placez votre propre `~/.config/sway/config` avant le build : il sera copié dans l'ISO pour tous les utilisateurs.

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

Cette base fournit un plan d’action clair et industrialisable pour Global-K-OS.
