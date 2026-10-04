; NSD / NASM FIELD EXAMPLE
; Read the matching numbered Markdown lesson one directory above.
; Adapted from gas_asm_lecture/00_start_here.asm.
; Build from extra_sources/nasm: make build/00_start_here
; Each file is a separate program. Do not link all entry points together.
bits 64
default rel
extern puts

section .rodata                        ; Read-only data in the linked program.
greeting:
    db "CRASH@NSD: instruction stream online.", 0
; db emits the string bytes and the explicit zero. puts needs the terminator.

section .text                          ; Machine instructions live here.
global main                            ; Export main so the C startup can find it.
main:
    push rbp                           ; Save our caller's frame pointer.
    mov rbp, rsp                       ; Establish our frame. Chapter 05 explains.
; main enters with rsp % 16 == 8. push subtracts 8: now aligned for call.
    lea rdi, [rel greeting]            ; First C argument = ADDRESS of greeting.
    call puts wrt ..plt                ; libc puts prints string + newline.
; PLT is a linker mechanism for calling an external function. Chapter 06.
    xor eax, eax                       ; Return value 0, like return(0); in C.
    pop rbp                            ; Restore what we borrowed.
    ret                                ; Return to C runtime, which exits for us.

; Tell the linker this object doesn't require executable stack memory.
section .note.GNU-stack noalloc noexec nowrite progbits
