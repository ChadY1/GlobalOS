#ifndef GLOBAL_OS_FS_H
#define GLOBAL_OS_FS_H

#include "types.h"

#define GFS_MAX_FILES 128
#define GFS_BLOCK_SIZE 512
#define GFS_MAX_BLOCKS 4096

enum gfs_inode_type {
    GFS_INODE_FREE = 0,
    GFS_INODE_FILE = 1,
    GFS_INODE_DIR  = 2,
};

struct gfs_inode {
    enum gfs_inode_type type;
    u32 size;
    u32 direct_block;
};

struct gfs_superblock {
    u32 total_blocks;
    u32 used_blocks;
    u32 journal_head;
};

void gfs_init(void);
int gfs_create(const char *name, enum gfs_inode_type type);
int gfs_write(const char *name, const void *data, u32 len);
int gfs_read(const char *name, void *out, u32 len);
int gfs_delete(const char *name);

#endif /* GLOBAL_OS_FS_H */
