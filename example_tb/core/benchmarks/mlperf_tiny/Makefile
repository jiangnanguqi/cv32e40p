###########################################
### MLPerf Tiny ad01 build (wrapper)    ###
###########################################
# Builds the MLPerf Tiny anomaly-detection benchmark (ad01, INT8, portable
# TFLM kernels) for the CV32E40P example testbench, with the same pinned
# model, inputs, golden outputs and measured region as the riscv-imt-model
# platform's sw/examples/mlperf_tiny (and the Ibex port). The bare-metal
# runtime is the example testbench's (../../custom: crt0.S, vectors.S,
# syscalls.c, newlib; crt0.S runs the C++ constructors); cv32e40p/platform.c
# adds the counter control and the report; the linker script is
# ../common/link.ld (custom/link.ld without a global pointer; see the note in
# it) with a 16 KiB stack and a 64 KiB heap.
#
# Build the simulator first (make -C example_tb/core verilate), then:
#   make -C example_tb/core/benchmarks/mlperf_tiny        # fetch, host reference, build
#   ./example_tb/core/benchmarks/mlperf_tiny/run_tiny.sh   # run, log to runlogs/
#
# prepare.py fetches MLCommons Tiny and TFLM at the pinned revisions into
# .deps/ (or TINY_DIR/TFLM_DIR), checks the model and input hashes and
# generates model_data.cc and input_data.cc. The host reference (native g++)
# produces golden.h, the expected outputs the target checks against.

HERE  := $(CURDIR)
BUILD ?= $(HERE)/build
TINY_DIR ?= $(HERE)/.deps/tiny
TFLM_DIR ?= $(HERE)/.deps/tflm
PYTHON ?= python3
HOST_CXX ?= g++
JOBS ?= 2
# Measured Invoke() calls (12 on the platform's single-hart runs)
ITERATIONS ?= 12

# Compiling configuration
RV_ISA ?= rv32im
RV_ABI ?= ilp32
RISCV_TOOLS ?= riscv64-unknown-elf
CC      := $(RISCV_TOOLS)-gcc
CXX     := $(RISCV_TOOLS)-g++
OBJCOPY := $(RISCV_TOOLS)-objcopy
OBJDUMP := $(RISCV_TOOLS)-objdump
SIZE    := $(RISCV_TOOLS)-size

# Bare-metal runtime: the example testbench's custom/ files, unchanged
SYSTEM_COMMON := $(HERE)/../../custom
PORT_DIR      := $(HERE)/cv32e40p
LINKER_SCRIPT := $(HERE)/../common/link.ld
STACK_SIZE    ?= 0x4000
HEAP_SIZE     ?= 0x10000

TFLM_MICRO := $(TFLM_DIR)/tensorflow/lite/micro
TFLM_REL_SRCS := \
  flatbuffer_conversions.cc flatbuffer_utils.cc memory_helpers.cc \
  micro_allocation_info.cc micro_allocator.cc micro_common.cc micro_context.cc \
  micro_interpreter.cc micro_interpreter_context.cc micro_interpreter_graph.cc \
  micro_log.cc micro_op_resolver.cc micro_resource_variable.cc micro_utils.cc \
  arena_allocator/non_persistent_arena_buffer_allocator.cc \
  arena_allocator/persistent_arena_buffer_allocator.cc \
  arena_allocator/single_arena_buffer_allocator.cc \
  memory_planner/greedy_memory_planner.cc memory_planner/linear_memory_planner.cc \
  memory_planner/non_persistent_buffer_planner_shim.cc \
  kernels/kernel_util.cc kernels/fully_connected.cc kernels/fully_connected_common.cc \
  kernels/quantize.cc kernels/quantize_common.cc \
  kernels/dequantize.cc kernels/dequantize_common.cc \
  kernels/internal/common.cc kernels/internal/portable_tensor_utils.cc \
  kernels/internal/quantization_util.cc kernels/internal/tensor_ctypes.cc
TFLM_HOST_OBJS := $(addprefix $(BUILD)/host/tflm/,$(TFLM_REL_SRCS:.cc=.o))
TFLM_RV_OBJS   := $(addprefix $(BUILD)/rv/tflm/,$(TFLM_REL_SRCS:.cc=.o))

INCLUDES := -I$(HERE) -I$(BUILD) -I$(TFLM_DIR) \
  -I$(TFLM_MICRO)/tools/make/downloads/flatbuffers/include
# -ffp-contract=off keeps the host reference and the target computing the
# same float results (the anomaly score and the input quantisation).
COMMON := -O3 -ffunction-sections -fdata-sections -ffp-contract=off \
  -DTF_LITE_STATIC_MEMORY -DFLATBUFFERS_LOCALE_INDEPENDENT=0
CXX_COMMON := $(COMMON) -std=c++17 -fno-exceptions -fno-rtti \
  -fno-threadsafe-statics -fno-use-cxa-atexit
# -misa-spec=2.2: see ../embench/Makefile
RV := -march=$(RV_ISA) -mabi=$(RV_ABI) -misa-spec=2.2 -mcmodel=medany -mstrict-align
RV_CFLAGS   := $(COMMON) $(RV) -std=gnu99 -ffreestanding -I$(SYSTEM_COMMON) -I$(HERE)/../common
RV_CXXFLAGS := $(CXX_COMMON) $(RV) -ffreestanding -DTF_LITE_USE_GLOBAL_CMATH_FUNCTIONS
DEPFLAGS := -MMD -MP

