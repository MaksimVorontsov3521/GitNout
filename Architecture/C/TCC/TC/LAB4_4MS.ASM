	ifndef	??version
?debug	macro
	endm
	endif
	?debug	S "d:\lab4_4ms.c"
_TEXT	segment	byte public 'CODE'
DGROUP	group	_DATA,_BSS
	assume	cs:_TEXT,ds:DGROUP,ss:DGROUP
_TEXT	ends
_DATA	segment word public 'DATA'
d@	label	byte
d@w	label	word
_DATA	ends
_BSS	segment word public 'BSS'
b@	label	byte
b@w	label	word
	?debug	C E90D8C655D0D643A5C6C6162345F346D732E63
	?debug	C E9A5315E5D15433A5C54435C494E434C5544455C737464696F2E68
	?debug	C E9A5315E5D15433A5C54435C494E434C5544455C5F646566732E68
	?debug	C E9A5315E5D15433A5C54435C494E434C5544455C5F6E756C6C2E68
	?debug	C E9A5315E5D15433A5C54435C494E434C5544455C636F6E696F2E68
_BSS	ends
_DATA	segment word public 'DATA'
_A	label	word
	dw	0
	dw	1
	dw	2
	dw	3
	dw	4
	dw	5
	dw	6
	dw	7
	dw	8
	dw	9
	db	160 dup (0)
_DATA	ends
_TEXT	segment	byte public 'CODE'
;	?debug	L 7
_main	proc	near
	push	si
	push	di
;	?debug	L 10
  	mov	 si, 0
;	?debug	L 11
  	mov	 di, 0
@2:
;	?debug	L 13
  	lea	 bx, DGROUP:_A
;	?debug	L 14
  	add	 bx, si
;	?debug	L 15
  	mov	 cx, 5
@3:
;	?debug	L 17
  	mov	 [bx], di
;	?debug	L 18
  	add	 bx, 2
;	?debug	L 19
  	inc	 di
;	?debug	L 20
  	loop	 @3
;	?debug	L 21
  	add	 si, 10
;	?debug	L 22
  	mov	 ax, 100
;	?debug	L 23
  	cmp	 ax, si
;	?debug	L 24
  	ja	  @2
;	?debug	L 26
	mov	word ptr DGROUP:_i,0
	jmp	short @7
@6:
;	?debug	L 28
	mov	ax,offset DGROUP:s@
	push	ax
	call	near ptr _printf
	pop	cx
;	?debug	L 29
	mov	word ptr DGROUP:_j,0
	jmp	short @11
@10:
;	?debug	L 30
	mov	bx,word ptr DGROUP:_i
	add	bx,word ptr DGROUP:_j
	shl	bx,1
	push	word ptr DGROUP:_A[bx]
	mov	ax,offset DGROUP:s@+2
	push	ax
	call	near ptr _printf
	pop	cx
	pop	cx
@9:
	inc	word ptr DGROUP:_j
@11:
	cmp	word ptr DGROUP:_j,5
	jl	@10
@8:
@5:
	mov	ax,word ptr DGROUP:_i
	add	ax,5
	mov	word ptr DGROUP:_i,ax
@7:
	cmp	word ptr DGROUP:_i,50
	jl	@6
@4:
;	?debug	L 32
	mov	ax,offset DGROUP:s@+6
	push	ax
	call	near ptr _printf
	pop	cx
;	?debug	L 33
	call	near ptr _getch
@1:
;	?debug	L 34
	pop	di
	pop	si
	ret	
_main	endp
_TEXT	ends
_BSS	segment word public 'BSS'
_i	label	word
	db	2 dup (?)
_j	label	word
	db	2 dup (?)
_BSS	ends
	?debug	C E9
_DATA	segment word public 'DATA'
s@	label	byte
	db	10
	db	0
	db	37
	db	54
	db	100
	db	0
	db	10
	db	80
	db	114
	db	101
	db	115
	db	115
	db	32
	db	97
	db	110
	db	121
	db	32
	db	107
	db	101
	db	121
	db	46
	db	46
	db	46
	db	0
_DATA	ends
_TEXT	segment	byte public 'CODE'
	extrn	_printf:near
	extrn	_getch:near
_TEXT	ends
	public	_main
	public	_j
	public	_i
	public	_A
	end
