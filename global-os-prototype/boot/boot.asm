; Global-OS bootstrap (BIOS-friendly, UEFI tested in CSM)
; Original code: minimal loader that jumps into 64-bit kernel

BITS 16
ORG 0x7c00

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    mov [BOOT_DRIVE], dl

; Enable A20 line (keyboard controller method)
enable_a20:
    in al, 0x64
.a20_wait1:
    test al, 2
    jnz .a20_wait1
    mov al, 0xd1
    out 0x64, al
.a20_wait2:
    in al, 0x64
    test al, 2
    jnz .a20_wait2
    mov al, 0xdf
    out 0x60, al

; Simple disk read: load 64 sectors after the boot sector into 0x100000
    mov bx, 0x0000
    mov es, bx
    mov bx, 0x0000
    mov di, 0
    mov si, 0
    mov dh, 0       ; head 0
    mov dl, [BOOT_DRIVE]
    mov ch, 0       ; cylinder 0
    mov cl, 2       ; sector 2
    mov bx, 0x0000
    mov ax, 0x1000  ; ES:BX = 0x10000:0 -> 0x100000
    mov es, ax
    mov bx, 0x0000
    mov ah, 0x02    ; INT 13h read sectors
    mov al, 64      ; read 64 sectors
    int 0x13
    jc disk_error

disk_error:
    mov si, disk_msg
    call print_string
    jmp hang16

; Basic 16-bit string printer using BIOS teletype
print_string:
    pusha
.next:
    lodsb
    cmp al, 0
    je .done
    mov ah, 0x0e
    int 0x10
    jmp .next
.done:
    popa
    ret

hang16:
    hlt
    jmp hang16

; Setup GDT
    lgdt [gdt_descriptor]

; Enter protected mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:protected_entry

[BITS 32]
protected_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x9fc00

; Enable PAE
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

; Build identity-mapped paging structures at 0x90000
    mov edi, 0x90000
    mov ecx, 0x1000/4
    xor eax, eax
    rep stosd

    ; PML4
    mov dword [0x90000], 0x91003
    ; PDPT
    mov dword [0x91000], 0x92003
    ; PD (2 MiB pages)
    mov dword [0x92000], 0x000083

    mov eax, 0x90000
    mov cr3, eax

; Enable long mode
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

; Enable paging
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

    jmp 0x08:long_mode_entry

[BITS 64]
long_mode_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov rsp, 0x80000

    movzx rdi, byte [BOOT_DRIVE]
    lea rsi, [kernel_info]
    mov rax, [kernel_info]
    call rax

.hang:
    hlt
    jmp .hang

BOOT_DRIVE db 0
kernel_info:
    dq 0x100000
    dq 64*512

disk_msg db 'Disk read error',0

; GDT with null, code, data descriptors
ALIGN 8
gdt_start:
    dq 0x0000000000000000
    dq 0x00af9a000000ffff ; code
    dq 0x00af92000000ffff ; data
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

TIMES 510-($-$$) db 0
DW 0xAA55
