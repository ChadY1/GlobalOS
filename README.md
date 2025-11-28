# Kali-GrapheneOS : feuille de route technique

Cette feuille de route décrit comment créer une distribution de bureau qui combine l'arsenal offensif de **Kali Linux** avec la posture de sécurité renforcée de **GrapheneOS**, en s'appuyant sur Debian *testing/sid* comme base.

## Objectifs
- Reprendre les durcissements noyau et espace utilisateur de GrapheneOS tout en conservant la compatibilité des paquets Debian/Kali.
- Fournir un environnement bureautique minimaliste basé sur Wayland, avec un sandboxing strict pour chaque application graphique.
- Distribuer l'arsenal d'outils offensive via des méta-paquets thématiques accompagnés de profils de confinement.

## Phase 1 : noyau et socle système
1. **Noyau Linux durci**
   - Partir d’un noyau *vanilla* (6.12+), appliquer les patchs du **Kernel Self-Protection Project (KSPP)** et les correctifs spécifiques GrapheneOS (p. ex. Memory Tagging Extension quand disponible).
   - Compilation avec `clang`/`lld`, et drapeaux de durcissement (`-fstack-protector-strong`, `-fPIE`, `-fvisibility=hidden`, `-Wl,-z,relro,-z,now`).
   - Exemples d’options `.config` :
     ```
     CONFIG_HARDENED_USERCOPY=y
     CONFIG_RANDOMIZE_BASE=y
     CONFIG_CC_STACKPROTECTOR_STRONG=y
     # CONFIG_COMPAT_BRK is not set
     # CONFIG_KEXEC is not set
     ```

2. **Chaîne de compilation système**
   - Basculer la toolchain par défaut sur LLVM (`update-alternatives` pour `cc`, `ld`, `ar`).
   - Activer des *hardening flags* globaux via `DEB_BUILD_MAINT_OPTIONS=hardening=+all` et `-D_FORTIFY_SOURCE=3` côté `dpkg-buildflags`.

3. **Système de fichiers et chiffrement**
   - Partition racine en **ext4**, /tmp et /var/tmp montés `noexec,nodev,nosuid` ; `/home` et `/var` avec `nodev`.
   - Chiffrement intégral par défaut avec **LUKS2**, clé dérivée d’un *KDF* mémoire-dure (argon2id) et activation de `discard` contrôlé.

## Phase 2 : sandboxing et permissions
- Utiliser **bubblewrap** pour les applis graphiques et **firejail** pour les usages CLI hérités.
- Exemple de lanceur Firefox (`/usr/local/bin/firefox-sandbox.sh`) :
  ```bash
  #!/bin/bash
  bwrap \
    --ro-bind /usr /usr \
    --ro-bind /lib /lib \
    --ro-bind /lib64 /lib64 \
    --tmpfs /home/user/.cache \
    --tmpfs /tmp \
    --proc /proc \
    --dev /dev \
    --symlink usr/lib /lib \
    --symlink usr/lib64 /lib64 \
    --unshare-all \
    --share-net \
    --die-with-parent \
    --new-session \
    firefox "$@"
  ```
- Étendre avec des profils *seccomp-bpf* et `xdg-dbus-proxy` pour limiter D-Bus ; isoler chaque profil dans `/etc/bubblewrap.d/<app>.conf`.

## Phase 3 : méta-paquets Kali + confinement
- Regrouper les outils par thème (web, réseau, wireless, mobile) avec des dépendances sur leurs profils de sandbox :
  ```
  Package: kali-grapheneos-web-tools
  Version: 2025.1
  Section: metapackages
  Priority: optional
  Architecture: all
  Depends: burpsuite, sqlmap, nikto, firefox-sandbox-profile
  Description: Outils de test web durcis pour Kali-GrapheneOS
   Installe les principaux outils d'audit web et leurs profils de sandboxing.
  ```
- Chaque méta-paquet inclut :
  - Un paquet `*-sandbox-profile` pour `bubblewrap`/`firejail`.
  - Des overrides `desktop`/`alternatives` pointant vers le lanceur confiné.

## Phase 4 : interface utilisateur
- Environnement Wayland minimal : **Sway** + **foot** + **wofi**.
- Configuration Sway inspirée de GrapheneOS (palette Nord, raccourcis simples) :
  ```
  # Apparence épurée
  client.focused          #4c566a #4c566a #eceff4 #4c566a #4c566a
  client.focused_inactive #3b4252 #3b4252 #d8dee9 #3b4252 #3b4252
  client.unfocused        #2e3440 #2e3440 #d8dee9 #2e3440 #2e3440

  # Lancer un terminal
  bindsym $mod+Return exec foot
  # Menu d'applications confinées
  bindsym $mod+d exec wofi --show drun
  ```
- Désactiver les services de télémétrie, limiter le démarrage automatique, et préférer des notifications minimales via `mako`.

## Phase 5 : génération d’ISO avec live-build
Script `build.sh` minimal dans un répertoire de build :
```bash
#!/bin/bash
set -e

lb clean
lb config \
  --distribution testing \
  --archive-areas "main contrib non-free non-free-firmware" \
  --debian-installer live \
  --bootloader grub \
  --debian-installer-gui true \
  --linux-packages "linux-image-amd64 linux-headers-amd64" \
  --iso-application "Kali-GrapheneOS" \
  --iso-publisher "YourName" \
  --iso-volume "Kali-GOS-2025.1"

echo "kali-grapheneos-core kali-grapheneos-web-tools sway" >> config/package-lists/my.list.chroot
mkdir -p config/includes.chroot/etc/skel/.config/sway/
cp ~/.config/sway/config config/includes.chroot/etc/skel/.config/sway/
cp firefox-sandbox.sh config/includes.chroot/usr/local/bin/

lb build
```

## Stratégie d’itération
1. **Prototype** : installer Debian *testing*, compiler le noyau durci, configurer Sway + un profil `bubblewrap` (Firefox) et vérifier la surface d’attaque (audit `seccomp`, `lsm`).
2. **Industrialiser** : généraliser les profils de sandbox, créer les méta-paquets, renforcer la toolchain par défaut.
3. **Automatiser** : intégrer les scripts `live-build` dans CI, publier des ISO signées, et documenter les mises à jour de noyau durci.
4. **Contribuer** : synchroniser les patchs amont (KSPP/GrapheneOS), suivre les CVE et mettre à jour les profils de confinement.

Cette base fournit un plan d’action clair pour une distribution Kali-GrapheneOS orientée sécurité et confidentialité.
