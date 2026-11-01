#!/usr/bin/env bash
# Runs the MLPerf Tiny ad01 image (example_tb/core/benchmarks/mlperf_tiny/tiny-ad01.hex)
# on the example testbench's Verilator simulator; the log goes to
# example_tb/core/benchmarks/mlperf_tiny/runlogs. Build the simulator
# (make -C example_tb/core verilate) and the image first (see ../README.md).
#
# The log holds the program's report (TINY_CHECK, TINY_STATS, TINY_PASS/FAIL
# and "Main Exit=..." lines) followed by the testbench's EXIT SUCCESS/FAILURE
# line and the number of cycles simulated.
# Environment: SIM (simulator binary) and LOG_DIR (where the logs go)
# override the defaults below, e.g. to keep runs of different
# configurations apart.
set -euo pipefail

CORE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TINY_DIR="$CORE_DIR/benchmarks/mlperf_tiny"
SIM="${SIM:-$CORE_DIR/cobj_dir/Vtb_top_verilator}"
LOG_DIR="${LOG_DIR:-$TINY_DIR/runlogs}"
HEX="$TINY_DIR/tiny-ad01.hex"

[ -f "$HEX" ] || { echo "No $HEX; run make in $TINY_DIR first."; exit 1; }
mkdir -p "$LOG_DIR"
cd "$LOG_DIR"
log="$LOG_DIR/tiny-ad01.log"

echo "=== RUN tiny-ad01 ==="
"$SIM" +firmware="$HEX" 2>&1 | tee "$log"
echo "=== DONE tiny-ad01 (log: ${log}) ==="
