/* ==================== NSD / VECTOR UNIT =======================
    Four lanes, one packed instruction. Now we're putting the vector unit
    to work. Crash's rule: account for the entire access width before you
    chase throughput. A fast out-of-bounds load is still a fucked load.
    First inspect floating-point representation, then load up the lanes.
    Build: gcc -g -nostdlib -no-pie -x assembler 10_float_and_simd_fuckery.asm -o /tmp/simd
    Run /tmp/simd; echo $?     Expected 0.

    XMM0..XMM15 are 128-bit vector registers in 64-bit mode. SSE/SSE2 are
    baseline for our x86-64 target. We're using that baseline, no AVX assumed.
    One XMM can be viewed as 16 bytes, 8 words, 4 dwords/floats, or 2 doubles.
    The instruction chooses lane interpretation. The register stores bits.
    SIMD = Single Instruction, Multiple Data. Lane-wise arithmetic, not
    automatically multiple threads and not always faster for every workload.

    Scalar floating-point:
        movss/addss/mulss  -> single float in low 32 bits
        movsd/addsd/mulsd  -> double in low 64 bits
    Packed floating-point: addps = four floats, addpd = two doubles.
    Integer packed addition: paddd = four 32-bit lanes, wrapping separately.
    No carry between lanes. Useful for arrays; wrong for a single big integer.

    IEEE binary32 float: 1 sign + 8 exponent + 23 fraction bits.
    IEEE binary64 double: 1 sign + 11 exponent + 52 fraction bits.
    Normal values have an implicit leading 1; special exponent patterns
    represent zeros/subnormals/infinities/NaNs. Binary fractions can't encode
    every decimal fraction exactly. 0.1 still needs rounding. Removing the
    compiler doesn't remove the number format's limits. Read the bit layout.
    MXCSR controls SSE rounding/exceptions; default masks generally produce
    special results instead of trapping. Treat MXCSR as control state:
    check the ABI's preservation rules before changing its settings.
    x87 is the older FP stack machinery you'll see in some disassemblies;
    our float/double examples use SSE2 (long double has different ABI rules).
*/
.intel_syntax noprefix
.section .rodata
.balign 16
left: .long 13, 53, 689, -1
right: .long 1, 2, 3, 4
expected: .long 14, 55, 692, 3
.balign 8
half: .double 0.5
answer: .double 27.0
not_a_number: .quad 0x7ff8000000000000  # Quiet NaN bit pattern, not an integer conversion.
.section .bss
.balign 16
packed_result: .zero 16
.text
.globl _start
_start:
    mov eax, 13
    cvtsi2sd xmm0, eax              # Numeric signed int -> double (13.0).
    addsd xmm0, QWORD PTR [rip + half]  # 13.5, exactly representable in binary.
    addsd xmm0, xmm0                # 27.0
    ucomisd xmm0, QWORD PTR [rip + answer]
    jp failed                      # PF=1: unordered. Check this before trusting ZF.
    jne failed
    cvttsd2si eax, xmm0             # Convert double -> signed int, truncate to zero.
    cmp eax, 27
    jne failed
    # CVTSD2SI follows MXCSR rounding; CVTTSD2SI explicitly truncates.
    # Out-of-range/NaN conversion raises invalid; with exceptions masked
    # the integer-indefinite result can equal INT_MIN. Validate input ranges
    # if that distinction matters. Bit-copy MOVQ is not numeric conversion.

    movsd xmm1, QWORD PTR [rip + not_a_number]
    ucomisd xmm1, xmm0
    jnp failed                     # NaN is unordered with everything, even itself.
    # For ordered comparisons: greater gives ZF/PF/CF=000, less=001,
    # equal=100, unordered=111. Check JP before JE/JB when NaN is possible.
    # Sign/overflow flags are cleared; use unsigned-style conditions here.

    movdqu xmm0, XMMWORD PTR [rip + left]
    movdqu xmm1, XMMWORD PTR [rip + right]
    paddd xmm0, xmm1                # Four independent int32 additions.
    movdqu XMMWORD PTR [rip + packed_result], xmm0
    # MOVDQU allows unaligned addresses, MOVDQA requires 16-byte alignment.
    # Unaligned doesn't mean out-of-bounds allowed: both touch 16 bytes.
    lea rsi, [rip + packed_result]
    lea rdi, [rip + expected]
    xor ecx, ecx
verify_lane:
    mov eax, DWORD PTR [rsi + rcx*4]
    cmp eax, DWORD PTR [rdi + rcx*4]
    jne failed
    inc ecx
    cmp ecx, 4
    jb verify_lane

    # Reduce four lanes with SSE2 shifts and adds: horizontal sum = 764.
    movdqa xmm1, xmm0               # Register->register, no alignment question.
    psrldq xmm1, 8                 # Shift whole vector right by EIGHT BYTES.
    paddd xmm0, xmm1                # Low lanes now a+c and b+d.
    movdqa xmm1, xmm0
    psrldq xmm1, 4
    paddd xmm0, xmm1
    movd eax, xmm0                 # Copy low 32 bits to EAX (no FP conversion).
    cmp eax, 764
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
    Real SIMD loops need a tail for lengths not divisible by lane count.
    A 16-byte load for three remaining int32s can read outside the allocation.
    Full-width access, full-width bounds check. Also inspect saturation vs wrapping:
    paddusb saturates unsigned bytes at 255; paddb wraps modulo 256.

    AVX introduces wider YMM and three-operand forms; AVX-512 adds ZMM/masks.
    Before AVX, check CPUID CPU features AND OSXSAVE/XGETBV OS state support.
    CPUID alone isn't enough; executing an unsupported instruction can SIGILL.
    Functions using AVX often use vzeroupper before returning/calling legacy
    SSE code to avoid transition costs on affected CPUs. Not needed here.
    Exercise: sum an array of 7 ints using four-lane chunks and scalar tail.
    Check negative elements, empty length and overflow policy before timing it.
    Then measure the actual workload. Wide registers don't owe you a speedup.
*/
