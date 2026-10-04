# 14 — Optional time machine: Linux i386

> **NSD / LEGACY TARGET** — Old target, different wiring. Check instruction mode, ELF format, and ABI before borrowing code. Recognizing the mnemonics is only the beginning of the inspection.

**Lab:** [i386 example](examples/14_x86_32_time_machine.asm), exit `0` with no output. This target is excluded from the default build.

```sh
make check32
```

Equivalent manual commands:

```sh
nasm -f elf32 -g -F dwarf examples/14_x86_32_time_machine.asm -o /tmp/time-machine.o
ld -m elf_i386 /tmp/time-machine.o -o /tmp/time-machine
/tmp/time-machine
echo $?
```

No 32-bit libc is required because the program uses a raw syscall. The OS must support executing i386 ELF; a 64-bit CPU alone does not establish that. A runtime without compatibility support may reject the executable.

## What changes?

| Contract | x86-64 course | i386 example |
| --- | --- | --- |
| Object format | elf64 | elf32 |
| General registers | 16 wide registers | EAX EBX ECX EDX ESI EDI EBP ESP |
| Pointer / C long | 64 / 64 bits | 32 / 32 bits |
| Ordinary call return slot | 8 bytes | 4 bytes |
| C integer arguments | first six in registers | on stack for cdecl |
| Raw syscall instruction | syscall | int 0x80 |
| Syscall number register | RAX | EAX |
| Syscall argument registers | RDI RSI RDX R10 R8 R9 | EBX ECX EDX ESI EDI EBP |
| exit / write numbers | 60 / 1 | 1 / 4 |

![Mode, ELF format, and ABI must agree; changing BITS alone does not change the running process.](diagrams/14_modes.png)

`bits 32` tells NASM how to encode instructions. It does not switch a running 64-bit process into compatibility mode. The executable format and OS loader participate in selecting execution mode. Likewise, `bits 16` doesn't summon firmware, arrange startup, or make a boot sector. Bare metal is where we inherit all that work Linux used to do.

## Trace the stack arguments

The sample aligns ESP, reserves eight bytes of padding, pushes 53, then pushes 13. Before CALL, the stack is aligned to sixteen bytes. CALL pushes a four-byte return address.

At `add_two` entry, `[esp]` is return address, `[esp+4]` is 13, and `[esp+8]` is 53. The helper loads EAX and adds the second argument, then returns. The caller releases sixteen bytes: eight argument bytes plus eight padding bytes.

Modern GNU/Linux conventions commonly use sixteen-byte alignment before calls; do not assume every historical i386 binary used identical alignment requirements. The sample makes its chosen rule explicit.

## Familiar instructions, wrong interface

Replacing `syscall` with `int 0x80` in a 64-bit program does not preserve the argument convention or syscall numbering. Addresses can be truncated under an incompatible interface. Replacing RAX with EAX throughout a file likewise does not update pointer layouts, stack slot sizes, and relocations correctly.

And because the naming wasn't crowded enough, there's x32: 64-bit instruction mode, 32-bit pointers, another set of ABI rules. It is not this i386 lesson. Sixteen-bit real mode is different again, involving segmentation and a different startup environment.

**Drill:** disassemble both the 64-bit stack example and this one. Mark every argument source, return-address width, and stack adjustment. The arithmetic result is still 66; the binary interface that produces it changed.

---

[Course map](README.md) · [Previous: 13](13_debugging_and_reading_the_nudes.md) · [Next: 15](15_your_input_program_from_bytes_to_number.md)

Companion: [original GAS lecture](../../gas_asm_lecture/14_x86_32_time_machine.asm).

Manuals: [reference index](REFERENCES.md).
