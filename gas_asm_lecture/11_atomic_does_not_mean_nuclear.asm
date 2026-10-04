/* ==================== NSD / SHARED STATE ======================
    Second core online. Your private sequence of operations now has company.
    Two cores can each execute valid instructions and still lose an update.
    Nobody has to malfunction. You just failed to coordinate the access.
    Let's make the shared operation indivisible where the hardware supports it.
    Build: gcc -g -nostdlib -no-pie -x assembler 11_atomic_does_not_mean_nuclear.asm -o /tmp/atomic
    Run /tmp/atomic; echo $?     Expected 0.

    inc QWORD PTR [counter] reads/modifies/writes memory. Multiple cores doing
    that without synchronization can lose updates. LOCK on a supported
    memory read-modify-write instruction makes that operation atomic with
    respect to other processors' accesses. Usually cache coherence handles
    it; 'LOCK always locks the entire memory bus' is an oversimplification.

    Aligned ordinary 64-bit loads/stores in normal write-back memory have
    architectural atomicity guarantees, but load; add; store is THREE steps.
    Alignment, size and memory type matter. Keep atomic data naturally aligned
    and avoid crossing cache-line boundaries. Some split locks even fault.

    These examples are single-threaded checks of instruction semantics.
    They are NOT a contention benchmark or proof of a concurrent algorithm.
    Establish the instruction's guarantees first. A mutex needs an actual
    concurrency argument; a LOCK prefix isn't a fucking certification stamp.
*/
.intel_syntax noprefix
.section .data
.balign 8
counter: .quad 13
guard: .long 0
.text
.globl _start
_start:
    mov eax, 40
    lock xadd QWORD PTR [rip + counter], rax
    # Memory += old RAX, and RAX receives OLD memory. Atomic fetch-add.
    cmp rax, 13
    jne failed
    cmp QWORD PTR [rip + counter], 53
    jne failed

    # Compare-and-exchange: implicit expected value in RAX.
    # If memory == RAX: store source register, ZF=1.
    # Else: load observed memory into RAX, ZF=0. Source isn't stored.
    mov eax, 53
    mov edx, 689
    lock cmpxchg QWORD PTR [rip + counter], rdx
    jne failed                     # Success: replaced 53 with 689.
    mov eax, 53                     # Stale expectation on purpose.
    mov edx, 13
    lock cmpxchg QWORD PTR [rip + counter], rdx
    je failed                      # Should fail and tell us the observed 689.
    cmp rax, 689
    jne failed
    cmp QWORD PTR [rip + counter], 689
    jne failed

    # XCHG with a memory operand is implicitly locked; no LOCK needed.
    mov eax, 1
    xchg DWORD PTR [rip + guard], eax
    test eax, eax                  # Old zero means we acquired it.
    jne failed
    # Tiny protected region would go here. No other thread exists in demo.
    mov DWORD PTR [rip + guard], 0  # Aligned store releases on x86 WB memory.

    xor edi, edi
    jmp finish
failed:
    mov edi, 53
finish:
    mov eax, 60
    syscall
.section .note.GNU-stack,"",@progbits

/*
    Ordering is related to atomicity, but distinct. For ordinary cacheable
    write-back memory x86 has a relatively strong memory model; a load can
    observe before an older store to a different address becomes visible to
    other cores (store buffer). 'x86 doesn't reorder anything' is a bad claim
    that survives suspiciously well among people who won't read the manual.
    Locked operations give strong ordering; MFENCE orders loads/stores.
    LFENCE/SFENCE have narrower roles and additional documented details.
    Device memory and non-temporal operations require their own careful rules.

    The release store above is sufficient for this hand-written x86 pattern
    under the stated memory assumptions. It is not permission to implement
    a C mutex with ordinary shared variables. C has its own memory model;
    use _Atomic and proper memory orders or pthread locks. volatile alone
    is not an atomic operation or a general synchronization primitive.

    A retrying CAS loop must recompute from the new observed value after a
    failed attempt. ABA (value changes A->B->A) and object lifetime can still
    wreck a lock-free structure despite every individual CAS being atomic.
    Atomic instruction != correct algorithm. I can trust the CAS and still
    reject the data structure. Check ownership, lifetime and every retry path.

    Exercise (paper first): two threads start counter=13, each adds 40.
    List an interleaving yielding 53 without LOCK, then explain why atomic
    fetch-add gives 93. If implementing a spin loop, PAUSE is a useful hint;
    it doesn't release a lock, yield the OS thread, or act as a memory fence.
    For actual long waits prefer OS/library synchronization over burning CPU.
    A core spinning at full load isn't proof useful work is happening.
*/
