// Copyright lowRISC contributors.
// Copyright 2018 ETH Zurich and University of Bologna, see also CREDITS.md.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0


// Source/Destination register instruction index
`define REG_S1 19:15
`define REG_S2 24:20
`define REG_S3 31:27
`define REG_D  11:07
  import ibex_pkg::*;

/**
 * RISC-V register file
 *
 * Register file with 31 or 15x 32 bit wide registers. Register 0 is fixed to 0.
 * This register file is based on flip flops. Use this register file when
 * targeting FPGA synthesis or Verilator simulation.
 */
module ibex_register_file #(
    parameter bit          RV32E             = 0,
    parameter int unsigned DataWidth         = 32,
    parameter bit          DummyInstructions = 0
) (
    // Clock and Reset
    input  logic                 clk_i,
    input  logic                 rst_ni,

    input  logic                 test_en_i,
    input  logic                 dummy_instr_id_i,

    //Read port R1
    input  logic [4:0]           raddr_a_i,
    output logic [DataWidth-1:0] rdata_a_o,

    //Read port R2
    input  logic [4:0]           raddr_b_i,
    output logic [DataWidth-1:0] rdata_b_o,


    // Write port W1
    input  logic [4:0]           waddr_a_i,
    input  logic [DataWidth-1:0] wdata_a_i,
    input  logic                 we_a_i,

    // hierarchy
  //  output logic reg_access_o,

    // reg stall
    output logic reg_stall_o,

    input  logic [31:0]               pc_id_i,
    input  logic                      immediate_inst_i,
    input logic [31:0] pref_inst_i,
    input logic instr_new_id_d_i
);

  localparam int unsigned ADDR_WIDTH = RV32E ? 4 : 5;
  localparam int unsigned NUM_WORDS  = 2**ADDR_WIDTH;

  logic [31:0]  reg_stall;
  logic [1:0][DataWidth-1:0] rf_reg;
  logic [NUM_WORDS-1:1] we_a_dec;
  logic reg_access;

  int idx_rd;

  logic [DataWidth-1:0] temp_reg_a;
  logic [DataWidth-1:0] temp_reg_b;

  logic [DataWidth-1:0] l2_rdata;

  logic [DataWidth-1:0] l2_rdata_A;
  logic [DataWidth-1:0] l2_rdata_B;  
  
  logic L1_sig_wr; // exist in level-1

  logic [3:0] cycle_count;
  logic sig_dly, pe, pe2, sig;
  logic two_op_signal;
  logic [4:0] tag;
  logic [4:0] addr;

  logic [4:0] addrA;
  logic [4:0] addrB;

  logic [4:0] addrA_d;
  logic [4:0] addrB_d;

  logic new_inst, new_inst_;
  logic [4:0] waddr;

  logic [4:0] rf_raddr_a;
  logic [4:0] rf_raddr_b;

  logic [4:0] reg_waddr;
  logic [31:0] reg_wdata;
  logic we_a;

  opcode_e opcode_id_stage;
  logic    immediate_inst;
  logic    instr_new_id_d_i_;

  always_comb begin : we_a_decoder
    for (int unsigned i = 1; i < NUM_WORDS; i++) begin
      we_a_dec[i] = waddr_a_i == 5'(i) ?  we_a_i : 1'b0;
    end
  end

  assign rf_raddr_a = pref_inst_i[`REG_S1]; // rs3 / rs1
  assign rf_raddr_b = pref_inst_i[`REG_S2]; // rs2

  assign opcode_id_stage = opcode_e'(pref_inst_i[6:0]);
  assign immediate_inst = (opcode_id_stage == OPCODE_OP_IMM ) ? 1 : 0 ;


  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        reg_waddr <= '{default:'0};
        reg_wdata <= '{default:'0};        
        instr_new_id_d_i_ <= 0;
    end
    else begin
        instr_new_id_d_i_ <= instr_new_id_d_i;
        reg_waddr <= we_a_i ? waddr_a_i : 
                     reg_waddr;
        reg_wdata <= we_a_i ? wdata_a_i : reg_wdata;
    end
  end

assign new_inst = instr_new_id_d_i_;//temp_pc_id != pc_id_i ? 1 : 0;      
assign addrA_d = instr_new_id_d_i  ? rf_raddr_a : raddr_a_i;
assign addrB_d = instr_new_id_d_i ? rf_raddr_b : raddr_b_i;

assign addrA = addrA_d;
assign addrB = we_a_i ? waddr_a_i : addrB_d;

  SRAM2RW32x32 l2_sram (
      .A1(addrA),
      .A2(addrB),
      .CE1(clk_i),
      .CE2(clk_i),
      .WEB1(1'b1),
      .WEB2(!(we_a_i)),
      .OEB1(1'b0),
      .OEB2(1'b0),
      .CSB1(1'b0),
      .CSB2(1'b0),
      .I1(),
      .I2(wdata_a_i),
      .O1(l2_rdata_A),
      .O2(l2_rdata_B)
  );

always_comb begin
  temp_reg_a = raddr_a_i == reg_waddr && reg_waddr != '0 ? reg_wdata : l2_rdata_A;//rf_reg_tmp[raddr_a];
  temp_reg_b = raddr_b_i == reg_waddr && reg_waddr != '0 ? reg_wdata : l2_rdata_B;//rf_reg_tmp[raddr_b];

end

  // With dummy instructions enabled, R0 behaves as a real register but will always return 0 for
  // real instructions.
  if (DummyInstructions) begin : g_dummy_r0
    logic        we_r0_dummy;
    logic [31:0] rf_r0;

    // Write enable for dummy R0 register (waddr_a_i will always be 0 for dummy instructions)
    assign we_r0_dummy = we_a_i & dummy_instr_id_i;

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        rf_r0 <= '0;
      end else if (we_r0_dummy) begin
        rf_r0 <= wdata_a_i;
      end
    end

    // Output the dummy data for dummy instructions, otherwise R0 reads as zero
    assign rf_reg[0] = dummy_instr_id_i ? rf_r0 : '0;

  end else begin : g_normal_r0
    logic unused_dummy_instr_id;
    assign unused_dummy_instr_id = dummy_instr_id_i;

    // R0 is nil
    assign rf_reg[0] = '0;
  end

  wire signal;

  assign rdata_a_o = raddr_a_i == 5'(0) ? rf_reg[0] : temp_reg_a;
  assign rdata_b_o = raddr_b_i == 5'(0) ? rf_reg[0] : temp_reg_b;
  assign signal =  rf_raddr_b == '0 ? 
                   0 : immediate_inst ?
                   0 : 1;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)
      sig_dly <= 0;
    else
      sig_dly <= signal;
  end
  assign sig = new_inst && sig_dly;

  assign pe = sig; 
  assign reg_stall_o = pe ;

endmodule
