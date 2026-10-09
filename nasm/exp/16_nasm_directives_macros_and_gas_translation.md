# 16 — NASM directives, macros, and the GAS translation desk

> **NSD / TOOLCHAIN DIALECTS** — Same CPU, different assembler. The instructions look familiar; the directives need translating. A renamed file is not a port.

**Prerequisites:** 00–08. The [GAS lecture directory](../../gas_asm_lecture/) is the companion source for chapters 00–14. This tutorial's executable versions are NASM files, not renamed GAS files.

## The common translation table

| GAS Intel syntax | NASM syntax | Purpose |
| --- | --- | --- |
| `.intel_syntax noprefix` | no equivalent needed | select Intel spelling in GAS |
| `.section .rodata` | `section .rodata` | select section |
| `.globl name` | `global name` | export symbol |
| `.extern puts` | `extern puts` | external symbol declaration |
| `.byte / .short / .long / .quad` | `db / dw / dd / dq` | initialized elements |
| `.ascii "abc"` | `db 'abc'` | bytes without terminator |
| `.asciz "abc"` | `db 'abc',0` | append NUL |
| `.zero 64` in BSS | `resb 64` | reserve 64 zero-initialized ELF BSS bytes |
| `.balign 16` | `align 16` or `alignb 16` in BSS | storage alignment |
| `.equ LEN, . - msg` | `LEN equ $ - msg` | assembly-time constant |
| `DWORD PTR [rax]` | `dword [rax]` | operand width |
| `[rip + symbol]` | `[rel symbol]` | RIP-relative memory/address form |
| `call printf@PLT` | `call printf wrt ..plt` | external PLT call |
| `# comment` / `/* block */` | `; comment` per line | comments |

GAS `.type/.size` and unwind/debug directives describe metadata; they are not CPU operations. Check their NASM equivalents before copying them. Compiler output includes a fair amount of toolchain paperwork between the actual instructions. A careful port preserves executable behavior and deliberately handles metadata through the target toolchain.

## Labels and local scope

```nasm
parse:
.loop:
    ; parse.loop is the full scoped name
    jmp .done
.done:
    ret

format:
.loop:
    ; a separate format.loop
    ret
```

A NASM dot-local label belongs to the previous nonlocal label. A jump to `.done` inside `parse` will not find a `.done` defined under `format`. An undefined-label error stops us at assembly time. There is no new executable to debug yet. Fix the symbol before interrogating the CPU about code it hasn't seen.

Always use colons on labels. A misspelled instruction with no operands can otherwise look like a label; `-w+orphan-labels` helps catch that. Labels do not emit RET or create scope at runtime.

## Three kinds of repetition/constants

`LIMIT equ 12` defines an assembler-time constant. `%define LIMIT 12` is a preprocessor token definition. `times 16 db 0` emits sixteen zero bytes into the object; `resb 16` reserves BSS storage. A runtime loop repeats instructions when the process executes. These occur at different stages.

`%if` chooses what source is assembled, not which path a running process takes. `%ifdef INFO` is not a general block comment: when INFO is defined, the enclosed text must become valid NASM source. Use semicolon-prefixed prose for explanations that should remain comments in every build.

## Expand the macro before trusting it

```nasm
%macro exit_with 1
    mov eax, 60
    mov edi, %1
    syscall
%endmacro

; exit_with 0 expands to three instructions at each use.
```

A macro can reduce repetition, but hides emitted code unless its contract is clear. `%1` denotes an argument. Use `%%local_name` for labels that must be unique per expansion. `%include "helpers.inc"` inserts shared source; include search paths belong in the build setup.

For early lessons, explicit instructions make clobbers and register jobs visible. Before introducing a macro, state what it reads, writes, emits, and whether it terminates or returns. A one-line macro can still trash RCX. Expand it and read what gets emitted; the short name doesn't reduce its responsibilities.

## Encoding constraints still apply

Most arithmetic instructions cannot encode an arbitrary 64-bit immediate; many use a sign-extended imm32. Load a full-width constant into a register when necessary. `mov r64,imm64` is a different encoding case. Likewise, `[rax+rcx*3]` is not a general scale encoding; compute the address with supported operations.

`bits 64`, `default rel`, and `-f elf64` address different choices: instruction mode, memory-address defaults, and output format. Keep their responsibilities distinct. Use `nasm -l /tmp/lesson.lst ...` to inspect a listing that relates source to emitted bytes.

**Drill:** port a five-line GAS data declaration with an embedded newline and terminator. Dump the NASM object's bytes with `objdump -s` and verify exact equality of the intended payload, not just visually similar source strings.

---

[Course map](../README.md) · [Previous: 15](15_bytes_to_numbers_and_back.md) · [Next: 17](17_practice_plan_and_answers.md)

Manuals: [reference index](../REFERENCES.md).
