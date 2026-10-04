# 17 — Practice plan, checks, and answer notes

> **NSD / OPERATOR QUALIFICATION** — Your turn at the console. Predict a result, run the experiment, inspect the disagreement. Keep notes. I trust those more than 'it worked once.'

## Work through the course in passes

| Pass | Chapters | Deliverable |
| --- | --- | --- |
| Basic machine model | 00–02 | Build a program, inspect widths, load/store an array |
| Control and functions | 03–06 | Trace flags, implement a loop, preserve a call frame |
| Bytes and OS | 07–09 | Copy binary input, handle counts, map and release nodes |
| Advanced mechanisms | 10–11 | Explain SIMD lane bounds and atomic operation results |
| Integration | 12–15 | Validate argv, format numbers, debug the input exercise |
| Tool fluency | 16 | Translate directives and inspect emitted bytes |

Use the expected outputs and statuses in each lesson to check the examples built with the [course map commands](../README.md#build-and-run). The current tree has no automated check script. Check boundaries in both input-driven programs manually. The i386 example is optional because host support varies. Diagram regeneration is independent of executable builds.

## Small drills, concrete answers

1. **Width:** after `mov rax,-1; mov ax,1`, RAX is `0xffffffffffff0001`. After `mov eax,1`, it is 1. Explain the difference without calling either operation mysterious.
2. **Endian:** `dd 0x01020304` emits bytes `04 03 02 01` at increasing addresses. Loading a byte from offset 1 gives 3.
3. **Pointer stride:** an int32 array's fourth element has offset 12; a qword array's fourth element has offset 24. Zero-based index is 3 in both.
4. **Flags:** byte `127+1` sets OF but not CF. Byte `255+1` sets CF but not OF. Both observations follow from different interpretations of the same-width addition.
5. **Division:** unsigned 136/10 produces quotient 13, remainder 6; the next division must clear the high dividend again.
6. **Stack:** entering with a return address, then pushing one qword and returning without a pop, makes RET consume that pushed value. It does not skip “non-address-looking” data.
7. **ABI:** at a scalar SysV function entry, RSP modulo 16 is 8. Reserve 8, 24, or 40 bytes to align before a nested call, accounting for any other pushes too.
8. **Strings:** a twelve-byte buffer fully filled by read has no automatic terminator and no spare byte. Bounds come from the returned count or a larger allocation plus explicit terminator.
9. **Write:** requesting 20 bytes and receiving 7 means next pointer is old+7 and remaining count is 13. The old pointer/count must not simply be repeated.
10. **Formatting:** pushing one qword per ASCII digit creates eight-byte slots. A byte-oriented write length does not collapse those slots into a string.
11. **SIMD:** three remaining int32 elements are insufficient for a sixteen-byte load. MOVDQU removes alignment requirements, not bounds requirements.
12. **Atomics:** atomic load and atomic store do not make a load/add/store sequence atomic. Specify the whole operation that must be indivisible.

## Larger projects, in dependency order

### A. Signed decimal parsing

Accept an optional leading minus, require at least one digit, reject other characters, and detect overflow before accumulation. Account for the asymmetric signed range: INT64_MIN has one more unit of magnitude than INT64_MAX. Use an unsigned magnitude with a sign-dependent limit.

Test zero, negative zero, leading zeros, both signed extremes, one value beyond each extreme, a lone minus, embedded whitespace, and empty input. Decide whether plus is accepted and document it.

### B. A real line reader

Maintain buffer capacity, accumulated length, and unconsumed bytes across reads. Stop only at the chosen delimiter or EOF. Define how to handle multiple lines in one read and a line too long for storage. Draining a rejected long line is useful if you intend to read another afterward.

Test input split one byte at a time, two lines arriving together, EOF without newline, an empty line, a full-capacity line, and a longer line. Chunk boundaries must not change the interpretation of the same byte stream.

### C. A calculator with an actual contract

Reuse validated parsing and formatting. Specify signedness and operation domain. For division, handle zero and INT64_MIN/−1. For addition/multiplication, choose rejection or a documented wrap policy. Separate input, arithmetic, and output errors so tests can identify which contract failed.

### D. An assembly helper called from C

Implement a sum over int32 elements, returning int64. Pass pointer and size in ABI argument registers, preserve callee-saved state, and define whether arithmetic overflow is possible in the supported size domain. Link the helper object with a C driver that compares results.

Start scalar. A vector implementation comes after a clear reference result and tail policy. A fast wrong answer is ready for debugging, not benchmarking.

## Keep an inspection record

Write the input domain, register inputs/outputs, clobbers, buffer capacities, and expected status. Include one boundary case and one deliberately invalid case where relevant. If the routine calls another routine, show stack alignment at that CALL.

When debugging, keep a tiny trace table of instruction, important registers before/after, and accessed address. Don't bury yourself in a full register dump after every instruction. Pick the state that could explain the failure and follow it. We're trying to find a cause, not generate more logs.

**Completion check:** independently explain how `123\n` becomes 136 and then the four output bytes `31 33 36 0a`, including which instruction overwrites the original numeric RAX result. If you can account for every boundary, good. You've removed another layer of guesswork. The registers are still there; now you know what to ask them.

---

[Course map](../README.md) · [Previous: 16](16_nasm_directives_macros_and_gas_translation.md)

Manuals: [reference index](../REFERENCES.md).
