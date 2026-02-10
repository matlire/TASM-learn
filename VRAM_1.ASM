; Push registers on stack macro (for procs)
PUSH_REGS MACRO
	push ax
	push bx
	push cx
	push dx
	push di
	push si
	push es
ENDM

; Pop registers from stack macro (for procs)
POP_REGS MACRO
	pop es
	pop si
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
ENDM

.model tiny					; Tiny memory model

.code
	org 100h				; Skip Program Segment Prefix

_start: mov ax, 0B800h				; Save vram address to es
	mov es, ax

   	xor bx, bx				; set bx to 0
	mov bl, byte ptr ds:[80h]		; Save cmd len to bl
	mov byte ptr [81h+bx], 0		; Set CR in cmd in PSP to 0

	call parse_args

	mov si, [str_ptr]			; Save string pointer to source index
	call strlen
	mov [str_len], ax			; Save strlen (strlen saves to ax)

	mov bp, [opt_rep]			; Save (optional) repeat to bp
	or bp, bp				; While repeat != 0
	jnz prmk
	mov bp, 1				; Do at least 1 time

prmk:						; Print main ok
	mov bx, [start_col]			; Save column and row to bx and dx accordingly
	mov dx, [start_row]
prmrp:						; Print main repeat
	mov si, [str_ptr]			; Save parameters to registers for print_str
	mov cl, [opt_attr]
	mov ch, [opt_dir]

	call print_str

	cmp byte ptr [opt_dir], 0		; If (vertical) { repeat vertical } Else { repeat horizontal }
	jne prmrpvrt
	add bx, [str_len]
	jmp prmrphrz

prmrpvrt:					; Print main repeat vertical
	add dx, [str_len]
prmrphrz:					; Print main repeat horizontal
	dec bp
	jnz prmrp

	mov ax, 4C00h				; Exit with code 0
	int 21h

; In:  ds:si = string, bx = start column, dx = start row, cl = attr, ch = direction
; Out: None
print_str proc near
	PUSH_REGS

						; di = (80 * row + column) * 2
	mov ax, dx
	mov di, 80
	mul di
	add ax, bx
	shl ax, 1
	mov di, ax

	cld					; Increment index with string instructions
	mov ah, cl				; Save attribute to ah

	cmp ch, 1				; If (direction == 1) { print_string_vertically }
	je prstrvrtlp

prstrhrzlp:					; Print string horizontal loop
	lodsb					; Load string byte from ds:si to al
	test al, al				; If (character == 0) { done } Else stosw
	jz prstrd
	stosw					; while(cx--) { es:[di += 2] = ax }
	jmp prstrhrzlp

prstrvrtlp:					; Print string vertical loop
	lodsb
	test al, al
	jz prstrd
	mov word ptr es:[di], ax		; es:[di] = ax
	add di, 160				; di += 80 * 2 - next row, same column
	jmp prstrvrtlp

prstrd:						; Print string done
	POP_REGS
	ret
print_str endp

; Changes variables in .data according to cmd arguments
parse_args proc near
	mov word ptr [str_ptr], offset default_str	  ; Defaults

pr_attr:					; Parse --attr
	mov si, 81h				; si -> cmd string
	mov di, offset key_attr			; di -> pattern string
	call find_key
	or ax, ax				; If (ax == 0) { parse dir }
	jz pr_dr
	mov si, ax				; si = ax
	call parse_hex8
	jc pr_dr				; If (CF == 1) { parse dir }
	mov [opt_attr], al			; Save attribute

pr_dr:						; Parse --dir
	mov si, 81h
	mov di, offset key_dir
	call find_key
	or ax, ax
	jz pr_rp
	mov si, ax
	cmp byte ptr [si], '"'			; If (str[si] != '"') { parse direction ?= 1 }
	jne pr_drd
	inc si

pr_drd:
	mov al, [si]
	cmp al, '1'				; If (al != '1') { parse direction ?= 0 }
	jne pr_drz
	mov byte ptr [opt_dir], 1		; direction = 1 (vertical)
	jmp pr_rp				; Parse repeat

pr_drz:						; Direction zero
	cmp al, '0'				; If (al != '0') { parse repeat }
	jne pr_rp
	mov byte ptr [opt_dir], 0		; direction = 0 (horizontal)

