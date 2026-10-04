; NSD / NASM FIELD EXAMPLE
; Read the matching numbered Markdown lesson one directory above.
; Adapted from gas_asm_lecture/03_arithmetic_and_flag_drama.asm.
; Build from extra_sources/nasm: make build/03_arithmetic_and_flag_drama
; Each file is a separate program. Do not link all entry points together.
bits 64
default rel

section .text
global _start
_start:
    mov al, 255
    add al, 1
    jnc failed                         ; Carry wasn't set? Something is wrong.
    jnz failed                         ; jcc reads flags without changing them.
    jo failed

    mov al, 127
    add al, 1
    jno failed
    jc failed
    cmp al, 0x80                       ; cmp overwrites flags! Old OF is gone now.
    jne failed

; 128-bit addition using two 64-bit limbs. CF carries across the boundary.
; (high:low) = (0:UINT64_MAX) + (0:1) -> (1:0).
    mov rax, -1
    xor edx, edx
    add rax, 1
    adc rdx, 0                         ; high += 0 + CF from the low addition.
    cmp rdx, 1
    jne failed
    test rax, rax                      ; AND for flags, discards result. Is zero?
    jne failed
; Reverse with sub low,1; sbb high,0. SBB includes borrow via CF.
    sub rax, 1
    sbb rdx, 0
    cmp rax, -1
    jne failed
    test rdx, rdx
    jne failed

; Two/three-operand imul keeps the low product, signals signed overflow.
    mov eax, 13
    imul eax, eax, 53                  ; eax = 689. NSD test pattern, exact product.
    jo failed
    cmp eax, 689
    jne failed

; One-operand mul r/m64: UNSIGNED RAX * operand -> RDX:RAX.
; One-operand imul is signed and also produces the full double-width pair.
; CF/OF indicate whether the high half was necessary for the relevant
; interpretation. Don't read ZF after mul/imul: not a defined result flag.
    mov rax, -1
    mov ecx, 2
    mul rcx
    cmp rdx, 1
    jne failed
    cmp rax, -2                        ; Low bits fffffffffffffffe.
    jne failed

; UNSIGNED division: RDX:RAX / divisor -> quotient RAX, remainder RDX.
; RDX is INPUT too. Stale high bits change the dividend. Clear the register.
; To divide a plain uint64_t, clear RDX. Divisor cannot be an immediate.
    mov eax, 689
    xor edx, edx
    mov ecx, 53
    div rcx
    cmp rax, 13
    jne failed
    test rdx, rdx
    jne failed

; SIGNED division: sign-extend RAX into RDX:RAX with CQO first.
; For 32-bit idiv use CDQ to extend EAX into EDX:EAX.
    mov rax, -53
    cqo
    mov ecx, 13
    idiv rcx                           ; -53 / 13 -> quotient -4, remainder -1.
    cmp rax, -4
    jne failed
    cmp rdx, -1
    jne failed
; Signed quotient truncates toward zero, remainder follows dividend sign.
; div/idiv don't give useful arithmetic flags. Inspect results explicitly.
; Zero divisor OR quotient that doesn't fit causes #DE, usually SIGFPE
; on Linux. Including INT64_MIN / -1, despite the nonzero divisor.

    xor edi, edi
    jmp finish
failed:
    mov edi, 53
finish:
    mov eax, 60
    syscall
section .note.GNU-stack noalloc noexec nowrite progbits
