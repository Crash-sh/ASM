# 07 — Strings without training wheels

> **NSD / BYTE STREAMS** — Today's sophisticated data structure is a pile of bytes and a pointer. Length, capacity, terminator: all our responsibility. The compiler used to handle some of this paperwork.

**Lab:** [string example](examples/07_strings_without_training_wheels.asm), exit `0`. It checks uppercase conversion, copying, and a bounded terminator search.

## Bytes, characters, and terminators

```nasm
message db 'hello', 10       ; six bytes; no NUL
length equ $ - message      ; assembly-time constant 6
cstring db 'hello', 0        ; six bytes including terminator
scratch resb 64              ; belongs in .bss
```

The last declaration is shown for comparison; switch to `section .bss` before using it. `equ` defines a numeric constant, not mutable storage. Ordinary NASM single/double-quoted strings do not interpret C-style `\n`; use `10` explicitly, as above. NASM backquoted strings support escape syntax, but explicit bytes keep the introductory examples obvious.

A counted byte span consists of pointer plus length. A C string ends at a zero byte and requires the caller to guarantee that readable terminator. Linux `write` wants the counted form; libc `puts` wants the terminated form. They are different interfaces.

ASCII `A` is 65, digit `0` is 48, newline is 10, and NUL is 0. The string `"123"` contains three digit bytes. There is no integer 123 in that buffer waiting for us to load it; we have to parse it. UTF-8 can use multiple bytes for one Unicode character. Byte indexing is not general text-character indexing.

## Bounded copy and ASCII case conversion

The sample checks `i < BYTE_COUNT`, loads one byte, tests whether it is between `'a'` and `'z'`, and subtracts `'a'-'A'` only in that interval. It then stores the byte and advances the index.

Blindly clearing bit 5 of every byte mangles punctuation too. This example handles ASCII lowercase, not international case conversion. The destination reserves an additional byte and explicitly stores a NUL after the copied content.

![A counted buffer and a NUL-terminated buffer have different stopping rules.](diagrams/07_strings.png)

The terminator has to exist as an actual zero byte. Naming something `cstring` doesn't put one there. Reserving 12 bytes and reading 12 bytes leaves no extra byte for a terminator. If the consumer needs one, reserve space and write it after checking the read result.

## Account for the implicit operands

| Instruction | Implicit operation in these 64-bit examples |
| --- | --- |
| `movsb` | copy [RSI] to [RDI], move both pointers |
| `stosb` | store AL to [RDI], move RDI |
| `lodsb` | load [RSI] into AL, move RSI |
| `scasb` | compare AL against [RDI], move RDI |
| `cmpsb` | compare [RSI] against [RDI], move both |

Direction flag DF selects forward or backward movement. `cld` clears it; `std` sets it. SysV requires DF clear across function call boundaries. If you set DF for a backward operation, clear it before calling or returning. Leaving the next routine walking backward is a nasty little parting gift.

`rep movsb` repeats while RCX is nonzero, reducing RCX each time. RSI and RDI finish past the copied range. `repe cmpsb` additionally stops on mismatch; `repne scasb` stops on a match. A zero initial count does no comparison and leaves old flags, so a general function must handle that case separately.

## Overlap and lifetime

Forward copying can overwrite source bytes that have not yet been read when destination starts inside source at a higher address. `memcpy` does not promise overlap handling; `memmove` does. A backward copy solves that particular direction, but must start at the final byte, special-case length zero, and restore DF afterward.

Pointers to a function's temporary stack buffer stop being valid when that frame is released. A pointer can retain the old numerical address while the bytes now belong to something else. String code is still memory-lifetime code.

**Drill:** write a bounded length helper that returns both length and “terminator found.” Test capacity zero, a terminator at the last allowed byte, and no terminator. Never read a thirteenth byte to discover that a twelve-byte buffer lacked one.

---

[Course map](README.md) · [Previous: 06](06_calling_c_without_pissing_off_the_abi.md) · [Next: 08](08_syscalls_and_io_thingy.md)

Companion: [original GAS lecture](../../gas_asm_lecture/07_strings_without_training_wheels.asm).

Manuals: [reference index](REFERENCES.md).
