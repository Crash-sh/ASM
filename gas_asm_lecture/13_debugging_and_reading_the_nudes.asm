/* ==================== NSD / MACHINE INTERROGATION ==============
    'What the fuck does this actually do?' Good question. Attach GDB.
    I want the instruction bytes, the registers and the address it touched.
    A confident story about the source means nothing if the machine state
    contradicts it. Freeze execution. Inspect. Then form your explanation.

    Build: gcc -g -nostdlib -no-pie -x assembler 13_debugging_and_reading_the_nudes.asm -o /tmp/debugme
    Run /tmp/debugme; echo $?     Expected 0.

    ===================== GDB WALKTHROUGH =====================
        gdb /tmp/debugme
        set disassembly-flavor intel
        break _start
        run
        display/i $pc
        info registers rax rdi rsi rsp rip eflags
        disassemble /r _start
        si
        ni
    si steps ONE machine instruction, entering calls. ni steps over calls.
    $pc is GDB's program-counter name; $rip is the x86-64 register name.
    disassemble /r shows raw bytes as well as mnemonics.
    Source-line step/next can encompass multiple instructions; use si/ni.

    At _start (before lea executes):
        x/4wx &values             four 4-byte words, hex
        x/16bx &values            same memory, sixteen bytes
        x/s &note                 zero-terminated string
        x/4gx $rsp                four 8-byte slots on initial stack
        p/x $rax                  register shown in hex
        p/d $rax                  same register shown in decimal
    GDB expressions aren't assembler syntax. '$rax' here is a debugger thing.
    For labels without C type info, explicitly cast when needed, e.g.
        watch *(long long *)&observed
        continue
    Hardware watchpoints can stop when memory changes. Useful for finding
    the exact instruction that wrote a value. Catch the write that caused
    the damage instead of repeatedly inspecting its aftermath.

    Stop just before our helper, inspect stack, then step into it:
        break sum_four
        continue
        x/gx $rsp                 return address at function entry
        info registers rdi rsi
        finish                    run until function returns
        info registers rax
    Pick commands for your current stop; don't paste the entire lecture as
    one GDB script. Track where execution stopped before issuing the next command.

    For chapter 05 try break factorial, run, bt. Frame pointers help here.
    Unwind metadata (.cfi_* directives in compiler output) describes where
    saved registers/return addresses are. Our raw examples don't emit full
    CFI, so backtraces through arbitrary stops/prologues aren't guaranteed.
    gdb: info registers eflags after cmp shows ZF/CF/etc in readable form.

    ================= ELF / LINKER ARCHAEOLOGY =================
        readelf -h /tmp/debugme          ELF class, architecture, entry point
        readelf -S /tmp/debugme          sections
        readelf -l /tmp/debugme          segments and permissions
        nm -n /tmp/debugme               symbols ordered by address
        objdump -d -Mintel /tmp/debugme  code disassembly

    .text/.rodata/.data/.bss are assembler/linker organization. PT_LOAD
    segments are what the loader maps. A .bss region can have memory size
    greater than file size: zero-initialized storage without disk zero spam.
    GNU_STACK without E means stack isn't requested executable. W^X means
    avoiding simultaneously writable+executable mappings, a useful policy.

    To see relocations BEFORE the linker resolves local distances:
        gcc -g -c -x assembler 13_debugging_and_reading_the_nudes.asm -o /tmp/debugme.o
        objdump -dr -Mintel /tmp/debugme.o
        readelf -r /tmp/debugme.o
    A relocation tells the linker where/how to fill an address or displacement.
    RIP-relative addresses use the NEXT instruction's RIP plus displacement.
    A direct call commonly encodes a signed relative displacement too.
    Distances can be fixed at link time while absolute load address changes.

    x86 instructions have variable length (up to 15 bytes). Prefixes, opcode,
    ModR/M, optional SIB, displacement and immediate encode the operation.
    Not every instruction uses every field. SIB describes scaled indexing.
    REX prefixes support 64-bit operands/new registers; some newer instruction
    families use VEX/EVEX. Disassemble instead of guessing instruction size.
    A branch must land at the intended instruction boundary. Bytes in the
    middle can decode as completely different instructions. Valid decoding
    alone doesn't prove you found the intended instruction stream.

    ==================== READING COMPILER ASM =================
    From repository root, for example:
        gcc -O0 -g -S -masm=intel reallyBasicThings/basics/fizzbuzz.c -o /tmp/fizz-O0.s
        gcc -O2 -S -masm=intel reallyBasicThings/basics/fizzbuzz.c -o /tmp/fizz-O2.s
    -S stops at assembly output. -c produces an object. Normal linking makes
    an executable. -masm=intel chooses the textual syntax for GCC's output.
    Compare loops and local storage across optimization levels. Variables may
    disappear, stay in registers, or get combined. Source lines aren't a
    promise about the exact instructions an optimizer must generate.

    asmCNudes uses GAS directives even though filenames end in .asm. Most
    files choose Intel syntax, but cmpBits uses AT&T. Check before reading.
    .Lfoo labels are assembler-local conventions; .globl exports symbols.
    .file/.loc/.cfi are metadata/debugging directives, not ALU operations.
    endbr64 relates to Intel CET indirect-branch tracking, not the C logic.
    Don't cargo-cult compiler metadata you haven't understood into your code.
*/
.intel_syntax noprefix
.section .rodata
values: .long 13, 53, 689, -1
note: .asciz "CRASH: dump the bytes. Verify the claim."
.section .bss
.balign 8
observed: .zero 8
.text
.globl _start
_start:
    lea rdi, [rip + values]
    mov esi, 4
    call sum_four
    mov QWORD PTR [rip + observed], rax
    cmp rax, 754
    jne failed
    xor edi, edi
    jmp finish
