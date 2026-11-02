%include "io.inc"

section .data
    result_reg dw 0

section .text
global main


add_v_registers:
    add ax, bx       
    ret 

main:
    mov ax, 150 
    mov bx, 250  
    
    call add_v_registers
    
    mov [result_reg], ax 
    
    PRINT_STRING "Result v Registers: "
    PRINT_DEC 2, [result_reg]
    NEWLINE

    xor eax, eax
    ret