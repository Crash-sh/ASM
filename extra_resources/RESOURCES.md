# External resources — keep the manuals within reach

> **NSD / TECHNICAL RECORDS** — The tutorial gets you oriented. The specification settles the argument. Keep the right document open for the machine you're actually targeting.

Start locally with the [NASM course](nasm/README.md) and [INFO DUMP: prerequisites, ABIs, and porting](nasm/INFO_DUMP.md). The [quick reference](nasm/QUICK_REFERENCE.md) is for the details you want beside the debugger.

## Linux interfaces: ask what the kernel actually expects

```sh
man 2 syscalls
man 2 syscall
man 2 read
man 2 write
man 2 mmap
```

The manual section number matters. `man 2 write` describes the system-call interface; `man 1 printf` describes a shell-facing utility. Many section-2 pages show C wrappers, so distinguish their `errno` behavior from raw assembly return values.

| Resource | What to use it for |
| --- | --- |
| [Linux syscall(2)](https://man7.org/linux/man-pages/man2/syscall.2.html) | Architecture-specific syscall entry and argument registers |
| [Linux read(2)](https://man7.org/linux/man-pages/man2/read.2.html) | Counts, EOF, interruptions, and partial input |
| [Linux write(2)](https://man7.org/linux/man-pages/man2/write.2.html) | Partial output, errors, and what success actually guarantees |
| [Linux mmap(2)](https://man7.org/linux/man-pages/man2/mmap.2.html) | Mapping parameters, permissions, and release rules |
| [Linux kernel x86-64 syscall table](https://github.com/torvalds/linux/blob/master/arch/x86/entry/syscalls/syscall_64.tbl) | Kernel-source mapping of syscall numbers to names; select the relevant kernel revision when needed |

A syscall table gives numbers. It does not give you the complete parameter types, ownership rules, or error handling. Read the operation's documentation before wiring registers to it.

## Assembler and instruction manuals

| Resource | Open it when… |
| --- | --- |
| [NASM manual](https://www.nasm.us/doc/) | A directive, expression, macro, label, or relocation spelling is unclear |
| [GNU assembler manual](https://sourceware.org/binutils/docs/as/) | Reading GAS source or using an assembler for another architecture |
| [Intel architecture manuals](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html) | Checking exact x86 instruction behavior, flags, exceptions, or architectural ordering |
| [RISC-V ISA manual source and releases](https://github.com/riscv/riscv-isa-manual) | Checking RISC-V instruction semantics and extension definitions |

Start with the entry for the instruction in front of you. Reading an entire architecture manual before writing ADD is not a prerequisite. Knowing where to check ADD's behavior is.

## ABIs: the agreement between separately built code

| Resource | Target and purpose |
| --- | --- |
| [System V AMD64 psABI](https://gitlab.com/x86-psABIs/x86-64-ABI) | Linux-style x86-64 function calls, data layout, and ELF conventions used by this course |
| [Microsoft x64 calling convention](https://learn.microsoft.com/en-us/cpp/build/x64-calling-convention?view=msvc-170) | Windows x64 argument registers, preservation, and call setup |
| [Microsoft x64 stack usage](https://learn.microsoft.com/en-us/cpp/build/stack-usage?view=msvc-170) | Shadow space, frames, alignment, and leaf functions |
| [Arm ABI collection](https://github.com/ARM-software/abi-aa) | Official Arm ABI specifications and releases |
| [AAPCS64](https://github.com/ARM-software/abi-aa/blob/main/aapcs64/aapcs64.rst) | AArch64 procedure calls and data layout; check platform-specific rules too |
| [RISC-V psABI](https://riscv-non-isa.github.io/riscv-elf-psabi-doc/) | RISC-V register roles, ABI variants, ELF details, and calling conventions |

Check the destination before borrowing a prologue. Similar-looking instructions do not guarantee that the caller left the arguments where you expect them.

## Debugging and cross-target work

| Resource | Job |
| --- | --- |
| [GNU GDB manual](https://sourceware.org/gdb/current/onlinedocs/gdb.html/) | Instruction stepping, register/memory inspection, watchpoints, and target debugging |
| [Clang cross-compilation guide](https://clang.llvm.org/docs/CrossCompilation.html) | Target selection, sysroots, and the difference between emitting an object and linking a usable program |
| [QEMU user-mode documentation](https://www.qemu.org/docs/master/user/main.html) | Running supported foreign userspace programs under emulation |

A foreign object assembling successfully is one check. Running the linked program and checking its behavior is another. Emulator timings are not a performance report for the real CPU.

## Existing bookmarks: useful context, check their scope

The original resource list included these links. They remain here as historical references:

- [LXR: Linux v3.2 x86 unistd_64.h](https://lxr.linux.no/linux+v3.2/arch/x86/include/asm/unistd_64.h) — explicitly tied to an old kernel revision; use current kernel source when you need newer entries.
- [Ryan Chapman's Linux x86-64 syscall table](https://blog.rchapman.org/posts/Linux_System_Call_Table_for_x86_64) — a convenient secondary lookup; verify details against the kernel table and relevant manual page.

A familiar bookmark can still describe the wrong architecture or an older interface. Check the target and revision before treating a number as a fact about your build.
