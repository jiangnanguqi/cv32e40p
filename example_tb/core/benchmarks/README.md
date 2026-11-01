# Embench and MLPerf Tiny on the CV32E40P example testbench

Single-hart runs of the two benchmark suites used by the riscv-imt-model
platform, on this fork's example testbench (`cv32e40p_tb_subsystem`:
CV32E40P, `mm_ram` and the stdout/exit peripherals) simulated with Verilator.
The ports follow the platform's `sw/examples/embench` and
`sw/examples/mlperf_tiny`, and the Ibex fork's `examples/sw/benchmarks`, so
that the same sources, compiler options and measured regions are used on all
three; see `../../../README.md` of the Ibex fork's benchmark directory for
the common description.

## Simulator

The core is built in its default configuration (`COREV_PULP=0`,
`COREV_CLUSTER=0`, `FPU=0`, `ZFINX=0`) with `mm_ram`'s memory stalls and the
random interrupt generator disabled, so instruction and data requests are
answered in the next cycle. `tb_top_verilator.sv`/`.cpp` follow core-v-verif's
`cv32e40p/tb/core/tb_top_verilator.*`; the Makefile targets are named like
core-v-verif's. From the repository root:

```
make -C example_tb/core verilate
make -C example_tb/core veri-run FIRMWARE=path/to/program.hex    # any program
```

`cv32e40p_tb_subsystem.sv` and `tb_top.sv` had the parameter names
`PULP_XPULP`/`PULP_CLUSTER` of an older `cv32e40p_top`; they are renamed to
`COREV_PULP`/`COREV_CLUSTER`, otherwise the example testbench does not
elaborate against the current core.

## Toolchain

The benchmarks are compiled with `riscv64-unknown-elf-gcc` (RISCV_TOOLS
selects another prefix, e.g. `RISCV_TOOLS=riscv-none-elf` for xPack),
`-march=rv32im -mabi=ilp32`, `-O3`, `-mstrict-align`, `-falign-functions=16
-falign-jumps=4`, `-mcmodel=medany`, as on the platform. The bare-metal
runtime is the example testbench's `custom/` (crt0.S, vectors.S, syscalls.c,
newlib), with `common/link.ld`: `custom/link.ld` without a global pointer,
like Ibex's Simple System runtime and the platform's single-hart build, so
that the linker relaxes no small-data access to gp-relative addressing and the
measured regions contain the same instructions on all three (see the note in
the script). `common/bench_counters.h`, shared with the Ibex port, starts and
stops `mcycle`/`minstret` through `mcountinhibit`.

## Embench

Embench is a git submodule at `embench/embench-iot`, pinned to the platform's
revision (`09c2ed8`, 19 benchmarks). `embench/Makefile` wraps Embench's scons
build; the board port is `embench/cv32e40p/boardsupport.c` (start/stop of the
counters around `benchmark()`, `GSF=12`, `WARMUP_HEAT=1`), and
`embench/cv32e40p/embench_report.c` wraps `main()` to print the counts and
the verification result afterwards.

```
git submodule update --init example_tb/core/benchmarks/embench/embench-iot
make -C example_tb/core/benchmarks/embench
./example_tb/core/benchmarks/embench/run_embench.sh
```

Each log in `embench/runlogs` ends with

```
Embench cycles=37113888 instret=30215130
Main Exit=0
EXIT SUCCESS
Cycles executed: 37149014
```

`Main Exit=0` means Embench's own `verify_benchmark()` accepted the result;
`EXIT SUCCESS` is the testbench seeing the same value in its exit register.
The counts are raw cycle and retired-instruction counts of the measured region
(plus the few instructions of the counter control), not Embench's normalised
scores.

## MLPerf Tiny (anomaly detection, ad01)

`mlperf_tiny` runs the ad01 INT8 model on TensorFlow Lite Micro's portable
kernels exactly as the platform's example does: MLCommons Tiny and TFLM are
fetched at pinned revisions by `prepare.py`, the model and input hashes are
checked, three real input windows are checked against a native reference
build (`golden.h`), one untimed warm-up is run, and `ITERATIONS` (default 12)
calls of `Invoke()` are measured. This is not the official MLPerf Tiny
submission flow; it measures the inference latency of the model only.
`mlperf_tiny/cv32e40p/platform.c` adds the counter control and the report,
which is buffered and printed after the measured region.

```
make -C example_tb/core/benchmarks/mlperf_tiny
./example_tb/core/benchmarks/mlperf_tiny/run_tiny.sh
```

The report lists the fixture checks (`TINY_CHECK ... mismatches=0`), the
measured counts (`TINY_STATS iterations=12 cycles=... instructions=...`),
`TINY_PASS` and `Main Exit=0`. Latency per inference is cycles / iterations.

## Recorded results

`embench/validation` and `mlperf_tiny/validation` keep the records of the
single-hart runs; `VALIDATION.md` there summarises them. The subfolder
`codex-20261030` holds the records of the earlier port (`benchmarks/imt_bench`
on branch `codex/embench-mlperf-single-hart-20261030`), which linked with a
global pointer and so has slightly different instruction counts.