HOST_SHARED := $(BUILD)/host/model_runner.o $(BUILD)/host/model_data.o $(BUILD)/host/input_data.o
RV_SHARED   := $(BUILD)/rv/model_runner.o $(BUILD)/rv/model_data.o $(BUILD)/rv/input_data.o
RV_OBJS := $(TFLM_RV_OBJS) $(RV_SHARED) $(BUILD)/rv/benchmark_main.o $(BUILD)/rv/target_log.o \
  $(BUILD)/rv/platform.o $(BUILD)/rv/syscalls.o $(BUILD)/rv/vectors.o $(BUILD)/rv/crt0.o

ELF := $(HERE)/tiny-ad01.elf

.PHONY: all prepare host elf clean

all: prepare
	$(MAKE) --no-print-directory -j$(JOBS) elf

prepare:
	$(PYTHON) prepare.py --tiny-dir '$(TINY_DIR)' --tflm-dir '$(TFLM_DIR)' --build-dir '$(BUILD)'

host: prepare
	$(MAKE) --no-print-directory -j$(JOBS) $(BUILD)/golden.h

elf: $(ELF) $(HERE)/tiny-ad01.hex $(HERE)/tiny-ad01.dis

# ---- host reference (native build of the same model and kernels) ----
$(BUILD)/host/tflm/%.o: $(TFLM_MICRO)/%.cc
	@mkdir -p $(@D)
	$(HOST_CXX) $(CXX_COMMON) $(INCLUDES) $(DEPFLAGS) -c $< -o $@
$(BUILD)/host/%.o: $(BUILD)/%.cc
	@mkdir -p $(@D)
	$(HOST_CXX) $(CXX_COMMON) $(INCLUDES) $(DEPFLAGS) -c $< -o $@
$(BUILD)/host/%.o: %.cc
	@mkdir -p $(@D)
	$(HOST_CXX) $(CXX_COMMON) $(INCLUDES) $(DEPFLAGS) -c $< -o $@
$(BUILD)/host/debug_log.o: $(TFLM_MICRO)/debug_log.cc
	@mkdir -p $(@D)
	$(HOST_CXX) $(CXX_COMMON) $(INCLUDES) $(DEPFLAGS) -c $< -o $@
$(BUILD)/host_reference: $(TFLM_HOST_OBJS) $(HOST_SHARED) $(BUILD)/host/host_reference.o $(BUILD)/host/debug_log.o
	$(HOST_CXX) -Wl,--gc-sections $^ -lm -o $@
$(BUILD)/golden.h: $(BUILD)/host_reference
	$(BUILD)/host_reference > $@.tmp 2> $(BUILD)/host_reference.log
	mv $@.tmp $@

# ---- target ----
$(BUILD)/rv/tflm/%.o: $(TFLM_MICRO)/%.cc
	@mkdir -p $(@D)
	$(CXX) $(RV_CXXFLAGS) $(INCLUDES) $(DEPFLAGS) -c $< -o $@
$(BUILD)/rv/%.o: $(BUILD)/%.cc
	@mkdir -p $(@D)
	$(CXX) $(RV_CXXFLAGS) $(INCLUDES) $(DEPFLAGS) -c $< -o $@
$(BUILD)/rv/%.o: %.cc
	@mkdir -p $(@D)
	$(CXX) $(RV_CXXFLAGS) $(INCLUDES) $(DEPFLAGS) -c $< -o $@
$(BUILD)/rv/benchmark_main.o: benchmark_main.cc $(BUILD)/golden.h
	@mkdir -p $(@D)
	$(CXX) $(RV_CXXFLAGS) -DTINY_ITERATIONS=$(ITERATIONS) $(INCLUDES) $(DEPFLAGS) -c $< -o $@
$(BUILD)/rv/platform.o: $(PORT_DIR)/platform.c
	@mkdir -p $(@D)
	$(CC) $(RV_CFLAGS) $(INCLUDES) $(DEPFLAGS) -c $< -o $@
$(BUILD)/rv/syscalls.o: $(SYSTEM_COMMON)/syscalls.c
	@mkdir -p $(@D)
	$(CC) $(RV_CFLAGS) $(DEPFLAGS) -c $< -o $@
$(BUILD)/rv/vectors.o: $(SYSTEM_COMMON)/vectors.S
	@mkdir -p $(@D)
	$(CC) $(RV) -c $< -o $@
$(BUILD)/rv/crt0.o: $(SYSTEM_COMMON)/crt0.S
	@mkdir -p $(@D)
	$(CC) $(RV) -c $< -o $@

$(ELF): $(RV_OBJS) $(LINKER_SCRIPT)
	$(CXX) $(RV) -static -nostartfiles -Wl,--gc-sections -T $(LINKER_SCRIPT) \
	  -Wl,--defsym=__stack_size=$(STACK_SIZE) -Wl,--defsym=__heap_size=$(HEAP_SIZE) \
	  -Wl,-Map=$(HERE)/tiny-ad01.map $(RV_OBJS) \
	  -Wl,--start-group -lc -lm -lgcc -Wl,--end-group -o $@
	$(SIZE) $@
$(HERE)/tiny-ad01.hex: $(ELF)
	$(OBJCOPY) -O verilog $< $@
$(HERE)/tiny-ad01.dis: $(ELF)
	$(OBJDUMP) -S -D $< > $@

clean:
	rm -rf $(BUILD) $(ELF) $(HERE)/tiny-ad01.hex $(HERE)/tiny-ad01.dis $(HERE)/tiny-ad01.map

-include $(wildcard $(BUILD)/host/*.d $(BUILD)/rv/*.d)
-include $(TFLM_HOST_OBJS:.o=.d) $(TFLM_RV_OBJS:.o=.d)
