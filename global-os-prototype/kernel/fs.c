#include "../include/fs.h"
#include "../include/utils.h"
#include "../include/vga.h"

static struct gfs_superblock super;
static struct gfs_inode inodes[GFS_MAX_FILES];
static u8 blocks[GFS_MAX_BLOCKS][GFS_BLOCK_SIZE];
static u8 block_bitmap[GFS_MAX_BLOCKS];

static int find_free_inode(void) {
    for (int i = 0; i < GFS_MAX_FILES; i++) {
        if (inodes[i].type == GFS_INODE_FREE) return i;
    }
    return -1;
}

static int find_block(void) {
    for (int i = 0; i < GFS_MAX_BLOCKS; i++) {
        if (!block_bitmap[i]) {
            block_bitmap[i] = 1;
            super.used_blocks++;
            return i;
        }
    }
    return -1;
}

static int find_inode_by_name(const char *name) {
    for (int i = 0; i < GFS_MAX_FILES; i++) {
        if (inodes[i].type != GFS_INODE_FREE && strcmp(name, (char *)blocks[i]) == 0) {
            return i;
        }
    }
    return -1;
}

void gfs_init(void) {
    memset(&super, 0, sizeof(super));
    super.total_blocks = GFS_MAX_BLOCKS;
    memset(inodes, 0, sizeof(inodes));
    memset(block_bitmap, 0, sizeof(block_bitmap));
}

int gfs_create(const char *name, enum gfs_inode_type type) {
    int idx = find_inode_by_name(name);
    if (idx >= 0) return -1;
    idx = find_free_inode();
    if (idx < 0) return -1;
    int block = find_block();
    if (block < 0) return -1;
    inodes[idx].type = type;
    inodes[idx].size = 0;
    inodes[idx].direct_block = block;
    memcpy(blocks[idx], name, strlen(name) + 1);
    return idx;
}

int gfs_write(const char *name, const void *data, u32 len) {
    int idx = find_inode_by_name(name);
    if (idx < 0) return -1;
    if (len > GFS_BLOCK_SIZE) len = GFS_BLOCK_SIZE;
    memcpy(blocks[inodes[idx].direct_block], data, len);
    inodes[idx].size = len;
    return 0;
}

int gfs_read(const char *name, void *out, u32 len) {
    int idx = find_inode_by_name(name);
    if (idx < 0) return -1;
    if (len > inodes[idx].size) len = inodes[idx].size;
    memcpy(out, blocks[inodes[idx].direct_block], len);
    return len;
}

int gfs_delete(const char *name) {
    int idx = find_inode_by_name(name);
    if (idx < 0) return -1;
    block_bitmap[inodes[idx].direct_block] = 0;
    super.used_blocks--;
    memset(&inodes[idx], 0, sizeof(inodes[idx]));
    return 0;
}
