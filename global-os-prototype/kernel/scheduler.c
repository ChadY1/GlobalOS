#include "../include/scheduler.h"
#include "../include/utils.h"
#include "../include/vga.h"

#define TASK_UNUSED 0
#define TASK_READY 1
#define TASK_RUNNING 2

static struct task tasks[MAX_TASKS];
static int current = -1;
static u64 next_id = 1;

void scheduler_init(void) {
    memset(tasks, 0, sizeof(tasks));
}

int scheduler_create(task_entry_t entry, void *arg) {
    for (int i = 0; i < MAX_TASKS; i++) {
        if (tasks[i].state == TASK_UNUSED) {
            tasks[i].id = next_id++;
            tasks[i].state = TASK_READY;
            tasks[i].entry = entry;
            tasks[i].arg = arg;
            return i;
        }
    }
    return -1;
}

void scheduler_tick(void) {
    int start = current;
    for (int i = 0; i < MAX_TASKS; i++) {
        int idx = (start + 1 + i) % MAX_TASKS;
        if (tasks[idx].state == TASK_READY) {
            current = idx;
            tasks[idx].state = TASK_RUNNING;
            tasks[idx].entry(tasks[idx].arg);
            tasks[idx].state = TASK_READY;
            break;
        }
    }
}

void scheduler_run(void) {
    while (1) {
        scheduler_tick();
    }
}
