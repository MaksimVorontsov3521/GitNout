%include "io.inc"

section .data
    array dw 1, 2, 3, 4, 5

section .text
global CMAIN
CMAIN:
    mov ebp, esp

    mov ecx, 10000000
    mov ebx, array
    xor esi, esi
    xor edi, edi

    push ebx
    push ecx
    xor eax, eax
    cpuid
    pop ecx
    pop ebx

    rdtsc
    mov esi, eax

loop_ten:
    mov ax, [ebx]         
    mov [ebx], ax          
    mov dx, cx             
    add bp, 1              
    mov si, [ebx]          
    mov [ebx], si          
    mov di, bx            
                  
    mov ax, [ebx]          
    mov [ebx], ax          
    
    dec ecx
    jnz loop_ten

    rdtsc
    sub eax, esi
    PRINT_STRING "Total cycles: "
    PRINT_UDEC 4, eax
    NEWLINE

    mov edx, 0
    mov ecx, 1000000
    div ecx
    PRINT_STRING "Per iteration: "
    PRINT_UDEC 4, eax
    NEWLINE

    xor eax, eax
    ret