pr_rp:						; --repeat
	mov si, 81h
	mov di, offset key_rep
	call find_key
	or ax, ax
	jz pr_str
	mov si, ax
	call parse_dec_u16			; If (CF == 1) { parse_str }
	jc pr_str
	or ax, ax				; If (ax == 0) { parse_str }
	jz pr_str
	mov [opt_rep], ax

pr_str:						; --str="..."
	mov si, 81h
	mov di, offset key_str
	call find_key
	or ax, ax
	jz prd
	mov [str_ptr], ax
	mov si, ax

pr_strsc:					; Str scan
	mov al, [si]
	test al, al
	jz prd
	cmp al, '"'
	je pr_strtrm
	inc si
	jmp pr_strsc

pr_strtrm:					; Str term
	mov byte ptr [si], 0			; Add terminator symbol

prd:						; Parse args done
	ret
parse_args endp

; In:  si - start of source string, di - start of str pattern
; Out: ax - first char after key
find_key proc near
	push bx					; Save registers
	push si
	push di

	mov bx, si									  
						; Here bx = source[source_start + i]
						;	  si - pointer in source for comparassion
						;	  di - pointer in pattern for comparassion
						;	  al - current pattern character
						;	  ah - current source character
fko:						; Find key outer, here we try every start position
	mov al, [bx]				; al = [bx] = [si] = str[si]
	test al, al				; If (al == 0) { not found }
	jz fknf

	mov si, bx				; si - current source candidata
	push di					; save di
fki:						; Find key inner, compare source with pattern char by char 
						; from si while pattern != 0
	mov al, [di]				; al = str[di] - pattern char
	test al, al				; If (al == 0) { found }
	jz fkf

	mov ah, [si]				; ah = str[si] - source char
	test ah, ah				; If (ah == 0) { failed }
	jz fkfl
	cmp ah, al				; If (source != patter) { fail }
	jne fkfl

	inc si					; COntinue matching next chars
	inc di
	jmp fki

fkfl:						; Find key failed
	pop di					; Restore di
	inc bx
	jmp fko

fkf:						; Find key found
	pop di					; Restore di
	mov ax, si				; Return ax
	jmp fkd

fknf:						; Find key not found
	xor ax, ax

fkd:						; Find key done
	pop di					; Restore registers
	pop si
	pop bx
	ret
find_key endp

; In:  si - hex text
; Out: al - value, CF = 0 - ok, CF = 1 - fail
parse_hex8 proc near
	push bx					; Save bx
	mov bl, [si]				; bl = str[si]
	cmp bl, '"'				; If (str[si] == '"') { parse hex }
	jne phf
	inc si
phf:						; Parse hex first
	mov al, [si]				; al = str[si]
	call hex_nibble
	jc phfl					; If (CF == 1) { fail }
	mov bl, al				; bl = hex(str[si])
	inc si					; si++

	mov al, [si]				; al = str[si]
	call hex_nibble
	jc phnd					; If (CF == 1) { fail }

						; Here bl = first nibble, al = second nibble
	shl bl, 4				; hex(str[si]) * 16 - move first nibble to higher 4 bytes
	or bl, al				; Put second nibble in lower 4 bytes
	mov al, bl				; Save parsed hex to al
	inc si
	jmp phs					; Parse suffix (h/H)
phnd:						; Parse hex one digit
	mov al, bl
phs:						; Parse hex suffix
	mov bl, [si]				; bl = str[si]
	cmp bl, 'h'				; If (str[si] == h/H) { skip h/H }
	je phsh
	cmp bl, 'H'
	jne phskq				; Skip quote if any
phsh:						; Parse hex skip h
	inc si					; si++

phskq:						; Parse hex skip (closing) quote
	cmp byte ptr [si], '"'
	jne phk
	inc si

phk:						; Parse hex ok
	clc					; CF = 0
	jmp phxt

phfl:
	stc					; CF = 1

phxt:						; Parse hex on exit
	pop bx
	ret
parse_hex8 endp

; In:  al = hex char
; Out: al = 0-15 CF = 0 - ok, CF = 1 - not ok
hex_nibble proc near
	cmp al, '0'				; If (al < '0') { fail } 
	jb hnf
	cmp al, '9'				; If (al <= '9') { parse decimal }
	jbe hnd

	cmp al, 'A'				; If (al < 'A') { parse lower }
	jb hnl
	cmp al, 'F'				; If (al <= 'F') { parse upper }
	jbe hnp

