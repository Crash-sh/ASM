/* ==================== NSD / FIELD EXERCISE ====================
    Assignment: FizzBuzz. Yeah, seriously. You're wiring the whole path from
    process entry to argument validation to ASCII output without libc.
    Anyone can decorate a terminal with a blacksite banner. Show me a parser
    that rejects overflow and a write loop that accounts for partial output.
    That's how you earn access to the next machine on the bench.

    Build: gcc -g -nostdlib -no-pie -x assembler 12_fizzbuzz_final_boss.asm -o /tmp/fizzbuzz
    Run: /tmp/fizzbuzz          -> lines 1..30
         /tmp/fizzbuzz 16       -> lines 1..16
    Multiples of 3 print Fizz, of 5 Buzz, of both FizzBuzz; others print n.
    Last two lines for 16: FizzBuzz and 16.
    Accept exactly zero or one argument. Optional limit: decimal 1..10000.
    Reject signs, whitespace, empty strings, letters, zero, oversized values.
    Leading zeros are accepted when the final value is nonzero/in range.
    Invalid input -> stderr message, status 13. I/O failure -> status 1.

    ===================== INITIAL STACK =======================
    At Linux x86-64 ELF entry, _start hasn't been called by a C function.
        [rsp]              argc (8-byte slot)
        [rsp+8]            argv[0], pointer to program name
        [rsp+16]           argv[1], if present
        ...                more argv pointers
        [rsp+8*(argc+1)]   NULL terminator for argv array
        ...                envp pointers, NULL, auxiliary vector pairs
    Actual argument strings are elsewhere in initial process memory; these
    slots contain pointers. Don't confuse the pointer array's terminator
    with the zero byte terminating each string. Different objects, different widths.
    We read argc/argv before changing RSP. Linux entry RSP is 16-byte aligned.

    ======================= REGISTER JOBS =====================
    R12 = upper bound, R13 = current number. These survive function calls.
    Other regs are scratch or helper arguments. Avoid RCX for persistent
    state because syscall clobbers it. Every helper below documents its contract.
    No globals for mutable output buffers; decimal conversion uses its stack.

    ======================= PARSING ===========================
    Accumulator starts at 0. Each ASCII digit gives n = n*10 + digit.
    First check the character; then check n <= (limit-digit)/10 BEFORE
    multiplying, so wraparound can't turn a giant input into a valid one.
    For fixed limit=10000 this becomes n<1000, or n==1000 and digit==0.
    This bounds every prefix. A thousand leading zeros is still valid input
    if the eventual number is 1..10000; no fixed input-copy buffer needed.
*/
.intel_syntax noprefix
.equ MAX_LIMIT, 10000
.equ DEFAULT_LIMIT, 30
.section .rodata
fizz: .ascii "Fizz\n"
.equ FIZZ_LEN, . - fizz
buzz: .ascii "Buzz\n"
.equ BUZZ_LEN, . - buzz
fizzbuzz: .ascii "FizzBuzz\n"
.equ FIZZBUZZ_LEN, . - fizzbuzz
usage: .ascii "CRASH: input rejected. Supply one decimal limit from 1 to 10000.\n"
.equ USAGE_LEN, . - usage

.text
.globl _start
_start:
    mov rax, QWORD PTR [rsp]
    mov r12d, DEFAULT_LIMIT
    cmp rax, 1
    je begin
    cmp rax, 2
    jne bad_input
    mov rdi, QWORD PTR [rsp + 16]
    call parse_limit
    test edx, edx
    jnz bad_input
    mov r12, rax
begin:
    mov r13d, 1
next_number:
    # Test divisibility by 15 first so multiples of both don't stop at Fizz.
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
    lea rsi, [rip + fizzbuzz]
    mov edx, FIZZBUZZ_LEN
    jmp print_word
choose_fizz:
    lea rsi, [rip + fizz]
    mov edx, FIZZ_LEN
    jmp print_word
