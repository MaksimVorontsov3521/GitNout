%include "io.inc"

section .data
    my_data dw 0x1111

section .text
global CMAIN
CMAIN:
    mov ebp, esp

    dw 0x2222

code_data_label:
    mov ax, [my_data]
    PRINT_STRING "From DS: 0x"
    PRINT_HEX 2, ax
    NEWLINE

    mov ax, [cs:code_data_label - 2]
    PRINT_STRING "From CS: 0x"
    PRINT_HEX 2, ax
    NEWLINE

    xor eax, eax
    ret