#ifndef GLOBAL_OS_VGA_H
#define GLOBAL_OS_VGA_H

#include "types.h"

#define VGA_WIDTH 80
#define VGA_HEIGHT 25

void vga_init(void);
void vga_write_char(char c);
void vga_write_string(const char *s);

#endif /* GLOBAL_OS_VGA_H */
