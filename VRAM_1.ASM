.model tiny

.code
	org 100h

_start: mov ax, 0B800h
	mov es, ax 				; push B800, pop es
	
	; ax = (row * 80 + col) * 2
	mov ax, [row]
	mov bx, 80
	mul bx					; dx:ax = ax * 80
	add ax, [col]
	shl ax, 1				; ax * 2
	mov bx, ax
	
	mov ax, word ptr [sym]			; AL = sym, AH = attr
	or ah, 80h				; get it blink
	mov word ptr es:[bx], ax
	
	mov ax, 4C00h
	int 21h

.data
col dw 3
row dw 2
;dir dw 0h	; 0 - horizontal line, 1 - vertical line
;cnt dw 1h 	; Amount of symbols
sym db 'A'
attr db 4eh

end _start