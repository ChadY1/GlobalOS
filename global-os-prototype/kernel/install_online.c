#include "../include/install.h"
#include "../include/vga.h"
#include "../include/utils.h"

static void fetch_stub(const char *url) {
    vga_write_string("[net] fetching: ");
    vga_write_string(url);
    vga_write_string("\n");
}

void install_online_run(void) {
    fetch_stub("https://packages.global-os.net/base.tar");
    vga_write_string("[install] online fetch complete (stub)\n");
}
