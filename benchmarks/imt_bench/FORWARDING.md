# Experimental CV32E40P forwarding comparison

CV32E40P includes ordinary EX-to-ID and WB-to-ID forwarding. The pinned upstream
top-level interface has no parameter to disable it. `CV_FORWARDING=0` in this
additive benchmark port selects a generated experimental controller; it is not
an upstream core parameter or an officially validated alternative core.

## Implementation

`no_forwarding.py` reads the unchanged `rtl/cv32e40p_controller.sv` and generates
`build/.../cv32e40p_controller_no_forwarding.sv`. The build substitutes this one
module while retaining every other original RTL file. The generated patch is
saved beside the simulator and archived with the validation records.

The copy removes normal WB/EX operand selections and defaults them to the
register file. It adds a RAW interlock using the original source-use and
destination comparison signals. A dependent instruction waits until its
producer has written the register file, using the existing load-stall bubble
and hold mechanism. The original misaligned-access and multi-cycle MULH replay
selections remain: these feed the same instruction internally. Removing those
would change the implementation of those instructions, not just forwarding
between instructions. Other controller decisions, load/JALR interlocks and the
datapath remain unchanged.

`cv_forward_audit.sv` observes the controller selections. With forwarding off it
asserts that every accepted non-replay instruction uses the register file, and
reports zero ordinary EX/WB forwarded operands. Independent performance-counter
and UART audits remain active. This experiment measures cycle cost; it does not
remove the datapath muxes for synthesis or establish any Fmax/area benefit.

## Reproduce

The ordinary flow defaults to the untouched controller (`CV_FORWARDING=1`):

```sh
cd benchmarks/imt_bench
make run CV_FORWARDING=0 RISCV_TOOLS=/path/to/riscv-none-elf
make run CV_FORWARDING=1 RISCV_TOOLS=/path/to/riscv-none-elf
```

Use the same software parameters and build directory for identical binary images.
Simulator and run directories are separated by `fw0` / `fw1`; software is shared.
Only change forwarding when reusing this directory. Standard workload, dependency
and tool settings are documented in README.md. The following also builds and
runs 12 directed check groups 64 times and runs the prepared full suite with
parallel host simulations:

```sh
make build BUILD="$PWD/build/forwarding" RISCV_TOOLS=/path/to/riscv-none-elf
python3 forwarding_checks.py --build-dir build/forwarding --forwarding 0 \
  --riscv-tools /path/to/riscv-none-elf --suite
python3 forwarding_checks.py --build-dir build/forwarding --forwarding 1 \
  --riscv-tools /path/to/riscv-none-elf
```

Directed checks cover ALU RAW chains and both operands, load-use, store data,
multiply RAW/WAW, CSR RAW, JALR, MULH/MULHU/MULHSU, misaligned word load/store at
offsets 1/2/3, division/remainder RAW and branch RAW. All must return zero.

The archived results are in `validation/forwarding/`; the original official-RTL
baseline remains in `validation/`. The newly rebuilt 20 program binaries match
the previous baseline SHA-256 hashes exactly, so the baseline cycle measurements
are reused. One forwarding-enabled Tiny rerun and the directed checks verify the
new audit hooks on the original controller. The no-forwarding experiment reruns
every workload and requires its instruction count to match the baseline.

This fork's original `rtl/`, `bhv/` and manifest are unchanged. Modified tracked
files in this update are only files previously added by the benchmark port;
the remaining changes are additions in that same directory.

## Measured results

All 19 Embench programs (GSF=12, warmup=1), Tiny ad01 (12 measured
inferences), and 12 directed hazard groups repeated 64 times pass with the
experimental no-forwarding controller. Software counters match the independent
RTL audit and no output occurs inside the measured window. The target reports
zero ordinary EX/WB forwarded operands for every no-forwarding run.

| Configuration | Embench geometric-mean IPC | Tiny IPC | Tiny cycles / inference | Tiny ms at assumed 80 MHz |
|---|---:|---:|---:|---:|
| Original forwarding | 0.774380 | 0.815123 | 3,040,125.42 | 38.00157 |
| Experimental no forwarding | 0.665777 | 0.743252 | 3,334,099.50 | 41.67624 |

At the same clock, enabling forwarding improves geometric-mean Embench throughput by 16.312% and Tiny throughput by 9.670%. These are not Fmax measurements or official normalized Embench scores.

The original-controller Tiny rerun exactly reproduces 36,481,505 cycles and
29,736,900 instructions. Directed checks execute 9,556 instructions in both
modes: 16,152 cycles with forwarding and 19,929 without. The normal Make/CLI
entry was also exercised on slre at GSF=1. Four mutated forwarding reports
(wrong mode, EX use, WB use, missing audit) were correctly rejected.
