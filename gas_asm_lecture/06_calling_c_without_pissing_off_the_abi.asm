/* ==================== NSD / ABI HANDSHAKE ======================
    External code on the line. libc expects arguments in specific places,
    a correctly aligned stack, and its saved registers returned intact.
    That's the interface. Your personal coding doctrine has no jurisdiction.

    Build: gcc -g -x assembler 06_calling_c_without_pissing_off_the_abi.asm -o /tmp/abi
    Run: /tmp/abi
    Expected: sum=28, float=13.53

    This file defines main, so GCC links its normal C startup and libc.
    Startup eventually calls main, and returning from main lets libc flush
    buffered stdio and perform normal exit handling. Raw sys_exit would
    bypass that flushing. Don't mix printf and syscall exit casually.

    main receives argc in EDI and argv in RSI under this ABI. Compare with
    chapter 12's _start: there they're on the INITIAL STACK instead.

    Basic INTEGER/POINTER arguments: RDI RSI RDX RCX R8 R9, then stack.
    Scalar float/double arguments: XMM0..XMM7, using a separate allocation
    sequence. A double return uses XMM0. Structs have classification rules:
    some split across registers, some use memory/hidden pointers. Read the
    ABI before assuming every object fits this tiny cheat sheet.

    Variadic functions like printf need AL = number of vector argument
    registers used (ABI permits an upper bound, up to 8). Use exact count.
    No floats? xor eax,eax. One double? mov eax,1.
    C promotes float to double for varargs; assembly must do that itself.
    Format strings are contracts too: %ld wants our 64-bit long, %d 32-bit
    int, %f a promoted double, %s a pointer to NUL-terminated bytes.
    Wrong width, wrong register, wrong format: you supplied a broken call.
    Don't blame libc for interpreting the bytes you fucking handed it.
*/
.intel_syntax noprefix
.section .rodata
format: .asciz "sum=%ld, float=%.2f\n"
.balign 8
decimal: .double 13.53

.text
.globl main
.type main, @function
main:
    push rbp
    mov rbp, rsp                   # RSP now aligned to 16 for calls.

    # long sum_seven(long a,b,c,d,e,f,g). First six get registers.
    # Need one 8-byte stack arg AND 8 bytes padding to retain alignment.
    sub rsp, 16
    mov QWORD PTR [rsp], 7          # Seventh arg nearest the return address.
    # [rsp+8] is padding. Put padding AFTER stack args, not before arg #7.
    mov edi, 1
    mov esi, 2
    mov edx, 3
    mov ecx, 4
    mov r8d, 5
    mov r9d, 6
    call sum_seven
    add rsp, 16                    # Caller reclaims stack arguments/padding.
    cmp rax, 28
    jne failed

    mov rsi, rax                   # printf arg: the long integer.
    lea rdi, [rip + format]        # printf arg: format pointer.
    movsd xmm0, QWORD PTR [rip + decimal]
    mov eax, 1                     # One vector arg. AFTER copying old RAX!
    call printf@PLT
    test eax, eax                  # printf reports negative on output error.
    js failed
    xor eax, eax
    pop rbp
    ret
failed:
    mov eax, 53
    pop rbp
    ret
.size main, .-main

.globl sum_seven
.type sum_seven, @function
sum_seven:
    lea rax, [rdi + rsi]
    add rax, rdx
    add rax, rcx
    add rax, r8
    add rax, r9
    add rax, QWORD PTR [rsp + 8]    # [rsp] is return address; next slot is g.
    ret
.size sum_seven, .-sum_seven
.section .note.GNU-stack,"",@progbits

/*
    Calling OUR assembly from C is the same agreement in the other direction.
    Copy sum_seven + .intel_syntax/.text/.globl/.type/.size and the GNU-stack
    note to its own file. C prototype:
        extern long sum_seven(long,long,long,long,long,long,long);
    Compile assembly with gcc -c -x assembler helper.asm -o helper.o, then
    link gcc driver.c helper.o -o demo. The name/prototype/ABI must agree.
    Don't link this whole file to another main: duplicate definitions.

    Linker inspection:
    @PLT names a Procedure Linkage Table call path for external functions.
    The dynamic linker resolves shared-library symbols; exact eager/lazy
    behavior depends on link/runtime options. GOT holds address slots.
    To access an external data symbol in position-independent code, a common
    pattern is mov rax,QWORD PTR [rip+symbol@GOTPCREL], then access [rax].
    Our local strings use RIP-relative addressing, so their relative distance
    stays valid when the binary moves. This source supports PIE linking.
    Explicit PIE build: gcc -g -pie -x assembler 06_calling_c_without_pissing_off_the_abi.asm -o /tmp/abi
    PIE enables relocation of the executable; OS ASLR decides randomization.
    -no-pie in our raw examples doesn't disable ASLR for stack/libraries.

    Windows x64 instead starts integer args in RCX,RDX,R8,R9 and has shadow
    space rules. 32-bit conventions differ again. Check the target ABI before
    borrowing code. Same instruction set doesn't guarantee the same handshake.
    Exercise: add another double to printf, set AL=2, use XMM1 for that value.
*/
