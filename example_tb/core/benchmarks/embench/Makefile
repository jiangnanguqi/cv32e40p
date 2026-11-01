###########################################
### Embench one-shot build (wrapper)    ###
###########################################
# Builds the Embench benchmarks for the CV32E40P example testbench with
# Embench's own scons flow, in the same way as the Embench wrapper of the
# riscv-imt-model platform (and of the Ibex port). The board port is in
# cv32e40p/ (boardsupport.c switches the performance counters) and the
# bare-metal runtime is the example testbench's (../../custom: crt0.S,
# vectors.S, syscalls.c, newlib), with the linker script ../common/link.ld
# (custom/link.ld without a global pointer; see the note in it).
#
# Build the simulator first (make -C example_tb/core verilate), then:
#   make -C example_tb/core/benchmarks/embench            # all 19 benchmarks
#   ./example_tb/core/benchmarks/embench/run_embench.sh    # run them, logs to runlogs/
# See ../README.md.

# Embench source (git submodule pinned to the revision used by the platform)
EMBENCH_DIR ?= $(CURDIR)/embench-iot
PORT_DIR    ?= $(CURDIR)/cv32e40p

# Compiling configuration
RV_ISA ?= rv32im
RV_ABI ?= ilp32
RISCV_TOOLS ?= riscv64-unknown-elf
CC      := $(RISCV_TOOLS)-gcc
AR      := $(RISCV_TOOLS)-ar
OBJDUMP := $(RISCV_TOOLS)-objdump
OBJCOPY := $(RISCV_TOOLS)-objcopy

OPATH     ?= $(CURDIR)/
BUILD_DIR ?= $(OPATH)build-embench
LOG_DIR   ?= $(OPATH)runlogs

# Bare-metal runtime: the example testbench's custom/ files, unchanged
SYSTEM_COMMON := $(CURDIR)/../../custom
CRT           := $(SYSTEM_COMMON)/crt0.S
LINKER_SCRIPT := $(CURDIR)/../common/link.ld
STACK_SIZE    ?= 0x4000

BM_DIR  := $(BUILD_DIR)/baremetal
BM_LIB  := $(BM_DIR)/libbm.a
BM_OBJS := $(BM_DIR)/embench_report.o
# The runtime is linked as objects, not from the library, as the example
# testbench's own rules do: nothing references crt0.o's symbols (link.ld
# names the entry point), the vector table is kept by link.ld only if
# vectors.o is in the link, and syscalls.o must come before newlib so that
# its system calls, not libgloss's ecall-based ones, are used.
RT_OBJS := $(BM_DIR)/crt0.o $(BM_DIR)/vectors.o $(BM_DIR)/syscalls.o

# -misa-spec=2.2 lets rv32im imply Zicsr (needed for the CSR instructions)
# with toolchains whose default ISA specification is newer, e.g. xPack; the
# platform's own toolchain is built with --with-isa-spec=2.2 and ignores it.
PORT_CFLAGS = -O3 -march=$(RV_ISA) -mabi=$(RV_ABI) -misa-spec=2.2 -mcmodel=medany -static \
		-std=gnu99 -fno-common -nostartfiles -ffreestanding \
		-mstrict-align -falign-functions=16 -falign-jumps=4

CFLAGS_COMMON   = $(PORT_CFLAGS) -I$(SYSTEM_COMMON) -I$(PORT_DIR) -I$(CURDIR)/../common
# --wrap=main routes Embench's unchanged main() through embench_report.c, which
# prints the counters and the verification result after the run.
LDFLAGS_COMMON := -nostartfiles -static -march=$(RV_ISA) -mabi=$(RV_ABI) -mcmodel=medany \
                  -T $(LINKER_SCRIPT) -Wl,-gc-sections -Wl,--wrap=main \
                  -Wl,--defsym=__stack_size=$(STACK_SIZE) \
                  -Wl,-Map=$(OPATH)bench.map -L$(BM_DIR) $(RT_OBJS)

# Global scale factor (one hart, so the same as the platform's TOTAL_GSF)
GSF ?= 12
WARMUP_HEAT ?= 1

.PHONY: all embench baremetal clean

all: embench

$(BM_DIR):
	mkdir -p $(BM_DIR)

$(BM_DIR)/crt0.o: $(CRT) | $(BM_DIR)
	$(CC) $(CFLAGS_COMMON) -c $< -o $@

$(BM_DIR)/vectors.o: $(SYSTEM_COMMON)/vectors.S | $(BM_DIR)
	$(CC) $(CFLAGS_COMMON) -c $< -o $@

$(BM_DIR)/syscalls.o: $(SYSTEM_COMMON)/syscalls.c | $(BM_DIR)
	$(CC) $(CFLAGS_COMMON) -c $< -o $@

$(BM_DIR)/embench_report.o: $(PORT_DIR)/embench_report.c | $(BM_DIR)
	$(CC) $(CFLAGS_COMMON) -c $< -o $@

$(BM_LIB): $(BM_OBJS)
	$(AR) rcs $@ $^

baremetal: $(BM_LIB) $(RT_OBJS)

# One-shot build of all Embench benchmarks using scons
embench: baremetal
	mkdir -p $(BUILD_DIR) $(LOG_DIR)
	cd $(EMBENCH_DIR) && scons \
	  --build-dir=$(BUILD_DIR) \
	  --config-dir=$(PORT_DIR) \
	  cc=$(CC) \
	  cflags='$(CFLAGS_COMMON)' \
	  ldflags='$(LDFLAGS_COMMON)' \
	  user_libs='bm m gcc' \
	  gsf=$(GSF) \
	  warmup_heat=$(WARMUP_HEAT)
	$(MAKE) embench-post

clean:
	rm -rf $(BUILD_DIR)
	$(MAKE) embench-clean-post

# ---- Post-processing: collect .elf, .hex (for +firmware) and .dis ----
EMBENCH_TOP      := $(CURDIR)
EMBENCH_EXEC_ROOT:= $(BUILD_DIR)/src

.PHONY: embench-post embench-clean-post

embench-post:
	@set -e; \
	for d in "$(EMBENCH_EXEC_ROOT)"/*; do \
	  [ -d "$$d" ] || continue; \
	  b=$$(basename "$$d"); \
	  in="$$d/$$b"; \
	  [ -f "$$in" ] || continue; \
	  cp -f "$$in" "$(EMBENCH_TOP)/$$b.elf"; \
	  "$(OBJCOPY)" -O verilog "$$in" "$(EMBENCH_TOP)/$$b.hex"; \
	  "$(OBJDUMP)" -S -D "$$in" > "$(EMBENCH_TOP)/$$b.dis"; \
	done

embench-clean-post:
	rm -f "$(EMBENCH_TOP)"/*.elf "$(EMBENCH_TOP)"/*.hex "$(EMBENCH_TOP)"/*.dis "$(EMBENCH_TOP)"/*.map
