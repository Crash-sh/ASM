/* ==================== NSD / KERNEL UPLINK ======================
    We're crossing the userspace/kernel boundary. Load the syscall number,
    wire up the arguments, inspect the return value. Linux owns this gate.
    The NSD badge gets you exactly fuck-all if the descriptor isn't valid.
    Task: move bytes from stdin to stdout until EOF. Account for every byte.

    Build: gcc -g -nostdlib -no-pie -x assembler 08_syscalls_and_io_thingy.asm -o /tmp/copy
    Run: printf 'link online\n' | /tmp/copy
    Expected: link online followed by newline, exit 0.
    Interactive: type lines; Ctrl-D at an empty terminal input line gives EOF.

    Linux x86-64 raw syscall interface:
        RAX = syscall number
        RDI RSI RDX R10 R8 R9 = arguments 1..6
        RAX = return value
        RCX and R11 = CLOBBERED by syscall
    Arg #4 is R10, not RCX like a C function! syscall uses RCX to save the
    return instruction address, and R11 for saved flags. Don't keep your
    loop counter in RCX across it. Also don't rely on arithmetic flags after.
    Document the clobbers before you write the loop. Saves a long fucking night.

    File descriptors are small integers naming open resources in a process.
    Convention: stdin=0, stdout=1, stderr=2. Redirection changes what those
    descriptors refer to, not our code. Could be terminal, pipe, regular file.
    read(0,buffer,capacity): positive byte count, 0=EOF, negative raw error.
    write(1,buffer,length): positive bytes written, possibly LESS than length.
    Raw errors are -errno, in [-4095,-1]. Libc wrappers instead return -1
    and set errno. We're not linked to libc; nobody sets errno for us.

    For read/write specifically successful counts are nonnegative, so test
    rax,rax / js catches errors. Pointer-returning calls need the error-range
    comparison shown in 09. EINTR is 4 on this Linux ABI: retry -4.
    EAGAIN needs readiness handling for nonblocking descriptors; this example
    expects BLOCKING descriptors and treats other errors as failure.

    A read can return half a line, three lines, or a chunk of binary data.
    No NUL terminator is added. Forward exactly the returned bytes.
    Capacity belongs to us; never pass a larger count than the actual buffer.
    Sources: https://man7.org/linux/man-pages/man2/read.2.html
             https://man7.org/linux/man-pages/man2/write.2.html
             https://man7.org/linux/man-pages/man2/syscall.2.html
*/
.intel_syntax noprefix
.equ SYS_READ, 0
.equ SYS_WRITE, 1
.equ SYS_EXIT, 60
.equ EINTR, 4
.equ CAPACITY, 4096                  # Buffer size, not a claim about all page sizes.
.section .bss
buffer: .zero CAPACITY
.text
.globl _start
_start:
read_again:
    mov eax, SYS_READ
    xor edi, edi                   # stdin
    lea rsi, [rip + buffer]
    mov edx, CAPACITY
    syscall
    cmp rax, -EINTR
    je read_again
    test rax, rax
    js io_failed
    jz success                     # EOF, not 'try again forever'.

    mov rdx, rax                   # Only the bytes we actually received.
    mov edi, 1
    call write_all                 # RSI still holds the buffer address.
    test rax, rax
    js io_failed
    jmp read_again
success:
    xor edi, edi
    jmp finish
io_failed:
    mov edi, 1
finish:
    mov eax, SYS_EXIT
    syscall

.type write_all, @function
write_all:
    # Contract: RDI fd, RSI readable pointer, RDX length.
    # Result: RAX=0 success, negative raw error otherwise.
    # Clobbers RAX,RCX,R11,RSI,RDX,flags; preserves callee-saved registers.
    # Empty writes succeed without touching the buffer.
    test rdx, rdx
    jz write_done
write_more:
    mov eax, SYS_WRITE
    syscall
    cmp rax, -EINTR
    je write_more                  # No progress reported; retry same range.
    test rax, rax
    js write_return
    jz write_stalled               # Avoid infinite retry if no bytes move.
    add rsi, rax                   # Skip the bytes successfully written.
    sub rdx, rax                   # Decrease remaining count by exactly that.
    jnz write_more
write_done:
    xor eax, eax
write_return:
    ret
write_stalled:
    mov rax, -5                    # Our helper reports -EIO for no progress.
    ret
.size write_all, .-write_all
.section .note.GNU-stack,"",@progbits

/*
    Known boundaries: no poll/epoll loop, no signal-handler installation.
    With a closed pipe reader, default SIGPIPE can terminate the process
    before we inspect EPIPE. Handling that is a separate signal policy.
    We don't promise durable disk storage merely because write succeeded.
    The copy loop reports transferred bytes. Durability needs a separate
    storage protocol. Know what your success signal actually guarantees.

    Raw exit(60) terminates the calling thread. Our examples have one thread.
    exit_group(231) ends all threads; libc exit normally uses process-wide
    termination after its own cleanup. main return is another layer still.

    Exercise: add a byte counter using R12, then format it after EOF using
    chapter 12's decimal conversion. Why is RCX a terrible place to keep it?
    Observe the boundary: strace -e read,write,exit /tmp/copy < some_file
    That's the kernel-facing record. Compare it with what you meant to request.
*/
