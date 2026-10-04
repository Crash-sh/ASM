/* ==================== NSD / CONTROL FLOW ======================
    Next target: the instruction pointer. if/else has been reduced to
    comparisons and branches. Pick a condition, verify its flags, redirect
    execution. A wrong branch will run the wrong code perfectly. Cold bastard.
    Build: gcc -g -nostdlib -no-pie -x assembler 04_branches_loops_and_bit_wizardry.asm -o /tmp/branches
    Run /tmp/branches; echo $?     Expected 0.

    cmp a,b computes a-b for FLAGS ONLY. Neither operand changes.
    test a,b computes a&b for flags only. test eax,eax checks zero/sign.
    jmp always jumps. jcc jumps when its condition holds, otherwise execution
    falls through to the next instruction. Labels aren't block boundaries:
    reaching a label doesn't automatically stop execution or return.
    A label is an address marker. It has zero authority over the CPU.

    After cmp a,b:     unsigned             signed
        a == b        je / jz              je / jz        ZF=1
        a != b        jne / jnz            jne / jnz      ZF=0
        a <  b        jb  (CF=1)           jl  (SF != OF)
        a <= b        jbe (CF=1 or ZF=1)   jle (ZF=1 or SF != OF)
        a >  b        ja  (CF=0 and ZF=0)  jg  (ZF=0 and SF == OF)
        a >= b        jae (CF=0)           jge (SF == OF)

    jl isn't just 'look at the sign'. Subtraction can overflow, hence OF.
    jz/je are names for the same condition. Signedness is your responsibility.
    setcc writes 0/1 into ONE BYTE. cmovcc conditionally copies a 16/32/64
    bit source. Both use the same conditions. cmov with a memory source can
    still fault when its condition is false: don't use it as a pointer guard.
*/
.intel_syntax noprefix
.text
.globl _start
_start:
    mov eax, -1
    cmp eax, 1
    jge failed                     # Signed -1 isn't >= 1.
    jbe failed                     # Unsigned 4294967295 isn't <= 1 either.

    # int max = (a > b) ? a : b; signed comparison.
    mov eax, 13
    mov edx, 53
    cmp eax, edx
    cmovl eax, edx                  # If signed less, take b.
    cmp eax, 53
    jne failed
    sete al                        # AL=1; doesn't clear upper EAX by itself.
    movzx eax, al                   # Now clean 0/1 in the whole register.
    cmp eax, 1
    jne failed

    # for (i=1,sum=0; i<=10; ++i) sum+=i;
    xor eax, eax
    mov ecx, 1
sum_loop:
    cmp ecx, 10
    ja sum_done                    # Top-tested loop: body can execute zero times.
    add eax, ecx
    inc ecx
    jmp sum_loop
sum_done:
    cmp eax, 55
    jne failed
    # dec ecx / jnz works for countdowns too, but initial zero would underflow
    # if you enter the body first. Explicitly handle empty counts.
    # x86 has a LOOP instruction; ordinary cmp/dec+jcc is clearer here and
    # LOOP isn't universally fast. I want timings, not mnemonic worship.

    # Bit masks: AND keeps selected bits, OR sets them, XOR toggles them.
    mov eax, 0b1010
    or eax, 0b0100                  # 1110
    and eax, 0b1101                 # 1100
    xor eax, 0b1000                 # 0100
    test eax, 0b0100
    jz failed                      # Selected bit should be set.
    not eax                        # Flip ALL 32 bits; doesn't change flags.
    cmp eax, 0xfffffffb
    jne failed

    mov eax, 13
    shl eax, 2                     # 52, low 32 bits of multiplying by 4.
    shr eax, 1                     # 26, zero bits enter at the top.
    cmp eax, 26
    jne failed
    mov eax, -3
    sar eax, 1                     # -2: signed shift rounds toward NEGATIVE infinity.
    cmp eax, -2                    # idiv by 2 gives -1. Different rounding contract.
    jne failed
    # SHL/SAL are aliases. SHR zero-fills, SAR sign-fills, ROL/ROR rotate
    # bits back around. CF gets the last shifted-out bit for ordinary small
    # nonzero shifts. OF generally has a defined meaning only for count 1.
    # Avoid depending on flags for large counts; consult the ISA manual.

    mov eax, 0x80000001
    rol eax, 1
    cmp eax, 3
    jne failed
    mov ecx, 32
    shl eax, cl                     # Variable count is CL for this instruction.
    cmp eax, 3                     # 32-bit shift count masked to 5 bits: 32 -> 0!
    jne failed
    # 64-bit operands use 6 count bits (mod 64); 8/16-bit use 5 too.
    # C shifts by >= operand width are UB. Hardware masking doesn't fix C.

    # Popcount without needing the optional POPCNT CPU feature:
    # while (x) { x &= x-1; ++count; } removes the lowest set bit each lap.
    mov eax, 0b101101
    xor ecx, ecx
count_loop:
    test eax, eax
    jz count_done
    lea edx, [eax - 1]
    and eax, edx
    inc ecx
    jmp count_loop
count_done:
    cmp ecx, 4
    jne failed
    xor edi, edi
    jmp finish
failed:
    mov edi, 53
finish:
    mov eax, 60
    syscall
.section .note.GNU-stack,"",@progbits

/*
    Exercise: replace jge with jae in the first comparison. Explain why it
    fails. Then implement min(a,b), and count bits in zero and UINT32_MAX.
    BT copies a selected bit to CF; BTS/BTR/BTC also set/reset/toggle it.
    BSF/BSR find a set bit but have an undefined destination for zero input;
    test zero first. Don't assume all bit instructions share that behavior.
    Read the zero-input case in the manual. That's where bad shortcuts hide.
*/
