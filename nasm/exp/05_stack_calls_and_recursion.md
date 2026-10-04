# 05 — Stack, calls, and keeping the return path alive

> **NSD / RETURN PATH** — The return address is sitting in writable memory. Count every byte you put above it. RET has no interest in what you meant to pop.

**Lab:** [stack example](examples/05_stack_calls_and_recursion.asm), exit `0`. It checks factorial, saved RBX, and restored RSP.

## Four operations. Count the bytes.

For the ordinary 64-bit forms used here:

| Instruction | Effect |
| --- | --- |
| `push rax` | RSP -= 8; store RAX at [RSP] |
| `pop rax` | load RAX from [RSP]; RSP += 8 |
| `call helper` | push next instruction address, jump to helper |
| `ret` | take return address from [RSP], advance RSP, resume there |

The stack grows toward lower addresses. `sub rsp,32` reserves space; `add rsp,32` releases it without clearing old bytes. Those local bytes can contain leftovers from earlier work. Initialize the ones you read; a stack reservation doesn't come with housekeeping.

![Factorial frame showing return address, saved RBP, saved RBX, and local storage.](diagrams/05_stack_frame.png)

A function boundary is a convention implemented with instructions. A label neither saves state nor inserts a return.

## Trace a broken return

At function entry, `[rsp]` is the return address. If you `push rsi` and later `ret` without undoing that push, the top slot is now the saved RSI value. RET takes that top value as its destination. No search, no plausibility check, no 'surely they meant the slot below.' This is how one missing POP turns into a wrecked return path.

In your original parser, recursive calls were also made without advancing the actual memory operand. First you ran out of stack; after repairing the recursion, the unbalanced push would still destroy the return path. Independent bugs do not cancel each other.

## Save whose registers?

System V AMD64 integer/pointer arguments use RDI, RSI, RDX, RCX, R8, R9; ordinary integer results use RAX. RBX, RBP, R12–R15 are callee-saved. A function that modifies them must restore the caller's values. RSP must also be restored.

RAX, RCX, RDX, RSI, RDI, R8–R11 and vector registers are caller-saved. If you need one across a call, save it or move persistent state into a preserved register whose own preservation you handle. These are promises between the caller and callee. The CPU lets you break them. The next function gets to discover the damage.

## Alignment is arithmetic, not decoration

For the ordinary calls in this course, RSP must be divisible by 16 immediately before `call`. The pushed eight-byte return address means function entry has `rsp % 16 == 8`. Linux `_start` begins aligned to 16; it is not a normal function entry.

In the recursive example:

```nasm
push rbp          ; entry remainder 8 -> 0
mov rbp, rsp
push rbx          ; remainder 0 -> 8
sub rsp, 8        ; remainder 8 -> 0, ready for nested call
; ... call factorial ...
add rsp, 8
pop rbx
pop rbp
ret
```

The unwind order reverses the setup. `[rbp+8]` is the return address; `[rbp]` saved RBP; `[rbp-8]` saved RBX; `[rbp-16]` the reserved local slot. RBP as a frame pointer is optional but makes the layout easier to inspect.

## Recursion needs a base case and preserved state

Factorial uses `f(0)=f(1)=1`, otherwise `f(n)=n*f(n−1)`. The original `n` must survive the nested call. The example holds it in RBX, which each recursive invocation saves before replacing. Each invocation owns a different stack frame.

The accepted domain is 0..20 because 21! does not fit uint64_t. A correct base case does not guarantee unlimited stack space or unlimited number size. An iterative loop removes the extra frames. It doesn't squeeze 21! into 64 bits. You can argue with the implementation; you can't negotiate another bit out of RAX.

SysV Linux userspace also provides a 128-byte red zone below RSP. A leaf can use it without adjusting RSP; values there must not remain live across calls. Windows and kernel code do not share this same contract.

**Drill:** implement iterative factorial, keeping the same input/output contract. Check 0, 1, 5, and 20. In GDB inspect `x/4gx $rsp` before CALL and at function entry; locate the exact new return address.

---

[Course map](README.md) · [Previous: 04](04_branches_loops_and_bit_wizardry.md) · [Next: 06](06_calling_c_without_pissing_off_the_abi.md)

Companion: [original GAS lecture](../../gas_asm_lecture/05_stack_calls_and_recursion.asm).

Manuals: [reference index](REFERENCES.md).
