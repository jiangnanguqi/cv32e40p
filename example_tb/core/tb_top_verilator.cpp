// Copyright 2018 Robert Balas <balasr@student.ethz.ch>
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Verilator driver for tb_top_verilator.sv, after core-v-verif's
// cv32e40p/tb/core/tb_top_verilator.cpp: drives clock and reset and runs
// until the testbench calls $finish. Build with -DVCD_TRACE (and Verilator's
// --trace) to dump verilator_tb.vcd.

#include "Vtb_top_verilator.h"
#include "verilated.h"
#ifdef VCD_TRACE
#include "verilated_vcd_c.h"
#endif

#include <cstdint>
#include <cstdlib>

static vluint64_t t = 0;

double sc_time_stamp() { return t; }

int main(int argc, char **argv, char **env) {
  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(true);
  Vtb_top_verilator *top = new Vtb_top_verilator();

#ifdef VCD_TRACE
  VerilatedVcdC *tfp = new VerilatedVcdC;
  top->trace(tfp, 99);
  tfp->open("verilator_tb.vcd");
#endif
  top->fetch_enable_i = 1;
  top->clk_i = 0;
  top->rst_ni = 0;
  top->eval();

  while (!Verilated::gotFinish()) {
    if (t > 40) top->rst_ni = 1;
    top->clk_i = !top->clk_i;
    top->eval();
#ifdef VCD_TRACE
    tfp->dump(t);
#endif
    t += 5;
  }
#ifdef VCD_TRACE
  tfp->close();
#endif
  top->final();
  delete top;
  return 0;
}
