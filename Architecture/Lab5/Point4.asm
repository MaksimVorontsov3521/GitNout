%include "io.inc"

bits 32

section .text
global main

subroutine_with_enter_leave:
    enter 4, 0 

    mov word [ebp - 2], 500  

    mov ax, [ebp - 2]        
    add ax, 100              

    leave 
    ret                      

main:
    mov ebp, esp              

    call subroutine_with_enter_leave

    PRINT_STRING "Result of calculation using enter/leave: "
    PRINT_DEC 2, ax
    NEWLINE

    xor eax, eax
    ret