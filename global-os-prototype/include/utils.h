#ifndef GLOBAL_OS_UTILS_H
#define GLOBAL_OS_UTILS_H

#include "types.h"

void *memset(void *dst, int value, size_t count);
void *memcpy(void *dst, const void *src, size_t count);
size_t strlen(const char *s);
int strcmp(const char *a, const char *b);

#endif /* GLOBAL_OS_UTILS_H */
