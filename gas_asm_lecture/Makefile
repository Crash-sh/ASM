# NSD / BUILD CONTROL. Operator: Crash.
# Each lesson owns its entry point. Build separate executables.
# Briefings and instruction notes live in the .asm files.
CC = gcc
AS = as
LD = ld
BUILD := build
SOURCES := $(filter-out 14_x86_32_time_machine.asm,$(wildcard *.asm))
PROGRAMS := $(patsubst %.asm,$(BUILD)/%,$(SOURCES))
LIBC_PROGRAMS := $(BUILD)/00_start_here $(BUILD)/06_calling_c_without_pissing_off_the_abi

.PHONY: all check32 clean
all: $(PROGRAMS)

$(BUILD):
	mkdir -p $@

$(LIBC_PROGRAMS): $(BUILD)/%: %.asm | $(BUILD)
	$(CC) -g -pie -x assembler $< -o $@

$(filter-out $(LIBC_PROGRAMS),$(PROGRAMS)): $(BUILD)/%: %.asm | $(BUILD)
	$(CC) -g -nostdlib -no-pie -x assembler $< -o $@

$(BUILD)/14_x86_32_time_machine.o: 14_x86_32_time_machine.asm | $(BUILD)
	$(AS) --32 -g $< -o $@

$(BUILD)/14_x86_32_time_machine: $(BUILD)/14_x86_32_time_machine.o
	$(LD) -m elf_i386 $< -o $@

check32: $(BUILD)/14_x86_32_time_machine
	./$(BUILD)/14_x86_32_time_machine
	@echo "NSD: i386 target verified. Exit status 0."

clean:
	$(RM) -r -- $(BUILD)
