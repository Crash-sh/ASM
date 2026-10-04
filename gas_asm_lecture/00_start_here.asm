/* ==================== NSD / OPERATOR BRIEF ====================

    [link established]
    operator : CRASH
    division : Hardware / Architecture / Special Projects
    target   : x86-64

    Before you touch the console:
        0- These are Linux x86-64 programs. Intel OR AMD CPU, both fine.
        1- Syntax is GNU assembler (GAS), Intel operand order.
        2- Everything that teaches the lecture lives in these comments.
        3- Read in numeric order. Each example is its own program.
        4- Basic C knowledge helps. No previous assembly knowledge needed.

    x86 is a family, not a promise that every file runs on your 8086.
    We're primarily using its 64-bit mode (AMD64 / Intel 64). Chapter 14
    gives 32-bit x86 its own runnable example and explains the differences.
    Windows x64 has a different ABI. ARM has a different instruction set.
    A renamed file doesn't change the target. Check the architecture first.
    I work on bare metal too; this operation runs under Linux in userspace.
    Keep that boundary straight. An edgy banner doesn't grant ring 0.

    ======================= HOW TO RUN ========================

    Tools: GNU make, GCC, GNU binutils.
    GDB is optional for execution. For interrogation, keep it within reach.
    To build just this file without the Makefile:
        gcc -g -x assembler 00_start_here.asm -o /tmp/asm_intro
        /tmp/asm_intro

    Why -x assembler? GCC doesn't automatically treat .asm as assembly.
    .s normally means assembly; .S means assembly with C preprocessing.
    We explicitly choose plain assembly. No C preprocessor on this route.
    The assembler translates instructions into machine-code bytes.
    The linker joins objects, resolves symbols and creates an ELF binary.
    GCC here is a driver arranging those steps and linking libc for main.
    It does NOT translate this into C first. Assembly goes to the assembler.

    Most chapters use _start and skip libc. Their command is:
        gcc -g -nostdlib -no-pie -x assembler FILE.asm -o /tmp/thingy
    Chapters 00 and 06 use main and the ordinary GCC link command instead.
    Build these files separately. Each supplies its own entry point;
    linking them together gives duplicate symbols. Check the build command.

    ======================== ROADMAP ==========================

    00 - This file: CPU / assembler / OS, syntax, first libc call.
    01 - Registers, widths, partial writes, signedness, extensions.
    02 - Sections, addresses, dereferencing, arrays, little endian.
    03 - Arithmetic, flags, carry chains, multiplication and division.
    04 - Comparisons, branches, loops, masks, shifts and rotates.
    05 - Stack, call/ret, saved registers, locals and recursion.
    06 - System V ABI, printf, seven arguments, calling C and PIE.
    07 - Byte strings, explicit lengths, rep instructions and DF.
    08 - Raw Linux read/write, EOF, short writes and errors.
    09 - mmap/munmap, struct layout and a tiny linked list.
    10 - Floating point and SSE2 SIMD without AVX prerequisites.
    11 - Atomic operations, cmpxchg, CPU ordering and limitations.
    12 - Final project: argv parsing + FizzBuzz + decimal formatting.
    13 - GDB, ELF, relocations, instruction bytes and performance.
    14 - Optional 32-bit program. Legacy target, different ABI.

    Chapters 01-05, 07, 09-11 and 13 are quiet on success. Check the
    exit status with echo $? IMMEDIATELY afterwards. Zero = worked.
    53 = our internal check failed. 13 = bad input in the final project.
    1 = I/O or mapping failure. Shell status only keeps the low 8 bits,
    so 689 gets truncated. The shell doesn't care about NSD's favorite numbers.

    =================== WHAT THE CPU SEES =====================

    C says: x += 5;
    Assembly might say: add eax, 5
    The CPU sees encoded bytes. Variable names and comments aren't CPU
    features; they're the annotations we leave for the next operator.

    An instruction set (ISA) specifies visible behavior: registers,
    instructions, flags. A microarchitecture is HOW a particular CPU
    implements that contract: caches, pipelines, execution units etc.
    One assembly instruction is not necessarily one cycle or one internal
    operation. Fewer lines doesn't automatically mean faster. Bring measurements.
    'Looks faster' is marketing. I don't take performance reports from marketing.

    Registers hold working values. Memory is addressed byte by byte.
    RIP tracks instruction execution. RFLAGS holds condition/status bits.
    The OS gives our process virtual memory and controls privileged work.
    Writing assembly does not grant root or let you casually touch hardware.
    Ring 3 is userspace; ring 0 is kernel privilege. syscall asks the kernel
    to do something under its rules. Your process still has to pass its checks.

    ====================== WIRE FORMAT ========================

    GAS Intel syntax:      mov eax, 13       destination, source
    GAS AT&T syntax:       movl $13, %eax    source, destination
    NASM Intel syntax:     mov eax, 13       similar instruction spelling

    But directives differ! GAS uses .section, .byte, .quad, .globl;
    NASM commonly uses section, db, dq, global. Don't paste NASM directives
    into GAS and blame the CPU. Wrong toolchain, wrong result. Comments here are
    slash-star blocks or # line comments; semicolon separates statements.

    Label: a name for a position. No bytes consumed by the label itself.
    Directive: an instruction to the assembler, usually starts with a dot.
    Mnemonic: a readable CPU operation name, such as mov, add, call, ret.
    Immediate: a literal number encoded in the instruction, such as 13.
    Register operand: eax. Memory operand: DWORD PTR [rip + some_label].
    PTR is an operand-size annotation, not a C pointer declaration.

    I'll explain each instruction when we reach it. Keep the manual open
    for exact behavior. You don't need to memorize it; you need to stop
    guessing when the answer is sitting in the fucking specification.

    Technical records (datasheets are long threat letters; read the terms):
    GAS syntax/directives: https://sourceware.org/binutils/docs/as/
    ISA manuals: https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html
    System V AMD64 ABI: https://gitlab.com/x86-psABIs/x86-64-ABI
    Linux syscall ABI: https://man7.org/linux/man-pages/man2/syscall.2.html
    GDB: https://sourceware.org/gdb/current/onlinedocs/gdb.html/
    The ABI and manuals define the contract. Even Crash has to obey the pins.
*/

