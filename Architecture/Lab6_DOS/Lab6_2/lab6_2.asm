MsgHead1.286 
.MODEL TINY

ShowS   MACRO msg
       lea  dx, msg
       mov  ah, 09h
       int  21h
ENDM

ShowC  MACRO
       lea  dx, MsgCr
       mov  ah, 09h
       int  21h
ENDM

.CODE
ORG 100h 

START:

       ShowS MsgTitle

       xor  ax, ax
       mov  es, ax 
       mov  ax, es:[0F0h*4+2]
       mov  OldSeg, ax
       mov  ax, es:[0F0h*4]
       mov  OldOfs, ax

       ShowS MsgIvtRange
       ShowS MsgIvtOld
       mov  ax, OldSeg
       call Phex16
       ShowS MsgSep
       mov  ax, OldOfs
       call Phex16
       ShowC


; 1. Установить новый вектор

       cli
       mov  word ptr es:[0F0h*4],     offset ISR_F0
       mov  word ptr es:[0F0h*4+2],   cs
       sti

       mov  ax, es:[0F0h*4+2]
       mov  NewSeg, ax
       mov  ax, es:[0F0h*4]
       mov  NewOfs, ax

       ShowS MsgIvtNew
       mov  ax, NewSeg
       call Phex16
       ShowS MsgSep
       mov  ax, NewOfs
       call Phex16
       ShowC
       ShowS MsgInstalled
       ShowC


; 2. Параметры ПП -> регистры и память, вызов пп через int
       ShowS MsgHead1

       mov  SpBefore, sp        

       pushf                    
       pop  ax                  
       mov  FlBefore, ax        

       mov  ax, 1234h           
       mov  bx, 0078h           
       lea  si, Array           
       mov  cx, 4               

       int  0F0h                

AfterInt:
       mov  CsExp, cs
       mov  IpExp, offset AfterInt
       pushf
       pop  ax
       mov  FlAfter, ax


; 3. Анализ заполнения стека

       ShowS MsgHead2
       ShowS MsgSpLbl
       mov  ax, SpBefore
       call Phex16
       ShowS MsgArrow
       mov  ax, SpIsr
       call Phex16

       ShowS MsgBytes            
       mov  ax, SpBefore
       sub  ax, SpIsr
       call Pdec16
       ShowS MsgWords
       mov  ax, SpBefore
       sub  ax, SpIsr
       shr  ax, 1
       call Pdec16
       ShowS MsgWordsUnit
       ShowC

       ShowS MsgTblHdr
       ShowS MsgTblIP
       mov  ax, StkIP
       call Phex16
       ShowS MsgCpu
       mov  ax, StkIP
       cmp  ax, IpExp
       jne  L_IpBad
       ShowS MsgEqRet
       ShowC
       jmp  L_IpShow
L_IpBad:
       ShowS MsgNeRet
       ShowC
L_IpShow:

       ShowS MsgTblCS
       mov  ax, StkCS
       call Phex16
       ShowS MsgCpu
       mov  ax, StkCS
       cmp  ax, CsExp
       jne  L_CsBad
       ShowS MsgEqRet
       ShowC
       jmp  L_CsShow
L_CsBad:
       ShowS MsgNeRet
       ShowC
L_CsShow:

       ShowS MsgTblFL
       mov  ax, StkFL
       call Phex16
       ShowS MsgCpu
       ShowS MsgOldFlags
       ShowC

       ShowS MsgBalanced
       mov  ax, sp
       call Phex16              
       cmp  sp, SpBefore        
       jne  L_BalBad
       ShowS MsgEqSp
       ShowC
       jmp  L_BalShow
L_BalBad:
       ShowS MsgNotEq
       ShowC
L_BalShow:


; 4. Результат обработки данных внутри ПП

       ShowS MsgHead3
       ShowS MsgSumLbl
       mov  ax, ResSum
       call Phex16
       ShowC
       ShowS MsgCntLbl
       mov  ax, ResCnt
       call Pdec16
       ShowC
       ShowS MsgReadLbl
       mov  ax, GotAX
       call Phex16
       ShowS MsgComma
       mov  ax, GotBX
       call Phex16
       ShowC
       ShowS MsgEntries
       mov  ax, Entries
       call Pdec16
       ShowC


