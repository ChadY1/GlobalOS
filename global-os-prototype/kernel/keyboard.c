#include "../include/keyboard.h"
#include "../include/io.h"

#define PS2_DATA 0x60
#define PS2_STATUS 0x64

void keyboard_init(void) {
    /* Enable first PS/2 port */
    outb(PS2_STATUS, 0xAE);
}

char keyboard_read_scancode(void) {
    if (!(inb(PS2_STATUS) & 1)) {
        return 0;
    }
    return (char)inb(PS2_DATA);
}
