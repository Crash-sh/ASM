; NSD / NASM FIELD EXAMPLE
; Read the matching numbered Markdown lesson one directory above.
; Adapted from gas_asm_lecture/05_stack_calls_and_recursion.asm.
; Build from extra_sources/nasm: make build/05_stack_calls_and_recursion
; Each file is a separate program. Do not link all entry points together.
bits 64
default rel

section .text
global _start
_start:
; Linux x86-64 process entry RSP is 16-byte aligned. Not function entry!
    mov r12, rsp                       ; Keep the initial stack pointer for a check.
    mov ebx, 689                       ; Sentinel to test our callee-saved promise.
    mov edi, 5
    call factorial
    cmp rax, 120
    jne failed
    cmp rbx, 689
    jne failed
    cmp rsp, r12
    jne failed

    xor edi, edi                       ; 0! = 1, base-case boundary.
    call factorial
    cmp rax, 1
    jne failed
; Function pointers aren't special either: a call can use a register.
    lea r11, [rel add_two]
    mov edi, 13
    mov esi, 53
    call r11
    cmp rax, 66
    jne failed

    xor edi, edi
    jmp finish
failed:
    mov edi, 53
finish:
    mov eax, 60
    syscall

add_two:
    lea rax, [rdi + rsi]               ; Leaf function: no calls, no stack needed.
    ret

factorial:
; Contract: unsigned n in RDI, 0..20; return n! in RAX.
; 21! doesn't fit uint64_t. This helper expects a bounded caller.
; Recursion depth grows with n, so arbitrary input also risks stack space.
    push rbp                           ; Entry: rsp%16=8 -> 0.
    mov rbp, rsp
    push rbx                           ; rsp%16=8 again.
    sub rsp, 8                         ; Back to 0; a local slot / alignment padding.
    mov qword [rbp - 16], rdi          ; Our slot; saved RBX lives at [rbp-8].
    mov eax, 1
    cmp rdi, 1
    jbe factorial_done

    mov rbx, rdi                       ; RBX survives recursive call by the ABI.
    dec rdi
    call factorial                     ; f(n-1), independent stack frame each time.
    imul rax, rbx                      ; n * f(n-1), low product (fits our domain).
factorial_done:
    add rsp, 8                         ; Undo reservation, in REVERSE order.
    pop rbx
    pop rbp
    ret
section .note.GNU-stack noalloc noexec nowrite progbits