; 5. Флаги TF и IF: процессор сбрасывает их при входе в GG

       ShowS MsgHead4
       ShowS MsgFlBefore
       mov  ax, FlBefore
       call Pflags
       ShowS MsgFlIsr
       mov  ax, FlIsr
       call Pflags
       ShowS MsgFlAfter
       mov  ax, FlAfter
       call Pflags
       ShowS MsgTfIfNote
       ShowC


; 6. Сравнение с вызовом подпрограммы (call near / call far)

       ShowS MsgHead5

       mov  SpB1, sp
       call NearSub                    

       mov  word ptr [FarPtr],     offset FarSub
       mov  word ptr [FarPtr+2],   cs
       mov  SpB2, sp
       call dword ptr [FarPtr]         

       ShowS MsgRowNear
       mov  ax, SpB1
       sub  ax, SpInNear
       shr  ax, 1
       call Pdec16
       ShowS MsgRowNear2
       mov  ax, NearRetIP
       call Phex16
       ShowC

       ShowS MsgRowInt
       mov  ax, SpBefore
       sub  ax, SpIsr
       shr  ax, 1
       call Pdec16
       ShowS MsgRowInt2
       mov  ax, StkIP
       call Phex16
       ShowS MsgSep
       mov  ax, StkCS
       call Phex16
       ShowS MsgSep
       mov  ax, StkFL
       call Phex16
       ShowC

       ShowS MsgRowFar
       mov  ax, SpB2
       sub  ax, SpInFar
       shr  ax, 1
       call Pdec16
       ShowS MsgRowFar2
       mov  ax, FarRetIP
       call Phex16
       ShowS MsgSep
       mov  ax, FarRetCS
       call Phex16
       ShowC

       ShowS MsgConclusion
       ShowC


; 7. Восстановить старый вектор

       xor  ax, ax
       mov  es, ax
       cli
       mov  ax, OldOfs               
       mov  es:[0F0h*4],   ax         
       mov  ax, OldSeg                
       mov  es:[0F0h*4+2], ax
       sti

       mov  ax, es:[0F0h*4+2]
       mov  ResSeg, ax
       mov  ax, es:[0F0h*4]
       mov  ResOfs, ax

       ShowS MsgRestored
       mov  ax, ResSeg
       call Phex16
       ShowS MsgSep
       mov  ax, ResOfs
       call Phex16
       ShowC


; 8. Разрешённые и запрещённые вектора

       ShowS MsgVecHdr
       ShowS MsgVecList
       ShowS MsgPause
IFNDEF NOWAIT            
       mov  ah, 00h
       int  16h
ENDIF

       mov  ah, 4Ch
       int  21h


ISR_F0 PROC FAR
       mov  GotAX, ax            
       mov  GotBX, bx            
       mov  SpIsr, sp            

       
       mov  bx, sp
       mov  ax, ss:[bx]
       mov  StkIP, ax
       mov  ax, ss:[bx+2]
       mov  StkCS, ax
       mov  ax, ss:[bx+4]
       mov  StkFL, ax

       
       pushf
       pop  ax
       mov  FlIsr, ax

       
       push ax
       push bx
       push cx
       push dx
       push es
       push ds
       push si
       push di
       push bp

       inc  Entries              

       ; --- ОБРАБОТКА ДАННЫХ в ПП ---
       
       mov  ResCnt, cx
       xor  ax, ax
       add  ax, GotAX
       add  ax, GotBX
       mov  bx, cx               
       L_IsrLoop:
       add  ax, [si]
       add  si, 2
       dec  bx
       jnz  L_IsrLoop
       mov  ResSum, ax

       
       pop  bp
       pop  di
       pop  si
       pop  ds
       pop  es
       pop  dx
       pop  cx
       pop  bx
       pop  ax
       iret                      
ISR_F0 ENDP


;  Подпрограммы для сравнения механизмов возврата

NearSub PROC NEAR
       mov  SpInNear, sp         
       push bx                   
       mov  bx, SpInNear         
       mov  ax, ss:[bx]          
       mov  NearRetIP, ax        
       pop  bx
       ret
