; NSD / INPUT INCIDENT RECONSTRUCTION
; Read 15_your_input_program_from_bytes_to_number.md one directory above.
; Standalone snapshot of nasm_experiments/01_user_input.asm.
; Build: make build/15_user_input (from extra_sources/nasm).
; Domain: 1..12 unsigned decimal digits, one read, optional final newline.
; This introductory example does not loop over short reads/writes or check
; write errors. Chapter 08 provides the fuller I/O contract.
bits 64
default rel

section .data
    txt db "Enter a number: "
    len equ $ - txt                    ; write uses a byte count, not a NUL terminator
    err_txt db "Enter 1 to 12 decimal digits (no sign).", 10
    err_len equ $ - err_txt

section .bss
    num resb 13                        ; up to 12 digits plus a newline
    result resb 21                     ; room for a 64-bit unsigned number plus a newline

section .text
    global _start

_start:
    call _print_prompt
    call _read_input                   ; rax = number of bytes read, or a negative error
    test rax, rax
    jle _invalid_input
    call _convert_to_int               ; rax = parsed number
    call _add_to_int
    call _iota                         ; rsi = first output byte, rdx = output length
    call _print_result

    mov eax, 60                        ; exit(0)
    xor edi, edi
    syscall

_print_prompt:
    mov eax, 1                         ; write(stdout, txt, len)
    mov edi, 1
    lea rsi, [txt]
    mov edx, len
    syscall                            ; clobbers rcx and r11; returns the byte count in rax
    ret

_read_input:
    xor eax, eax                       ; read(stdin, num, 13)
    xor edi, edi
    lea rsi, [num]
    mov edx, 13
    syscall                            ; read does not append a NUL terminator
    ret

_convert_to_int:
    mov rcx, rax                       ; only inspect bytes actually returned by read
    lea rsi, [num]
    xor eax, eax                       ; accumulated value
    xor r8d, r8d                       ; digit count

.loop:
    test rcx, rcx
    jz .done
    movzx edx, byte [rsi]
    cmp dl, 10                         ; stop at newline
    je .done
    sub edx, '0'
    cmp edx, 9                         ; unsigned comparison also rejects characters below '0'
    ja _invalid_input
    cmp r8d, 12
    jae _invalid_input
    imul rax, rax, 10
    add rax, rdx                       ; value = value * 10 + digit
    inc r8d
    inc rsi
    dec rcx
    jmp .loop

.done:
    test r8d, r8d
    jz _invalid_input
    ret

_add_to_int:
    add rax, 13                        ; 12 input digits plus 13 fit comfortably in 64 bits
    ret

_iota:
    ; Division produces digits from right to left. Store consecutive bytes
    ; backwards in result, leaving the call's return address untouched.
    lea rsi, [result + 20]
    mov byte [rsi], 10                 ; trailing newline
    mov ecx, 1                         ; output length, including newline
    mov r8d, 10

.loop:
    xor edx, edx
    div r8                             ; quotient in rax, remainder in rdx
    add dl, '0'
    dec rsi
    mov [rsi], dl
    inc ecx
    test rax, rax
    jnz .loop

    mov edx, ecx                       ; return the byte count alongside the pointer in rsi
    ret

_print_result:
    mov eax, 1                         ; write(stdout, rsi, rdx)
    mov edi, 1
    syscall
    ret

_invalid_input:
    mov eax, 1                         ; write(stderr, err_txt, err_len)
    mov edi, 2
    lea rsi, [err_txt]
    mov edx, err_len
    syscall
    mov eax, 60                        ; exit(1); no need to unwind calls when exiting
    mov edi, 1
    syscall

section .note.GNU-stack noalloc noexec nowrite progbits
