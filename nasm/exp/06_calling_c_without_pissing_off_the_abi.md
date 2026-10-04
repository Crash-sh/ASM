# 06 — Calling C without pissing off the ABI

> **NSD / ABI HANDSHAKE** — libc is on the other end of this call. It expects the ABI. Give it the registers, alignment, and types it asked for; the NSD badge buys no exceptions.

**Lab:** [libc example](examples/06_calling_c_without_pissing_off_the_abi.asm). Expected output: `sum=28, float=13.53` and newline, status `0`.

## The ABI connects separately written code

An application binary interface specifies register roles, stack alignment, data layout, and more. Both routines can contain perfectly valid x86 instructions and still disagree about where the first argument lives. That is enough to break the call. This chapter uses Linux System V AMD64, not Windows x64.

For ordinary scalar integer/pointer arguments, the first six positions use RDI, RSI, RDX, RCX, R8, R9. Later ones use stack slots. Floating-point arguments have a separate XMM0–XMM7 allocation sequence. An integer result uses RAX; a scalar double result uses XMM0. Structs have additional classification rules; do not extend this small table by guessing.

![Function ABI and syscall ABI use different fourth argument registers.](diagrams/06_abi.png)

## Assemble first, link with the C runtime second

```sh
nasm -f elf64 -g -F dwarf examples/06_calling_c_without_pissing_off_the_abi.asm -o /tmp/abi.o
gcc -g -pie /tmp/abi.o -o /tmp/abi
/tmp/abi
```

`global main` exports the function the runtime will call. `extern printf` declares a symbol supplied by another object/library. `call printf wrt ..plt` requests the ELF PLT call path in NASM syntax. GAS spells that relocation differently; `printf@PLT` is not what we write here.

`default rel` and `[rel format]` let local data references use RIP-relative addressing. They do not automatically make every possible absolute address position-independent. The dynamic linker and GOT/PLT solve external symbol linkage; those are linker mechanisms, not extra CPU calling instructions.

## Seventh integer argument: draw the slots

At aligned RSP, reserve 16 bytes: eight for argument seven, eight for padding. Store the argument at `[rsp]`, not `[rsp+8]`, and then call. The call pushes a return address below it. At callee entry, `[rsp]` is return address and `[rsp+8]` is argument seven.

The sample sums 1+2+3+4+5+6+7 = 28. The caller reclaims all 16 reserved bytes afterward. Keep the ownership straight: the caller reclaims these arguments. The callee's RET takes its return address. Start popping the other side's slots and the return path gets interesting in the worst way.

## Read the small print before calling printf

The format string defines interpretation: `%d` expects a 32-bit int, `%ld` a 64-bit long on our ABI, `%s` a readable NUL-terminated string, and `%f` a promoted double. Dropping an integer bit pattern into XMM0 doesn't turn it into a double. printf trusts the format. If we give it the wrong representation, that's our mess.

For a variadic call, AL communicates the number of vector argument registers used (the ABI permits an upper bound). Use the exact count: zero for no vector arguments, one for the sample double. Copy an old RAX result into its destination argument register before writing EAX to set AL.

```nasm
mov rsi, rax             ; integer result becomes printf argument
lea rdi, [rel format]
movsd xmm0, [rel decimal]
mov eax, 1               ; one vector argument
call printf wrt ..plt
```

Check RSP before making the call. Yes, even if the previous printf happened to work. A function working by accident with integer-only output may fail when an implementation saves vector registers using aligned stores.

## Returning through libc matters

`printf` can buffer output. Returning from `main` lets the runtime perform normal cleanup and flushing. Raw syscall 60 bypasses libc cleanup. The examples using raw `_start` do not call printf, so there is no hidden stdio buffer to flush.

To call assembly from C, put a helper in its own object with `global helper`, use the correct ABI, and declare a matching C prototype. Do not link the whole example containing `main` to a C file that also defines `main`.

**Drill:** add a second double to the output in XMM1, extend the format string, and set AL=2. Then diagram the seventh integer argument from both sides of CALL. If the diagrams disagree, the code's interface does too.

---

[Course map](README.md) · [Previous: 05](05_stack_calls_and_recursion.md) · [Next: 07](07_strings_without_training_wheels.md)

Companion: [original GAS lecture](../../gas_asm_lecture/06_calling_c_without_pissing_off_the_abi.asm).

Manuals: [reference index](REFERENCES.md).
