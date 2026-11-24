DOSSEG
.MODEL TINY
.DATA
    
    Array DW 10, 20, 30, 40, 50, 60, 70, 80

.CODE
ORG 100h

start:

; 1 регистровая адресация
    mov  ax, 100h       
    mov  bx, 00FFh
    add  ax, bx         
                        

; 2 косвенно-регистровая адресация
    lea  bx, Array      
    add  ax, [bx]       
                        
; 3 базовая (индексная) адресация
    add  ax, [bx+4]     
                        

; 4 базово-индексная адресация
    mov  si, 6          
    add  ax, [bx+si]    
                        
; 5 базово-индексная адресация со смещением
    add  ax, [bx+si+2]  
                        

    mov  ah, 4Ch
    int  21h

END start