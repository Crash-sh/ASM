%ifdef COMMENT 

    [Link Established]
    Operator : CRASH
    Division : Hardware / Architecture / Special Projects
    Target   : x86-64

    Project: nasm_experiments/sieve.asm
    Objective: Implement the Sieve of Eratosthenes algorithm in x86-64 assembly using NASM syntax.

    Algorithm Overview: 

    1. Create a byte array with indices 0 through N, initially zero. Use 0 for “not marked” and 1 for “not prime.”
    2. Mark 0 and 1.
    3. Starting with p = 2, if p is unmarked, mark its multiples starting at p * p.
    4. Repeat while p * p <= N.
    5. The unmarked indices from 2 through N are primes. Start at p * p because smaller multiples were already marked by smaller primes.

%endif 


bits 64
default rel

%define N 500

section .bss
    sieve resb N+1 ;
    buf resb 21


section .text
    global _start

_start:
    lea rdi, [rel sieve]  ; Load address of sieve array into rdi
    mov byte [rdi], 1         ; 0 as not prime
    mov byte [rdi + 1], 1     ; 1 is also not a prime

    mov ecx, 2          ; Start with p = 2
    
.next_candidate:
    mov eax, ecx
    imul eax, eax
    cmp eax, N
    ja .print_primes

    cmp byte [rdi + rcx], 0
    jne .move_on

.mark_multiples:
    mov byte [rdi + rax], 1
    add eax, ecx
    cmp eax, N
    jbe .mark_multiples

.move_on:
    inc ecx
    jmp .next_candidate

.print_primes:
    lea r12, [rel sieve]     ; Keep array address across writes
    mov r13d, 2              ; Number to check

.scan:
    cmp r13d, N
    ja .done

    cmp byte [r12 + r13], 0
    jne .next_number        ; Composite: fucking skip it

    ; Convert the prime to decimal text, working backward.
    mov eax, r13d
    lea rsi, [rel buf + 20]
    mov byte [rsi], 10       ; Newline at the end
    mov ebx, 1              ; Output length, including newline
    mov ecx, 10             ; Decimal divisor

.convert:
    xor edx, edx            ; DIV uses EDX:EAX as its dividend
    div ecx                 ; EAX = quotient, EDX = remainder
    add dl, '0'             ; Digit value -> ASCII
    dec rsi
    mov [rsi], dl
    inc ebx
    test eax, eax
    jnz .convert

    ; write(stdout, first_digit, length)
    mov edx, ebx
    mov edi, 1
    mov eax, 1
    syscall

.next_number:
    inc r13d
    jmp .scan

.done:
    mov eax, 60
    xor edi, edi
    syscall