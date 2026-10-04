# 08 — Raw syscalls and accounting for every byte

> **NSD / KERNEL UPLINK** — Kernel boundary ahead. Load the number, wire the arguments, inspect the result. Linux gets the request you actually made. Swearing at a bad descriptor remains unsupported.

**Lab:** [copy program](examples/08_syscalls_and_io_thingy.asm).

```sh
printf 'link online\n' | ./build/08_syscalls_and_io_thingy
```

Expected: identical bytes, exit `0`. Interactive EOF is usually Ctrl-D on an empty terminal input line; it is not an input character named EOF.

## The Linux x86-64 syscall interface

RAX contains the syscall number. Arguments 1–6 use RDI, RSI, RDX, **R10**, R8, R9. The return value is in RAX. RCX and R11 are clobbered by the `syscall` instruction. Keep a digit count in RCX across SYSCALL and you'll get the wrong value back. I check this register first when an output loop starts behaving like it has lost its mind.

For this ABI: read=0, write=1, mmap=9, munmap=11, exit=60. These are Linux x86-64 numbers, not universal instruction constants. Chapter 14 uses a different interface and different numbers.

A file descriptor is a small integer referencing an open resource in the process. Conventionally 0 is stdin, 1 stdout, 2 stderr. Redirection changes the resource behind the descriptor; your program can use the same code for a terminal, pipe, or file.

## Read returns a count, not a string

```nasm
xor eax, eax
xor edi, edi
lea rsi, [rel buffer]
mov edx, CAPACITY
syscall
```

For read/write, positive means progress, zero from read means EOF, and a negative raw result is an error. Read does not append NUL and does not promise one complete line. A read may return part of a line or several lines. 4096 is the most we're offering to receive. Linux doesn't owe us a full buffer on each call.

Raw errors are encoded as negative errno values. Libc wrappers typically return −1 and set `errno`; this program has no wrapper doing that translation. Retry `-EINTR` (−4 here) where appropriate. Nonblocking `EAGAIN` needs readiness handling; the example assumes blocking descriptors and reports other errors.

## Linux wrote some of it. Finish the job.

![Write-all retries interruptions and advances pointer/count after each successful partial transfer.](diagrams/08_write_all.png)

Suppose you request 100 bytes and get 30. The remaining work is pointer+30, count=70. Repeating the original request duplicates output. Advancing by 100 discards 70 bytes. Use the returned count. That's the record of what happened; the original count only records what we asked for.

The helper's contract is RDI=fd, RSI=readable pointer, RDX=count; return RAX=0 on success or negative error. It preserves callee-saved registers but changes RSI/RDX as it progresses. Its loop:

1. Return success immediately for zero count.
2. Request the remaining bytes.
3. Retry EINTR with the same range.
4. Return other negative errors.
5. Treat zero progress as an error rather than spin forever.
6. Advance RSI and reduce RDX by the positive result; repeat if bytes remain.

After read, the copy program passes the **returned** count into write_all. It never writes the entire capacity just because that much space exists.

## Inspect the boundary

With `strace` installed:

```sh
printf 'abc\n' | strace -e read,write,exit ./build/08_syscalls_and_io_thingy
```

You should see a successful read, output write(s), another read returning zero, and exit. The chunk sizes can vary between runs. Follow the counts in the trace. If your explanation requires one syscall per line, the explanation needs fixing.

A closed pipe reader can trigger SIGPIPE under the default signal disposition before your code handles EPIPE. Successful write does not promise durable disk storage. Syscall 60 exits the calling thread; these examples are single-threaded. Process-wide exit and libc cleanup are separate matters.

**Drill:** add a total-byte counter that survives all helper calls and syscalls. Explain why R12 is a sensible persistent register here and why RCX is not. Then test binary input containing NUL: the copy must preserve it because the protocol is counted bytes, not a C string.

---

[Course map](README.md) · [Previous: 07](07_strings_without_training_wheels.md) · [Next: 09](09_mmap_and_structs_in_the_wild.md)

Companion: [original GAS lecture](../../gas_asm_lecture/08_syscalls_and_io_thingy.asm).

Manuals: [reference index](REFERENCES.md).
