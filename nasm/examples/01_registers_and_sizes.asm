; NSD / NASM FIELD EXAMPLE
; Read the matching numbered Markdown lesson one directory above.
; Adapted from gas_asm_lecture/01_registers_and_sizes.asm.
; Build from extra_sources/nasm: make build/01_registers_and_sizes
; Each file is a separate program. Do not link all entry points together.
bits 64
default rel

section .text
global _start
_start:
; _start is the ELF entry point here. No C caller pushed a return address.
; ret here would consume argc as a return address. Wrong exit route.
    mov rax, -1                        ; ffffffffffffffff
    mov al, 0x13                       ; ffffffffffffff13: only low 8 changed.
    cmp rax, -237                      ; Same 64-bit pattern interpreted signed.
    jne failed                         ; Jump if not equal; chapters 03/04 unpack it.

    mov ax, 0x53                       ; ffffffffffff0053: low 16 changed.
    mov eax, 0x689                     ; 0000000000000689: upper 32 CLEARED.
    cmp rax, 0x689
    jne failed

    mov al, 0xff
    movzx ecx, al                      ; Zero-extend: ECX = 255; also clears RCX high.
    movsx edx, al                      ; Sign-extend: EDX = ffffffff, signed -1.
    cmp ecx, 255
    jne failed
    cmp edx, -1
    jne failed
; Inspect RDX: 00000000ffffffff. The EDX write cleared its upper half.
; A signed 32-bit result isn't automatically sign-extended to 64 bits.
    movsxd rdx, edx                    ; Now RDX = ffffffffffffffff, signed -1.
    cmp rdx, -1
    jne failed

    mov r8d, 13
    mov r9d, r8d                       ; Copies a value. Doesn't establish a link.
    add r8d, 40                        ; r8d=53, r9d still 13. Like int b=a in C.
    cmp r9d, 13
    jne failed

    xor edi, edi                       ; Status argument 0. xor x,x produces zero.
    jmp finish
failed:
    mov edi, 53
finish:
    mov eax, 60                        ; Linux x86-64 syscall number for exit.
    syscall                            ; Kernel receives status in RDI. Never returns.
; This syscall instruction is not a function call. Chapter 08 goes deep.
section .note.GNU-stack noalloc noexec nowrite progbits
