CC ?= clang
LD ?= ld
NASM ?= nasm
CFLAGS = -ffreestanding -mno-red-zone -fstack-protector-strong -fPIE -D_FORTIFY_SOURCE=3 -Wall -Wextra -std=c11 -Iinclude
LDFLAGS = -nostdlib -T link.ld -static -z relro -z now
OBJS = kernel/kernel.o kernel/memory.o kernel/vga.o kernel/keyboard.o kernel/scheduler.o kernel/syscall.o kernel/fs.o kernel/ai.o kernel/install_offline.o kernel/install_online.o kernel/utils.o

all: boot.bin kernel.bin

boot.bin: boot/boot.asm
$(NASM) -f bin $< -o $@

kernel.bin: $(OBJS)
$(LD) $(LDFLAGS) -o $@ $(OBJS)

%.o: %.c
$(CC) $(CFLAGS) -c $< -o $@

clean:
rm -f $(OBJS) boot.bin kernel.bin

.PHONY: all clean
