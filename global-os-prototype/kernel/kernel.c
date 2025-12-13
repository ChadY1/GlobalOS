#include "../include/types.h"
#include "../include/vga.h"
#include "../include/memory.h"
#include "../include/keyboard.h"
#include "../include/scheduler.h"
#include "../include/syscall.h"
#include "../include/fs.h"
#include "../include/ai.h"
#include "../include/install.h"
#include "../include/utils.h"

extern char _kernel_end;

static struct ai_model kernel_ai;

static void task_heartbeat(void *arg) {
    (void)arg;
    vga_write_string("[sched] heartbeat\n");
}

static void task_ai(void *arg) {
    (void)arg;
    float input[AI_MAX_INPUTS] = {1, 0, 0, 0};
    float target[2] = {1, 0};
    ai_train(&kernel_ai, input, target);
}

void kmain(u64 boot_drive, void *info) {
    (void)boot_drive;
    (void)info;
    vga_init();
    vga_write_string("Global-OS bootstrap online\n");
    memory_init(64 * 1024 * 1024, (u64)&_kernel_end);
    keyboard_init();
    scheduler_init();
    syscall_init();
    gfs_init();
    ai_init(&kernel_ai);
    install_offline_run();
    install_online_run();

    scheduler_create(task_heartbeat, NULL);
    scheduler_create(task_ai, NULL);
    scheduler_run();
}
