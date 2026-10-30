// SPDX-License-Identifier: Apache-2.0
module cv_forward_audit;
 longint unsigned ex_operands,wb_operands,raw_stall_cycles;
 wire measured=!$root.bench_top.core.core_i.cs_registers_i.mcountinhibit_q[0];
 wire replay=$root.bench_top.core.core_i.id_stage_i.controller_i.data_misaligned_i ||
             $root.bench_top.core.core_i.id_stage_i.controller_i.mult_multicycle_i;
 wire accepted=$root.bench_top.core.core_i.id_stage_i.controller_i.id_valid_i;
 always @(posedge $root.bench_top.clk_i) begin
  if(!$root.bench_top.rst_ni) begin ex_operands<=0;wb_operands<=0;raw_stall_cycles<=0;end
  else begin
   if(measured && accepted && !replay) begin
    ex_operands<=ex_operands+
      ($root.bench_top.core.core_i.id_stage_i.controller_i.operand_a_fw_mux_sel_o==cv32e40p_pkg::SEL_FW_EX)+
      ($root.bench_top.core.core_i.id_stage_i.controller_i.operand_b_fw_mux_sel_o==cv32e40p_pkg::SEL_FW_EX)+
      ($root.bench_top.core.core_i.id_stage_i.controller_i.operand_c_fw_mux_sel_o==cv32e40p_pkg::SEL_FW_EX);
    wb_operands<=wb_operands+
      ($root.bench_top.core.core_i.id_stage_i.controller_i.operand_a_fw_mux_sel_o==cv32e40p_pkg::SEL_FW_WB)+
      ($root.bench_top.core.core_i.id_stage_i.controller_i.operand_b_fw_mux_sel_o==cv32e40p_pkg::SEL_FW_WB)+
      ($root.bench_top.core.core_i.id_stage_i.controller_i.operand_c_fw_mux_sel_o==cv32e40p_pkg::SEL_FW_WB);
   end
`ifdef CV_FORWARDING_OFF
   if(measured && $root.bench_top.core.core_i.id_stage_i.controller_i.load_stall_o && !replay)
    raw_stall_cycles<=raw_stall_cycles+1;
   if(accepted && !replay &&
      (($root.bench_top.core.core_i.id_stage_i.controller_i.operand_a_fw_mux_sel_o!=cv32e40p_pkg::SEL_REGFILE) ||
       ($root.bench_top.core.core_i.id_stage_i.controller_i.operand_b_fw_mux_sel_o!=cv32e40p_pkg::SEL_REGFILE) ||
       ($root.bench_top.core.core_i.id_stage_i.controller_i.operand_c_fw_mux_sel_o!=cv32e40p_pkg::SEL_REGFILE)))
    $fatal(1,"Inter-instruction forwarding selected in no-forwarding mode");
`endif
   if($root.bench_top.data_req && $root.bench_top.data_we &&
      $root.bench_top.data_addr==32'h20008 && $root.bench_top.data_wdata[0])
    $display("BENCH_CV_FWD forwarding=%0d ex_operands=%0d wb_operands=%0d raw_stall_cycles=%0d",
`ifdef CV_FORWARDING_OFF
      0,
`else
      1,
`endif
      ex_operands,wb_operands,raw_stall_cycles);
  end
 end
endmodule
bind bench_top cv_forward_audit forwarding_audit_inst();
