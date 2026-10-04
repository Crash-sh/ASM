# NASM quick reference — Linux x86-64

Keep this beside the debugger once you have worked through the lessons. Register assignments, widths, build commands: the details I want within reach when something breaks. For an instruction's exact edge cases, open the manual. Memory is a poor substitute for the specification, including mine.

## Build routes

```sh
# Raw entry point (_start), no libc:
nasm -f elf64 -g -F dwarf examples/01_registers_and_sizes.asm -o /tmp/regs.o
ld /tmp/regs.o -o /tmp/regs

# C runtime entry (main), libc calls:
nasm -f elf64 -g -F dwarf examples/06_calling_c_without_pissing_off_the_abi.asm -o /tmp/abi.o
gcc -g -pie /tmp/abi.o -o /tmp/abi
```

Run these from `nasm/`. A `.asm` extension does not force GCC to use NASM. Assemble with NASM explicitly, then link its object.

## Operands and storage

| Form | Meaning |
| --- | --- |
| `mov eax,13` | immediate value into a register; RAX high half cleared |
| `lea rax,[rel item]` | address of local symbol, no dereference |
| `mov eax,[rax]` | load four bytes from the address in RAX |
| `mov byte [rax],13` | store exactly one byte |
| `movzx eax,byte [rsi]` | byte to zero-extended integer |
| `movsxd rax,dword [rsi]` | signed dword to signed qword |
| `dd 13,53` | emit two four-byte elements |
| `resq 2` in BSS | reserve two qwords: sixteen bytes |
| `length equ $-message` | fixed byte-distance constant at assembly time |

## Function versus syscall

| Property | Ordinary SysV scalar function | Raw Linux x86-64 syscall |
| --- | --- | --- |
| Arguments | RDI RSI RDX RCX R8 R9, then stack | RDI RSI RDX R10 R8 R9 |
| Selection | CALL target | RAX syscall number |
| Integer result | RAX | RAX |
| Special clobbers | caller-saved registers per ABI | RCX and R11; RAX result |
| Stack | aligned to 16 before ordinary call | not a CALL return frame |

Functions preserve RBX, RBP, R12–R15 and restore RSP. Vector and aggregate arguments have additional ABI rules. Variadic printf calls require AL to describe vector argument register usage. Syscall numbers here: read 0, write 1, mmap 9, munmap 11, exit 60. Consult [chapter 08](exp/08_syscalls_and_io_thingy.md) for error interpretation.

## Flags and operations

| Operation | Reminder |
| --- | --- |
| `mov`, `lea` | arithmetic flags unchanged |
| `add/sub/cmp` | update arithmetic flags |
| `inc/dec` | preserve CF, change several other flags |
| `xor/and/or/test` | CF/OF clear; ZF/SF/PF from result; AF undefined |
| `adc/sbb` | consume incoming CF |
| `mul r64` | unsigned RAX × operand -> RDX:RAX |
| `div r64` | unsigned RDX:RAX / operand -> quotient RAX, remainder RDX |
| `cqo; idiv r64` | signed division of a sign-extended RAX |
| `setcc al` | writes one byte only |

After `cmp a,b`: unsigned less is `jb`, signed less `jl`; unsigned greater `ja`, signed greater `jg`; equality uses `je` either way. Check flags before any intervening instruction overwrites them.

## Decimal conversion

Parse: validate digit, check bound, then `value = value*10 + digit`.

Format: clear RDX, divide by ten, convert remainder with `'0'`, store one byte backward, repeat until quotient zero. Execute once even for input zero. Maximum uint64 needs twenty digits; reserve twenty-one bytes with newline. Write consumes a pointer plus byte count, not a numeric register value.

## GDB and ELF inspection

```text
set disassembly-flavor intel
break _start
run
si
ni
info registers
x/16bx $rsi
x/4gx $rsp
p/x $rax
disassemble /r _start
```

`readelf -h` shows format/entry, `-S` sections, `-l` segments, `-r` relocations. `objdump -d -Mintel` disassembles; `nm -n` lists ordered symbols.

Before blaming Linux, inspect the failing instruction. Check its width, address, bounds, flags, clobbers, stack state, and mode. The kernel has plenty of real problems; establish that this one belongs to it.
