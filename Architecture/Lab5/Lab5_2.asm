%include "io.inc"

section .data
    param1 dd 100
    param2 dd 200
    res    dd 0

section .text
global main

calc_sum:
    push ebp
    mov ebp, esp

    mov eax, [ebp + 8]
    add eax, [ebp + 12]

    mov esp, ebp
    pop ebp
    ret

main:
    mov ebp, esp

    push dword [param2]
    push dword [param1]
    
    call calc_sum
    add esp, 8

    mov [res], eax

    PRINT_STRING "Result: "
    PRINT_DEC 4, [res]
    NEWLINE

    xor eax, eax
    ret