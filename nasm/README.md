# NASM from scratch — NSD field manual

```text
NSD / HARDWARE & ARCHITECTURE
operator : Crash
target   : Linux x86-64 userspace
status   : removing abstractions
```

Crash on the console. We're going to find out what the compiler was handling for us: registers, addresses, stack frames, function calls, and the occasional unpleasant detail hiding behind a line of C.

> Neuro & Basic-C got the GAS because he wnated to inspect his 'C Nudes' but you'll get nasm because it is the common one in asm programming. (_speaking for x86 ARM excluded_)

This manual follows the repository's [GAS lectures](../../gas_asm_lecture/), using NASM syntax for the runnable examples. Read the explanation, inspect the instructions, and check what the machine actually did. A convincing comment still loses an argument with the register dump.

Start with [00 — Start here](00_start_here.md). Keep the commented example open beside the lesson. Predict the result before running it; when it disagrees, we have something useful to investigate. The PNG diagrams display directly in Markdown, without an extension or network connection.

Need the background first? Read [INFO DUMP — prerequisites, ABIs, and porting](INFO_DUMP.md). It explains the interfaces behind the instructions and compares the same function across four targets.

## What is on the bench

- **18 ordered chapters**, from toolchain basics through SIMD, atomics, debugging, and practice projects.
- **16 independent commented NASM programs:** 15 x86-64 programs and one optional i386 program.
- **16 PNG diagrams** with editable Graphviz `.dot` sources.
- A dedicated reconstruction of [your input-and-add-13 program](15_your_input_program_from_bytes_to_number.md).
- Exercises, answer notes, a [quick reference](QUICK_REFERENCE.md), and [primary-source references](REFERENCES.md).

The scope is Linux ELF userspace on x86. It does not assume prior assembly knowledge, but basic C helps explain pointers and function interfaces. Bootloaders, kernel development, Windows calling conventions, full Unicode handling, and production concurrent data structures need additional courses.

## Build and run

Tools: NASM, GNU binutils, GCC, GNU Make, and Python 3. GDB is useful for instruction stepping. Graphviz is needed only to regenerate the already included PNGs.

From the repository root:

```sh
cd extra_resources/nasm
make
make check
./build/00_start_here
printf '123\n' | ./build/15_user_input
./build/12_fizzbuzz_final_boss 16
```

`make check` compares outputs, exit statuses, invalid-input behavior, and binary copy results. Most lessons report success with status 0 and keep quiet about it. Their internal checks report 53 on mismatch. Check the status; silence by itself tells us very little. The check script covers 53 program executions; it does not inject EINTR, force short writes, or establish concurrent algorithm correctness.

The optional legacy target is separate:

```sh
make check32
```

It needs an environment that permits i386 execution and syscalls. A sandbox can terminate it with `Bad system call` even when it assembles correctly and runs on the host. The normal x86-64 checks do not depend on it.

## Ordered lessons

| Chapter | What you learn | Runnable example |
| --- | --- | --- |
| [00 — Start here](00_start_here.md) | CPU, NASM, linker, ELF, `_start` versus `main` | [00](examples/00_start_here.asm) |
| [01 — Registers and sizes](01_registers_and_sizes.md) | Aliases, partial writes, signedness, extension | [01](examples/01_registers_and_sizes.asm) |
| [02 — Memory and pointers](02_memory_and_pointer_hell.md) | Sections, addresses, loads/stores, arrays, endian | [02](examples/02_memory_and_pointer_hell.asm) |
| [03 — Arithmetic and flags](03_arithmetic_and_flag_drama.md) | Carry, overflow, multiply, divide, flag lifetimes | [03](examples/03_arithmetic_and_flag_drama.asm) |
| [04 — Branches and bits](04_branches_loops_and_bit_wizardry.md) | Conditions, loops, masks, shifts, conditional values | [04](examples/04_branches_loops_and_bit_wizardry.asm) |
| [05 — Stack and recursion](05_stack_calls_and_recursion.md) | CALL/RET, frame layout, preservation, alignment | [05](examples/05_stack_calls_and_recursion.asm) |
| [06 — Calling C](06_calling_c_without_pissing_off_the_abi.md) | SysV ABI, printf, stack arguments, PIE | [06](examples/06_calling_c_without_pissing_off_the_abi.asm) |
| [07 — Strings](07_strings_without_training_wheels.md) | Lengths, NUL, ASCII, REP, DF, overlap | [07](examples/07_strings_without_training_wheels.asm) |
| [08 — Syscalls and I/O](08_syscalls_and_io_thingy.md) | Raw errors, EOF, partial reads/writes, binary copy | [08](examples/08_syscalls_and_io_thingy.asm) |
| [09 — mmap and structs](09_mmap_and_structs_in_the_wild.md) | Dynamic mappings, padding, nodes, cleanup | [09](examples/09_mmap_and_structs_in_the_wild.asm) |
| [10 — Float and SIMD](10_float_and_simd_fuckery.md) | IEEE values, SSE2, NaNs, lanes, tails | [10](examples/10_float_and_simd_fuckery.asm) |
| [11 — Atomics](11_atomic_does_not_mean_nuclear.md) | Lost updates, XADD, CAS, ordering limits | [11](examples/11_atomic_does_not_mean_nuclear.asm) |
| [12 — FizzBuzz project](12_fizzbuzz_final_boss.md) | argv, bounded parsing, decimal formatting, helpers | [12](examples/12_fizzbuzz_final_boss.asm) |
| [13 — Debugging](13_debugging_and_reading_the_nudes.md) | GDB, bytes, symbols, ELF, relocations, diagnosis | [13](examples/13_debugging_and_reading_the_nudes.asm) |
| [14 — Optional i386](14_x86_32_time_machine.md) | 32-bit mode, format, stack arguments, int 0x80 | [14](examples/14_x86_32_time_machine.asm) |
| [15 — Your input program](15_your_input_program_from_bytes_to_number.md) | Explain every original bug and the repaired data flow | [15](examples/15_user_input.asm) |
| [16 — NASM translation desk](16_nasm_directives_macros_and_gas_translation.md) | GAS differences, local labels, directives, macros | Syntax exercises |
| [17 — Practice and answers](17_practice_plan_and_answers.md) | Guided drills, signed parsing, line reader, calculator | Project specifications |

## How the files fit together

```text
extra_resources/nasm/
    README.md                   course map and commands
    00_...md through 17_...md    lessons with linked diagrams
    INFO_DUMP.md                prerequisites, ABIs, and architecture porting
    QUICK_REFERENCE.md          instruction/interface reminders
    REFERENCES.md               manuals and companion lectures
    examples/                   standalone NASM programs
    diagrams/                   PNGs and editable DOT sources
    build/                      generated objects/executables, ignored by git
```

Chapters 00–14 follow the corresponding `gas_asm_lecture` numbering. Their code is adapted from those local examples, with instruction-level comments retained and syntax/relocations converted to NASM. Chapter 15 is a standalone snapshot of the input experiment for a reproducible lesson; later experiment edits do not silently rewrite the tutorial.

The short Markdown snippets isolate one operation; they are not all standalone programs. Build the complete files in `examples/`. Each owns its own `_start` or `main`. Linking the entire directory together just gives the linker several competing entry points to complain about.
