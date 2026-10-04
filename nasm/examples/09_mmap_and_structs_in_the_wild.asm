; NSD / NASM FIELD EXAMPLE
; Read the matching numbered Markdown lesson one directory above.
; Adapted from gas_asm_lecture/09_mmap_and_structs_in_the_wild.asm.
; Build from extra_sources/nasm: make build/09_mmap_and_structs_in_the_wild
; Each file is a separate program. Do not link all entry points together.
bits 64
default rel

SYS_MMAP equ 9
SYS_MUNMAP equ 11
NODE_VALUE equ 0
NODE_NEXT equ 8
NODE_SIZE equ 16
MAP_LENGTH equ NODE_SIZE * 2
section .text
global _start
_start:
    mov eax, SYS_MMAP
    xor edi, edi                       ; addr hint = NULL
    mov esi, MAP_LENGTH
    mov edx, 3                         ; PROT_READ(1) | PROT_WRITE(2)
    mov r10d, 0x22                     ; MAP_PRIVATE(2) | MAP_ANONYMOUS(0x20)
    mov r8, -1                         ; fd, ignored for this anonymous mapping
    xor r9d, r9d                       ; offset
    syscall
    cmp rax, -4095
    jae map_failed                     ; Unsigned high range encodes raw errors.
; libc mmap would give MAP_FAILED=(void*)-1 and set errno instead.
    mov r12, rax                       ; Own the mapping; preserve for cleanup.

    lea rdx, [r12 + NODE_SIZE]
    mov dword [r12 + NODE_VALUE], 13
    mov qword [r12 + NODE_NEXT], rdx
    mov dword [rdx + NODE_VALUE], 53
    mov qword [rdx + NODE_NEXT], 0

    mov rsi, r12                       ; iter = first
    xor eax, eax                       ; sum
walk_list:
    test rsi, rsi
    jz walk_done
    movsxd rdx, dword [rsi + NODE_VALUE]
    add rax, rdx
    mov rsi, qword [rsi + NODE_NEXT]
    jmp walk_list
walk_done:
    xor r13d, r13d
    cmp rax, 66
    je cleanup
    mov r13d, 53                       ; Preserve result across munmap's RAX return.
cleanup:
    mov eax, SYS_MUNMAP
    mov rdi, r12
    mov esi, MAP_LENGTH
    syscall
    test rax, rax
    js map_failed
    xor r12d, r12d                     ; Clear OUR pointer; other aliases wouldn't clear.
    mov edi, r13d
    jmp finish
map_failed:
    mov edi, 1
finish:
    mov eax, 60
    syscall
section .note.GNU-stack noalloc noexec nowrite progbits
