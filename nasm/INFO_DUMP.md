# INFO DUMP — know the machine before arguing with it

> **NSD / BACKGROUND BRIEFING** — Assembly removes a lot of conveniences. It does not remove the agreements underneath them. Before we start moving registers around, find out who expects what to be in them.

Read this before [chapter 00](00_start_here.md), or keep it open when a lesson throws another acronym at you. You do not need to memorize the whole file before writing an instruction. Learn enough to identify which part of the system you are currently breaking.

## Contents

- [The layers people keep mixing together](#the-layers-people-keep-mixing-together)
- [What an ABI actually is](#what-an-abi-actually-is)
- [Why there are different ABIs](#why-there-are-different-abis)
- [Four calling conventions on the bench](#four-calling-conventions-on-the-bench)
- [The background knowledge worth bringing](#the-background-knowledge-worth-bringing)
- [Porting assembly: specify the destination](#porting-assembly-specify-the-destination)
- [One function, four implementations](#one-function-four-implementations)
- [A porting workflow that catches the expensive mistakes](#a-porting-workflow-that-catches-the-expensive-mistakes)
- [Readiness check](#readiness-check)

## The layers people keep mixing together

| Layer | What it defines | Example |
| --- | --- | --- |
| ISA: instruction set architecture | Instructions, registers, encodings, architectural effects | x86-64, AArch64, RISC-V RV64 |
| Microarchitecture | How a particular CPU implements an ISA | Pipelines, caches, execution units, speculation |
| Assembly dialect | How source spells instructions and directives | NASM Intel syntax, GAS Intel/AT&T syntax |
| ABI: application binary interface | Agreements between separately built binary components | System V AMD64, Microsoft x64, AAPCS64 |
| OS interface | Services, handles/descriptors, syscall conventions | Linux read/write and raw syscall entry |
| Object/executable format | Organization of code, symbols, relocations, loader metadata | ELF, PE/COFF, Mach-O |
| Runtime/library | Startup, allocation, formatting, language support | libc, a C++ runtime |

The lines interact, but they do different jobs. NASM is an assembler for the x86 family. It does not become an Arm assembler because you change a register name. GAS supports different targets through the appropriate build/toolchain; Intel versus AT&T syntax is a separate x86 spelling choice. See the [NASM manual](https://www.nasm.us/doc/) and [GNU assembler manual](https://sourceware.org/binutils/docs/as/).

Likewise, two processors implementing the same required ISA can run the same instructions while taking different numbers of cycles. That is why the target's optional extensions and the performance measurements both matter.

Record a target completely enough to build for it:

```text
CPU/mode     : x86-64, 64-bit userspace
OS           : Linux
ABI          : System V AMD64, LP64 data model
source       : NASM Intel syntax
object       : ELF64
entry        : _start, raw syscalls, no libc
ISA baseline : instructions supported by the intended machines
```

“64-bit assembly” leaves most of that unspecified. The missing details are usually where the interesting failures live.

## What an ABI actually is

An **application binary interface** is the agreement that lets compiled pieces of a program cooperate without sharing their source code.

Suppose C declares:

```c
#include <stdint.h>
uint64_t add_two(uint64_t a, uint64_t b);
```

That declaration tells the C compiler what the function means at the source interface: its name, parameter types, and result type. The ABI tells it how to make the actual binary call. Which registers carry `a` and `b`? Where does the result appear? What must the callee preserve? How is the stack arranged?

The **API**, or application programming interface, describes how source code uses a component. The ABI describes how its binary pieces fit together. A matching header is useful, but it cannot repair a function assembled for the wrong calling convention.

### Calling convention is only part of it

An ABI can cover:

- Argument and return-value placement, including stack arguments and hidden parameters.
- Registers the callee must preserve and registers the caller must treat as disposable.
- Stack alignment, frame layout, and rules for special storage areas.
- Sizes, alignment, and layout of language data types and structures.
- Symbol naming, relocation conventions, and cooperation with the object format.
- Unwinding, exception handling, thread-local storage, and language-specific machinery.

A register table is the first page of the paperwork. It is not the whole specification. A scalar integer function can be easy to connect; returning a large struct or throwing a C++ exception across a boundary involves more rules. The [x86-64 psABI project](https://gitlab.com/x86-psABIs/x86-64-ABI) is the primary reference for the System V interface used in these lessons.

### Caller-saved and callee-saved: who owes the old value?

The **caller** makes the call. The **callee** is the function being called.

If a register is caller-saved, the caller saves any live value it needs after the call. The callee may overwrite it. If a register is callee-saved, the callee must restore the incoming value before returning if it uses that register.

The CPU does not maintain an ABI violation counter. A callee can trash a preserved register and return normally. The caller discovers the damage when its supposedly intact value is used three instructions later.

Private routines can use a custom agreement when you control every caller. Write it down. The moment you call external code, return to external code, or expose a function to C, you need the agreed platform interface at that boundary. “Works inside my program” is not a calling convention you can hand to a linker.

### The ABI does not define your whole algorithm

It can tell you where a pointer goes without proving the pointer is valid. It can specify an integer return register without choosing whether your arithmetic rejects overflow. Those are additional function contracts: input domain, bounds, lifetime, error handling, and arithmetic policy.

For every helper, record inputs, output, clobbers, and failure behavior. Then record the ABI through which callers obtain that behavior. Both layers need to agree.

## Why there are different ABIs

There is no universal register arrangement the CPU forces every language and OS to use. Platform designers have choices, and existing binaries make those choices expensive to change.

**Different hardware provides different machinery.** Register counts, instruction sets, stack behavior, and floating-point facilities influence how a calling convention is designed. An interface built around x86's registers cannot literally use those names on Arm.

**Different platforms make different tradeoffs on the same hardware.** Windows x64 and System V AMD64 both use x86-64 instructions, but they make different decisions about argument registers, preservation, stack areas, and runtime integration. The CPU's ADD instruction does not settle any of those questions.

**History matters.** Once libraries, applications, debuggers, and language runtimes use an ABI, changing it can break already shipped binaries. A new architecture or mode is an opportunity for a different design; maintaining compatibility can also require keeping old interfaces alive.

**Data models and feature choices differ.** A platform may use 32-bit pointers in a 64-bit instruction mode, or choose an ABI that passes floating-point values through different register classes. Compiler target options can select materially different interfaces. Merely agreeing on the processor family is insufficient.

### A data-model trap from C

On conventional 64-bit Linux x86-64, LP64 means `int` is 32 bits, `long` and pointers are 64. Windows x64 uses LLP64: `int` and `long` remain 32 bits, pointers are 64. Microsoft's [data model description](https://learn.microsoft.com/en-us/windows/win32/winprog64/abstract-data-models) documents that choice.

Consequently, a C prototype using `long` can describe a different-width operation on the other platform. For the porting example below, `uint64_t` states the intended width explicitly. It still does not prescribe which register carries it.

Structure layout also follows the target's rules. A member after a `char` does not necessarily start at byte 1. Check `sizeof`, alignment, and `offsetof` on the destination. Copying the old offset constants without checking them is an efficient way to corrupt the wrong field.

## Four calling conventions on the bench

This table covers **ordinary integer/pointer scalar arguments only**. Floating-point, variadic, aggregate, and vector arguments need their own rules.

| Destination | Initial integer argument registers | One 64-bit integer result | Return-address mechanism |
| --- | --- | --- | --- |
| Linux x86-64, System V AMD64 | RDI, RSI, RDX, RCX, R8, R9 | RAX | CALL pushes address on stack |
| Windows x64, default Microsoft convention | RCX, RDX, R8, R9 | RAX | CALL pushes address on stack |
| Linux AArch64, ordinary AAPCS64 calls | X0–X7 | X0 | BL places address in X30/LR |
| Linux RV64, standard integer convention | a0–a7 | a0 | A call normally puts address in ra/x1 |

Sources: [System V AMD64](https://gitlab.com/x86-psABIs/x86-64-ABI), [Microsoft x64](https://learn.microsoft.com/en-us/cpp/build/x64-calling-convention?view=msvc-170), [Arm AAPCS64](https://github.com/ARM-software/abi-aa/blob/main/aapcs64/aapcs64.rst), and [RISC-V psABI](https://riscv-non-isa.github.io/riscv-elf-psabi-doc/).

Windows x64 callers reserve a 32-byte shadow area for register arguments even when the callee does not use it. SysV's userspace red zone is a different facility; do not copy assumptions about it into Windows code. For ordinary scalar calls on either of these x86-64 interfaces, the stack is aligned to 16 before CALL, and the pushed return address changes its alignment at callee entry. Microsoft's [stack usage documentation](https://learn.microsoft.com/en-us/cpp/build/stack-usage?view=msvc-170) explains its frame rules.

On AArch64, BL overwrites the link register. A routine that makes another call must protect its own return address as needed, commonly by saving it in a properly aligned frame. A leaf like our example can return through X30 without creating a frame. See [AAPCS64](https://github.com/ARM-software/abi-aa/blob/main/aapcs64/aapcs64.rst).

RISC-V similarly uses a return-address register. The ordinary RV64 ABI uses a 16-byte-aligned stack; ra is not callee-saved. A non-leaf routine must keep its own return route intact. These are the standard ABI's rules, not a claim about every possible embedded variant. See the [RISC-V calling convention](https://riscv-non-isa.github.io/riscv-elf-psabi-doc/).

### A syscall has another interface

A normal C call and a raw syscall are different boundaries. In our Linux x86-64 programs, function argument four uses RCX while syscall argument four uses R10. SYSCALL clobbers RCX and R11. Keep those contracts in separate notes.

A Linux syscall number is also architecture-specific. Moving to AArch64 or RISC-V requires checking the syscall instruction, number register, arguments, results, and error protocol. Moving to another OS requires checking its supported service interface altogether. For Windows application code, use the documented APIs instead of transplanting Linux calls or assuming raw service numbers are a stable public interface. Start with [Linux syscall(2)](https://man7.org/linux/man-pages/man2/syscall.2.html) for the Linux architectures.

## The background knowledge worth bringing

### Bits, bases, and finite arithmetic

A bit is zero or one; a byte is eight bits on our targets. Hex is a compact spelling: one hex digit represents four bits. `0x41`, decimal 65, and ASCII `A` can refer to the same byte under different interpretations.

A register has a fixed width. Eight bits provide 256 patterns. Unsigned interpretation gives 0..255; signed two's complement gives −128..127. Signedness is not a sticker attached to the register. Instructions, extensions, comparisons, and our interpretation determine the meaning.

Practice converting small binary/hex values, setting a bit with OR, clearing bits with AND, and identifying the top bit. Understand that arithmetic can wrap and that a processor's overflow behavior is not automatically the C language's rule. [Chapters 01](01_registers_and_sizes.md) and [03](03_arithmetic_and_flag_drama.md) do the actual register work.

### Addresses, values, and bounds

An address identifies a location. The bytes stored there are another value. A pointer variable can itself contain an address, so loading the pointer and following it are two distinct operations.

Arrays need element sizes and counts. A pointer alone does not carry either. Endianness describes how a multibyte value's bytes are arranged; alignment describes address constraints or preferences for an object/access. Neither establishes whether an access stays inside the object.

You should be able to draw four bytes containing an integer, a separate eight-byte pointer to them, and the result of loading through that pointer. If the drawing is unclear, slow down in [chapter 02](02_memory_and_pointer_hell.md). Memory bugs are easier to understand before the addresses become a thousand lines of hex.

### Stack, lifetime, and control flow

Understand assignment, conditions, loops, and function calls from any programming language. At machine level these become explicit data movement, comparisons, branches, and call/return mechanisms.

The stack holds temporary state and often saved registers or return addresses. Static storage, stack locals, and dynamically allocated objects have different lifetimes. Copying a pointer does not extend an object's lifetime. Returning the address of a discarded stack local can look fine until the next call reuses the bytes. That's a bug with good timing, not successful memory management.

Learn the difference between a value and its representation, and between an object being mapped and still belonging to you. [Chapter 05](05_stack_calls_and_recursion.md) traces the stack; [chapter 09](09_mmap_and_structs_in_the_wild.md) handles dynamic mappings.

### Enough C to read the interface

Useful C topics: integer types, arrays, `&`, `*`, pointer arithmetic, structs, function prototypes, and `sizeof`. Fixed-width types and `offsetof` are particularly helpful for assembly interfaces.

You do not need C mastery to start. You do need to understand that `*p` accesses an object while `p` holds its address. When inspecting compiler output, remember that optimized C can omit variables and rearrange work. Undefined behavior in a C reference program makes it a poor oracle for an assembly test.

### Userspace, the OS, and I/O

A process receives virtual memory and permissions; a userspace program does not get unrestricted physical RAM access. A syscall requests a kernel service. Writing assembly does not change your privilege level.

Know stdin/stdout/stderr, redirection, pipes, exit status, EOF, and byte counts. Reads can be short, and writes can be partial. A terminal often makes input look line-oriented, but a generic byte stream does not promise one read per line. [Chapter 08](08_syscalls_and_io_thingy.md) keeps the accounting explicit.

### The build pipeline and debugger

Source is assembled into an object; objects are linked into an executable or library. Symbols name locations. Relocations tell tools which address-dependent fields need adjustment. The loader creates runtime mappings and transfers control according to the platform's startup rules.

Get comfortable with a shell, paths, commands, and exit statuses. Know how to ask `file`, `readelf`, `objdump`, and GDB what they see. Distinguish assembler rejection, linker rejection, and runtime failure. You cannot debug a new instruction stream if the assembler never produced it.

A healthy beginner loop is: predict one change, execute one instruction, inspect the relevant register or bytes, explain the difference. “What the fuck happened?” becomes productive when followed by an address and a disassembly.

## Porting assembly: specify the destination

Different changes require different work:

| Move | Main work |
| --- | --- |
| GAS x86 Intel syntax → NASM on the same platform | Rewrite directives, comments, expressions, and relocation syntax; preserve behavior |
| Linux x86-64 → Windows x64 | Adapt ABI, data layout, libraries/OS calls, object format, startup, and metadata |
| Linux x86-64 → Linux AArch64 | Rewrite instruction logic and register allocation; adapt ABI, relocations, syscalls, build target |
| Linux AArch64 → another AArch64 OS | Recheck platform-specific ABI details, services, binary format, and startup |
| Userspace → bare metal | Supply startup, memory layout, stack, device access, and runtime services previously supplied by the OS |

Port the **algorithm and its contract**. Do not begin with a table that says “RAX becomes X0” and rename the entire file. The same old register may have held an argument, scratch value, division input, or syscall number at different points. Those roles need different translations.

Instructions also differ. A memory-source arithmetic instruction on x86 may become a load followed by arithmetic on another ISA. Immediate ranges differ. Conditional branches may consume flags or compare registers directly. Address materialization can require several instructions plus relocations.

Subregister behavior deserves particular attention: a rule remembered from EAX does not automatically describe an RV64 word operation. Atomics and memory ordering need a new review too. A synchronization sequence whose ordering was adequate on x86 may be insufficient elsewhere. Follow the destination specification, not the resemblance between instruction names.

## One function, four implementations

Contract: take two `uint64_t` values, return their sum modulo 2^64. No caller-buffer accesses, nested calls, global state, or OS services. A leaf this small lets us see the interface change without dragging a runtime into the room.

These are **separate object-file sources**, not four standalone executables. Each exports the same function name. Link exactly one into a caller built for the matching target.

### Linux x86-64: NASM, System V AMD64

Save as `/tmp/add_sysv.asm`:

```nasm
bits 64
section .text
global add_two
add_two:
    mov rax, rdi
    add rax, rsi
    ret
section .note.GNU-stack noalloc noexec nowrite progbits
```

### Windows x64: NASM, Microsoft convention

Save as `/tmp/add_win.asm`:

```nasm
bits 64
section .text
global add_two
add_two:
    mov rax, rcx
    add rax, rdx
    ret
```

Same ISA, different argument locations. This leaf neither changes RSP nor makes calls; its caller still owes the required Windows call setup. More complex routines also need the appropriate prologue and unwind metadata.

### Linux AArch64: GNU/LLVM assembler syntax

Save as `/tmp/add_aarch64.s`:

```asm
.text
.global add_two
.type add_two, %function
add_two:
    add x0, x0, x1
    ret
.size add_two, .-add_two
.section .note.GNU-stack,"",%progbits
```

Here X0 is both first input and output, and RET uses the link register. This is AArch64 source, not NASM source with unusual names.

### Linux RISC-V RV64: GNU/LLVM assembler syntax

Save as `/tmp/add_rv64.s`:

```asm
.text
.globl add_two
.type add_two, @function
add_two:
    add a0, a0, a1
    ret
.size add_two, .-add_two
.section .note.GNU-stack,"",@progbits
```

`a0` is the first input and result. `ret` is an assembler pseudoinstruction for returning through `ra`. Pseudoinstructions expand into actual instructions; their convenient spelling is a tool feature.

### Assemble without pretending we ran every target

With NASM and a Clang build supporting these targets:

```sh
nasm -f elf64 /tmp/add_sysv.asm -o /tmp/add_sysv.o
nasm -f win64 /tmp/add_win.asm -o /tmp/add_win.obj
clang --target=aarch64-linux-gnu -c /tmp/add_aarch64.s -o /tmp/add_aarch64.o
clang --target=riscv64-linux-gnu -march=rv64gc -mabi=lp64d -c /tmp/add_rv64.s -o /tmp/add_rv64.o
file /tmp/add_sysv.o /tmp/add_win.obj /tmp/add_aarch64.o /tmp/add_rv64.o
```

The RISC-V options explicitly select an ISA extension set and ABI; this integer-only function still lives inside that selected binary interface. Its eventual caller and libraries must agree. See the [RISC-V psABI](https://riscv-non-isa.github.io/riscv-elf-psabi-doc/).

A cross-assembler producing an object is useful evidence, but it proves neither correct linkage nor runtime behavior. Linking a foreign libc program also needs destination startup objects, libraries, and a suitable linker/sysroot. A sysroot supplies a target filesystem view for build inputs; it is not an emulator. See [Clang cross-compilation](https://clang.llvm.org/docs/CrossCompilation.html).

## A porting workflow that catches the expensive mistakes

1. **Write the behavior first.** Inputs, widths, overflow, error policy, memory bounds, and output bytes. Keep a reference implementation with defined semantics.
2. **Inventory platform dependencies.** Calls, syscalls, register preservation, stack layout, symbol names, relocations, TLS, SIMD, atomics, and unwind information. A short arithmetic helper has fewer dependencies than an entire executable.
3. **Choose the exact target.** ISA/mode/extensions, OS, ABI, endianness, object format, assembler, and runtime. Match the caller and libraries to it.
4. **Assign roles to destination registers.** Separate arguments, persistent state, scratch values, results, and return-address handling. Record what survives each call.
5. **Rewrite by operation.** Preserve the arithmetic and memory semantics, not the original line count. Recheck signed/unsigned loads and every access width.
6. **Rebuild the boundaries.** Startup, calls, OS services, object layout, and cleanup need to work before optimizing the loop body.
7. **Assemble and inspect.** Check object architecture, symbols, relocations, and disassembly with tools that understand the target. Host `objdump` is not guaranteed to support every foreign ISA; LLVM or target-prefixed binutils may be needed.
8. **Link and run on the destination or suitable emulation.** Test zero, bounds, invalid input, alignment, and register preservation. Compare output against the reference. A passing integer test alone does not certify an ABI implementation.
9. **Measure on the intended hardware.** An emulator is useful for functional testing, not a substitute for a target CPU's performance measurements.

QEMU user-mode emulation can run supported foreign userspace programs with the relevant OS interface. Full-system emulation instead provides a virtual machine that can boot a guest OS. Neither option means arbitrary Windows, Linux, and bare-metal binaries are interchangeable. See [QEMU user-mode documentation](https://www.qemu.org/docs/master/user/main.html).

For your input program, preserve the parser's state machine and decimal arithmetic, then rewrite the actual loads/stores and register assignments. Adapt the input/output layer separately. Test the same byte sequence delivered in different chunks once you implement a streaming reader. Changing the CPU should not silently change what counts as valid input.

## Readiness check

Before diving deeper, explain these without guessing:

| Question | What the answer should establish |
| --- | --- |
| Is NASM an ISA? | No: it is an assembler; x86 is the architecture family it targets. |
| Can two x86-64 routines disagree about argument one? | Yes: System V uses RDI here; Microsoft x64 uses RCX. |
| Does an ABI-valid pointer have to point at live storage? | No: object lifetime and bounds remain separate responsibilities. |
| Is a qword always the size of C `long`? | No: the instruction width and the language data model are separate facts. |
| Does cross-assembling prove the program runs? | No: the loader, linkage, ABI behavior, and execution remain to be checked. |
| Can Linux write be ported by keeping its old syscall number? | No: verify the destination kernel interface and number table. |
| What does the compiler normally hide? | Register allocation, representation choices, instruction selection, and ABI setup, among other work. |

If a row feels shaky, follow the linked lesson or manual and run a small experiment. Nobody needs to memorize every ABI. You do need to know when you've crossed into a different one. That's usually the point where the old assumptions start doing damage.

[Course map](README.md) · [Start the lessons](00_start_here.md) · [External resources](../RESOURCES.md) · [NASM quick reference](QUICK_REFERENCE.md)
