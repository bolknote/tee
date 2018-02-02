; nasm -f elf64 tee.asm && ld -s -o tee tee.o

SYS_EXIT	equ 60
SYS_READ	equ 0
SYS_WRITE	equ 1
SYS_OPEN	equ 2
SYS_CLOSE	equ 3
SYS_CREAT	equ 85
SYS_BRK		equ 12

STDIN		equ 0
STDOUT		equ 1
STDERR		equ 2

O_WRONLY 	equ 0x001
O_CREAT		equ 0x040
O_TRUNC		equ 0x200
O_APPEND	equ 0x400

CHUNK		equ 8192

section .data
	errorFile db `: Error opening file for writing\n`
	.len equ $ - errorFile

	errorMemory db `Cannot allocate memory\n`
	.len  equ $ - errorMemory

section .bss
	buffer resb CHUNK

section .text
	global _start

_start:
	xor r15, r15 ; r15 - append flag

	pop rcx ; argc
	cmp rcx, 1
	jle tee

	cld
	pop rsi ; skip *argv[0]

	; allocate memory for file handlers table
	push rcx
	mov rax, SYS_BRK
	xor rdi, rdi
	syscall ; get current brk pointer
	pop rcx

	cmp rax, 0
	jl memory_error

	mov r13, rax ; r13 — start of file handlers table
	mov r14, rax ; r14 — current position in file handlers table

	push rcx
	lea rdi, [rcx * 8 + rax] ; add necessary space
	mov rax, SYS_BRK
	syscall
	pop rcx

	cmp rax, 0
	jge allocated

memory_error:
 	mov rax, SYS_WRITE
 	mov rdi, STDERR
 	mov rsi, errorMemory
 	mov rdx, errorMemory.len
 	syscall
 	jmp exit

allocated:
	mov rax, STDOUT
	call store_filehandler

	dec rcx ; minus useless for us argv[0]

next_arg:
	pop rsi ; *argv[]
	push rcx

	mov eax, dword [rsi]

	and eax, 0x00FFFFFF ; clear last byte
	cmp eax, '-a'		; -a\0
	je append_flag
	cmp ax, `-\0`		; -\0?
	je file_stdout

	;real filename
	call copy2buf ; rdx — length

	push rdx
	call open_file ; rax — file handler, 0 if error
	pop rdx

	cmp rax, 0
	jg file_real

	call file_error
	jmp arg_loop

file_stdout:
	mov rax, STDOUT
file_real:
	call store_filehandler
	jmp arg_loop

append_flag:
	; set append flag
	inc r15

arg_loop:
	pop rcx
	loopnz next_arg

tee:
	mov rax, SYS_READ
	mov rdi, STDIN
	mov rsi, buffer
	mov rdx, CHUNK
	syscall

	cmp rax, 0
	jle exit

	xchg rax, rdx ; size read into buffer

	mov rcx, r14
	sub rcx, r13 ; count of file handlers
	shr rcx, 3 ; div by 8

write_loop:
	push rcx

	mov rax, SYS_WRITE
	mov rdi, qword [r13 + (rcx - 1) * 8]
	syscall

	inc r14
	pop rcx
	loopnz write_loop

	jmp tee

exit:
	mov rax, SYS_EXIT
	xor rdi, rdi
	syscall

; in
;	rsi — *from
; out
;	rdx — length
copy2buf:
	xor rdx, rdx
	mov rdi, buffer

copy2buf_loop:
	cmp byte [rsi], 0
	movsb
	je copy2buf_finish

	inc rdx

	cmp rdx, CHUNK
	jl copy2buf_loop

	mov byte [rdi], 0

copy2buf_finish:
	ret

; in
; 	r15 - append flag
; out
;	rax - file handler or 0 if error
open_file:
	test r15, r15
	jz create_file
	mov rsi, O_WRONLY | O_CREAT | O_APPEND
	jmp open_file_call

create_file:
	mov rsi, O_WRONLY | O_CREAT | O_TRUNC

open_file_call:
	mov rax, SYS_OPEN
	mov rdi, buffer
	mov rdx, 0o660
	syscall

	ret

; in
;   rdx - length of filename string
file_error:
	mov rax, SYS_WRITE
 	mov rdi, STDERR
 	mov rsi, buffer
 	syscall

 	mov rax, SYS_WRITE
 	mov rsi, errorFile
 	mov rdx, errorFile.len
 	syscall
 	ret

; in
;	rax - file handler
;	r14 — pointer to table of file handlers
store_filehandler:
	mov qword [r14], rax
	add r14, 8
	ret
