OUTPUT_FORMAT(elf64-x86-64)
ENTRY(kmain)
SECTIONS
{
    . = 1M;
    .text : {
        *(.text*)
    }
    .rodata : { *(.rodata*) }
    .data : { *(.data*) }
    .bss : { *(.bss*) *(COMMON) }
}
