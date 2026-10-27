DOSSEG
.MODEL TINY
.DATA
Message DB 13,10,'Hi Привет! ',13,10,'$'
.CODE
ORG 100h

start:

    mov ah,9
    mov dx,OFFSET Message
    int 21h

    mov ah,4ch
    int 21h
END start