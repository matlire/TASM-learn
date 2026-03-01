LOCALS @@
.model tiny
.code
	org 100h

_start: mov ax, 3509h
	int 21h
	mov Oldofs, bx
	mov bx, es
	mov Oldseg, bx

	xor ax, ax
	mov es, ax
	mov bx, 4*09h
	
	cli
	mov es:[bx], offset RegisterIRQ
	mov ax, cs
	mov es:[bx+2], ax
	sti

	mov ax, 3100h
	mov dx, offset EOF
	shr dx, 4
	inc dx
	int 21h	

	mov ax, 4C00h
	int 21h

RegisterIRQ proc far
	push ax bx cx ds es
	
	mov ax, 0B800h
	mov es, ax
	mov bx, (80d * 5 + 40d) * 2
	
	in al, 60h
	mov es:[bx], ax
	in al, 61h
	or al, 80h
	out 61h, al
	and al, not 80h
	out 61h, al
	mov al, 20h
	out 20h, al

	pop es ds cx bx ax
	db 0eah
	
	Oldofs dw 0
	Oldseg dw 0

	iret
endp

.data
show_flag db 0

EOF:
end _start
