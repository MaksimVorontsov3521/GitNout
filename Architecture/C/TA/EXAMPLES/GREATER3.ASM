; Determine the largest value among three multi-digit numbers
; Program to find the greater of 3 numbers taken from user.
; Max 3 digit number is supported

; Author: Lakhya Jyoti Nath aka ljnath
; Email: ljnath@ljnath.com
; https://www.ljnath.com
; Dated: 22nd April 2013

; data segment starts
DATA_SEG    SEGMENT
    COM_MSG     DB  'Program to find the greater of 3 numbers passed as argument',13,10,'$'
    M1          DB  13,10,'Enter 1st number : $'
    M2          DB  13,10,'Enter 2nd number : $'
    M3          DB  13,10,'Enter 3rd number : $'
    M4          DB  13,10,'Greater number is : $'

    NUM1        DW  0   ; variable for storing 1st number
    NUM2        DW  0   ; variable for storing 2nd number
    NUM3        DW  0   ; variable for storing the 3rd number

    FACT        DW  10
    COUNT       DB  0
    TEMP1       DW  0
    TEMP2       DW  0
    SUM_ARR     DW  50  DUP(0) ; Initilizing an array for displaying the multi-digit result
    DATA_SEG    ENDS
; data segment ends


; routine segment starts
; procedure FIND_GREATER
ROUTINE_SEG SEGMENT
 ASSUME CS:ROUTINE_SEG, DS:DATA_SEG
    FIND_GREATER    PROC    FAR

        POP_ADD:
            POP BX              ; poping register address
            POP CX              ; poping register address

            MOV TEMP1, BX
            MOV TEMP2, CX

        ; poping out numbers passed as arguments
        POP_AGR:
            POP AX
            POP BX
            POP CX

        ; comparing for AX
        COMPARE_AX1:
            CMP AX,BX
            JG  COMPARE_AX2

        COMPARE_AX2:
            CMP AX,CX
            JG  RETURN_AX

        ; comparing for BX
        COMPARE_BX1:
            CMP BX,AX
            JG  COMPARE_BX2

        COMPARE_BX2:
            CMP BX,CX
            JG  RETURN_BX

        ; comparing for CX
        COMPARE_CX1:
            CMP CX,AX
            JG  COMPARE_CX2

        COMPARE_CX2:
            CMP CX,BX
            JG  RETURN_CX

        ; pushing the greater
        RETURN_AX:
            PUSH    AX
            JMP RETURN_1

        RETURN_BX:
            PUSH    BX
            JMP RETURN_1

        RETURN_CX:
            PUSH    CX
            JMP RETURN_1

        ; pushing the offset address and returning
        RETURN_1:
            PUSH    TEMP2       ; pushing the register address
            PUSH    TEMP1
            RET

    FIND_GREATER    ENDP
ROUTINE_SEG ENDS


; procedure IP_MULTIDIGIT to take multidigit number input
ROUTINE_SEG SEGMENT
 ASSUME CS:ROUTINE_SEG, DS:DATA_SEG
    IP_MULTIDIGIT   PROC    FAR
        POPING:
            POP BX              ;poping register address
            POP CX              ;poping register address

        REFRESHING:
            MOV TEMP1, BX
            MOV TEMP2, CX
            MOV BX,0
            MOV CX,0

        INPUT:
            MOV     AH,01
            INT     21H
            CMP     AL,13
            JZ      RETURN_2
                                ;converting to multidigit number
            SUB     AL,48
            MOV     BL,AL
            MOV     AX,CX
            MUL     FACT
            ADD     BX,AX
            MOV     CX,BX
            JMP     INPUT

        RETURN_2:
            PUSH    CX
            PUSH    TEMP2
            PUSH    TEMP1

        RETURNING:
            RET
    IP_MULTIDIGIT   ENDP
ROUTINE_SEG ENDS
; end of routine segment


; code segment begins
CODE_SEG SEGMENT
  ASSUME CS:CODE_SEG, DS:DATA_SEG
    START:
        MOV     AX, DATA_SEG
        MOV     DS, AX

        MOV     BX,0        ; refreshing the regiseter values
        MOV     CX,0

        MOV     AH,09
        MOV     DX, OFFSET COM_MSG
        INT     21H

    DIS_MSG1:
        MOV     AH,09
        MOV     DX, OFFSET M1
        INT     21H

    ; calling input procedue to get 1st number from user
    NUM1_IP:
        CALL    IP_MULTIDIGIT
        POP     NUM1

    DIS_MSG2:
        MOV     AH,09
        MOV     DX, OFFSET M2
        INT     21H

    ; calling input procedue to get 2nd number from user
    NUM2_IP:
        CALL    IP_MULTIDIGIT
        POP     NUM2

    DIS_MSG3:
        MOV     AH,09
        MOV     DX, OFFSET M3
        INT     21H

    ; calling input procedue to get 3rd number from user
    NUM3_IP:
        CALL    IP_MULTIDIGIT
        POP     NUM3

    SEND_ARG:
        PUSH    NUM1            ; push 1st number to be sent to the FIND_GREATER procedure
        PUSH    NUM2            ; push 2nd number to be sent to the FIND_GREATER procedure
        PUSH    NUM3            ; push 3rd number to be sent to the FIND_GREATER procedure

        CALL    FIND_GREATER
                                ; refreshing register(s)
        MOV     BX,0
        MOV     CX,0
                                ; poping the result
        POP     CX

    DISPLAY_MSG:
        MOV     AH,09
        MOV     DX, OFFSET M4
        INT     21H

    DISPLAY_SUM:
        MOV     AX, CX
        MOV     BX,10
        MOV     SI, OFFSET SUM_ARR
        MOV     NUM1,SI

    BREAKING_NUM:                   ; break the number digit before displaying
        MOV     DX,0
        DIV     BX
        ADD     DX,48
        MOV     [SI],DX
        INC     SI
        CMP     AX,0
        JZ      JOIN_N_DISPLAY
        JMP     BREAKING_NUM

    JOIN_N_DISPLAY:                 ; join and display
        MOV     DX, [SI]
        MOV     AH,02
        INT     21H
        CMP     NUM1,SI
        JZ      EXIT_PROGRAM
        DEC     SI
        JMP     JOIN_N_DISPLAY

    EXIT_PROGRAM:
        MOV     AH,4CH
        MOV     AL,0
        INT     21H
CODE_SEG    ENDS
    END START
 ; end of code segment