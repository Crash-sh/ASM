# Technical records — manuals and provenance

The course's structure, examples, direct tone, and C comparisons follow the repository's [GAS lectures](../gas_asm_lecture/). Chapters 00–14 adapt the corresponding local examples into NASM, retaining instruction commentary. The [input chapter](exp/15_your_input_program_from_bytes_to_number.md) documents the [standalone input example](examples/15_user_input.asm). New Markdown explanations and diagrams connect those examples into a standalone course.

Datasheets are long threat letters. These are the ones worth keeping open: the assembler's syntax, the CPU's instruction contracts, the ABI, and Linux's interfaces. When a detail matters, find the relevant section. Neither a tutorial nor a confident comment outranks the specification.

External reference links were checked on 2026-10-04. The course targets the stated Linux x86 environment; use the primary references for exact encodings and unusual cases.

| Question | Primary reference | Where this course uses it |
| --- | --- | --- |
| NASM source syntax, declarations, local labels | [NASM language manual](https://www.nasm.us/doc/nasm03.html) | 00, 02, 07, 16 |
| NASM output formats, ELF relocations | [NASM output formats](https://www.nasm.us/doc/nasm09.html) | 06, 13, 14, 16 |
| Instruction behavior, flags, SIMD, ordering | [Intel architecture manuals](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html) | 01–05, 10–11 |
| Function calls, register preservation, layouts | [System V x86-64 psABI project](https://gitlab.com/x86-psABIs/x86-64-ABI) | 05–06, 09 |
| Raw syscall register interfaces | [Linux syscall(2)](https://man7.org/linux/man-pages/man2/syscall.2.html) | 08, 14 |
| Counts, EOF, short reads | [Linux read(2)](https://man7.org/linux/man-pages/man2/read.2.html) | 08, 15 |
| Partial writes and errors | [Linux write(2)](https://man7.org/linux/man-pages/man2/write.2.html) | 08, 12 |
| Mapping parameters and lifetime | [Linux mmap(2)](https://man7.org/linux/man-pages/man2/mmap.2.html) | 09 |
| GDB commands and inspection | [GNU GDB manual](https://sourceware.org/gdb/current/onlinedocs/gdb.html/) | 13 |

The Linux man pages often describe C wrappers. When writing raw assembly, distinguish the operation's semantics from the wrapper's `errno` translation and function calling convention. The syscall reference supplies the raw register interface.

The examples are instructional: the atomic example does not start threads; the single-read input exercise is not a streaming line reader; no benchmark establishes performance claims. The tests check actual outputs and boundaries without claiming to verify every OS scheduling or error condition.

For ABI comparisons and the cross-architecture examples, see [INFO DUMP](INFO_DUMP.md). The shared [external resource list](../extra_resources/RESOURCES.md) also covers Microsoft x64, Arm, RISC-V, and cross-compilation tools.
