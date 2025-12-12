#include "../include/vga.h"
#include "../include/utils.h"

static volatile u16 *vga_buffer = (u16 *)0xB8000;
static u8 cursor_row = 0;
static u8 cursor_col = 0;

static void put_entry(char c, u8 color) {
    const size_t index = cursor_row * VGA_WIDTH + cursor_col;
    vga_buffer[index] = ((u16)color << 8) | (u8)c;
}

void vga_init(void) {
    cursor_row = 0;
    cursor_col = 0;
    for (size_t y = 0; y < VGA_HEIGHT; y++) {
        for (size_t x = 0; x < VGA_WIDTH; x++) {
            vga_buffer[y * VGA_WIDTH + x] = 0x0720;
        }
    }
}

void vga_write_char(char c) {
    if (c == '\n') {
        cursor_row++;
        cursor_col = 0;
        return;
    }
    put_entry(c, 0x07);
    cursor_col++;
    if (cursor_col >= VGA_WIDTH) {
        cursor_col = 0;
        cursor_row++;
    }
    if (cursor_row >= VGA_HEIGHT) {
        cursor_row = 0;
    }
}

void vga_write_string(const char *s) {
    while (*s) {
        vga_write_char(*s++);
    }
}
