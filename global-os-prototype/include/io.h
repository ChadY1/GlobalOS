#ifndef GLOBAL_OS_IO_H
#define GLOBAL_OS_IO_H

#include "types.h"

static inline void outb(u16 port, u8 val) {
    __asm__ __volatile__("outb %0, %1" : : "a"(val), "Nd"(port));
}

static inline u8 inb(u16 port) {
    u8 ret;
    __asm__ __volatile__("inb %1, %0" : "=a"(ret) : "Nd"(port));
    return ret;
}

#endif /* GLOBAL_OS_IO_H */
