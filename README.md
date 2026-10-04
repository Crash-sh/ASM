# ASM

> Some x86_64 Linux assembly


### Dir

```text
ASM/
    extra_resources/
        RESOURCES.md
        register_chart.png
    
    gas_asm_lecture/
        00_start_here.asm
        01_registers_and_sizes.asm
        02_memory_and_pointer_hell.asm
        03_arithmetic_and_flag_drama.asm
        04_branches_loops_and_bit_wizardry.asm
        05_stack_calls_and_recursion.asm
        06_calling_c_without_pissing_off_the_abi.asm
        07_strings_without_training_wheels.asm
        08_syscalls_and_io_thingy.asm
        09_mmap_and_structs_in_the_wild.asm
        10_float_and_simd_fuckery.asm
        11_atomic_does_not_mean_nuclear.asm
        12_fizzbuzz_final_boss.asm
        13_debugging_and_reading_the_nudes.asm
        14_x86_32_time_machine.asm
    
    nasm/
        diagrams/
            some_diagrams_to_visualize_what_happening
        exp/
            fuck_ton_of_markdown_explaining_whats_going_on
        examples/
            00_start_here.asm
            01_registers_and_sizes.asm
            02_memory_and_pointer_hell.asm
            03_arithmetic_and_flag_drama.asm
            04_branches_loops_and_bit_wizardry.asm
            05_stack_calls_and_recursion.asm
            06_calling_c_without_pissing_off_the_abi.asm
            07_strings_without_training_wheels.asm
            08_syscalls_and_io_thingy.asm
            09_mmap_and_structs_in_the_wild.asm
            10_float_and_simd_fuckery.asm
            11_atomic_does_not_mean_nuclear.asm
            12_fizzbuzz_final_boss.asm
            13_debugging_and_reading_the_nudes.asm
            14_x86_32_time_machine.asm
            15_user_input.asm
        INFO_DUMP.md
        QUICK_REFERENCES.md
        REFERENCES.md
        README.md

    nasm_experiments/
        00_init.asm

    .gitignore
    README.md
```

### Notes

> [gas_asm_lecture](gas_asm_lecture/) are same lectures from [Basic-C-Repo Lectures](https://github.com/neurmancer/Basic-C-Examples)
> [nasm_experiments](nasm_experiments/) on the other hand, are writtten for NASM assembler(therefore uses Intel syntax)

### NASM tutorial

[Start the NASM field manual](extra_resources/nasm/README.md): 18 structured chapters, commented runnable examples, PNG diagrams, exercises, and a walkthrough of the input program. Follows the GAS lecture progression using NASM syntax.