NearSub ENDP

FarSub  PROC FAR
       mov  SpInFar, sp          
       push bx
       mov  bx, SpInFar
       mov  ax, ss:[bx]          
       mov  FarRetIP, ax
       mov  ax, ss:[bx+2]        
       mov  FarRetCS, ax
       pop  bx
       ret
FarSub  ENDP




Phex16 PROC
       push ax
       push bx
       push cx
       push dx
       mov  cx, 4
L_ph1:
       rol  ax, 4
       push ax
       mov  dl, al
       and  dl, 0Fh
       add  dl, '0'
       cmp  dl, '9'
       jbe  L_ph2
       add  dl, 7
L_ph2:
       mov  ah, 02h
       int  21h
       pop  ax
       loop L_ph1
       pop  dx
       pop  cx
       pop  bx
       pop  ax
       ret
Phex16 ENDP




Pdec16 PROC
       push bx
       push cx
       push dx
       push si
       mov  bx, offset DecBuf + 6
       mov  byte ptr [bx], '$'
       mov  si, 10
L_pd1:
       xor  dx, dx
       div  si
       add  dl, '0'
       dec  bx
       mov  [bx], dl
       test ax, ax
       jnz  L_pd1
       lea  dx, [bx]
       mov  ah, 09h
       int  21h
       pop  si
       pop  dx
       pop  cx
       pop  bx
       ret
Pdec16 ENDP




Pflags PROC     
       push bx
       push cx
       call Phex16               
       mov  bx, ax               
       ShowS MsgNCF
       mov  ax, bx
       and  ax, 1                
       call Pdec16
       ShowS MsgNPF
       mov  ax, bx
       shr  ax, 1
       shr  ax, 1                
       and  ax, 1
       call Pdec16
       ShowS MsgNAF
       mov  ax, bx
       shr  ax, 4                
       and  ax, 1
       call Pdec16
       ShowS MsgNZF
       mov  ax, bx
       shr  ax, 6                
       and  ax, 1
       call Pdec16
       ShowS MsgNSF
       mov  ax, bx
       shr  ax, 7                
       and  ax, 1
       call Pdec16
       ShowS MsgNTF
       mov  ax, bx
       shr  ax, 8                
       and  ax, 1
       call Pdec16
       ShowS MsgNIF
       mov  ax, bx
       shr  ax, 9                
       and  ax, 1
       call Pdec16
       ShowS MsgBrkC
       pop  cx
       pop  bx
       ret
Pflags ENDP




.DATA
Array       DW  1000h, 2000h, 0003h, 0004h

SpBefore    DW  ?
SpIsr       DW  ?
StkIP       DW  ?
StkCS       DW  ?
StkFL       DW  ?
FlBefore    DW  ?
FlIsr       DW  ?
FlAfter     DW  ?
CsExp       DW  ?
IpExp       DW  ?

OldOfs      DW  ?
OldSeg      DW  ?
NewOfs      DW  ?
NewSeg      DW  ?
ResOfs      DW  ?
ResSeg      DW  ?

GotAX       DW  ?
GotBX       DW  ?
ResSum      DW  ?
ResCnt      DW  ?
Entries     DW  0

SpB1        DW  ?
SpInNear    DW  ?
SpB2        DW  ?
SpInFar     DW  ?
NearRetIP   DW  ?
FarRetIP    DW  ?
FarRetCS    DW  ?
FarPtr      DD  ?
DecBuf      DB  7 DUP(?)

MsgCr       DB  13,10,'$'
MsgSep      DB  ':$'
MsgComma    DB  ', BX=$'
MsgArrow    DB  '  ->  $'
MsgBytes    DB  '  = $'
MsgWords    DB  '  = $'
MsgWordsUnit DB ' words of stack$'
MsgCpu      DB  '   <- pushed by THE PROCESSOR$'
MsgEqRet    DB  '  = return address (ok)$'
MsgNeRet    DB  '  <> return address (!)$'
MsgEqSp     DB  '  = SP before INT: stack balanced$'
MsgNotEq    DB  '  <> SP before INT: LEAK!$'
MsgOldFlags DB  '   (old flags, saved before the interrupt)$'
MsgNCF      DB  '  CF=$'
MsgNPF      DB  ' PF=$'
MsgNAF      DB  ' AF=$'
MsgNZF      DB  ' ZF=$'
MsgNSF      DB  ' SF=$'
MsgNTF      DB  ' TF=$'
MsgNIF      DB  ' IF=$'
MsgBrkC     DB  '   (bits 0,2,4,6,7,8,9)$'

