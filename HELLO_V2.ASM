.model tiny    			; Tiny memory model (64K)

CRLF 	equ 0dh, 0ah

.code				; Code section
	org 100h 		; Skip system info & cmd

_start: mov ah, 09h		; store 09h (print string) in ah
	mov dx, offset hello_str; store hello_str address in dx
	int 21h			; interrupt

	mov ax, 4C00h		; exit program, 4C - exit, 00 - exit code
	int 21h			; interrupt

.data
hello_str: db CRLF, "Hello World!", CRLF, "MEOW!$" ; string

end _start			; after end nothing compiles