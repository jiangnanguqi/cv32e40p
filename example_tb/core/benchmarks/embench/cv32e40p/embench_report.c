// Copyright 2026 Chuanxin Tang
// SPDX-License-Identifier: Apache-2.0
//
// Report for the Embench benchmarks on the CV32E40P example testbench.
//
// Embench's support/main.c is compiled unchanged. The link option
// -Wl,--wrap=main (see ../Makefile) makes crt0.S call __wrap_main, which runs
// the real main and then prints the measured region's cycle and
// retired-instruction counts and the verification result through newlib's
// printf (custom/syscalls.c writes to the testbench's stdout peripheral).
// The counters were stopped in stop_trigger (cv32e40p/boardsupport.c) and
// are not touched in between, so they still hold the measured region when
// they are read here. main's return value then reaches the testbench's exit
// register through crt0.S and exit(), and the testbench prints EXIT SUCCESS
// for 0.

#include <stdio.h>

#include "bench_counters.h"

extern int __real_main(int argc, char *argv[]);

int __wrap_main(int argc, char *argv[]) {
  int exit_code = __real_main(argc, argv);

  printf("Embench cycles=%llu instret=%llu\n", (unsigned long long)bench_read_mcycle(),
         (unsigned long long)bench_read_minstret());
  // 0 when verify_benchmark() accepted the result; printed as on the platform.
  printf("Main Exit=%u\n", (unsigned)exit_code);

  return exit_code;
}
