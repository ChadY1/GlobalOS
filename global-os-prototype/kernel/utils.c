#include "../include/utils.h"

void *memset(void *dst, int value, size_t count) {
    unsigned char *p = dst;
    while (count--) {
        *p++ = (unsigned char)value;
    }
    return dst;
}

void *memcpy(void *dst, const void *src, size_t count) {
    unsigned char *d = dst;
    const unsigned char *s = src;
    while (count--) {
        *d++ = *s++;
    }
    return dst;
}

size_t strlen(const char *s) {
    size_t len = 0;
    while (s[len]) {
        len++;
    }
    return len;
}

int strcmp(const char *a, const char *b) {
    while (*a && (*a == *b)) {
        a++; b++;
    }
    return *(const unsigned char *)a - *(const unsigned char *)b;
}
