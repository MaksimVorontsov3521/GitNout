%include "io.inc"

bits 32

section .data
    iNWords   dd 2
    iNShift   dd 1
    iMas1     dw 0x8234, 0x1234

section .text
global main

main:
    mov ebp, esp

    mov ebx, [iNShift]     

cykl_po_sdwigam:
    mov ecx, [iNWords]     
    
    mov esi, iMas1         
    mov eax, [iNWords]
    shl eax, 1
    add esi, eax

    test word [esi - 2], 0x8000  
    jns cycle_po_slov
    stc 
    jmp do_shift

cycle_po_slov:
    clc

do_shift:
    
shift_loop:
    sub esi, 2
    rcr word [esi], 1
    loop shift_loop

    dec ebx
    jg cykl_po_sdwigam

    mov ecx, [iNWords]
    xor edx, edx
    mov esi, iMas1

zero:
    or dx, [esi]
    add esi, 2
    loop zero

    test dx, 0xFFFF

    NEWLINE
    PRINT_STRING "Aripmetic shift right completed successfully!"
    NEWLINE

    xor eax, eax
    ret