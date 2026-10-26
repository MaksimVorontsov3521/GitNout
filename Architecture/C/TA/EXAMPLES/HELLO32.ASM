; Hello, World!
; Simple Hello World program in assembly language to be executed in Turbo 32-bit mode

.386
.model flat
        extrn ExitProcess:proc
        extrn MessageBoxA:proc
.data
        msg_title   DB "GUI Turbo Assembler",0
        msg_message DB "Hello World!",0
.code

start:
        push 0
        push offset msg_title
        push offset msg_message
        
        push 0
        call MessageBoxA

        push 0
        call ExitProcess
end start