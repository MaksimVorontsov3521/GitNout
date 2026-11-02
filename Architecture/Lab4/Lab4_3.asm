%include "io.inc"

section .data
    matrix dw 0,0,0,0
           dw 0,0,0,0
           dw 0,0,0,0
           dw 0,0,0,0

    ROWS equ 4
    COLS equ 4
    ROW_BYTES equ 8

section .text
global CMAIN
CMAIN:
    mov ebp, esp

    mov ebx, matrix
    mov edx, 0

row_loop:
    mov eax, edx
    and eax, 1
    jnz next_row

    xor esi, esi

col_loop:
    mov [ebx + esi], word 777
    add esi, 2
    cmp esi, ROW_BYTES
    jl col_loop

next_row:
    add ebx, ROW_BYTES
    inc edx
    cmp edx, ROWS
    jl row_loop


   
    NEWLINE
    PRINT_STRING "--- Matrix ---"
    NEWLINE

    mov ebx, matrix
    mov ecx, 16
    xor esi, esi
    mov dl, 4

print_loop:
    PRINT_UDEC 2, [ebx + esi]
    PRINT_STRING " "

    add esi, 2          
    
    dec dl
    jnz continue_print
    NEWLINE
    mov dl, 4           

continue_print:
    dec ecx            
    jnz print_loop      

    xor eax, eax
    ret