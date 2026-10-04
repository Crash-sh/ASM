/* ==================== NSD / LEGACY TARGET =====================
    Old hardware records, still live instructions. We're targeting i386 now.
    Recheck the register set, pointer width and syscall interface before
    sending anything. Familiar mnemonics can conceal a different ABI.
    This file is OPTIONAL and excluded from the default 64-bit build.
    Build with binutils, no 32-bit libc installation required:
        as --32 -g 14_x86_32_time_machine.asm -o /tmp/time-machine.o
        ld -m elf_i386 /tmp/time-machine.o -o /tmp/time-machine
        /tmp/time-machine
        echo $?
    Expected exit 0, no output. Or: make check32
    Requires a Linux kernel/runtime that can execute i386 ELF programs.
    A 64-bit CPU alone doesn't guarantee the OS enabled compatibility mode.

    .code32 changes instruction encoding; it doesn't transform a running
    64-bit process into a 32-bit process. ELF class and OS loading matter too.
    --32 and elf_i386 give this file the proper object/executable format.

    Main differences for THIS i386 Linux example:
        eight general-purpose regs EAX EBX ECX EDX ESI EDI EBP ESP
        pointers and ordinary C long are 32 bits (ILP32 ABI)
        ordinary push/pop/call/ret use 4-byte slots
        C cdecl arguments passed on stack, caller reclaims them
        integer result EAX; preserve EBX ESI EDI EBP and restore ESP
        no RIP-relative addressing like our 64-bit examples
        int 0x80 syscall ABI: EAX number, EBX ECX EDX ESI EDI EBP args
        syscall numbers differ: exit=1, write=4 (not 60 and 1)
    Historical i386 ABIs used weaker stack alignment; current GNU/Linux
    conventions commonly require 16-byte alignment before calls. We maintain
    that here too. Don't assume all old 32-bit code obeys the same rules.

    16-bit real mode is another environment, not the same file with AX used
    everywhere. Segments, addresses, startup and available OS services differ.
    Also x32 ABI is NOT i386: it uses 64-bit instruction mode with 32-bit
    pointers and its own ABI details. Check all three: mode, format, ABI.
*/
.intel_syntax noprefix
.code32
.text
.globl _start
_start:
    # We don't use initial argv here, so safely align down before calls.
    and esp, -16
    sub esp, 8                     # Padding for two 4-byte stack arguments.
    push 53                        # Rightmost argument first.
    push 13
    call add_two
    add esp, 16                    # 8 bytes args + 8 bytes padding.
    cmp eax, 66
    jne failed
    xor ebx, ebx                   # i386 sys_exit status in EBX.
    jmp finish
failed:
    mov ebx, 53
finish:
    mov eax, 1
    int 0x80

.type add_two, @function
add_two:
    mov eax, DWORD PTR [esp + 4]    # [esp] return address, +4 first argument.
    add eax, DWORD PTR [esp + 8]
    ret
.size add_two, .-add_two
.section .note.GNU-stack,"",@progbits

/*
    Exercise: objdump -d -Mintel /tmp/time-machine and compare chapter 05's
    add_two. Same mathematical job; different register/stack contracts.
    Don't replace syscall with int 0x80 in a 64-bit file and expect your
    64-bit pointers and argument registers to work. Wrong interface.
    Record the target before reusing instructions from an old dump. Legacy
    systems already have enough unexplained damage without your contribution.
    [legacy inspection complete / return to primary console]
*/
