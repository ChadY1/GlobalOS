#ifndef GLOBAL_OS_MEMORY_H
#define GLOBAL_OS_MEMORY_H

#include "types.h"

#define PAGE_SIZE 4096
#define MAX_ORDER 10 /* up to 4 MiB blocks */

struct page {
    u8 order;
    u8 used;
    struct page *next;
};

void memory_init(u64 mem_size, u64 kernel_end_phys);
void *alloc_page(void);
void free_page(void *page);
void *kmalloc(size_t size);
void kfree(void *ptr);

#endif /* GLOBAL_OS_MEMORY_H */
