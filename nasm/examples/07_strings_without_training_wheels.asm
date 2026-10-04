; NSD / NASM FIELD EXAMPLE
; Read the matching numbered Markdown lesson one directory above.
; Adapted from gas_asm_lecture/07_strings_without_training_wheels.asm.
; Build from extra_sources/nasm: make build/07_strings_without_training_wheels
; Each file is a separate program. Do not link all entry points together.
bits 64
default rel

section .rodata
source: db "nsd: port online!", 0
BYTE_COUNT equ $ - source - 1
expected: db "NSD: PORT ONLINE!"
section .bss
destination: resb BYTE_COUNT + 1
copy_again: resb BYTE_COUNT + 1
section .text
global _start
_start:
    lea rsi, [rel source]
    lea rdi, [rel destination]
    xor ecx, ecx
copy_loop:
    cmp rcx, BYTE_COUNT
    jae copy_done
    mov al, byte [rsi + rcx]
    cmp al, 'a'
    jb store_byte
    cmp al, 'z'
    ja store_byte
    sub al, 'a' - 'A'
store_byte:
    mov byte [rdi + rcx], al
    inc rcx
    jmp copy_loop
copy_done:
    mov byte [rdi + rcx], 0            ; Explicit terminator; capacity includes it.

; String instructions have implicit operands. Check every register they touch:
; movsb: copy byte [RSI] -> [RDI], advance/decrement BOTH pointers.
; stosb: store AL -> [RDI], move RDI. lodsb loads [RSI] -> AL, moves RSI.
; scasb compares AL with [RDI]; cmpsb compares [RSI] with [RDI].
; Suffix b/w/d/q chooses element width (1/2/4/8 bytes).
; DF, the direction flag: 0 moves forward; 1 moves backward.
; CLD clears DF. STD sets it. SysV requires DF clear at call/return.
    cld
    lea rsi, [rel destination]
    lea rdi, [rel copy_again]
    mov ecx, BYTE_COUNT + 1
    rep movsb                          ; Copy RCX bytes; ends with RCX=0.
; RSI/RDI now point past copied bytes. Preserve original addresses if
; you need them later. REP advances them; no backup copy is maintained.

    lea rsi, [rel copy_again]
    lea rdi, [rel expected]
    mov ecx, BYTE_COUNT                ; expected has no terminator; exclude it.
    repe cmpsb                         ; Repeat while equal AND RCX != 0.
    jne failed
    cmp byte [rel copy_again + BYTE_COUNT], 0
    jne failed

; A bounded strlen-style search: look for zero within the allocated size.
    lea rdi, [rel copy_again]
    mov ecx, BYTE_COUNT + 1
    xor eax, eax                       ; AL = byte to search for, zero.
    repne scasb                        ; Repeat while not equal and count remains.
    jne failed                         ; No terminator encountered in this buffer.
; For a ZERO initial count, these repeat instructions do no work and
; leave flags alone. Handle that separately in a general helper.
    lea rax, [rel copy_again]
    sub rdi, rax
    dec rdi                            ; RDI advanced past NUL; exclude that byte.
    cmp rdi, BYTE_COUNT
    jne failed
    xor edi, edi
    jmp finish
failed:
    mov edi, 53
finish:
    mov eax, 60
    syscall
section .note.GNU-stack noalloc noexec nowrite progbits
