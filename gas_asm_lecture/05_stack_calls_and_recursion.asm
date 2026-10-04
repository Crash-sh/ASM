/* ==================== NSD / RETURN PATH =======================
    The stack carries saved state and return addresses. That's control-flow
    data sitting in writable memory. I count every byte going onto it and
    every byte coming off. Lose track and ret follows your garbage faithfully.
    Build: gcc -g -nostdlib -no-pie -x assembler 05_stack_calls_and_recursion.asm -o /tmp/stack
    Run /tmp/stack; echo $?     Expected 0.

    Stack grows toward LOWER addresses. For ordinary 64-bit push/pop:
        push rax   -> rsp -= 8; [rsp] = rax
        pop rax    -> rax = [rsp]; rsp += 8
        call func  -> pushes address of NEXT instruction, then jumps to func
        ret        -> pops that saved address into instruction execution
    ret takes the saved address from the stack. No function-name check.
    sub rsp,32 reserves 32 bytes; add rsp,32 releases them, without erasing.
    Uninitialized stack bytes aren't automatically zero. Initialize locals.

    System V AMD64 integer/pointer args: RDI RSI RDX RCX R8 R9.
    Integer/pointer result: RAX (small values use its appropriate low part).
    Caller-saved: RAX RCX RDX RSI RDI R8 R9 R10 R11, vector registers.
    Callee-saved: RBX RBP R12 R13 R14 R15, and restore RSP on return.
    'Saved' means an ABI agreement. The CPU doesn't enforce your promises.
    Need a caller-saved value AFTER call? Save it yourself before the call.
    Use a callee-saved register? Preserve your caller's old value first.

    For our ordinary calls, RSP must be divisible by 16 BEFORE call.
    call pushes 8 -> callee enters with rsp % 16 == 8.
    Wider stack-passed vectors can require stronger alignment; this course
    only passes scalar args / register vectors and uses the 16-byte case.

    RBP as frame pointer is a convention. The silicon doesn't require it.
    A frame makes locals/arguments easy to reference while RSP moves.
    Compilers often omit it. Debug unwind metadata can describe frames too.
*/
.intel_syntax noprefix
.text
.globl _start
_start:
    # Linux x86-64 process entry RSP is 16-byte aligned. Not function entry!
    mov r12, rsp                   # Keep the initial stack pointer for a check.
    mov ebx, 689                   # Sentinel to test our callee-saved promise.
    mov edi, 5
    call factorial
    cmp rax, 120
    jne failed
    cmp rbx, 689
    jne failed
    cmp rsp, r12
    jne failed

    xor edi, edi                   # 0! = 1, base-case boundary.
    call factorial
    cmp rax, 1
    jne failed
    # Function pointers aren't special either: a call can use a register.
    lea r11, [rip + add_two]
    mov edi, 13
    mov esi, 53
    call r11
    cmp rax, 66
    jne failed

    xor edi, edi
    jmp finish
failed:
    mov edi, 53
finish:
    mov eax, 60
    syscall

.type add_two, @function
add_two:
    lea rax, [rdi + rsi]            # Leaf function: no calls, no stack needed.
    ret
.size add_two, .-add_two

.type factorial, @function
factorial:
    # Contract: unsigned n in RDI, 0..20; return n! in RAX.
    # 21! doesn't fit uint64_t. This helper expects a bounded caller.
    # Recursion depth grows with n, so arbitrary input also risks stack space.
    push rbp                       # Entry: rsp%16=8 -> 0.
    mov rbp, rsp
    push rbx                       # rsp%16=8 again.
    sub rsp, 8                     # Back to 0; a local slot / alignment padding.
    mov QWORD PTR [rbp - 16], rdi   # Our slot; saved RBX lives at [rbp-8].
    mov eax, 1
    cmp rdi, 1
    jbe factorial_done

    mov rbx, rdi                   # RBX survives recursive call by the ABI.
    dec rdi
    call factorial                 # f(n-1), independent stack frame each time.
    imul rax, rbx                  # n * f(n-1), low product (fits our domain).
factorial_done:
    add rsp, 8                     # Undo reservation, in REVERSE order.
    pop rbx
    pop rbp
    ret
.size factorial, .-factorial
.section .note.GNU-stack,"",@progbits

/*
    Frame during factorial:
        [rbp+8]  return address
        [rbp]    caller's rbp
        [rbp-8]  saved rbx
        [rbp-16] our local n
    Before leaving, rsp must point at the right saved item. One extra push
    without restoring RSP and ret can consume the wrong slot as its target.
    A pristine-looking function body won't save a fucked return path.

    Linux SysV userspace also has a 128-byte red zone below RSP: signal
    handlers preserve it. A LEAF function can use it without moving RSP.
    Don't keep live data there across calls; callees use that space too.
    Kernel code and Windows don't share this userspace red-zone promise.

    Exercise: implement iterative factorial, then compare call depth in GDB.
    Try n=20 and compare to 2432902008176640000. Don't 'fix' n=21 by merely
    deleting an overflow check; a 64-bit register still has exactly 64 bits.
    You can argue with me. You can't negotiate another bit out of the register.
*/
