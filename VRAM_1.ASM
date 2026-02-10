.model tiny

.code
	org 100h

_start: mov ax, word ptr [sym]
	or ah, 80h
	mov bx, 3
	mov dx, 2
	mov cl, 5
    mov ch, 1
	call print_symbols

    mov bx, 3
    mov dx, 4
    mov cl, byte ptr [attr]
    or cl, 80h
    lea si, msg
    mov ch, 0
    call print_str
	
	mov ax, 4C00h
	int 21h

; ds:si = string, bx = start column, dx = start row, cl = attr, ch = direction
print_str proc near
	push es

	mov ax, 0B800h
	mov es, ax
	
	mov al, dl
	mov ah, 80
	mul ah
	add ax, bx
	shl ax, 1
	mov di, ax

	cld
	mov ah, cl

    cmp ch, 1
    je prstr_ver_loop

prstr_hor_loop:
    lodsb
    test al, al
    jz prstr_done
    stosw
    jmp prstr_hor_loop

prstr_ver_loop:
    lodsb
    test al, al
    jz prstr_done
    mov word ptr es:[di], ax
    add di, 160
    jmp prstr_ver_loop

prstr_done:
	pop es
	ret
print_str endp

; al = char, ah = attr, bx = start column, dx = start row, cl = amount, ch = direction
print_symbols proc near
	push es
	push di
	push si

	mov si, ax

	mov ax, 0B800h
	mov es, ax

	mov ax, dx
	mov di, 80
	mul di
	add ax, bx
	shl ax, 1
	mov di, ax

	mov ax, si
	cld

    cmp ch, 1
    je prsym_ver

prsym_hor:
    xor ch, ch
	rep stosw
    jmp prsym_done

prsym_ver:
    test cl, cl
    jz prsym_done
prsym_loop:
    mov word ptr es:[di], ax
    add di, 160
    dec cl
    jnz prsym_loop

prsym_done:
	pop si
	pop di
	pop es
	ret
print_symbols endp

.data
sym db 03h
attr db 4eh
msg db 'Hello World!', 0

end _start
