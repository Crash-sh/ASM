/* ==================== NSD / STATUS FLAGS ======================
    Arithmetic leaves status bits behind. Read them before the next
    instruction overwrites the evidence. CF and OF report different failures;
    wiring your branch to the wrong one is operator error, not CPU betrayal.
    Build: gcc -g -nostdlib -no-pie -x assembler 03_arithmetic_and_flag_drama.asm -o /tmp/math
    Run /tmp/math; echo $?     Expected 0.

    RFLAGS is a register full of status/control bits. Main arithmetic ones:
        CF - carry/borrow, useful for UNSIGNED overflow
        OF - SIGNED overflow (result doesn't fit the signed width)
        ZF - result equals zero
        SF - top bit of result, the signed sign bit
        PF - even parity of low result byte (not all 64 bits)
    AF exists too (carry across low nibble); mostly historical for our needs.

    add/sub/cmp update these arithmetic flags. mov/lea do not.
    inc/dec update several flags but PRESERVE CF. xor/and/or clear CF/OF,
    set ZF/SF/PF from result, leave AF undefined. Undefined flag means do
    not depend on it. An undocumented outcome isn't a feature you discovered.

    8-bit 255+1 -> 0, CF=1, OF=0. Unsigned overflow.
    8-bit 127+1 -> 128 (-128 signed), CF=0, OF=1. Signed overflow.
    Same add instruction. Different interpretations. Select the right alarm.
    Unlike signed overflow in C, the instruction itself has defined wrap
    behavior. That doesn't make a C expression with signed overflow valid.
*/
.intel_syntax noprefix
.text
.globl _start
_start:
    mov al, 255
    add al, 1
    jnc failed                     # Carry wasn't set? Something is wrong.
    jnz failed                     # jcc reads flags without changing them.
    jo failed

    mov al, 127
    add al, 1
    jno failed
    jc failed
    cmp al, 0x80                   # cmp overwrites flags! Old OF is gone now.
    jne failed

    # 128-bit addition using two 64-bit limbs. CF carries across the boundary.
    # (high:low) = (0:UINT64_MAX) + (0:1) -> (1:0).
    mov rax, -1
    xor edx, edx
    add rax, 1
    adc rdx, 0                     # high += 0 + CF from the low addition.
    cmp rdx, 1
    jne failed
    test rax, rax                  # AND for flags, discards result. Is zero?
    jne failed
    # Reverse with sub low,1; sbb high,0. SBB includes borrow via CF.
    sub rax, 1
    sbb rdx, 0
    cmp rax, -1
    jne failed
    test rdx, rdx
    jne failed

    # Two/three-operand imul keeps the low product, signals signed overflow.
    mov eax, 13
    imul eax, eax, 53               # eax = 689. NSD test pattern, exact product.
    jo failed
    cmp eax, 689
    jne failed

    # One-operand mul r/m64: UNSIGNED RAX * operand -> RDX:RAX.
    # One-operand imul is signed and also produces the full double-width pair.
    # CF/OF indicate whether the high half was necessary for the relevant
    # interpretation. Don't read ZF after mul/imul: not a defined result flag.
    mov rax, -1
    mov ecx, 2
    mul rcx
    cmp rdx, 1
    jne failed
    cmp rax, -2                     # Low bits fffffffffffffffe.
    jne failed

    # UNSIGNED division: RDX:RAX / divisor -> quotient RAX, remainder RDX.
    # RDX is INPUT too. Stale high bits change the dividend. Clear the register.
    # To divide a plain uint64_t, clear RDX. Divisor cannot be an immediate.
    mov eax, 689
    xor edx, edx
    mov ecx, 53
    div rcx
    cmp rax, 13
    jne failed
    test rdx, rdx
    jne failed

    # SIGNED division: sign-extend RAX into RDX:RAX with CQO first.
    # For 32-bit idiv use CDQ to extend EAX into EDX:EAX.
    mov rax, -53
    cqo
    mov ecx, 13
    idiv rcx                       # -53 / 13 -> quotient -4, remainder -1.
    cmp rax, -4
    jne failed
    cmp rdx, -1
    jne failed
    # Signed quotient truncates toward zero, remainder follows dividend sign.
    # div/idiv don't give useful arithmetic flags. Inspect results explicitly.
    # Zero divisor OR quotient that doesn't fit causes #DE, usually SIGFPE
    # on Linux. Including INT64_MIN / -1, despite the nonzero divisor.

    xor edi, edi
    jmp finish
failed:
    mov edi, 53
finish:
    mov eax, 60
    syscall
.section .note.GNU-stack,"",@progbits

/*
    Exercise: put xor r8d,r8d between add rax,1 and adc rdx,0.
    That zeroing destroys CF; the carry chain fails. mov r8d,0 would not.
    One 'harmless' instruction killed the carry. This is why I track flags.
    neg x computes 0-x, sets CF for nonzero x and OF for the signed minimum.
    LEA can do arithmetic without flags: lea rax,[rdi+rdi*4] gives 5*rdi.
    It only supports address-shaped expressions, not arbitrary algebra.
*/
