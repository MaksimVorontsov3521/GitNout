DOSSEG
.MODEL TINY
.DATA
    Array DW 100 DUP(0)

    MsgHeader DB 13,10,'=== Izmerenie vremeni ADD (raznye adresacii) ===',13,10,'$'
    MsgEmpty  DB 13,10,'Empty loop (overhead)    : $'
    MsgReg    DB 13,10,'add ax,bx  (register)    : $'
    MsgInd    DB 13,10,'add ax,[bx] (kosv.-reg.) : $'
    MsgBI     DB 13,10,'add ax,[bx+si+5] (b+i+d) : $'
    MsgIndW   DB 13,10,'add [bx],ax (kosv.-reg.) : $'
    MsgTicks  DB ' PIT units',13,10,'$'

    NumBuf       DB 11 DUP(?)
    TempTickLo   DW ?
    TempTickHi   DW ?
    TempPit      DW ?
    StartTicksLo DW ?
    StartTicksHi DW ?
    StartPit     DW ?
    EndTicksLo   DW ?
    EndTicksHi   DW ?
    EndPit       DW ?
    ElapsedLo    DW ?

.CODE
ORG 100h

start:
    mov  dx, OFFSET MsgHeader
    mov  ah, 9
    int  21h

    lea  bx, Array
    mov  si, 0
    xor  ax, ax


; Пустой цикл

    call ReadTime
    mov  [StartTicksLo], dx
    mov  [StartTicksHi], cx
    mov  [StartPit], ax

    xor  cx, cx
    mov  dx, 1000
OuterEmpty:
    mov  cx, 1000
InnerEmpty:
    nop
    nop
    nop
    loop InnerEmpty
    dec  dx
    jnz  OuterEmpty

    call ReadTime
    mov  [EndTicksLo], dx
    mov  [EndTicksHi], cx
    mov  [EndPit], ax

    mov  dx, OFFSET MsgEmpty
    mov  ah, 9
    int  21h
    call CalcDiff
    call PrintNum32
    mov  dx, OFFSET MsgTicks
    mov  ah, 9
    int  21h


; add ax, bx

    call ReadTime
    mov  [StartTicksLo], dx
    mov  [StartTicksHi], cx
    mov  [StartPit], ax

    mov  dx, 1000
OuterReg:
    mov  cx, 1000
InnerReg:
    add  ax, bx
    loop InnerReg
    dec  dx
    jnz  OuterReg

    call ReadTime
    mov  [EndTicksLo], dx
    mov  [EndTicksHi], cx
    mov  [EndPit], ax

    mov  dx, OFFSET MsgReg
    mov  ah, 9
    int  21h
    call CalcDiff
    call PrintNum32
    mov  dx, OFFSET MsgTicks
    mov  ah, 9
    int  21h


; add ax, [bx]

    call ReadTime
    mov  [StartTicksLo], dx
    mov  [StartTicksHi], cx
    mov  [StartPit], ax

    mov  dx, 1000
OuterInd:
    mov  cx, 1000
InnerInd:
    add  ax, [bx]
    loop InnerInd
    dec  dx
    jnz  OuterInd

    call ReadTime
    mov  [EndTicksLo], dx
    mov  [EndTicksHi], cx
    mov  [EndPit], ax

    mov  dx, OFFSET MsgInd
    mov  ah, 9
    int  21h
    call CalcDiff
    call PrintNum32
    mov  dx, OFFSET MsgTicks
    mov  ah, 9
    int  21h


; add ax, [bx+si+5]

    call ReadTime
    mov  [StartTicksLo], dx
    mov  [StartTicksHi], cx
    mov  [StartPit], ax

    mov  dx, 1000
OuterBI:
    mov  cx, 1000
InnerBI:
    add  ax, [bx+si+5]
    loop InnerBI
    dec  dx
    jnz  OuterBI

    call ReadTime
    mov  [EndTicksLo], dx
    mov  [EndTicksHi], cx
    mov  [EndPit], ax

    mov  dx, OFFSET MsgBI
    mov  ah, 9
    int  21h
    call CalcDiff
    call PrintNum32
    mov  dx, OFFSET MsgTicks
    mov  ah, 9
    int  21h


; add [bx], ax

    call ReadTime
    mov  [StartTicksLo], dx
    mov  [StartTicksHi], cx
    mov  [StartPit], ax

    mov  dx, 1000
OuterIndW:
    mov  cx, 1000
InnerIndW:
    add  [bx], ax
    loop InnerIndW
    dec  dx
    jnz  OuterIndW

    call ReadTime
    mov  [EndTicksLo], dx
    mov  [EndTicksHi], cx
    mov  [EndPit], ax

    mov  dx, OFFSET MsgIndW
    mov  ah, 9
    int  21h
    call CalcDiff
    call PrintNum32
    mov  dx, OFFSET MsgTicks
    mov  ah, 9
    int  21h

    mov  ah, 4Ch
    int  21h

ReadTime PROC
    push bx
@retry:
    mov  ah, 0
    int  1Ah
    mov  [TempTickLo], dx
    mov  [TempTickHi], cx

    mov  al, 00h
    out  43h, al
    in   al, 40h
    mov  bl, al
    in   al, 40h
    mov  bh, al

    mov  ax, bx
    xor  ax, 0FFFFh
    mov  [TempPit], ax

    mov  ah, 0
    int  1Ah
    cmp  dx, [TempTickLo]
    jne  @retry
    cmp  cx, [TempTickHi]
    jne  @retry

    mov  dx, [TempTickLo]
    mov  cx, [TempTickHi]
    mov  ax, [TempPit]
    pop  bx
    ret
ReadTime ENDP

CalcDiff PROC
    mov  ax, [EndPit]
    sub  ax, [StartPit]
    mov  [ElapsedLo], ax
    sbb  dx, dx
    neg  dx              

    mov  ax, [EndTicksLo]
    sub  ax, [StartTicksLo]
    mov  bx, ax

    mov  ax, [EndTicksHi]
    sbb  ax, [StartTicksHi]
    mov  cx, ax

    sub  bx, dx
    sbb  cx, 0

    mov  dx, bx
    mov  ax, [ElapsedLo]
    ret
CalcDiff ENDP

Div32_10 PROC
    mov  cx, ax
    mov  ax, dx
    xor  dx, dx
    mov  bx, 10
    div  bx
    push ax
    mov  ax, cx
    div  bx
    mov  bx, dx
    mov  cx, ax
    pop  dx
    mov  ax, cx
    ret
Div32_10 ENDP

PrintNum32 PROC
    push ax
    push bx
    push cx
    push dx
    push si

    lea  si, NumBuf+10
    mov  byte ptr [si], '$'
    dec  si

@loop:
    call Div32_10
    add  bl, '0'
    mov  [si], bl
    dec  si

    mov  cx, ax
    or   cx, dx
    jnz  @loop

    inc  si
    mov  dx, si
    mov  ah, 9
    int  21h

    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret
PrintNum32 ENDP

END start