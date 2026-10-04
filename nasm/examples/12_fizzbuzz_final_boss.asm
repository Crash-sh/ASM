; NSD / NASM FIELD EXAMPLE
; Read the matching numbered Markdown lesson one directory above.
; Adapted from gas_asm_lecture/12_fizzbuzz_final_boss.asm.
; Build from extra_sources/nasm: make build/12_fizzbuzz_final_boss
; Each file is a separate program. Do not link all entry points together.
bits 64
default rel

MAX_LIMIT equ 10000
DEFAULT_LIMIT equ 30
section .rodata
fizz: db "Fizz", 10
FIZZ_LEN equ $ - fizz
buzz: db "Buzz", 10
BUZZ_LEN equ $ - buzz
fizzbuzz: db "FizzBuzz", 10
FIZZBUZZ_LEN equ $ - fizzbuzz
usage: db "CRASH: input rejected. Supply one decimal limit from 1 to 10000.", 10
USAGE_LEN equ $ - usage

section .text
global _start
_start:
    mov rax, qword [rsp]
    mov r12d, DEFAULT_LIMIT
    cmp rax, 1
    je begin
    cmp rax, 2
    jne bad_input
    mov rdi, qword [rsp + 16]
    call parse_limit
    test edx, edx
    jnz bad_input
    mov r12, rax
begin:
    mov r13d, 1
next_number:
; Test divisibility by 15 first so multiples of both don't stop at Fizz.
    mov rax, r13
    xor edx, edx
    mov ecx, 15
    div rcx
    test rdx, rdx
    jz choose_fizzbuzz
    mov rax, r13
    xor edx, edx
    mov ecx, 3
    div rcx
    test rdx, rdx
    jz choose_fizz
    mov rax, r13
    xor edx, edx
    mov ecx, 5
    div rcx
    test rdx, rdx
    jz choose_buzz

    mov rdi, r13
    call print_u64
    jmp output_checked
choose_fizzbuzz:
    lea rsi, [rel fizzbuzz]
    mov edx, FIZZBUZZ_LEN
    jmp print_word
choose_fizz:
    lea rsi, [rel fizz]
    mov edx, FIZZ_LEN
    jmp print_word
choose_buzz:
    lea rsi, [rel buzz]
    mov edx, BUZZ_LEN
print_word:
    mov edi, 1
    call write_all
output_checked:
    test rax, rax
    js io_failed
    inc r13
    cmp r13, r12
    jbe next_number
    xor edi, edi
    jmp finish
bad_input:
    mov edi, 2                         ; Error message goes to stderr.
    lea rsi, [rel usage]
    mov edx, USAGE_LEN
    call write_all
    test rax, rax
    js io_failed
    mov edi, 13
    jmp finish
io_failed:
    mov edi, 1
finish:
    mov eax, 60
    syscall

parse_limit:
; RDI: readable NUL-terminated string (provided by process startup).
; Return RAX=value, EDX=0 on success; EDX=1 on failure, RAX unspecified.
; Clobbers RAX,RCX,RDX,RDI,flags. Leaf, no callee-saved regs touched.
    xor eax, eax
    cmp byte [rdi], 0
    je parse_bad                       ; Empty string is not a number.
parse_digit:
    movzx ecx, byte [rdi]
    test ecx, ecx
    jz parse_end
    sub ecx, '0'
    cmp ecx, 9
    ja parse_bad                       ; Unsigned: also rejects negative differences.
    cmp rax, MAX_LIMIT / 10
    ja parse_bad
    jb accumulate
    cmp ecx, MAX_LIMIT % 10
    ja parse_bad
accumulate:
    imul rax, rax, 10
    add rax, rcx
    inc rdi
    jmp parse_digit
parse_end:
    test rax, rax
    jz parse_bad                       ; Range starts at 1, even for "0000".
    xor edx, edx
    ret
parse_bad:
    mov edx, 1
    ret

print_u64:
; RDI = ANY uint64_t, not just the final project's tiny 1..10000 range.
; Returns write_all's status in RAX. All callee-saved registers preserved.
; Max uint64_t is 18446744073709551615: 20 digits, plus newline = 21 bytes.
; Reserve 40: enough storage and proper alignment for nested call.
; On entry rsp%16=8; subtract 40 (8 mod 16) -> rsp%16=0 before call.
    sub rsp, 40
    lea rsi, [rsp + 39]                ; Last byte in our reservation.
    mov byte [rsi], 10                 ; Newline. write uses length, no NUL needed.
    mov rax, rdi
    mov r8d, 1                         ; Byte count includes newline already.
    mov r9d, 10
decimal_digit:
; Repeated unsigned division yields digits backwards: 689 -> 9,8,6.
; Build BACKWARDS in the buffer so final visible order is 6,8,9.
    xor edx, edx
    div r9                             ; quotient in RAX, remainder 0..9 in RDX.
    add dl, '0'                        ; 9 the integer becomes '9' the ASCII byte.
    dec rsi
    mov byte [rsi], dl
    inc r8
    test rax, rax
    jnz decimal_digit
; A do-while shape: input zero still emits one '0'. Zero gets tested too.
    mov rdx, r8
    mov edi, 1
    call write_all
    add rsp, 40                        ; Buffer stays alive until output completes.
    ret

write_all:
; RDI fd, RSI pointer, RDX count -> RAX=0 or negative error.
; Same contract as chapter 08; repeated so this file stands alone.
    test rdx, rdx
    jz write_done
write_more:
    mov eax, 1
    syscall
    cmp rax, -4                        ; EINTR
    je write_more
    test rax, rax
    js write_return
    jz write_stalled
    add rsi, rax
    sub rdx, rax
    jnz write_more
write_done:
    xor eax, eax
write_return:
    ret
write_stalled:
    mov rax, -5                        ; No progress: report EIO rather than spin.
    ret
section .note.GNU-stack noalloc noexec nowrite progbits
