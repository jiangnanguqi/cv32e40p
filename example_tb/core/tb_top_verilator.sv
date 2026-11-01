// Copyright 2018 Robert Balas <balasr@student.ethz.ch>
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Top level wrapper for a Verilator CV32E40P testbench, after
// core-v-verif's cv32e40p/tb/core/tb_top_verilator.sv (contributor: Robert
// Balas), for this fork's example testbench: clock and reset come from
// tb_top_verilator.cpp, the firmware is loaded with +firmware=<hex>, and the
// simulation ends when the program writes the exit register (see
// mm_ram.sv) or after +maxcycles=<n> cycles. Memory stalls and the random
// interrupt generator stay disabled unless the program enables them.

module tb_top_verilator #(
    parameter INSTR_RDATA_WIDTH = 32,
    parameter RAM_ADDR_WIDTH = 22,
    parameter BOOT_ADDR = 'h180,
    parameter COREV_PULP = 0,
    parameter COREV_CLUSTER = 0,
    parameter FPU = 0,
    parameter ZFINX = 0,
    parameter NUM_MHPMCOUNTERS = 1,
    parameter DM_HALTADDRESS = 32'h1A110800
) (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic fetch_enable_i,
    output logic tests_passed_o,
    output logic tests_failed_o,
    output logic exit_valid_o,
    output logic [31:0] exit_value_o
);

  // cycle counter and the optional +maxcycles=<n> limit
  int unsigned cycle_cnt_q;
  int unsigned maxcycles = 0;

  // load the firmware
  initial begin : load_prog
    automatic string firmware;
    if ($value$plusargs("firmware=%s", firmware)) begin
      if ($test$plusargs("verbose")) $display("[TESTBENCH] loading firmware %0s ...", firmware);
      $readmemh(firmware, wrapper_i.ram_i.dp_ram_i.mem);
    end else begin
      $display("No firmware specified");
      $finish;
    end
  end

  // count cycles; abort after +maxcycles=<n> cycles, if given
  initial begin
    if (!$value$plusargs("maxcycles=%d", maxcycles)) maxcycles = 0;
  end

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (~rst_ni) begin
      cycle_cnt_q <= 0;
    end else begin
      cycle_cnt_q <= cycle_cnt_q + 1;
      if (maxcycles != 0 && cycle_cnt_q >= maxcycles) begin
        $display("Simulation aborted due to maximum cycle limit (pc_id = %h, mepc = %h, mcause = %h)",
                 wrapper_i.top_i.core_i.pc_id, wrapper_i.top_i.core_i.cs_registers_i.mepc_q,
                 wrapper_i.top_i.core_i.cs_registers_i.mcause_q);
        $finish;
      end
    end
  end

  // +pcfrom=<cycle>: print the ID-stage PC and instruction every cycle from
  // that cycle on (for finding where a program went wrong)
  int unsigned pcfrom = 0;
  initial begin
    if (!$value$plusargs("pcfrom=%d", pcfrom)) pcfrom = 0;
  end
  always_ff @(posedge clk_i) begin
    if (pcfrom != 0 && cycle_cnt_q >= pcfrom && wrapper_i.top_i.core_i.is_decoding)
      $display("cycle %0d pc_id=%h instr=%h", cycle_cnt_q, wrapper_i.top_i.core_i.pc_id,
               wrapper_i.top_i.core_i.instr_rdata_id);
  end

  // check if we succeeded
  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (tests_passed_o) begin
      $display("ALL TESTS PASSED");
      $display("Cycles executed: %0d", cycle_cnt_q);
      $finish;
    end
    if (tests_failed_o) begin
      $display("TEST(S) FAILED!");
      $display("Cycles executed: %0d", cycle_cnt_q);
      $finish;
    end
    if (exit_valid_o) begin
      if (exit_value_o == 0) $display("EXIT SUCCESS");
      else $display("EXIT FAILURE: %d", exit_value_o);
      $display("Cycles executed: %0d", cycle_cnt_q);
      $finish;
    end
  end

  // wrapper for cv32e40p, the memory system and stdout peripheral
  cv32e40p_tb_subsystem #(
      .INSTR_RDATA_WIDTH(INSTR_RDATA_WIDTH),
      .RAM_ADDR_WIDTH   (RAM_ADDR_WIDTH),
      .BOOT_ADDR        (BOOT_ADDR),
      .COREV_PULP       (COREV_PULP),
      .COREV_CLUSTER    (COREV_CLUSTER),
      .FPU              (FPU),
      .ZFINX            (ZFINX),
      .NUM_MHPMCOUNTERS (NUM_MHPMCOUNTERS),
      .DM_HALTADDRESS   (DM_HALTADDRESS)
  ) wrapper_i (
      .clk_i         (clk_i),
      .rst_ni        (rst_ni),
      .fetch_enable_i(fetch_enable_i),
      .tests_passed_o(tests_passed_o),
      .tests_failed_o(tests_failed_o),
      .exit_valid_o  (exit_valid_o),
      .exit_value_o  (exit_value_o)
  );

endmodule  // tb_top_verilator
