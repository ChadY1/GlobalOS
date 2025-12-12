#include "../include/install.h"
#include "../include/vga.h"
#include "../include/fs.h"
#include "../include/utils.h"

void install_offline_run(void) {
    gfs_create("/boot", GFS_INODE_DIR);
    gfs_create("/etc", GFS_INODE_DIR);
    gfs_write("/boot", "kernel.bin", 11);
    vga_write_string("[install] offline base layout prepared\n");
}
