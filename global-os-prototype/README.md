# Global-OS prototype (from-scratch kernel lane)

This directory seeds an experimental "Global-OS" prototype with original bootloader, kernel, memory manager, filesystem, AI stub, and installer scaffolding. The code is self-contained and does not reuse upstream OS sources.

## Layout
- `boot/boot.asm` — NASM bootloader enabling A20, building a minimal paging identity map, and jumping to the 64-bit kernel entry.
- `kernel/*.c` — freestanding kernel components (scheduler, memory, filesystem, AI, installers, syscalls, VGA, keyboard).
- `include/` — minimal headers shared across components.
- `Makefile` — builds boot sector and freestanding kernel using Clang/LLVM and NASM.
- `build.sh` — convenience wrapper to compile and, when `grub-mkrescue` is present, assemble a bootable ISO and SHA256 hash.
- `link.ld` — linker script placing the kernel at 1 MiB.

## Build (prototype)
```bash
cd global-os-prototype
./build.sh
```
Requirements: `clang`, `ld`/`ld.lld`, `nasm`, and optionally `grub-mkrescue` + `xorriso` for ISO creation. The build uses `-fstack-protector-strong`, `-fPIE`, and `-D_FORTIFY_SOURCE=3` to mirror the hardening flags requested.

The resulting artifacts are:
- `boot.bin` — 512-byte boot sector.
- `kernel.bin` — ELF64 kernel image.
- `global-os-prototype.iso` + `global-os-prototype.iso.sha256` (if `grub-mkrescue` is installed).

## Security and ethics
This prototype ships under the repository GPL license. Usage is explicitly prohibited for human-rights violations or offensive cyber operations.

## Status
The implementation is intentionally minimal but cohesive:
- Buddy-style allocator and page bookkeeping stubs.
- Round-robin cooperative scheduler.
- GFS in-memory prototype with inode, bitmap, and journal placeholders.
- Syscall table with a write primitive.
- Integrated AI module exposing a tiny trainable MLP.
- Offline/online installer stubs that exercise the filesystem and network messaging layers.

Further work is required to flesh out hardware drivers, persistence, and full UEFI validation, but this baseline allows incremental bring-up inside QEMU/OVMF.