MsgTitle    DB  13,10,'=== Lab6 step 2 (ASM): stack fill of a software interrupt ===',13,10,'$'
MsgIvtRange DB  'IVT: 256 vectors x 4 bytes = 0000:0000..0000:03FF (first 1 KB)',13,10,'$'
MsgIvtOld   DB  '  vector 0F0h, old = $'
MsgIvtNew   DB  '  vector 0F0h, new = $'
MsgInstalled DB '  new vector installed by direct IVT write under CLI/STI$'

MsgHead1    DB  13,10,'--- 1) INT 0F0h as a subroutine call: params in AX,BX,CX,SI ---',13,10,'$'
MsgHead2    DB  13,10,'--- 2) STACK FILL at the handler entry ---',13,10,'$'
MsgSpLbl    DB  '  SP before INT = $'
MsgTblHdr   DB  13,10,'  frame contents:',13,10,'$'
MsgTblIP    DB  '    [SP+0] IP    = $'
MsgTblCS    DB  '    [SP+2] CS    = $'
MsgTblFL    DB  '    [SP+4] FLAGS = $'
MsgBalanced DB  13,10,'  SP after IRET  = $'

MsgHead3    DB  13,10,'--- 3) data processed INSIDE the handler (PP) ---',13,10,'$'
MsgSumLbl   DB  '  SUM(array + AX + BX) = $'
MsgCntLbl   DB  '  array elements       = $'
MsgReadLbl  DB  '  handler really read: AX=$'
MsgEntries  DB  '  entries into PP      = $'

MsgHead4    DB  13,10,'--- 4) TF and IF are cleared by the CPU at the interrupt ---',13,10,'$'
MsgFlBefore DB  '  FLAGS before INT : $'
MsgFlIsr    DB  13,10,'  FLAGS inside PP  : $'
MsgFlAfter  DB  13,10,'  FLAGS after IRET : $'
MsgTfIfNote DB  13,10,'  expected: TF=0 and IF=0 INSIDE the PP, restored after IRET$'

MsgHead5    DB  13,10,'--- 5) CALL vs INT: words added to the stack ---',13,10,'$'
MsgRowNear  DB  '    CALL NEAR -> words = $'
MsgRowNear2 DB  '   (IP only), saved return IP = $'
MsgRowInt   DB  '    INT  0F0h -> words = $'
MsgRowInt2  DB  '   (IP, CS, FLAGS) = $'
MsgRowFar   DB  '    CALL FAR  -> words = $'
MsgRowFar2  DB  '   (IP, CS; FLAGS NOT saved) = $'
MsgConclusion DB '  Conclusion: an interrupt is an INDIRECT far transfer through a',13,10,'  IVT vector, and it saves FLAGS as well - therefore the handler returns',13,10,'  with IRET (3 words), not RET (1..2 words).',13,10,'$'

MsgRestored DB  '  vector 0F0h restored = $'
MsgVecHdr   DB  13,10,'--- 6) allowed / forbidden vectors ---',13,10,'$'
MsgVecList  DB  '    00h..07h  CPU exceptions        - forbidden for an app',13,10
            DB  '    08h..0Fh  hardware IRQ (8259)   - reserved',13,10
            DB  '    10h..1Ah  BIOS                  - reserved',13,10
            DB  '    20h..3Fh  DOS                   - reserved',13,10
            DB  '    40h..6Fh  DOS/BIOS tables       - reserved',13,10
            DB  '    70h..77h  IRQ (second 8259)     - reserved',13,10
            DB  '    78h..B7h  local / user          - ALLOWED',13,10
            DB  '    B8h..FFh  user-definable        - ALLOWED (we used 0F0h)',13,10,'$'
MsgPause    DB  13,10,'>>> Press any key to finish... $'

END START