failed:
    mov edi, 53
finish:
    mov eax, 60
    syscall

.type sum_four, @function
sum_four:
    # RDI -> int32_t array, RSI = count (despite name works for any valid count).
    # Return signed sum, assuming it fits int64_t; no writes to array.
    xor eax, eax
    xor ecx, ecx
sum_loop:
    cmp rcx, rsi
    jae sum_done
    movsxd rdx, DWORD PTR [rdi + rcx*4]
    add rax, rdx
    inc rcx
    jmp sum_loop
sum_done:
    ret
.size sum_four, .-sum_four
.section .note.GNU-stack,"",@progbits

/*
    ===================== DEBUGGING CHECKLIST =================
    Segfault? Inspect the faulting instruction and its address operands.
    Wrong number? Inspect WIDTH, sign/zero extension, stale registers, flags.
    Crash in printf? Check stack alignment, argument regs, AL, format types.
    Weird return? Compare pushes/pops/reservations on EVERY control-flow path.
    Infinite loop? Check initialization, termination and flag clobbers.
    SIGFPE? Check divisor AND full dividend/high half AND quotient overflow.
    SIGILL? Check CPU feature requirements and that execution reached code.
    GDB won't start? Some containers restrict ptrace; that is an environment
    restriction. Identify which layer refused the operation before debugging
    a program that never got a chance to execute.

    =================== PERFORMANCE INSPECTION =================
    Cache locality often matters more than shaving one instruction. Arrays
    are contiguous; linked lists chase dependent pointers. Independent work
    can overlap in the CPU; a dependency chain must wait for prior results.
    Branch prediction makes predictable branches cheap; cmov isn't always
    better because it may lengthen dependencies or compute unnecessary work.
    Syscalls per digit are usually far costlier than a few arithmetic ops.
    Buffer before showing off obscure instructions. Measure representative
    inputs, warm/cold behavior and actual target CPUs. perf may need system
    permission. Repeat measurements and account for noise. I don't sign off
    on throughput claims because one stopwatch reading looked sick.

    Next targets: instruction encoding, unwind tables, TLS via FS,
    dynamic linking, CPUID dispatch, vectorized parsers, and OS development.
    .code16 alone doesn't give you a bootloader; real mode, firmware entry,
    segmentation and executable format all need their own setup. These files
    run as userspace ELF. Bare metal means taking responsibility for the
    startup state and services Linux supplied here. That's the next briefing.

    [interrogation log closed]
    If it has registers, it can be questioned. Bring the fucking manual.
    -- Crash / NSD Hardware & Architecture
*/
