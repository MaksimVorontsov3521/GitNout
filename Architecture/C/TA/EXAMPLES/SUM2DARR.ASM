; Compute the sum of two multi-digit numbers using a array
; Assembly program to add 2 multi digit number using Array

; Author: Lakhya Jyoti Nath aka ljnath
; Email: ljnath@ljnath.com
; https://www.ljnath.com
; Dated: 18th February 2013


DATA_SEG    SEGMENT
    MSG1    DB  'Program to add 2 multi-digit number using array',13,10,'$'
    MSG2    DB  13,10,'Enter the 1st number: $'
    MSG3    DB  13,10,'Enter the 2nd number: $'
    MSG4    DB  13,10,'The sum of the number is $'
    NUM1    DW  0
    NUM2    DW  0
    MUL_FAC DB  10
    COUNTER DB  0
    ARR_NUM DW  50  DUP(0)
DATA_SEG    ENDS

CODE_SEG    SEGMENT
   ASSUME CS: CODE_SEG, DS:DATA_SEG
    START:  MOV     AX, DATA_SEG
            MOV     DS, AX

    INITIAL_MSG:
            MOV     AH, 09
            MOV     DX, OFFSET MSG1
            INT     21H

    FIRST_MSG:
            MOV     AH, 09
            MOV     DX, OFFSET MSG2
            INT     21H

    GET_1ST_NUM:
            MOV     AH, 01
            INT     21H
            CMP     AL,13
            JZ      SECOND_MSG

    CONVERT_1ST_NUM:
            SUB     AL, 48
            MOV     BL,AL
            MOV     BH,0
            MOV     AX,NUM1
            MUL     MUL_FAC
            ADD     BX,AX
            MOV     NUM1,BX
            JMP     GET_1ST_NUM

    SECOND_MSG:
            MOV     AH, 09
            MOV     DX, OFFSET MSG3
            INT     21H


    GET_2ND_NUM:
            MOV     AH, 01
            INT     21H
            CMP     AL,13
            JZ      ADD_NUMS

    CONVERT_2ND_NUM:
            SUB     AL, 48
            MOV     BL,AL
            MOV     BH,0
            MOV     AX,NUM2
            MUL     MUL_FAC
            ADD     BX,AX
            MOV     NUM2,BX
            JMP     GET_2ND_NUM

    ADD_NUMS:
            MOV     BX, NUM1
            MOV     CX, NUM2
            ADD     CX,BX

            MOV     AH, 09
            MOV     DX, OFFSET MSG4
            INT     21H

    DISPLAYING:
            MOV     AX,CX
            MOV     BX,10
            MOV     DI, OFFSET ARR_NUM
            MOV     NUM1, DI

    BREAKING_NUM:
            MOV     DX,0
            DIV     BX
            ADD     DX,48
            MOV     [DI],DX
            INC     DI
            CMP     AX,0
            JZ      JOIN_N_DISPLAY
            JMP     BREAKING_NUM


    JOIN_N_DISPLAY:
            MOV     DX, [DI]
            MOV     AH,02
            INT     21H
            CMP     NUM1,DI
            JZ      EXIT_PROGRAM
            DEC     DI
            JMP     JOIN_N_DISPLAY

    EXIT_PROGRAM:
            MOV     AH, 4CH
            MOV     AL, 0
            INT     21H

CODE_SEG    ENDS
    END START