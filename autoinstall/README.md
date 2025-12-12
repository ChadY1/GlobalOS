# Global-K-OS autoinstall (preseed)

This directory ships a Debian Installer preseed file for Global-K-OS so you can perform unattended installs on a dedicated Debian host or VM. The preseed is opinionated but minimal: en_US.UTF-8 locale, US keyboard, DHCP networking, a non-root user `global` with password `changeme`, and a full-disk ext4 layout.

## Files
- `global-os.preseed`: Debian Installer preseed file copied into the ISO at build time (into `/preseed/global-os.preseed`).

## Safety
- **Disk wipe**: The recipe uses `partman-auto/disk string /dev/sda` and wipes the entire disk. Override the disk target at boot (`partman-auto/disk=/dev/vda` etc.) or edit the file before building.
- **Credentials**: Change the default username/password or pass overrides at boot (`passwd/username`, `passwd/user-password`, `passwd/user-password-again`).
- **Review**: Always audit preseed files before use in production. Test in a VM first.

## How to use from the ISO boot menu
1. Boot the Global-K-OS ISO in UEFI mode.
2. At the GRUB menu, press `e` on the installer entry and append:
   ```
   auto=true priority=critical preseed/file=/preseed/global-os.preseed partman-auto/disk=/dev/sda
   ```
   Adjust the disk path and any credentials as needed.
3. Press `Ctrl+x` to start the unattended installation.

## Build integration
`scripts/build.sh` copies `autoinstall/global-os.preseed` into `config/preseed/` so the installer can load it from `/preseed/global-os.preseed` on the ISO.
