; NSD / NASM FIELD EXAMPLE
; Read the matching numbered Markdown lesson one directory above.
; Adapted from gas_asm_lecture/14_x86_32_time_machine.asm.
; Build from extra_sources/nasm: make build/14_x86_32_time_machine
; Each file is a separate program. Do not link all entry points together.
bits 32

section .text
global _start
_start:
; We don't use initial argv here, so safely align down before calls.
    and esp, -16
    sub esp, 8                         ; Padding for two 4-byte stack arguments.
    push 53                            ; Rightmost argument first.
    push 13
    call add_two
    add esp, 16                        ; 8 bytes args + 8 bytes padding.
    cmp eax, 66
    jne failed
    xor ebx, ebx                       ; i386 sys_exit status in EBX.
    jmp finish
failed:
    mov ebx, 53
finish:
    mov eax, 1
    int 0x80

add_two:
    mov eax, dword [esp + 4]           ; [esp] return address, +4 first argument.
    add eax, dword [esp + 8]
    ret
section .note.GNU-stack noalloc noexec nowrite progbits
