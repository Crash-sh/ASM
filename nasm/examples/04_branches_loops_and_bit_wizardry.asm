; NSD / NASM FIELD EXAMPLE
; Read the matching numbered Markdown lesson one directory above.
; Adapted from gas_asm_lecture/04_branches_loops_and_bit_wizardry.asm.
; Build from extra_sources/nasm: make build/04_branches_loops_and_bit_wizardry
; Each file is a separate program. Do not link all entry points together.
bits 64
default rel

section .text
global _start
_start:
    mov eax, -1
    cmp eax, 1
    jge failed                         ; Signed -1 isn't >= 1.
    jbe failed                         ; Unsigned 4294967295 isn't <= 1 either.

; int max = (a > b) ? a : b; signed comparison.
    mov eax, 13
    mov edx, 53
    cmp eax, edx
    cmovl eax, edx                     ; If signed less, take b.
    cmp eax, 53
    jne failed
    sete al                            ; AL=1; doesn't clear upper EAX by itself.
    movzx eax, al                      ; Now clean 0/1 in the whole register.
    cmp eax, 1
    jne failed

; for (i=1,sum=0; i<=10; ++i) sum+=i;
    xor eax, eax
    mov ecx, 1
sum_loop:
    cmp ecx, 10
    ja sum_done                        ; Top-tested loop: body can execute zero times.
    add eax, ecx
    inc ecx
    jmp sum_loop
sum_done:
    cmp eax, 55
    jne failed
; dec ecx / jnz works for countdowns too, but initial zero would underflow
; if you enter the body first. Explicitly handle empty counts.
; x86 has a LOOP instruction; ordinary cmp/dec+jcc is clearer here and
; LOOP isn't universally fast. I want timings, not mnemonic worship.

; Bit masks: AND keeps selected bits, OR sets them, XOR toggles them.
    mov eax, 0b1010
    or eax, 0b0100                     ; 1110
    and eax, 0b1101                    ; 1100
    xor eax, 0b1000                    ; 0100
    test eax, 0b0100
    jz failed                          ; Selected bit should be set.
    not eax                            ; Flip ALL 32 bits; doesn't change flags.
    cmp eax, 0xfffffffb
    jne failed

    mov eax, 13
    shl eax, 2                         ; 52, low 32 bits of multiplying by 4.
    shr eax, 1                         ; 26, zero bits enter at the top.
    cmp eax, 26
    jne failed
    mov eax, -3
    sar eax, 1                         ; -2: signed shift rounds toward NEGATIVE infinity.
    cmp eax, -2                        ; idiv by 2 gives -1. Different rounding contract.
    jne failed
; SHL/SAL are aliases. SHR zero-fills, SAR sign-fills, ROL/ROR rotate
; bits back around. CF gets the last shifted-out bit for ordinary small
; nonzero shifts. OF generally has a defined meaning only for count 1.
; Avoid depending on flags for large counts; consult the ISA manual.

    mov eax, 0x80000001
    rol eax, 1
    cmp eax, 3
    jne failed
    mov ecx, 32
    shl eax, cl                        ; Variable count is CL for this instruction.
    cmp eax, 3                         ; 32-bit shift count masked to 5 bits: 32 -> 0!
    jne failed
; 64-bit operands use 6 count bits (mod 64); 8/16-bit use 5 too.
; C shifts by >= operand width are UB. Hardware masking doesn't fix C.

; Popcount without needing the optional POPCNT CPU feature:
; while (x) { x &= x-1; ++count; } removes the lowest set bit each lap.
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
section .note.GNU-stack noalloc noexec nowrite progbits
