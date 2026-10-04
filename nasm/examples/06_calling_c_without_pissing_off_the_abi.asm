; NSD / NASM FIELD EXAMPLE
; Read the matching numbered Markdown lesson one directory above.
; Adapted from gas_asm_lecture/06_calling_c_without_pissing_off_the_abi.asm.
; Build from extra_sources/nasm: make build/06_calling_c_without_pissing_off_the_abi
; Each file is a separate program. Do not link all entry points together.
bits 64
default rel
extern printf

section .rodata
format: db "sum=%ld, float=%.2f", 10, 0
align 8
decimal: dq 13.53

section .text
global main
main:
    push rbp
    mov rbp, rsp                       ; RSP now aligned to 16 for calls.

; long sum_seven(long a,b,c,d,e,f,g). First six get registers.
; Need one 8-byte stack arg AND 8 bytes padding to retain alignment.
    sub rsp, 16
    mov qword [rsp], 7                 ; Seventh arg nearest the return address.
; [rsp+8] is padding. Put padding AFTER stack args, not before arg #7.
    mov edi, 1
    mov esi, 2
    mov edx, 3
    mov ecx, 4
    mov r8d, 5
    mov r9d, 6
    call sum_seven
    add rsp, 16                        ; Caller reclaims stack arguments/padding.
    cmp rax, 28
    jne failed

    mov rsi, rax                       ; printf arg: the long integer.
    lea rdi, [rel format]              ; printf arg: format pointer.
    movsd xmm0, qword [rel decimal]
    mov eax, 1                         ; One vector arg. AFTER copying old RAX!
    call printf wrt ..plt
    test eax, eax                      ; printf reports negative on output error.
    js failed
    xor eax, eax
    pop rbp
    ret
failed:
    mov eax, 53
    pop rbp
    ret

global sum_seven
sum_seven:
    lea rax, [rdi + rsi]
    add rax, rdx
    add rax, rcx
    add rax, r8
    add rax, r9
    add rax, qword [rsp + 8]           ; [rsp] is return address; next slot is g.
    ret
section .note.GNU-stack noalloc noexec nowrite progbits
