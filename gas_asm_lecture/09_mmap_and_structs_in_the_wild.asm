/* ==================== NSD / MAPPING CONTROL ===================
    Request a region. Check the result. Write two nodes. Walk the chain.
    Release the mapping. That's the operation, including cleanup.
    I don't leave live pointers aimed at memory I've already handed back.
    Some other allocation can occupy that address later. Bad place to get lazy.
    Build: gcc -g -nostdlib -no-pie -x assembler 09_mmap_and_structs_in_the_wild.asm -o /tmp/mapping
    Run /tmp/mapping; echo $?     Expected 0; mapping errors give 1.

    mmap requests a virtual-memory mapping. malloc usually subdivides larger
    regions and keeps bookkeeping; one mmap per tiny object is not an
    efficient malloc replacement. See descend/but_wtf_malloc_actually_is.c
    for Neuro's sbrk-based allocator experiment elsewhere in Basic-C-Examples repo.

    Linux mmap args: address hint, length, protection, flags, fd, offset.
    NULL hint lets kernel choose. PROT_READ|PROT_WRITE means readable/writable.
    MAP_PRIVATE|MAP_ANONYMOUS gives a private zero-initialized mapping without
    backing file; fd=-1, offset=0. Permissions deliberately exclude execute.
    Kernel rounds mapping length to page boundaries. We request 32 bytes;
    the object capacity is still 32. Page rounding isn't authorization to
    write past the object. Track the size you actually requested.
    munmap requires the page-aligned base and a nonzero length; matching our
    original requested length releases the mapping here.
    Source: https://man7.org/linux/man-pages/man2/mmap.2.html

    C model on Linux AMD64:
        struct node {
            int value;          // offset 0, 4 bytes
                                // offset 4, 4 bytes padding
            struct node *next;  // offset 8, 8 bytes
        };                      // total 16, alignment 8
    Assembly has no automatic struct layout unless we define one ourselves.
    Padding is space for alignment, not a secret member. If sharing with C,
    verify sizeof/offsetof and packing settings. Layout is part of the interface.
    A char, then a pointer is NOT necessarily offsets 0 and 1 in normal C.
*/
.intel_syntax noprefix
.equ SYS_MMAP, 9
.equ SYS_MUNMAP, 11
.equ NODE_VALUE, 0
.equ NODE_NEXT, 8
.equ NODE_SIZE, 16
.equ MAP_LENGTH, NODE_SIZE * 2
.text
.globl _start
_start:
    mov eax, SYS_MMAP
    xor edi, edi                   # addr hint = NULL
    mov esi, MAP_LENGTH
    mov edx, 3                     # PROT_READ(1) | PROT_WRITE(2)
    mov r10d, 0x22                 # MAP_PRIVATE(2) | MAP_ANONYMOUS(0x20)
    mov r8, -1                     # fd, ignored for this anonymous mapping
    xor r9d, r9d                   # offset
    syscall
    cmp rax, -4095
    jae map_failed                 # Unsigned high range encodes raw errors.
    # libc mmap would give MAP_FAILED=(void*)-1 and set errno instead.
    mov r12, rax                   # Own the mapping; preserve for cleanup.

    lea rdx, [r12 + NODE_SIZE]
    mov DWORD PTR [r12 + NODE_VALUE], 13
    mov QWORD PTR [r12 + NODE_NEXT], rdx
    mov DWORD PTR [rdx + NODE_VALUE], 53
    mov QWORD PTR [rdx + NODE_NEXT], 0

    mov rsi, r12                   # iter = first
    xor eax, eax                   # sum
walk_list:
    test rsi, rsi
    jz walk_done
    movsxd rdx, DWORD PTR [rsi + NODE_VALUE]
    add rax, rdx
    mov rsi, QWORD PTR [rsi + NODE_NEXT]
    jmp walk_list
walk_done:
    xor r13d, r13d
    cmp rax, 66
    je cleanup
    mov r13d, 53                   # Preserve result across munmap's RAX return.
cleanup:
    mov eax, SYS_MUNMAP
    mov rdi, r12
    mov esi, MAP_LENGTH
    syscall
    test rax, rax
    js map_failed
    xor r12d, r12d                 # Clear OUR pointer; other aliases wouldn't clear.
    mov edi, r13d
    jmp finish
map_failed:
    mov edi, 1
finish:
    mov eax, 60
    syscall
.section .note.GNU-stack,"",@progbits

/*
    Allocation record:
        mappings acquired: 1 if mmap succeeds
        mappings released: 1 on normal and internal-check cleanup paths
        pointers used after unmap: 0. Released means stop fucking touching it.

    This walk trusts the two nodes WE constructed. A general list imported
    from arbitrary bytes needs bounds, lifetime and cycle handling. Reading
    a forged next pointer means following an address supplied by bad data.
    Establish validity before dereferencing. The MMU won't validate your list.
    .data/.bss addresses last for process lifetime; stack locals for their
    frame; allocated regions until released. Same C lifetime idea, manually.
    Exercise: add a third node with -1, enlarge mapping request, expect 65.
    Then use offsets instead of absolute next pointers and explain why that
    representation is easier to serialize or move to a different base.
*/
