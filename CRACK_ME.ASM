LOCALS @@

.model tiny
.code
org 100h

CRLF 	equ 0dh, 0ah

_start: jmp init

print_dollar proc near
    mov ah, 09h
    int 21h
    ret
endp

say_granted proc near
    mov dx, offset msg_granted
    call print_dollar
    ret
endp

say_denied proc near
    mov dx, offset msg_denied
    call print_dollar
    ret
endp

grant_and_exit:
    call say_granted
    jmp program_exit

int0_fail_handler proc far
    call say_denied
    iret
endp

int0_success_handler proc far
    call say_granted
    iret
endp

; ------------------------------------------------------------
; SDBM hash
;
; hash = c + (hash << 6) + (hash << 16) - hash
;
; In:
;   DS:SI -> buffer
;   CX    -> len
; Out:
;   DX:AX -> 32 bit hash
; ------------------------------------------------------------

sdbm_hash proc near
    xor ax, ax
    xor dx, dx

@@hash_loop:
    or  cx, cx
    jz  @@hash_done

    mov bl, [si]
    xor bh, bh
    inc si

    push bx ax dx

    mov bl, 6

@@shift_loop:
    shl ax, 1
    rcl dx, 1
    dec bl
    jnz @@shift_loop

    pop bx di

    add dx, di

    sub ax, di
    sbb dx, bx

    pop bx
    add ax, bx
    adc dx, 0

    dec cx
    jmp @@hash_loop

@@hash_done:
    ret
endp

; ------------------------------------------------------------
; VULN #1:
; local buffer on stack = 40 bytes
; read from STDIN up to 80 bytes
;
; Layout:
;   [bp-40 .. bp-1]  - local buffer
;   [bp]             - saved BP
;   [bp+2]           - return IP
;
; Exploit:
;   40 junk bytes -> buffer
;   2 bytes       -> saved BP
;   2 bytes       -> RET
; ------------------------------------------------------------

read_password_stack proc near
    push bp
    mov  bp, sp

    sub  sp, 40
    lea  dx, [bp-40]

    mov  bx, 0
    mov  cx, 80
    mov  ah, 3Fh
    int  21h

    jc   @@rps_done

    mov  [bytes_read], ax

    lea  si, [bp-40]
    mov  di, offset global_input
    mov  cx, ax
    rep  movsb

@@rps_done:
    mov  sp, bp
    pop  bp
    ret
endp

; ------------------------------------------------------------
; VULN #2:
; Copy to normbuf without checks
; There is fake_int0_vector after normbuf
;
; 16 bytes -> normbuf
; 2 bytes  -> fake_int0_off
; 2 bytes  -> fake_int0_seg
; ------------------------------------------------------------

normalize_copy proc near
    mov si, offset global_input
    mov di, offset normbuf
    mov cx, [bytes_read]

@@nc_loop:
    or  cx, cx
    jz  @@nc_done

    lodsb

    cmp al, 0Dh
    je  @@nc_done
    cmp al, 0Ah
    je  @@nc_done

    stosb

    dec cx
    jmp @@nc_loop

@@nc_done:
    mov ax, di
    sub ax, offset normbuf
    mov [norm_len], ax
    ret
endp

; ------------------------------------------------------------
; INT0 pseudo-handler
; ------------------------------------------------------------

trigger_fake_div0 proc near
    xor bx, bx

    cmp bx, 0
    jne tfd_safe

    pushf
    call dword ptr [fake_int0_vector]
    ret

tfd_safe:
    call say_denied
    ret
endp

init:
    cli

    push cs cs cs
    pop  ds es ax

    mov  ss, ax
    mov  sp, offset stack_top

    sti

    push cs
    pop  ax
    mov  [fake_int0_seg], ax

    cld

    mov  dx, offset prompt
    call print_dollar

    call read_password_stack
    call normalize_copy

    mov  si, offset normbuf
    mov  cx, [norm_len]
    call sdbm_hash

    cmp  ax, [stored_hash_lo]
    jne  auth_fail
    cmp  dx, [stored_hash_hi]
    jne  auth_fail

auth_ok:
    call say_granted
    jmp  program_exit

auth_fail:
    call trigger_fake_div0

program_exit:
    mov  ax, 4C00h
    int  21h

.data
prompt                  db 'Enter password: $'
msg_granted             db 13,10,'Access granted!$'
msg_denied              db 13,10,'Denied!$'

; SDBM("POLTORASHKAMEOW") = A38AC9E2h
stored_hash_lo          dw 0C9E2h
stored_hash_hi          dw 0A38Ah

bytes_read              dw 0
norm_len                dw 0

global_input            db 80 dup (0)

normbuf                 db 16 dup (0)

fake_int0_vector        label dword
fake_int0_off           dw offset int0_fail_handler
fake_int0_seg           dw 0

stack_area              db 128 dup (0)
stack_top               label byte

end _start
