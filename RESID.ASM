LOCALS @@

PUSH_REGS macro
	push ax bx cx dx ds es di si bp
endm

POP_REGS macro
	pop bp si di es ds dx cx bx ax
endm

.model tiny
.code
	org 100h

_start: push cs
	pop ds
	mov ax, 3509h
	int 21h

	mov word ptr cs:old_vec, bx
	mov word ptr cs:old_vec+2, es

	xor ax, ax
	mov es, ax
	mov bx, 4*09h
	
	cli
	mov es:[bx], offset RegIRQ
	mov ax, cs
	mov es:[bx+2], ax
	sti

	mov ax, 3100h
	mov dx, offset EOF
	add dx, 0Fh
	shr dx, 4
	inc dx
	int 21h	

	mov ax, 4C00h
	int 21h

RegIRQ proc far
	PUSH_REGS
	
	mov ax, 0040h
	mov ds, ax
	mov bx, 001Ch
	mov dx, [bx]

	pushf
	call dword ptr cs:old_vec
	
	mov ax, 0040h
	mov ds, ax
	mov bx, 001Ch
	
	cmp dx, [bx]
	je @@done

	mov si, [bx]
	sub si, 2
	cmp si, 001Eh
	jae @@ok
	add si, 32

@@ok:
	mov ax, [si]
	cmp ax, 5400h
	jne @@done

	xor cs:show_flag, 1

	mov ax, 0B800h
	mov es, ax
	mov bx, (80d * 5 + 40d) * 2

	cmp cs:show_flag, 0
	je @@erase
	
	mov ax, 072Ah
	call DrawFrame
	jmp short @@done

@@erase:
	mov ax, 0720h
	mov es:[bx], ax

@@done:
	POP_REGS
	iret
endp

SETCHR macro OFFSET
	mov al, byte ptr frame_border + OFFSET
	IF OFFSET EQ 8
		mov ah, bh
	ELSE
		mov ah, bl
	ENDIF
endm

PUTCHR macro OFFSET
	SETCHR OFFSET
	stosw
endm

REPCHR8 macro OFFSET, CNT8
	SETCHR OFFSET
	xor ch, ch
	mov cl, CNT8
	rep stosw
endm

REPCHRCX macro OFFSET
	SETCHR OFFSET
	stosw
endm

DrawFrame proc near
	PUSH_REGS

	cld
	push cs
	pop ds

	mov al, frame_width
	cmp al, 2
	jae @@cont1
	jmp near ptr @@done

@@cont1:
	mov al, frame_height
	cmp al, 2
	jae @@cont2
	jmp near ptr @@done

@@cont2:
	mov ax, 0B800h
	mov es, ax
	
	; di = (frame_y * 80 + frame_x) * 2
	mov al, frame_y
	xor ah, ah
	mov bl, 80
	mul bl
	mov bl, frame_x
	xor bh, bh
	add ax, bx
	shl ax, 1
	mov di, ax

	; cx = width, dl = inner width
	mov al, frame_width
	xor ah, ah
	mov cx, ax
	mov dl, al
	sub dl, 2

	; bp = inner height
	mov al, frame_height
	xor ah, ah
	sub al, 2
	mov bp, ax

	; si = row skip = (80 - width) * 2
	mov ax, 80
	sub ax, cx
	shl ax, 1
	mov si, ax

	; bl = border attribute, bh = fill attribute
	mov al, frame_border_bg_color
	shl al, 4
	or al, frame_border_color
	mov bl, al

	mov al, frame_color
	shl al, 4
	or al, frame_bg_color
	mov bh, al

@@top_line_draw:
	PUTCHR 0
	REPCHR8 1, dl
	PUTCHR 2

	add di, si

@@middle_lines_draw:
	or bp, bp
	jz @@bottom_line_draw

	PUTCHR 7
	REPCHR8 8, dl
	PUTCHR 3

	add di, si
	dec bp
	jmp @@middle_lines_draw

@@bottom_line_draw:
	PUTCHR 6
	REPCHR8 5, dl
	PUTCHR 4

@@done:
	POP_REGS
	ret
endp

.data
old_vec   dd 0
show_flag db 0

frame_x db 1d
frame_y db 1d
frame_width  db 10d
frame_height db 7d

frame_border db "123456789" ; border starts at top left, clock wise. Last - background

frame_bg_color        db 2h
frame_color           db 3h
frame_border_bg_color db 4h
frame_border_color    db 5h

EOF:
end _start
