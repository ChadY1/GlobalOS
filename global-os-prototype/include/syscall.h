#ifndef GLOBAL_OS_SYSCALL_H
#define GLOBAL_OS_SYSCALL_H

#include "types.h"

#define SYSCALL_MAX 8

typedef u64 (*syscall_handler_t)(u64, u64, u64, u64);

void syscall_init(void);
u64 syscall_invoke(u64 num, u64 a, u64 b, u64 c);

#endif /* GLOBAL_OS_SYSCALL_H */
