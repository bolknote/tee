SYS_EXIT	equ 60
SYS_READ	equ 0
SYS_WRITE	equ 1
SYS_OPEN	equ 2
SYS_CLOSE	equ 3
SYS_CREAT	equ 85

STDIN		equ 0
STDOUT		equ 1
STDERR		equ 2

O_WRONLY 	equ 0x001

CHUNK		equ 8192

section .data
	errorStr db `Error opening file for writing.\n`
	errorLen equ $ - errorStr

section .bss
	buffer resb CHUNK

section .text
	global _start

_start:
	xor r15, r15 ; second file descriptor or 0 if none

	pop rax ; argc
	cmp rax, 1
	jle loop

	pop rsi ; *argv[0]
	pop rsi ; *argv[1]

	cmp word [rsi], `-\0`
	je alsostdout

filename:
	cld
	mov rcx, CHUNK
	xor rax, rax
	mov rdi, rsi
	repne scasb ; rdi - rsi = length

	sub rdi, rsi
	mov rcx, rdi
	mov rdi, buffer
	rep movsb ; copy argv[1] to buffer

	mov rax, SYS_CREAT
	mov rdi, buffer
	mov rsi, 0o660
	syscall

	cmp rax, 0
	jle error

	mov r15, rax
	jmp loop

alsostdout:
	; second descriptor is also STDOUT
	mov r15, STDOUT
	jmp loop

error:
	mov rax, SYS_WRITE
	mov rdi, STDERR
	mov rsi, errorStr
	mov rdx, errorLen
	syscall

loop:
	mov rax, SYS_READ
	mov rdi, STDIN
	mov rsi, buffer
	mov rdx, CHUNK
	syscall

	cmp rax, 0
	jle exit

	xchg rax, rdx ; size read into buffer

	mov rax, SYS_WRITE
	mov rdi, STDOUT
	syscall

	test r15, r15
	jz loop

	mov rax, SYS_WRITE
	mov rdi, r15
	syscall

	jmp loop

exit:
	mov rax, SYS_EXIT
	xor rdi, rdi
	syscall
