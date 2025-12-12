#include "../include/memory.h"
#include "../include/utils.h"

static struct page page_pool[(1 << MAX_ORDER) * 2];
static struct page *free_lists[MAX_ORDER + 1];
static u64 total_pages;

static u64 round_up_pow2(u64 v) {
    u64 p = 1;
    while (p < v) p <<= 1;
    return p;
}

void memory_init(u64 mem_size, u64 kernel_end_phys) {
    (void)kernel_end_phys;
    total_pages = mem_size / PAGE_SIZE;
    if (total_pages > (u64)((1 << MAX_ORDER) * 2)) {
        total_pages = (1 << MAX_ORDER) * 2;
    }
    memset(page_pool, 0, sizeof(page_pool));
    for (u64 i = 0; i < total_pages; i++) {
        page_pool[i].order = 0;
        page_pool[i].used = 0;
        page_pool[i].next = free_lists[0];
        free_lists[0] = &page_pool[i];
    }
}

static int find_order(size_t size) {
    u64 pages = (size + PAGE_SIZE - 1) / PAGE_SIZE;
    u64 needed = round_up_pow2(pages);
    int order = 0;
    while ((1ULL << order) < needed && order < MAX_ORDER) {
        order++;
    }
    return order;
}

void *alloc_page(void) {
    if (!free_lists[0]) {
        return NULL;
    }
    struct page *p = free_lists[0];
    free_lists[0] = p->next;
    p->used = 1;
    return (void *)(p - page_pool) ;
}

void free_page(void *page) {
    struct page *p = &page_pool[(u64)page];
    p->used = 0;
    p->next = free_lists[0];
    free_lists[0] = p;
}

void *kmalloc(size_t size) {
    int order = find_order(size);
    for (int o = order; o <= MAX_ORDER; o++) {
        if (free_lists[o]) {
            struct page *p = free_lists[o];
            free_lists[o] = p->next;
            p->used = 1;
            return (void *)((p - page_pool) * PAGE_SIZE);
        }
    }
    return NULL;
}

void kfree(void *ptr) {
    if (!ptr) return;
    u64 idx = (u64)ptr / PAGE_SIZE;
    struct page *p = &page_pool[idx];
    p->used = 0;
    p->next = free_lists[p->order];
    free_lists[p->order] = p;
}
