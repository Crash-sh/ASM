; NSD / NASM FIELD EXAMPLE
; Read the matching numbered Markdown lesson one directory above.
; Adapted from gas_asm_lecture/02_memory_and_pointer_hell.asm.
; Build from extra_sources/nasm: make build/02_memory_and_pointer_hell
; Each file is a separate program. Do not link all entry points together.
bits 64
default rel

section .rodata
pattern: dd 0x12345678
numbers: dd 13, 53, 689, -1
NUMBER_COUNT equ ($ - numbers) / 4
; equ defines an assembler-time constant. $ is the current position.
; dd emits 4 bytes; C long on this ABI is 8. Names are not a size check.
section .data
mutable: dd 13
section .bss
alignb 8                               ; Align the next label to an 8-byte boundary.
saved_pointer: resb 8                  ; Space for one pointer, initially zero.
result: resb 8

section .text
global _start
_start:
    movzx eax, byte [rel pattern]
    cmp eax, 0x78                      ; First byte is the LOW byte.
    jne failed
    mov eax, dword [rel pattern]
    bswap eax                          ; Reverse the order of four bytes.
    cmp eax, 0x78563412
    jne failed

    lea rax, [rel mutable]
    mov qword [rel saved_pointer], rax
    mov rdx, qword [rel saved_pointer]
    mov dword [rdx], 53                ; *saved_pointer = 53, with a 32-bit pointee.
    cmp dword [rel mutable], 53
    jne failed

; Effective address: base + index*scale + displacement.
; Scale can be 1,2,4,8. Here an int takes 4 bytes, so arr[i] uses i*4.
; There's no automatic pointer scaling like C's int_ptr++.
; RIP-relative operands can't also contain an index; load a base first.
    lea rsi, [rel numbers]
    xor ecx, ecx                       ; i = 0
    xor eax, eax                       ; signed 64-bit sum = 0
sum_loop:
    cmp rcx, NUMBER_COUNT
    jae sum_done                       ; Check bounds BEFORE accessing arr[i].
    movsxd rdx, dword [rsi + rcx*4]
    add rax, rdx                       ; Need sign-extension to sum the -1 properly.
    inc rcx
    jmp sum_loop
sum_done:
    mov qword [rel result], rax
    cmp rax, 754
    jne failed

    lea rdx, [rsi + 2*4]               ; &numbers[2]; LEA doesn't dereference it.
    cmp dword [rdx], 689
    jne failed
    xor edi, edi
    jmp finish
failed:
    mov edi, 53
finish:
    mov eax, 60
    syscall
section .note.GNU-stack noalloc noexec nowrite progbits
