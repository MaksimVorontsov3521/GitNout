%include "io.inc"

section .data
    var1   dw 300 
    var2   dw 700 
    result_mem dw 0 

section .text
global main


add_via_memory:
    mov ax, [var1]
    add ax, [var2]
    mov [result_mem], ax
    ret

main:
    call add_via_memory
    
    PRINT_STRING "Result via Memory: "
    PRINT_DEC 2, [result_mem]
    NEWLINE

    xor eax, eax
    ret