.intel_syntax noprefix             # Intel order, no % before registers.
.section .rodata                   # Read-only data in the linked program.
greeting:
    .asciz "CRASH@NSD: instruction stream online."
    # .asciz emits bytes AND a trailing zero. puts expects that terminator.

.section .text                     # Machine instructions live here.
.globl main                        # Export main so the C startup can find it.
.type main, @function              # ELF metadata; not a CPU instruction.
main:
    push rbp                       # Save our caller's frame pointer.
    mov rbp, rsp                    # Establish our frame. Chapter 05 explains.
    # main enters with rsp % 16 == 8. push subtracts 8: now aligned for call.
    lea rdi, [rip + greeting]       # First C argument = ADDRESS of greeting.
    call puts@PLT                  # libc puts prints string + newline.
    # PLT is a linker mechanism for calling an external function. Chapter 06.
    xor eax, eax                   # Return value 0, like return(0); in C.
    pop rbp                        # Restore what we borrowed.
    ret                            # Return to C runtime, which exits for us.
.size main, .-main                  # Function size = current position - main.

# Tell the linker this object doesn't require executable stack memory.
.section .note.GNU-stack,"",@progbits

/*
    Exercise: change the greeting, build again, observe what changes.
    Then objdump -d -Mintel /tmp/asm_intro and find main.
    There's extra startup code because libc programs have a runtime around
    them. Next chapter we enter at _start and handle termination ourselves.
    One abstraction removed. Keep going.
*/
