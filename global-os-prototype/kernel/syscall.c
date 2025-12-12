#include "../include/syscall.h"
#include "../include/vga.h"
#include "../include/utils.h"

static u64 sys_write(u64 ptr, u64 len, u64 unused1, u64 unused2) {
    const char *cptr = (const char *)ptr;
    (void)len; (void)unused1; (void)unused2;
    vga_write_string(cptr);
    return 0;
}

static u64 sys_noop(u64 a, u64 b, u64 c, u64 d) {
    (void)a; (void)b; (void)c; (void)d;
    return 0;
}

static syscall_handler_t table[SYSCALL_MAX];

void syscall_init(void) {
    for (int i = 0; i < SYSCALL_MAX; i++) {
        table[i] = sys_noop;
    }
    table[0] = sys_write;
}

u64 syscall_invoke(u64 num, u64 a, u64 b, u64 c) {
    if (num >= SYSCALL_MAX) {
        return (u64)-1;
    }
    return table[num](a, b, c, 0);
}