choose_buzz:
    lea rsi, [rip + buzz]
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
    mov edi, 2                     # Error message goes to stderr.
    lea rsi, [rip + usage]
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

/* ====================== FUNCTION BODIES ===================== */
.type parse_limit, @function
parse_limit:
    # RDI: readable NUL-terminated string (provided by process startup).
    # Return RAX=value, EDX=0 on success; EDX=1 on failure, RAX unspecified.
    # Clobbers RAX,RCX,RDX,RDI,flags. Leaf, no callee-saved regs touched.
    xor eax, eax
    cmp BYTE PTR [rdi], 0
    je parse_bad                   # Empty string is not a number.
parse_digit:
    movzx ecx, BYTE PTR [rdi]
    test ecx, ecx
    jz parse_end
    sub ecx, '0'
    cmp ecx, 9
    ja parse_bad                   # Unsigned: also rejects negative differences.
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
    jz parse_bad                   # Range starts at 1, even for "0000".
    xor edx, edx
    ret
parse_bad:
    mov edx, 1
    ret
.size parse_limit, .-parse_limit

.type print_u64, @function
print_u64:
    # RDI = ANY uint64_t, not just the final project's tiny 1..10000 range.
    # Returns write_all's status in RAX. All callee-saved registers preserved.
    # Max uint64_t is 18446744073709551615: 20 digits, plus newline = 21 bytes.
    # Reserve 40: enough storage and proper alignment for nested call.
    # On entry rsp%16=8; subtract 40 (8 mod 16) -> rsp%16=0 before call.
    sub rsp, 40
    lea rsi, [rsp + 39]             # Last byte in our reservation.
    mov BYTE PTR [rsi], 10          # Newline. write uses length, no NUL needed.
    mov rax, rdi
    mov r8d, 1                     # Byte count includes newline already.
    mov r9d, 10
decimal_digit:
    # Repeated unsigned division yields digits backwards: 689 -> 9,8,6.
    # Build BACKWARDS in the buffer so final visible order is 6,8,9.
    xor edx, edx
    div r9                         # quotient in RAX, remainder 0..9 in RDX.
    add dl, '0'                    # 9 the integer becomes '9' the ASCII byte.
    dec rsi
    mov BYTE PTR [rsi], dl
    inc r8
    test rax, rax
    jnz decimal_digit
    # A do-while shape: input zero still emits one '0'. Zero gets tested too.
    mov rdx, r8
    mov edi, 1
    call write_all
    add rsp, 40                    # Buffer stays alive until output completes.
    ret
.size print_u64, .-print_u64

.type write_all, @function
write_all:
    # RDI fd, RSI pointer, RDX count -> RAX=0 or negative error.
    # Same contract as chapter 08; repeated so this file stands alone.
    test rdx, rdx
    jz write_done
write_more:
    mov eax, 1
    syscall
    cmp rax, -4                    # EINTR
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
    mov rax, -5                    # No progress: report EIO rather than spin.
    ret
.size write_all, .-write_all
.section .note.GNU-stack,"",@progbits

/*
    Known limits: one write call sequence per output line; blocking I/O;
    default SIGPIPE disposition, same as chapter 08. Each line is written
    separately so the output path stays easy to inspect. Buffering more lines
    is the obvious next throughput improvement. Start there before showing
    me some unreadable bit trick you haven't fucking measured.

    Exercises:
        0- Buffer multiple lines and flush when full. Keep capacity checks.
        1- Replace repeated division with separate 3/5 countdowns. Compare
           outputs before claiming an optimization victory.
        2- Add signed decimal printing. Don't signed-negate INT64_MIN and
           assume its positive magnitude fits int64_t; use unsigned magnitude.
        3- Replace FizzBuzz with prime printing. Reuse the validated input path.
        4- Add two validated operands and implement the calculator operations.
           Specify overflow and divide-by-zero behavior before adding features.
    Every byte from argv to stdout now has an explanation. That's the standard.
    [field exercise complete / operator: CRASH]
*/
