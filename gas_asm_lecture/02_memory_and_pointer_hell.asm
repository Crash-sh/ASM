/* ==================== NSD / MEMORY ACCESS =====================
    Memory map acquired. Now distinguish the address from the bytes at it.
    Get that wrong and you'll spend the night inspecting a fault dump.
    I want the address, access width and permission checked before the write.
    Build: gcc -g -nostdlib -no-pie -x assembler 02_memory_and_pointer_hell.asm -o /tmp/mem
    Run /tmp/mem; echo $?     Expected 0.

    A label names an address. Memory at that address holds bytes.
    lea rax,[rip+number] calculates &number. No memory read happens.
    mov eax,DWORD PTR [rip+number] reads number's four bytes.
    mov DWORD PTR [rax],53 writes four bytes to the address in RAX.
    Those are the operations behind &, * and *p=53. Follow the actual access.

    Ordinary integer mov doesn't support two memory operands. To copy
    [a] into [b], load a register then store it. Also memory has no int tag:
    mov QWORD PTR [a],53 writes EIGHT bytes even if a was declared .long.
    Four extra bytes get overwritten. The assembler won't flag your intent
    as a type error; you explicitly requested an eight-byte store. Own it.

    Sections:
        .text   code, normally mapped executable and read-only
        .rodata constants, normally mapped read-only
        .data   initialized writable storage
        .bss    zero-initialized writable storage, no full zero blob on disk
    ELF sections help the linker. Loadable SEGMENTS tell the loader what to
    map; sections and segments aren't interchangeable words. Chapter 13.
    Stack and heap mappings are separate from these static variables.

    Pointers here are virtual addresses, not physical RAM coordinates.
    Memory permissions are page-granular. An illegal access may fault;
    an out-of-bounds access that stays in mapped memory may silently work
    and corrupt adjacent data. Silent corruption is still corruption.
    'It didn't crash' is a shit inspection report. Check the bounds.

    x86 is little endian: least significant byte at the lowest address.
    .long 0x12345678 -> bytes 78 56 34 12 at increasing addresses.
    Bytes aren't bit-reversed. Network byte order is usually big endian;
    inspect the byte dump before you ship a reversed field over the wire.
*/
.intel_syntax noprefix
.section .rodata
pattern: .long 0x12345678
numbers: .long 13, 53, 689, -1
.equ NUMBER_COUNT, (. - numbers) / 4
# .equ is an assembler-time constant. '.' is the current position.
# .long emits 4 bytes here; C long on this ABI is 8. Names aren't a size check.
.section .data
mutable: .long 13
.section .bss
.balign 8                          # Align the next label to an 8-byte boundary.
saved_pointer: .zero 8             # Space for one pointer, initially zero.
result: .zero 8

.text
.globl _start
_start:
    movzx eax, BYTE PTR [rip + pattern]
    cmp eax, 0x78                  # First byte is the LOW byte.
    jne failed
    mov eax, DWORD PTR [rip + pattern]
    bswap eax                      # Reverse the order of four bytes.
    cmp eax, 0x78563412
    jne failed

    lea rax, [rip + mutable]
    mov QWORD PTR [rip + saved_pointer], rax
    mov rdx, QWORD PTR [rip + saved_pointer]
    mov DWORD PTR [rdx], 53         # *saved_pointer = 53, with a 32-bit pointee.
    cmp DWORD PTR [rip + mutable], 53
    jne failed

    # Effective address: base + index*scale + displacement.
    # Scale can be 1,2,4,8. Here an int takes 4 bytes, so arr[i] uses i*4.
    # There's no automatic pointer scaling like C's int_ptr++.
    # RIP-relative operands can't also contain an index; load a base first.
    lea rsi, [rip + numbers]
    xor ecx, ecx                   # i = 0
    xor eax, eax                   # signed 64-bit sum = 0
sum_loop:
    cmp rcx, NUMBER_COUNT
    jae sum_done                   # Check bounds BEFORE accessing arr[i].
    movsxd rdx, DWORD PTR [rsi + rcx*4]
    add rax, rdx                   # Need sign-extension to sum the -1 properly.
    inc rcx
    jmp sum_loop
sum_done:
    mov QWORD PTR [rip + result], rax
    cmp rax, 754
    jne failed

    lea rdx, [rsi + 2*4]            # &numbers[2]; LEA doesn't dereference it.
    cmp DWORD PTR [rdx], 689
    jne failed
    xor edi, edi
    jmp finish
failed:
    mov edi, 53
finish:
    mov eax, 60
    syscall
.section .note.GNU-stack,"",@progbits

/*
    In GDB: x/4wx &numbers displays four 32-bit words in hexadecimal.
    x/16bx &numbers displays the SAME storage as sixteen individual bytes.
    Exercise: extend numbers with 7. NUMBER_COUNT adjusts automatically;
    change expected sum to 761. Then try forgetting sign extension and
    explain the huge positive sum from the incorrectly extended value.
    No random behavior to blame. The bit pattern tells you exactly why.

    Alignment: ordinary scalar x86 loads often allow unaligned addresses,
    but crossing cache lines/pages can cost more, and some SIMD instructions
    require alignment. Page permissions still apply to every byte touched.
*/
