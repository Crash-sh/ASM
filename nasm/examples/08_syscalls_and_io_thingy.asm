; NSD / NASM FIELD EXAMPLE
; Read the matching numbered Markdown lesson one directory above.
; Adapted from gas_asm_lecture/08_syscalls_and_io_thingy.asm.
; Build from extra_sources/nasm: make build/08_syscalls_and_io_thingy
; Each file is a separate program. Do not link all entry points together.
bits 64
default rel

SYS_READ equ 0
SYS_WRITE equ 1
SYS_EXIT equ 60
EINTR equ 4
CAPACITY equ 4096                      ; Buffer size, not a claim about all page sizes.
section .bss
buffer: resb CAPACITY
section .text
global _start
_start:
read_again:
    mov eax, SYS_READ
    xor edi, edi                       ; stdin
    lea rsi, [rel buffer]
    mov edx, CAPACITY
    syscall
    cmp rax, -EINTR
    je read_again
    test rax, rax
    js io_failed
    jz success                         ; EOF, not 'try again forever'.

    mov rdx, rax                       ; Only the bytes we actually received.
    mov edi, 1
    call write_all                     ; RSI still holds the buffer address.
    test rax, rax
    js io_failed
    jmp read_again
success:
    xor edi, edi
    jmp finish
io_failed:
    mov edi, 1
finish:
    mov eax, SYS_EXIT
    syscall

write_all:
; Contract: RDI fd, RSI readable pointer, RDX length.
; Result: RAX=0 success, negative raw error otherwise.
; Clobbers RAX,RCX,R11,RSI,RDX,flags; preserves callee-saved registers.
; Empty writes succeed without touching the buffer.
    test rdx, rdx
    jz write_done
write_more:
    mov eax, SYS_WRITE
    syscall
    cmp rax, -EINTR
    je write_more                      ; No progress reported; retry same range.
    test rax, rax
    js write_return
    jz write_stalled                   ; Avoid infinite retry if no bytes move.
    add rsi, rax                       ; Skip the bytes successfully written.
    sub rdx, rax                       ; Decrease remaining count by exactly that.
    jnz write_more
write_done:
    xor eax, eax
write_return:
    ret
write_stalled:
    mov rax, -5                        ; Our helper reports -EIO for no progress.
    ret
section .note.GNU-stack noalloc noexec nowrite progbits
