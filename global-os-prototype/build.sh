#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR"

if ! command -v clang >/dev/null; then
  echo "clang not found" >&2
  exit 1
fi
if ! command -v nasm >/dev/null; then
  echo "nasm not found" >&2
  exit 1
fi

make clean
make

ISO_DIR=$SCRIPT_DIR/iso_root
mkdir -p "$ISO_DIR/boot/grub"
cp boot.bin "$ISO_DIR/boot/boot.bin"
cp kernel.bin "$ISO_DIR/boot/kernel.bin"
cat > "$ISO_DIR/boot/grub/grub.cfg" <<'CFG'
set timeout=0
set default=0
menuentry "Global-OS" {
    multiboot2 /boot/kernel.bin
    boot
}
CFG

ISO_NAME="global-os-prototype.iso"
if command -v grub-mkrescue >/dev/null; then
  grub-mkrescue -o "$ISO_NAME" "$ISO_DIR"
  sha256sum "$ISO_NAME" > "$ISO_NAME.sha256"
  echo "ISO generated: $ISO_NAME"
else
  echo "grub-mkrescue not available; skipped ISO generation" >&2
fi
