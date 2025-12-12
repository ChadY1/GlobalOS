# Installation de Global-OS 4.0 sous VirtualBox (2010–2026)

Ce guide couvre VirtualBox 4.x à 7.x sur hôtes Windows, macOS et Linux.

## Pré-requis
- CPU x86_64 avec VT-x/AMD-V activé dans le BIOS/UEFI.
- 4 Go de RAM minimum (8 Go recommandé).
- 20 Go de stockage libre pour le disque virtuel.
- VirtualBox installé (version >= 4.3 pour l'UEFI, >= 6.x conseillé).

## Étapes
1. **Créer la VM**
   - Nom : `Global-OS 4.0`
   - Type : `Linux`, Version : `Debian (64-bit)`
   - Mémoire : 4096 Mo (ou plus selon votre RAM)
   - Disque : `VDI` dynamique, 20 Go+

2. **Activer l'UEFI et l'I/O APIC**
   - Paramètres → Système → Carte mère : cocher **Activer EFI (uniquement systèmes d'exploitation spéciaux)**.
   - Vérifier **I/O APIC** activé.

3. **CPU & Accélération**
   - Processeur : 2 vCPU minimum (4 recommandé).
   - Activer **PAE/NX** et **VT-x/AMD-V**.

4. **Affichage**
   - Mémoire vidéo : 64 Mo minimum.
   - Activer **Contrôleur graphique VMSVGA** et **Accélération 3D** si disponible.

5. **Montage de l'ISO**
   - Stockage → Contrôleur IDE/SATA → Ajouter un lecteur optique → Choisir le fichier ISO `Global-K-OS-4.0.iso` (ou le nom généré par `scripts/build.sh`).

6. **Réseau**
   - Mode : `NAT` (simple) ou `Accès par pont` (si besoin d'une IP LAN visible par d'autres machines).

7. **Démarrer et installer**
   - Démarrer la VM ; l'autologin lance Sway.
   - Pour installer sur disque virtuel : lancer l'installeur Debian depuis le menu ou via terminal `sudo calamares` si intégré.
   - Choisir le partitionnement guidé LUKS2 (chiffrement) et ext4.

8. **Post-installation**
   - Éjecter l'ISO depuis VirtualBox.
   - Redémarrer la VM sur le disque virtuel.
   - Créer un utilisateur dédié et désactiver le compte live.

## Résolution des problèmes fréquents
- **Écran noir après boot** : vérifier que l'UEFI est activé et que le contrôleur graphique est `VMSVGA`.
- **Clavier AZERTY manquant** : dans le menu Sway, `setxkbmap fr` ou régler pendant l'installation.
- **ISO non détectée** : remplacer le contrôleur par SATA, ou désactiver Secure Boot dans l'UEFI VirtualBox.
