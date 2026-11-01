#!/usr/bin/env bash
# Runs each built Embench benchmark (example_tb/core/benchmarks/embench/*.hex)
# on the example testbench's Verilator simulator; logs go to
# example_tb/core/benchmarks/embench/runlogs. Build the simulator
# (make -C example_tb/core verilate) and the benchmarks first (see ../README.md).
#
# Each log holds the program's output ("Embench cycles=... instret=..." and
# "Main Exit=...") followed by the testbench's EXIT SUCCESS/FAILURE line and
# the number of cycles simulated.
set -euo pipefail

CORE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
EMB_DIR="$CORE_DIR/benchmarks/embench"
SIM="${SIM:-$CORE_DIR/cobj_dir/Vtb_top_verilator}"
LOG_DIR="$EMB_DIR/runlogs"

mkdir -p "$LOG_DIR"
cd "$LOG_DIR"

shopt -s nullglob
hexs=("$EMB_DIR"/*.hex)
if [ ${#hexs[@]} -eq 0 ]; then
  echo "No .hex found in ${EMB_DIR}; run make there first."
  exit 1
fi

for hex in "${hexs[@]}"; do
  b="$(basename "$hex" .hex)"
  log="${LOG_DIR}/${b}.log"

  echo "=== RUN ${b} ==="
  # save the output to the log, and also show it on screen
  "$SIM" +firmware="$hex" 2>&1 | tee "$log"
  echo "=== DONE ${b} (log: ${log}) ==="
  echo
done
