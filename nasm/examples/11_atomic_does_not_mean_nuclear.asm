; NSD / NASM FIELD EXAMPLE
; Read the matching numbered Markdown lesson one directory above.
; Adapted from gas_asm_lecture/11_atomic_does_not_mean_nuclear.asm.
; Build from extra_sources/nasm: make build/11_atomic_does_not_mean_nuclear
; Each file is a separate program. Do not link all entry points together.
bits 64
default rel

section .data
align 8
counter: dq 13
guard: dd 0
section .text
global _start
_start:
    mov eax, 40
    lock xadd qword [rel counter], rax
; Memory += old RAX, and RAX receives OLD memory. Atomic fetch-add.
    cmp rax, 13
    jne failed
    cmp qword [rel counter], 53
    jne failed

; Compare-and-exchange: implicit expected value in RAX.
; If memory == RAX: store source register, ZF=1.
; Else: load observed memory into RAX, ZF=0. Source isn't stored.
    mov eax, 53
    mov edx, 689
    lock cmpxchg qword [rel counter], rdx
    jne failed                         ; Success: replaced 53 with 689.
    mov eax, 53                        ; Stale expectation on purpose.
    mov edx, 13
    lock cmpxchg qword [rel counter], rdx
    je failed                          ; Should fail and tell us the observed 689.
    cmp rax, 689
    jne failed
    cmp qword [rel counter], 689
    jne failed

; XCHG with a memory operand is implicitly locked; no LOCK needed.
    mov eax, 1
    xchg dword [rel guard], eax
    test eax, eax                      ; Old zero means we acquired it.
    jne failed
; Tiny protected region would go here. No other thread exists in demo.
    mov dword [rel guard], 0           ; Aligned store releases on x86 WB memory.

    xor edi, edi
    jmp finish
failed:
    mov edi, 53
finish:
    mov eax, 60
    syscall
section .note.GNU-stack noalloc noexec nowrite progbits
