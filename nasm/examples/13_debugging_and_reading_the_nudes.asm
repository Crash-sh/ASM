; NSD / NASM FIELD EXAMPLE
; Read the matching numbered Markdown lesson one directory above.
; Adapted from gas_asm_lecture/13_debugging_and_reading_the_nudes.asm.
; Build from extra_sources/nasm: make build/13_debugging_and_reading_the_nudes
; Each file is a separate program. Do not link all entry points together.
bits 64
default rel

section .rodata
values: dd 13, 53, 689, -1
note: db "CRASH: dump the bytes. Verify the claim.", 0
section .bss
alignb 8
observed: resb 8
section .text
global _start
_start:
    lea rdi, [rel values]
    mov esi, 4
    call sum_four
    mov qword [rel observed], rax
    cmp rax, 754
    jne failed
    xor edi, edi
    jmp finish
failed:
    mov edi, 53
finish:
    mov eax, 60
    syscall

sum_four:
; RDI -> int32_t array, RSI = count (despite name works for any valid count).
; Return signed sum, assuming it fits int64_t; no writes to array.
    xor eax, eax
    xor ecx, ecx
sum_loop:
    cmp rcx, rsi
    jae sum_done
    movsxd rdx, dword [rdi + rcx*4]
    add rax, rdx
    inc rcx
    jmp sum_loop
sum_done:
    ret
section .note.GNU-stack noalloc noexec nowrite progbits