hnl:						; Hex nibble lower
	cmp al, 'a'				; If (character < 'a') { fail }
	jb hnf
	cmp al, 'f'				; If (character > 'f') { fail }
	ja hnf
	sub al, 'a' - 10			; 'a-f' - ('a' - 10) = 10-15
	clc					; CF = 0
	ret 
	
hnp:						; Hex nibble upper
	sub al, 'A' - 10			; 'A-F' - ('A' - 10) = 10-15
	clc					; CF = 0
	ret

hnd:						; Hex nibble decimal
	sub al, '0'				; '0-9' - '0' = 0-9
	clc					; CF = 0
	ret

hnf:						; Hex nibble fail
	stc					; CF = 1
	ret
hex_nibble endp

; In:  si = decimal text
; Out: ax = value, CF = 0 - ok, CF = 1 - not ok
parse_dec_u16 proc near
	push bx					; Save bx and dx; bx = 0; dx = 0
	push dx

	xor ax, ax
	xor dx, dx

	cmp byte ptr [si], '"'			; If (str[si] != '"') { parse decimal_loop } Else { si++ }
	jne pdlp
	inc si

pdlp:						; Parse dec loop
	mov bl, [si]				; Save str[si] to bl
	cmp bl, '0'				; If (str[si] < '0') { parsed decimal }
	jb pdd
	cmp bl, '9'				; If (str[si] > '9') { parsed decimal }
	ja pdd
	
	mov bx, ax				; bx = old ax value
	shl ax, 1				; ax *= 2
	shl bx, 3				; bx *= 8
	add ax, bx				; ax = old value * 10

	mov bl, [si]				; bl = str[si]
	sub bl, '0'				; Character decimal -> decimal
	xor bh, bh				; bh = 0
	add ax, bx				; ax = old value * 10 + new value

	inc si					; si++; dl++
	inc dl					; dl - amount of parsed characters
	jmp pdlp

pdd:						; Parse dec done
	cmp dl, 0				; If (amount of parsed characters > 0) { parsed ok } Else { CF = 1; ret }
	jne pdk
	stc
	jmp pdxt

pdk:						; Parse dec ok
	clc					; CF = 0

pdxt:						; Parse dec exit
	pop dx
	pop bx
	ret
parse_dec_u16 endp

; In:  si - string
; Out: ax - length
strlen proc near
	push si					; Save si
	xor ax, ax				; ax = 0
sll:						; String len loop
	cmp byte ptr [si], 0			; while (str[si] != 0) { ax++; si++; }
	je sld
	inc si
	inc ax
	jmp sll
sld:						; String len done
	pop si
	ret
strlen endp

; al = char, ah = attr, bx = start column, dx = start row, cl = amount, ch = direction
print_symbols proc near
	PUSH_REGS

	mov si, ax				; Save character + attribute

						; di = (80 * row + column) * 2
	mov ax, dx
	mov di, 80
	mul di
	add ax, bx
	shl ax, 1
	mov di, ax

	mov ax, si
	cld					; Increment index with string instructions 

	cmp ch, 1				; If (direction == 1) { print_vertically }
	je prchrvrtlp

prchrhrz:					; Print character horinzontal
	xor ch, ch
	rep stosw				; while (cx--) { es:[di += 2] = ax }
	jmp prchrd

prchrvrtlp:					; Print character vertical
	test cl, cl				; while (cl--) { es:[di] = ax }
	jz prchrd
prchrlp:					; Print character loop
	mov word ptr es:[di], ax
	add di, 160				; di += 80 * 2 - next row, same column
	dec cl
	jnz prchrlp

prchrd:						; Print character done
	POP_REGS
	ret
print_symbols endp

.data
opt_attr  db 4eh				; Optional attribute
opt_dir   db 0					; Optional direction, 0 - horizontal, 1 - vertical
opt_rep   dw 1					; Repeat
start_col dw 0					; Starting column
start_row dw 0					; Starting row
str_ptr   dw 0					; String pointer
str_len   dw 0					; String length

						; Pattern for arguments parsing
key_str  db '--str="',   0
key_attr db '--attr=',   0
key_dir  db "--dir=",	0
key_rep  db "--repeat=", 0

						; Default string
default_str db 'No string (--str="...") provided', 0

end _start
