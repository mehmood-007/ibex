// Copyright lowRISC contributors.
// Copyright 2018 ETH Zurich and University of Bologna, see also CREDITS.md.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

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
    input  logic                      immediate_inst_i
);

  logic write_stall_o;
  logic [31:0]  reg_stall;
  logic [31:0]  reg_stall_;

  localparam int unsigned REG_SZ = 4;
  localparam int unsigned ADDR_WIDTH = RV32E ? 4 : 5;
  localparam int unsigned NUM_WORDS  = 2**ADDR_WIDTH;

  logic [1:0][DataWidth-1:0] rf_reg;
 // logic [REG_SZ-1:0][DataWidth-1:0] rf_reg_tmp;
  logic [NUM_WORDS-1:1] we_a_dec;
  logic reg_access;

  int idx_rd;
  logic cache_miss_a;
  logic cache_miss_b;
  logic cache_miss_c;

  logic [DataWidth-1:0] rd_buf_a;
  logic [DataWidth-1:0] rd_buf_b;
  logic [DataWidth-1:0] wr_buf;

  logic [DataWidth-1:0] l2_rdata;

  logic reg_stall_t;
  logic reg_stall_long; 
  logic [3:0] cnt_stall;
  logic [3:0] cnt_stall_1;
  logic [3:0] cycle_count;
  logic sig_dly, pe, pe2, sig;
  logic two_op_signal;

  logic write_stall;
  logic write_stall_1;
  logic write_stall_patch;
  
  logic [4:0] tag;
  logic [4:0] addr;
  logic L1_sig_wr; // exist in level-1

  logic sel_op_a;
  logic sel_op_b;
  logic _sel_op_b;
  logic sel_op_wr;

  logic rd_valid_a;
  logic rd_valid_b;
  logic wr_valid;

  logic sel_sec_op;
  logic write_enable;

  logic cnt, temp;

  logic new_inst;
  logic [31:0] temp_pc_id;
  logic [4:0] waddr;
  logic [$clog2(REG_SZ)-1:0] l1_reg_waddr;

  logic [DataWidth-1:0]  t_rdata_a_o;
  logic [DataWidth-1:0]  t_rdata_b_o;
    
  always_comb begin : we_a_decoder
    for (int unsigned i = 1; i < REG_SZ; i++) begin
      we_a_dec[i] = waddr_a_i == 5'(i) ?  we_a_i : 1'b0;
    end
  end

assign write_enable = |we_a_dec;
assign l1_reg_waddr = waddr_a_i[$clog2(REG_SZ)-1:0];

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)
        temp_pc_id <= '{default:'0};
    else
        temp_pc_id <= temp_pc_id != pc_id_i && !write_stall_patch ? pc_id_i : temp_pc_id; 
end

assign new_inst = temp_pc_id != pc_id_i && !write_stall_patch ? 1 : 0;
assign addr = wr_valid ? waddr :
               raddr_b_i ;

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni)
    waddr <= '0;
  else
    waddr <= waddr_a_i;
end

always_ff @(posedge clk_i or negedge rst_ni) begin: buffers
  if (!rst_ni) begin
    wr_buf <= '{default:'0};
    wr_valid <= 0;
  end else begin
    wr_buf  <= wdata_a_i ;
    wr_valid <= write_enable;
  end
end

assign tag = addr; //< 8 ? addr: 8 + (addr-15);
//assign L1_sig_wr = ( waddr_a_i == 12 || waddr_a_i == 13 || waddr_a_i == 14 || waddr_a_i == 15 ) ? 1 : 0;

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
   // rf_reg_tmp <= '{default:'0};
    write_stall_1 <= 0;
  end else begin
   // if ( write_enable )
     // rf_reg_tmp[l1_reg_waddr] <= L1_sig_wr ? wdata_a_i : rf_reg_tmp[l1_reg_waddr];
  write_stall_1 <= write_stall;
  end
end

/*
 // L2 register access
 ibex_l2_register_file l2 (
      .clk_i      (clk_i),
      .rst_ni     (rst_ni),
      .addr_i     (tag),
      .wdata_i    (wr_buf),
      .rdata_o    (l2_rdata),
      .we_i       (wr_valid)
  );
*/

 SRAM2RW32x32 l2_sram (
     .A1(raddr_a_i),
     .A2(addr),
     .CE1(clk_i),
     .CE2(clk_i),
     .WEB1(),
     .WEB2(~wr_valid),
     .OEB1(1'b0),
     .OEB2(1'b0),
     .CSB1(1'b0),
     .CSB2(1'b0),
     .I1(),
     .I2(wr_buf),
     .O1(t_rdata_a_o),
     .O2(t_rdata_b_o)
);

 // r_reg_count[r] <= (raddr_a_i == 5'(r) || raddr_b_i == 5'(r)) ? (r_reg_count[r] + 1) : r_reg_count[r];
assign cache_miss_b = new_inst ? 1 : 0;
assign sel_op_b = cache_miss_b ? 1 : 0;

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
      cnt <= 0;
  end
  else begin
    if(write_stall && !cnt)
      cnt <= ~cnt;
    else if(!write_stall)
      cnt <= 0;
  end
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


  assign rdata_a_o =  raddr_a_i == 5'(0) ? rf_reg[0] : t_rdata_a_o;
                  //    rf_reg_tmp[raddr_a_i[$clog2(REG_SZ)-1:0]];
  
  assign rdata_b_o =  raddr_b_i == 5'(0) ? rf_reg[0] : t_rdata_b_o;
                 //     rf_reg_tmp[raddr_b_i[$clog2(REG_SZ)-1:0]];


  assign sig = cache_miss_b;
    // This always block ensures that sig_dly is exactly 1 clock behind sig
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sig_dly <= 0;
      two_op_signal <= 0;
    end
    else begin
      sig_dly <= sig;
      two_op_signal <= cache_miss_b;
    end
  end

 // Combinational logic where sig is AND with delayed, inverted version of sig
// Assign statement assigns the evaluated expression in the RHS to the internal net pe
  assign pe = sig & ~sig_dly; 
  assign pe2 = 0;//two_op_signal;

  logic shift_1, shift_2;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      shift_1 <= 0;
      shift_2 <= 0;
    end
    else begin
      shift_1 <= write_stall_1;
      shift_2 <= shift_1;
    end
  end

  assign write_stall_patch = write_stall_1;
  assign write_stall_o = pe ? shift_1 : 
                         pe2 ? shift_2 : write_stall_1;
  assign reg_stall_o = pe || pe2 || write_stall_o ;
 // assign reg_access_o = reg_access;
  
endmodule