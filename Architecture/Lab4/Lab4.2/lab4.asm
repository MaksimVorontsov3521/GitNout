%include "io.inc"

section .data
    val dw 10
    array dw 1, 2, 3, 4, 5

section .text
global CMAIN
CMAIN:
    mov ebp, esp
    
    mov ax, 5
    
    mov ax, bx          

    mov ebx, array
    mov ax, [ebx]       

    mov ebx, array
    mov ax, [ebx + 2]    

    mov ebx, array
    xor esi, esi
    mov ax, [ebx + esi]   

    mov ax, [ebx + esi + 4] 


    xor eax, eax
    ret