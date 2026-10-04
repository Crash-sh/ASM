/* ==================== NSD / REGISTER ACCESS ===================
    Crash on the console. First target: the register file.
    RAX, EAX, AX and AL expose overlapping bits. Learn which bits a write
    touches before you start firing values into them. Half a register write
    can leave the other half armed with yesterday's garbage.

    Build: gcc -g -nostdlib -no-pie -x assembler 01_registers_and_sizes.asm -o /tmp/regs
    Run: /tmp/regs
    Then: echo $?       Expected: 0. No printed output. GDB can show values.

    16 general-purpose registers in 64-bit mode:
        rax rbx rcx rdx rsi rdi rbp rsp r8 r9 r10 r11 r12 r13 r14 r15
    General-purpose doesn't mean interchangeable everywhere. Division uses
    particular registers; rsp is the stack pointer; calling conventions
    give registers jobs at function boundaries. More on that soon.

    Full 64 bits    low 32    low 16    low 8
        rax          eax       ax        al
        rbx          ebx       bx        bl
        rcx          ecx       cx        cl
        rdx          edx       dx        dl
        rsi          esi       si        sil
        rdi          edi       di        dil
        rbp          ebp       bp        bpl
        rsp          esp       sp        spl
        r8           r8d       r8w       r8b     (same pattern through r15)

    Those aren't separate storage boxes. EAX is the bottom 32 bits of RAX.
    Writing EAX also CLEARS the upper 32 bits of RAX in 64-bit mode.
    Writing AX or AL preserves the other bits. That's the trap. Log it.
    AH/BH/CH/DH address bits 8..15 of the first four registers, but cannot
    be encoded with a REX prefix (needed for many 64-bit/new-register uses).
    Use the low-byte names here. We'll leave that legacy wiring alone.

    Width vocabulary: byte=8, word=16, dword=32, qword=64 bits here.
    An x86 word stays 16 bits even on a 64-bit CPU. Read the spec, not the badge.
    Memory addresses/pointers are 64 bits in our LP64 Linux ABI; int is 32.
    That isn't a universal C rule about all machines or even all x86 ABIs.

    0xff = 255 = 0b11111111. Different spellings, same bits.
    Unsigned 8-bit range: 0..255. Signed two's complement: -128..127.
    Signed negative x is represented modulo 2^width: -1 is all ones.
    Registers have bits, not signedness tags. Instruction choice and our
    interpretation decide whether 0xff means 255 or -1. No type tags survive
    down here to rescue a bad assumption. You're responsible for the width.
*/
.intel_syntax noprefix
.text
.globl _start
_start:
    # _start is the ELF entry point here. No C caller pushed a return address.
    # ret here would consume argc as a return address. Wrong exit route.
    mov rax, -1                     # ffffffffffffffff
    mov al, 0x13                    # ffffffffffffff13: only low 8 changed.
    cmp rax, -237                   # Same 64-bit pattern interpreted signed.
    jne failed                     # Jump if not equal; chapters 03/04 unpack it.

    mov ax, 0x53                    # ffffffffffff0053: low 16 changed.
    mov eax, 0x689                   # 0000000000000689: upper 32 CLEARED.
    cmp rax, 0x689
    jne failed

    mov al, 0xff
    movzx ecx, al                   # Zero-extend: ECX = 255; also clears RCX high.
    movsx edx, al                   # Sign-extend: EDX = ffffffff, signed -1.
    cmp ecx, 255
    jne failed
    cmp edx, -1
    jne failed
    # Inspect RDX: 00000000ffffffff. The EDX write cleared its upper half.
    # A signed 32-bit result isn't automatically sign-extended to 64 bits.
    movsxd rdx, edx                 # Now RDX = ffffffffffffffff, signed -1.
    cmp rdx, -1
    jne failed

    mov r8d, 13
    mov r9d, r8d                    # Copies a value. Doesn't establish a link.
    add r8d, 40                     # r8d=53, r9d still 13. Like int b=a in C.
    cmp r9d, 13
    jne failed

    xor edi, edi                   # Status argument 0. xor x,x produces zero.
    jmp finish
failed:
    mov edi, 53
finish:
    mov eax, 60                     # Linux x86-64 syscall number for exit.
    syscall                        # Kernel receives status in RDI. Never returns.
    # This syscall instruction is not a function call. Chapter 08 goes deep.
.section .note.GNU-stack,"",@progbits

/*
    Exercise: replace mov eax,0x689 with mov ax,0x689. Predict exit status.
    Answer: 53, because the upper bits from -1 survive the 16-bit write.
    Also try movsx rdx,al directly: it sign-extends byte -> 64 in one step.
    mov doesn't change arithmetic flags; xor does. Track the side effects.
    The mnemonic is only part of the instruction's contract.
*/
