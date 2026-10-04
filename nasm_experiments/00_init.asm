
%ifdef INTRO

    [link established]
    operator : CRASH

    To build and run this file, use the following commands in your terminal:
    nasm -f elf64 00_init.asm -o 00_init.o -> creates an object file from the fucking source
    ld 00_init.o -o 00_init -> links the object
    ./00_init you fucking know what this does

%endif

section .data
    init db "Operator initialized", 10 ; 10 = '\n'
    len equ $ - init ; this calculates the length of the string

section .text
    global _start ; this fucker is the entry point for the program

_start:
    mov rax, 1 ; syscall: write (check the fucking syscall table for your architecture)
    mov rdi, 1 ; file descriptor: stdout (stdin = 0, stdout = 1, stderr = 2)
    mov rsi, init ; pointer to the string to output
    mov rdx, len ; length of the string
    syscall ; summon the kernel

    mov rax, 60 ; syscall : exit
    xor rdi , 0 ; return 0 status
    syscall ; summon the kernel to exit
