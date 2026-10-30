#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Generate an experimental inter-instruction no-forwarding controller copy."""
from pathlib import Path
import difflib

def generate(root,output):
    original=root/'rtl/cv32e40p_controller.sv'
    source=original.read_text()
    marker='  // stall because of misaligned data access\n'
    assert source.count(marker)==1
    # The source-use comparisons already exclude x0 and unused operands.
    declarations='''  // Experimental no-forwarding variant: interlock ordinary RAW hazards.
  // Internal multi-cycle replay is a separate path and remains unchanged.
  wire noforward_raw_hazard =
      (regfile_alu_we_fw_i &&
       (reg_d_alu_is_reg_a_i || reg_d_alu_is_reg_b_i || reg_d_alu_is_reg_c_i)) ||
      (regfile_we_wb_i &&
       (reg_d_wb_is_reg_a_i || reg_d_wb_is_reg_b_i || reg_d_wb_is_reg_c_i));

'''
    source=source.replace(marker,declarations+marker)
    marker='    // Stall because of jr path\n'
    assert source.count(marker)==1
    addition='''    // Wait until a preceding producer has written the register file.
    // Reuse the existing load interlock's bubble/hold protocol.
    if (is_decoding_o && instr_valid_i && !data_misaligned_i &&
        !mult_multicycle_i && noforward_raw_hazard) begin
      deassert_we_o = 1'b1;
      load_stall_o = 1'b1;
    end

'''
    source=source.replace(marker,addition+marker)
    start=source.index('    // Forwarding WB -> ID\n')
    end=source.index('    // for misaligned memory accesses\n',start)
    source=source[:start]+'''    // All ordinary operands use SEL_REGFILE. The existing replay
    // selections below serve the same instruction, not a following consumer.

'''+source[end:]
    target=output/'cv32e40p_controller_no_forwarding.sv'
    if not target.exists() or target.read_text()!=source:target.write_text(source)
    (output/'no-forwarding.patch').write_text(''.join(difflib.unified_diff(
        original.read_text().splitlines(True),source.splitlines(True),
        fromfile='rtl/cv32e40p_controller.sv',tofile='generated/cv32e40p_controller_no_forwarding.sv')))
    return target
