# 11 — Atomic does not mean nuclear

> **NSD / SHARED STATE** — Second core enters the picture. Now the bug can depend on when something happens. Establish exactly which operation is atomic before trusting the result.

**Lab:** [atomic instruction example](examples/11_atomic_does_not_mean_nuclear.asm), exit `0`. It is a single-threaded semantics check, not a multithreaded correctness proof or contention benchmark.

## The lost update

Start at counter=13. Two threads each read 13, calculate 53, and store 53. Final value is 53, though two additions of 40 should give 93. Both threads followed their instructions. We failed to make the whole update indivisible. Hard to blame the silicon for that one.

![An ordinary interleaving loses an update; atomic fetch-add operations serialize to 93.](diagrams/11_atomic_updates.png)

An appropriately aligned ordinary load/store can be atomic while load/add/store as a sequence is not. Size, alignment, and memory type matter. This chapter assumes normal cacheable write-back memory and naturally aligned operands.

`lock` on a supported memory read-modify-write operation makes that operation atomic with respect to other processors' accesses. It does not mean every operation literally locks the entire external bus; cache coherence normally handles cacheable operands. Avoid split locks and cache-line-crossing operands.

## Fetch-add tells you the old value

```nasm
mov eax, 40
lock xadd qword [rel counter], rax
```

Memory gets old memory + old RAX; RAX receives old memory. With counter initially 13, the result is counter=53, RAX=13. When designing a ticket counter, returning the old versus new value is an important part of the function's contract.

## Compare-and-exchange has a failure output

For qword `cmpxchg`, RAX holds the expected value and the explicit source register holds the desired replacement. If memory matches RAX, the CPU stores the replacement and sets ZF. On mismatch it loads observed memory into RAX and clears ZF.

```nasm
mov eax, 53
mov edx, 689
lock cmpxchg qword [rel counter], rdx
jne retry_or_fail
```

A retry loop must recompute its desired value from the newly observed RAX. Recompute the desired result after a failed attempt. A successful CAS can faithfully install your stale calculation, which is not the victory it looks like. The example tests one successful replacement and a deliberately stale expected value.

`xchg` with a memory operand is implicitly locked. The sample exchanges 1 into an aligned guard, sees old zero, and later stores zero to release it under the stated x86 memory assumptions. It creates no actual competing thread.

## Atomicity is not the whole memory model

Atomicity asks whether an operation can be observed partially. Ordering asks which operations become observable in what order. Ordinary x86 write-back memory has relatively strong ordering, but store buffers permit important Store→Load effects across different addresses. “x86 never reorders” is not a safe model.

Locked operations provide strong ordering; fences have their own specific contracts. `pause` is a spin-loop hint, not a fence, lock release, or scheduler yield. Long waits normally belong to OS/library synchronization rather than a core burning cycles.

These handwritten assembly properties do not license a C mutex built from ordinary shared variables. C has a separate memory model; use `_Atomic` or library locks. `volatile` is not general synchronization.

## The CAS worked. Is the object still alive?

A pointer can change A→B→A, making a simple equality comparison miss intervening changes: the ABA problem. An object can also be freed while another thread retains its address. CAS can do its job perfectly while the surrounding code follows a dead pointer. I trust the instruction. The data structure still needs an argument for ownership and reclamation.

**Drill:** write the lost-update interleaving on paper, then the two possible fetch-add orderings. Both atomic orderings must end at 93, though the threads receive different old values depending on who goes first. Explain what this proves and what it does not prove about a larger data structure.

---

[Course map](README.md) · [Previous: 10](10_float_and_simd_fuckery.md) · [Next: 12](12_fizzbuzz_final_boss.md)

Companion: [original GAS lecture](../../gas_asm_lecture/11_atomic_does_not_mean_nuclear.asm).

Manuals: [reference index](REFERENCES.md).
