LOCALS @@

PUSH_REGS macro
	push ax bx cx dx ds es di si bp
endm

POP_REGS macro
	pop bp si di es ds dx cx bx ax
endm

GET_VEC macro INTNO, DEST
	mov ax, 3500h + INTNO
	int 21h
	mov word ptr cs:DEST, bx
	mov word ptr cs:DEST+2, es
endm

SET_VEC macro INTNO, HANDLER
	xor ax, ax
	mov es, ax
	mov bx, 4 * INTNO
	cli
	mov es:[bx], offset HANDLER
	mov ax, cs
	mov es:[bx+2], ax
	sti
endm

.model tiny
.code
	org 100h

_start: push cs
	pop ds

	GET_VEC 08h, old_vec_timer
	GET_VEC 09h, old_vec_keyboard

	SET_VEC 08h, TimerIRQ
	SET_VEC 09h, RegIRQ

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
	call dword ptr cs:old_vec_keyboard
	
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
	call SaveFrame
	call DrawFrame
	jmp short @@done

@@erase:
	call RestoreFrame

@@done:
	POP_REGS
	iret
endp

TimerIRQ proc far
	PUSH_REGS

	pushf
	call dword ptr cs:old_vec_timer

	cmp cs:show_flag, 0
	je @@done

	call SyncFrameTick

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

CALCPOS macro DST16, X8, Y8
	mov al, Y8
	xor ah, ah
	mov bl, 80
	mul bl
	mov bl, X8
	xor bh, bh
	add ax, bx
	shl ax, 1
	mov DST16, ax
endm

LOADW macro DST16, SRC8
	mov al, SRC8
	xor ah, ah
	mov DST16, ax
endm

ROWSKIP macro DST16, WIDTH16
	mov ax, 80
	sub ax, WIDTH16
	shl ax, 1
	mov DST16, ax
endm

PUTC macro CH
	mov al, CH
	mov ah, bh
	stosw
endm

PUTSPACES macro CNT
	mov al, ' '
	mov ah, bh
	mov cx, CNT
	rep stosw
endm

SaveFrame proc near
	PUSH_REGS
	cld

	push cs
	pop es
	mov di, offset save_buf

	mov ax, 0B800h
	mov ds, ax

	CALCPOS si, cs:frame_x, cs:frame_y
	LOADW bp, cs:frame_width
	LOADW cx, cs:frame_height
	ROWSKIP dx, bp

@@row:
	push cx
	mov cx, bp
	rep movsw
	add si, dx
	pop cx
	loop @@row	

	POP_REGS
	ret
endp

SyncFrameTick proc near
	PUSH_REGS

	push cs
	pop ds
	
	mov ax, 0B800h
	mov es, ax
	
	CALCPOS di, frame_x, frame_y
	LOADW bp, cs:frame_width
	LOADW cx, cs:frame_height
	ROWSKIP dx, bp

	mov si, offset draw_buf
	mov bx, offset save_buf
	
@@r:
	push cx
	mov cx, bp
@@c:
	mov ax, es:[di]
	cmp ax, [si]
	je @@ok
	mov [bx], ax
	mov ax, [si]
	mov es:[di], ax
@@ok:
	add di, 2
	add si, 2
	add bx, 2
	loop @@c

	add di, dx
	pop cx
	loop @@r

	POP_REGS
	ret
endp

RestoreFrame proc near
	PUSH_REGS

	cld
	push cs
	pop ds
	mov si, offset save_buf

	mov ax, 0B800h
	mov es, ax
	CALCPOS di, cs:frame_x, cs:frame_y
	LOADW bp, cs:frame_width
	LOADW cx, cs:frame_height
	ROWSKIP dx, bp

@@row:
	push cx
	mov cx, bp	
	rep movsw
	add di, dx
	pop cx
	loop @@row

	POP_REGS
	ret
endp

DrawFrame proc near
	PUSH_REGS

	cld
	push cs
	pop ds

	LOADW ax, cs:frame_width
	cmp al, 2
	jae @@cont1
	jmp near ptr @@done

@@cont1:
	LOADW ax, cs:frame_height
	cmp al, 2
	jae @@cont2
	jmp near ptr @@done

@@cont2:
	LOADW cx, cs:frame_width
	mov dl, al
	sub dl, 2
	
	LOADW ax, cs:frame_height
	sub ax, 2
	mov bp, ax

	mov al, frame_border_bg_color
	shl al, 4
	or al, frame_border_color
	mov bl, al
	
	mov al, frame_bg_color
	shl al, 4
	or al, frame_color
	mov bh, al

	push ds
	pop es
	mov di, offset draw_buf

@@top_line_draw:
	PUTCHR 0
	REPCHR8 1, dl
	PUTCHR 2

@@middle_lines_draw:
	or bp, bp
	jz @@bottom_line_draw

	PUTCHR 7
	REPCHR8 8, dl
	PUTCHR 3

	dec bp
	jmp @@middle_lines_draw

@@bottom_line_draw:
	PUTCHR 6
	REPCHR8 5, dl
	PUTCHR 4

	mov ax, 0B800h
	mov es, ax
	
	CALCPOS di, frame_x, frame_y
	LOADW bp, cs:frame_width
	LOADW cx, cs:frame_height
	ROWSKIP dx, bp

	mov si, offset draw_buf

@@blit_row:
	push cx
	mov cx, bp
	rep movsw
	add di, dx
	pop cx
	loop @@blit_row

@@done:
	POP_REGS
	ret
endp

.data
old_vec_keyboard dd 0
old_vec_timer    dd 0

show_flag db 0

frame_x db 1d
frame_y db 1d
FRAME_W equ 15
FRAME_H equ 15
frame_width  db FRAME_W
frame_height db FRAME_H

frame_border db "12345678 " ; border starts at top left, clock wise. Last - background

frame_bg_color        db 2h
frame_color           db 3h
frame_border_bg_color db 4h
frame_border_color    db 5h

draw_buf dw FRAME_W * FRAME_H dup(?)
save_buf dw FRAME_W * FRAME_H dup(?)

EOF:
end _start
