LOCALS @@

.model tiny
.code
	org 100h

_start: push cs
	pop  ds

	mov ax, 0B800h
	mov es, ax
	
	mov cl, [attr]
	mov ax, msg_len
	push ax
	lea si, msg
	call print_string_centered
	add sp, 2

	mov ax, 4C00h
	int 21h

COMPUTE_POS macro
	; di = ((frame_top + row) * screen_width + (frame_left + col)) * 2

	; ax = (frame_top + row) * screen_width
	mov al, [screen_height]
	sub al, [frame_height]
	jnc $+4
	xor al, al
	shr al, 1
	add al, dl
	mul byte ptr [screen_width]

	; di = frame_left + col
	push ax
	mov al, [screen_width]
	sub al, [frame_width]
	jnc $+4
	xor al, al
	shr al, 1
	xor ah, ah
	add ax, bx
	mov di, ax
	pop ax
	
	; final byte offset
	add ax, di
	shl ax, 1
	mov di, ax
endm

; Calculates center of screen for string
; Cdecl
; Entry: bp+4 = strlen
; Exit : ax   = vram pos
;	 bx   = start col
;	 dx   = start row
; Destr: ax, cx
calculate_center proc near
	push bp
	mov bp, sp
	
	push si
	push di
	
	mov cx, [bp+4]

	xor ax, ax
	mov al, [frame_width]
	mov si, ax

	xor ax, ax
	mov al, [screen_width]
	cmp si, ax
	jbe @@fw_ok
	mov si, ax
@@fw_ok:
	cmp cx, si
	jbe @@len_ok
	mov cx, si
@@len_ok:
	mov bx, si
	sub bx, cx
	shr bx, 1

	xor ax, ax
	mov al, [frame_height]
	mov di, ax
	
	xor ax, ax
	mov al, [screen_height]

	cmp di, ax
	jbe @@done
	mov di, ax
@@done:
	mov dx, di
	shr dx, 1
	mov ax, di

	pop di
	pop si
	pop bp

	ret
endp

; Prints string centered using provided strlen
; Cdecl
; Entry: ds:si  -> string
;        cl     -> attr
;        [bp+4] = strlen
; Exit :
; Destr: ax, bx, cx, dx, si, di, bp
print_string_centered proc near
	push bp
	mov  bp, sp
	push cx

	mov ax, [bp+4]
	push ax
	call calculate_center
	add sp, 2

	pop cx
	xor ch, ch
	call print_string
	
	pop bp
	ret
endp

; Prints given str to console
; Entry: ds:si -> string to print
;	 bx = start col
;	 dx = start row
;	 cl = attr
; 	 ch = dir (0 = horizaontal, 1 = vertical)
; Exit : 
; Destr: ax, bx, cx, dx, si, di, bp
print_string proc near
	; Check start pos
	xor ax, ax
	mov al, [frame_width]
	cmp bx, ax
	jb @@fw_1
	jmp near ptr @@done
@@fw_1:
	xor ax, ax
	mov al, [frame_height]
	cmp dx, ax
	jb @@fw_2
	jmp near ptr @@done
@@fw_2:
	COMPUTE_POS
	cld

	mov bp, bx
	cmp ch, 1
	jne @@horizontal_entry
	jmp @@vertical_entry
@@horizontal_entry:
@@horizontal:
	lodsb; Load from ds:si to al, inc si
	test al, al
	jnz @@horizontal_nzero
	jmp near ptr @@done
@@horizontal_nzero:
	cmp al, CR
	je @@newline
	cmp al, LF
	je @@newline

	mov ah, cl
	stosw ; es[di += 2] = ax
	inc bx
	
	xor ax, ax
	mov al, [frame_width]
	cmp bx, ax
	jb @@horizontal
@@newline:
	mov bx, bp
	inc dx
	
	xor ax, ax
	mov al, [frame_height]
	cmp dx, ax
	jb @@horizontal_row_ok
	jmp near ptr @@done
@@horizontal_row_ok:
	COMPUTE_POS
	
	jmp @@horizontal

@@vertical_entry:
	mov bp, dx
@@vertical:
	lodsb
	test al, al
	jz @@done
	
	cmp al, CR
	je @@new_column
	cmp al, LF
	je @@new_column

	mov ah, cl
	mov word ptr es:[di], ax
	add di, 160
	inc dx
	
	xor ax, ax
	mov al, [frame_height]
	cmp dx, ax
	jb @@vertical
@@new_column:
	mov dx, bp
	inc bx

	xor ax, ax
	mov al, [frame_width]
	cmp bx, ax
	jae @@done
	
	COMPUTE_POS
	jmp @@vertical
@@done:
	ret
endp 

; Prints X chars to vram
; Entry: al -> char
; 	 ah -> attr
;	 bx =  start col
;	 dx =  start row
;	 cl =  amount
;	 ch =  dir (0 = horizontal, 1 = vertical)
; Exit : 
; Destr: ax, cx, si, di are broke by function 
print_char proc near
	mov si, ax
	
	; pos = (row * 80 + col) * 2
	mov ax, dx
	mov di, 80
	mul di
	add ax, bx
	shl ax, 1
	mov di, ax
	
	mov ax, si
	cld
	cmp ch, 1
	je @@vertical

@@horizontal:
	xor ch, ch
	rep stosw ; while (cx--) { es[di += 2] = ax }
	jmp @@done
@@vertical:
	test cl, cl
	jz @@done
@@loop:
	mov word ptr es:[di], ax
	add di, 160
	dec cl
	jnz @@loop
@@done:
	ret	
endp

.data
CR equ 13
LF equ 10

screen_width  db 80
screen_height db 25

frame_width  db 25
frame_height db 20

chr  db 03h
attr db 1Eh

msg db "Hello Meowwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww!!!", 0
msg_len equ $ - msg - 1

end _start
