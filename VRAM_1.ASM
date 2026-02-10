.model tiny

.code
	org 100h

_start: mov dx, word ptr [sym]
	or dh, 80h
	mov bx, 3
	mov cx, 2
	call print_symbol
	
	mov ax, 4C00h
	int 21h

; dl = symbol, dh = attr, bx = column, cx = row
print_symbol proc near
	push es

	mov ax, 0B800h
	mov es, ax
	
	mov ax, 80
	mul byte ptr cl
	add ax, bx
	shl ax, 1
	mov bx, ax

	mov word ptr es:[bx], dx

	pop es
	ret
print_symbol endp

.data
col dw 3
row dw 2
;dir dw 0h	; 0 - horizontal line, 1 - vertical line
;cnt dw 1h 	; Amount of symbols
sym db 03h
attr db 4eh

end _start
