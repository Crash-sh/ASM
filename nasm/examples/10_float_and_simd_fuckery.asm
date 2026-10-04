; NSD / NASM FIELD EXAMPLE
; Read the matching numbered Markdown lesson one directory above.
; Adapted from gas_asm_lecture/10_float_and_simd_fuckery.asm.
; Build from extra_sources/nasm: make build/10_float_and_simd_fuckery
; Each file is a separate program. Do not link all entry points together.
bits 64
default rel

section .rodata
align 16
left: dd 13, 53, 689, -1
right: dd 1, 2, 3, 4
expected: dd 14, 55, 692, 3
align 8
half: dq 0.5
answer: dq 27.0
not_a_number: dq 0x7ff8000000000000    ; Quiet NaN bit pattern, not an integer conversion.
section .bss
alignb 16
packed_result: resb 16
section .text
global _start
_start:
    mov eax, 13
    cvtsi2sd xmm0, eax                 ; Numeric signed int -> double (13.0).
    addsd xmm0, qword [rel half]       ; 13.5, exactly representable in binary.
    addsd xmm0, xmm0                   ; 27.0
    ucomisd xmm0, qword [rel answer]
    jp failed                          ; PF=1: unordered. Check this before trusting ZF.
    jne failed
    cvttsd2si eax, xmm0                ; Convert double -> signed int, truncate to zero.
    cmp eax, 27
    jne failed
; CVTSD2SI follows MXCSR rounding; CVTTSD2SI explicitly truncates.
; Out-of-range/NaN conversion raises invalid; with exceptions masked
; the integer-indefinite result can equal INT_MIN. Validate input ranges
; if that distinction matters. Bit-copy MOVQ is not numeric conversion.

    movsd xmm1, qword [rel not_a_number]
    ucomisd xmm1, xmm0
    jnp failed                         ; NaN is unordered with everything, even itself.
; For ordered comparisons: greater gives ZF/PF/CF=000, less=001,
; equal=100, unordered=111. Check JP before JE/JB when NaN is possible.
; Sign/overflow flags are cleared; use unsigned-style conditions here.

    movdqu xmm0, oword [rel left]
    movdqu xmm1, oword [rel right]
    paddd xmm0, xmm1                   ; Four independent int32 additions.
    movdqu oword [rel packed_result], xmm0
; MOVDQU allows unaligned addresses, MOVDQA requires 16-byte alignment.
; Unaligned doesn't mean out-of-bounds allowed: both touch 16 bytes.
    lea rsi, [rel packed_result]
    lea rdi, [rel expected]
    xor ecx, ecx
verify_lane:
    mov eax, dword [rsi + rcx*4]
    cmp eax, dword [rdi + rcx*4]
    jne failed
    inc ecx
    cmp ecx, 4
    jb verify_lane

; Reduce four lanes with SSE2 shifts and adds: horizontal sum = 764.
    movdqa xmm1, xmm0                  ; Register->register, no alignment question.
    psrldq xmm1, 8                     ; Shift whole vector right by EIGHT BYTES.
    paddd xmm0, xmm1                   ; Low lanes now a+c and b+d.
    movdqa xmm1, xmm0
    psrldq xmm1, 4
    paddd xmm0, xmm1
    movd eax, xmm0                     ; Copy low 32 bits to EAX (no FP conversion).
    cmp eax, 764
    jne failed
    xor edi, edi
    jmp finish
failed:
    mov edi, 53
finish:
    mov eax, 60
    syscall
section .note.GNU-stack noalloc noexec nowrite progbits
