#ifndef GLOBAL_OS_SCHEDULER_H
#define GLOBAL_OS_SCHEDULER_H

#include "types.h"

#define MAX_TASKS 16

typedef void (*task_entry_t)(void *);

struct task {
    u64 id;
    u64 state;
    u64 rsp;
    task_entry_t entry;
    void *arg;
};

void scheduler_init(void);
int scheduler_create(task_entry_t entry, void *arg);
void scheduler_tick(void);
void scheduler_run(void);

#endif /* GLOBAL_OS_SCHEDULER_H */
