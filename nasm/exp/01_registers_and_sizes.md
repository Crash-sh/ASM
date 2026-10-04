# 01 — Registers, widths, and yesterday's garbage

> **NSD / REGISTER ACCESS** — First target: the register file. RAX, EAX, AX, AL. Same storage, different access widths. Before writing anything, know which bits you're about to disturb.

**Prerequisite:** chapter 00. **Lab:** [register example](examples/01_registers_and_sizes.asm), exit `0`, no output.

## Sixteen working registers, overlapping names

The general-purpose registers are `rax rbx rcx rdx rsi rdi rbp rsp r8 r9 r10 r11 r12 r13 r14 r15`. `rip` tracks instruction execution and `rflags` carries status/control bits. They are not extra general-purpose storage.

![RAX contains overlapping EAX, AX, and AL views; EAX writes clear the high half.](diagrams/01_register_views.png)

| Full register | Low 32 bits | Low 16 bits | Low 8 bits |
| --- | --- | --- | --- |
| rax | eax | ax | al |
| rbx | ebx | bx | bl |
| rcx | ecx | cx | cl |
| rdx | edx | dx | dl |
| rsi / rdi | esi / edi | si / di | sil / dil |
| rbp / rsp | ebp / esp | bp / sp | bpl / spl |
| r8 through r15 | r8d through r15d | r8w through r15w | r8b through r15b |

Think of these names as access points into the same register. Writing AL changes part of RAX. There isn't a second little register keeping its own copy.

```nasm
mov rax, -1          ; ffffffffffffffff
mov al, 0x13        ; ffffffffffffff13
mov ax, 0x53        ; ffffffffffff0053
mov eax, 0x689      ; 0000000000000689
```

Writing a 32-bit general-purpose register clears the upper half of its 64-bit parent. An 8- or 16-bit write preserves other bits. `xor eax,eax` therefore clears all of RAX, and changes flags. `mov eax,0` also clears all of RAX, without changing arithmetic flags.

Legacy `ah/bh/ch/dh` name bits 8–15, but cannot be encoded in instructions requiring a REX prefix. Prefer low-byte names while learning; do not mix `ah` and `r8b` and expect an encoding.

## Width is a contract

| NASM width | Bytes | Bits | Unsigned range |
| --- | ---: | ---: | --- |
| byte | 1 | 8 | 0..255 |
| word | 2 | 16 | 0..65535 |
| dword | 4 | 32 | 0..2^32−1 |
| qword | 8 | 64 | 0..2^64−1 |

An x86 word is still 16 bits. The 64-bit badge didn't promote it. In our Linux LP64 C ABI, `int` is 32 bits and `long`/pointers are 64. Record those sizes with the target; don't carry them into some other ABI as universal C law.

Hex groups four bits per digit: `0xff = 255 = 0b11111111`. An eight-bit two's-complement signed interpretation ranges from −128 to 127. The bit pattern `0xff` means either 255 unsigned or −1 signed. The instruction and the programmer choose the interpretation.

## Extension: copy which meaning?

```nasm
mov al, 0xff
movzx ecx, al        ; ECX = 255; RCX = 255
movsx edx, al        ; EDX = ffffffff; RDX = 00000000ffffffff
movsxd rdx, edx      ; RDX = ffffffffffffffff, signed -1
```

`movzx` fills added bits with zeros. `movsx` repeats the source sign bit. But the destination still matters: writing EDX zeroes RDX's high half even when the value placed in EDX came from sign extension. For byte directly to signed 64-bit, use `movsx rdx,al`.

`mov r9d,r8d` copies a value. Later modifying R8D does not update R9D. There is no relationship like a reference or pointer unless you explicitly create one.

## Inspect and break it deliberately

```sh
make build/01_registers_and_sizes
gdb build/01_registers_and_sizes
```

In GDB: `break _start`, `run`, then repeat `si` and `p/x $rax`. GDB's `$rax` syntax belongs to GDB; NASM uses `rax`.

Replace the EAX write in the example with an AX write. The internal comparison fails and exits `53`: old high bits survived. Before debugging a “random huge number,” check destination width and sign extension. Yesterday's high bits are still there, doing exactly what the instruction allowed. Dump the whole register before calling the result random.

**Checkpoint:** why does `mov eax,-1` leave RAX equal to unsigned 4294967295, while `mov rax,-1` fills all 64 bits?

---

[Course map](README.md) · [Previous: 00](00_start_here.md) · [Next: 02](02_memory_and_pointer_hell.md)

Companion: [original GAS lecture](../../gas_asm_lecture/01_registers_and_sizes.asm).

Manuals: [reference index](REFERENCES.md).
