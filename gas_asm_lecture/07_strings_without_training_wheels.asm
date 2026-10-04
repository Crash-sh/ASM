/* ==================== NSD / BYTE STREAMS =======================
    The buffer has no idea it's holding a message. 0x41 could be 'A', 65,
    or part of an instruction. We assign the meaning and enforce the bounds.
    A NUL terminator is a convention. Forget to store it and a scanner can
    keep reading past your message into whatever mapped bytes come next.
    Build: gcc -g -nostdlib -no-pie -x assembler 07_strings_without_training_wheels.asm -o /tmp/strings
    Run /tmp/strings; echo $?     Expected 0.

    .ascii emits exactly the bytes, .asciz adds a zero byte at the end.
    strlen scans until zero and excludes that zero from its result.
    A pointer doesn't carry capacity with it. Unbounded scanning is only
    valid if the caller guarantees a readable terminator. We're using a
    known static source and passing an explicit length to our copy loop.

    ASCII 'a'..'z' are contiguous and 32 above 'A'..'Z'. Subtract 32 only
    AFTER checking the range. Blindly ANDing every character with ~32 also
    mangles punctuation. This is ASCII handling, not Unicode case conversion.
    UTF-8 characters may occupy multiple bytes. Byte count != character count.
*/
.intel_syntax noprefix
.section .rodata
source: .asciz "nsd: port online!"
.equ BYTE_COUNT, . - source - 1
expected: .ascii "NSD: PORT ONLINE!"
.section .bss
destination: .zero BYTE_COUNT + 1
copy_again: .zero BYTE_COUNT + 1
.text
.globl _start
_start:
    lea rsi, [rip + source]
    lea rdi, [rip + destination]
    xor ecx, ecx
copy_loop:
    cmp rcx, BYTE_COUNT
    jae copy_done
    mov al, BYTE PTR [rsi + rcx]
    cmp al, 'a'
    jb store_byte
    cmp al, 'z'
    ja store_byte
    sub al, 'a' - 'A'
store_byte:
    mov BYTE PTR [rdi + rcx], al
    inc rcx
    jmp copy_loop
copy_done:
    mov BYTE PTR [rdi + rcx], 0      # Explicit terminator; capacity includes it.

    # String instructions have implicit operands. Check every register they touch:
    # movsb: copy byte [RSI] -> [RDI], advance/decrement BOTH pointers.
    # stosb: store AL -> [RDI], move RDI. lodsb loads [RSI] -> AL, moves RSI.
    # scasb compares AL with [RDI]; cmpsb compares [RSI] with [RDI].
    # Suffix b/w/d/q chooses element width (1/2/4/8 bytes).
    # DF, the direction flag: 0 moves forward; 1 moves backward.
    # CLD clears DF. STD sets it. SysV requires DF clear at call/return.
    cld
    lea rsi, [rip + destination]
    lea rdi, [rip + copy_again]
    mov ecx, BYTE_COUNT + 1
    rep movsb                      # Copy RCX bytes; ends with RCX=0.
    # RSI/RDI now point past copied bytes. Preserve original addresses if
    # you need them later. REP advances them; no backup copy is maintained.

    lea rsi, [rip + copy_again]
    lea rdi, [rip + expected]
    mov ecx, BYTE_COUNT             # expected has no terminator; exclude it.
    repe cmpsb                     # Repeat while equal AND RCX != 0.
    jne failed
    cmp BYTE PTR [rip + copy_again + BYTE_COUNT], 0
    jne failed

    # A bounded strlen-style search: look for zero within the allocated size.
    lea rdi, [rip + copy_again]
    mov ecx, BYTE_COUNT + 1
    xor eax, eax                   # AL = byte to search for, zero.
    repne scasb                    # Repeat while not equal and count remains.
    jne failed                     # No terminator encountered in this buffer.
    # For a ZERO initial count, these repeat instructions do no work and
    # leave flags alone. Handle that separately in a general helper.
    lea rax, [rip + copy_again]
    sub rdi, rax
    dec rdi                        # RDI advanced past NUL; exclude that byte.
    cmp rdi, BYTE_COUNT
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
    Overlap inspection: a forward copy can destroy source bytes when destination
    begins inside the source at a higher address. memcpy doesn't promise
    overlap support; memmove does. A backward loop can handle that direction.
    If you use STD/rep movsb, start at the LAST byte, handle length=0 before
    subtracting one, and CLD before calling/returning. Leave DF set and the
    next string operation can walk backwards. Restore the fucking state.
    This demo's buffers don't overlap.
    Exercise: write a bounded string-length function returning both length
    and whether it found a terminator. Try capacity 0 and missing terminator.
*/
