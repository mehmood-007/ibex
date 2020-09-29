// Copyright lowRISC contributors.
// Copyright 2018 ETH Zurich and University of Bologna, see also CREDITS.md.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0


// Source/Destination register instruction index
`define REG_S1 19:15
`define REG_S2 24:20
`define REG_S3 31:27

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

    // PC to identify new instrctions
    input  logic [31:0]               pc_id_i,

    // immediate instrction flag
    input  logic                      immediate_inst_i,

    // reg stall
    output logic reg_stall_o,

    input logic [31:0] pref_inst_i,

    input logic instr_new_id_d_i
);
  parameter int CACHE_LEN = 4;
  localparam int unsigned ADDR_WIDTH = RV32E ? 4 : 5;
  localparam int unsigned CACHE_WIDTH = $clog2(CACHE_LEN);
  //localparam int unsigned NUM_WORDS  = $clog2(CACHE_LEN);
  localparam int unsigned NUM_WORDS  = 2**ADDR_WIDTH;

  logic [31:0]  reg_stall;
  logic [31:0]  reg_stall_;
  
  logic [CACHE_LEN-1:0][4:0] cache_1_index;
  // int qu[$];

  logic [NUM_WORDS-1:0][DataWidth-1:0] rf_reg;
  logic [CACHE_LEN-1:0][DataWidth-1:0] rf_reg_tmp;
  logic [NUM_WORDS-1:1]                we_a_dec;

  logic [DataWidth-1:0] temp_reg_a;
  logic [DataWidth-1:0] temp_reg_b;
  
  logic cache_a_match;
  logic cache_b_match;
  logic cache_c_match;

  logic [CACHE_LEN-1:0] cache_a_match_1;
  logic [CACHE_LEN-1:0] cache_b_match_1;
  logic [CACHE_LEN-1:0] cache_c_match_1;

  logic [CACHE_LEN-1:0] cache_a_match_comb;
  logic [CACHE_LEN-1:0] cache_b_match_comb;
  logic [CACHE_LEN-1:0] cache_b_match_comb_;

  logic [CACHE_LEN-1:0] cache_c_match_comb;

  logic [CACHE_LEN-1:0] cache_miss_a_dec;

  logic write_enable;

  wire [ CACHE_WIDTH-1:0] tag_a [CACHE_LEN:0];
  wire [ CACHE_WIDTH-1:0] tag_b [CACHE_LEN:0];
  wire [ CACHE_WIDTH-1:0] tag_c [CACHE_LEN:0] ;

  logic [4:0] addr;

  logic [4:0] addrA;
  logic [4:0] addrB;

  logic [4:0] reg_address_a;
  logic [4:0] reg_address_b;
  logic cache_miss_a, cache_miss_b, cache_miss_c;

  logic cache_miss_a_;

  logic new_inst;
  logic [31:0] temp_pc_id;

  logic cnt, temp, write_stall_o;
  logic sig_dly, pe, pe2, sig;
  logic two_op_signal;
  logic shift_1, shift_2;

  logic write_stall_1, write_stall;

  logic [4:0] counter;

  logic [CACHE_WIDTH-1:0] counter_a;
  logic [NUM_WORDS-1:0] counter_b;
  logic [NUM_WORDS-1:0] counter_c;

  logic [DataWidth-1:0] rd_buf_a;
  logic [DataWidth-1:0] rd_buf_b;
  logic [DataWidth-1:0] wr_buf;
  logic [DataWidth-1:0] l2_rdata;

  logic [DataWidth-1:0] l2_rdata_A;
  logic [DataWidth-1:0] l2_rdata_B;  

  logic L1_sig_wr; // exist in level-1

  logic rd_valid_a;
  logic rd_valid_b;
  logic wr_valid;
  logic [4:0] waddr;

  logic sel_sec_op;
  logic sel_op_a;
  logic sel_op_b;
  logic _sel_op_b;
  logic sel_op_wr;


  logic [4:0] addrA_q;
  logic [4:0] addrA_d;
  logic [4:0] rf_raddr_a;
  logic [4:0] rf_raddr_b;

  logic [4:0] reg_waddr;
  logic [31:0] reg_wdata;

  logic fetch_l2_b;
  logic instr_new_id_d_i_;

  always_comb begin : we_a_decoder
    for (int unsigned i = 1; i < NUM_WORDS; i++) begin
      we_a_dec[i] = waddr_a_i == 5'(i) ?  we_a_i : 1'b0;
    end
  end

  assign rf_raddr_a = pref_inst_i[`REG_S1]; // rs3 / rs1
  assign rf_raddr_b = pref_inst_i[`REG_S2]; // rs3 / rs1

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      //temp_pc_id <= '{default:'0};
     // addrA_q <= '{default:'0};
      instr_new_id_d_i_ <= 0;
      fetch_l2_b <= 0;
    end      
    else begin
     // addrA_q <= addrA_d;
      //temp_pc_id <= temp_pc_id != pc_id_i ? pc_id_i : temp_pc_id;
      instr_new_id_d_i_ <= instr_new_id_d_i;
      reg_waddr <= we_a_i ? waddr_a_i : 
                   reg_stall_o ? reg_waddr :
                   '0;
      reg_wdata <= we_a_i ? wdata_a_i : reg_wdata;
      fetch_l2_b <= ~we_a_i & instr_new_id_d_i;
    end      
  end

  assign new_inst = instr_new_id_d_i_;//temp_pc_id != pc_id_i ? 1 : 0;      
  assign addrA_d = instr_new_id_d_i  ? rf_raddr_a : raddr_a_i; // addrA_q

  assign addrA = addrA_d;
  assign addrB = ~we_a_i & instr_new_id_d_i ? rf_raddr_b :
                 !cache_miss_b ? waddr_a_i : raddr_b_i;

  // loop from 1 to NUM_WORDS-1 as R0 is nil
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)
      rf_reg_tmp <= '{default:'0};
    else begin
    // if ( write_enable && |cache_c_match_comb && cache_miss_a_ && tag_c[0] == counter_a)
    //   rf_reg_tmp[tag_c[0]] <= wdata_a_i;
      for (int r = 0 ; r < CACHE_LEN; r++) begin
       //if ( cache_c_match_comb[r] && cache_miss_b_dec[r])
      //  rf_reg_tmp[r] <= wdata_a_i;
     //   else begin
          rf_reg_tmp[r] <= cache_c_match_comb[r] ? wdata_a_i : 
                           cache_miss_a_dec[r] ? l2_rdata_B : 
                           rf_reg_tmp[r];
//          rf_reg_tmp[r] <= cache_miss_a_dec[r] ? l2_rdata_A : rf_reg_tmp[r];
      //  end 
      end
     // else begin 
     //  if ( |cache_c_match_comb)
     //   rf_reg_tmp[tag_c[0]] <= wdata_a_i;
     //  if ( cache_miss_a_ )
     //   rf_reg_tmp[counter_a] <= l2_rdata_A;    
     end
  end
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cache_miss_a_ <= 0;
    end else begin
      cache_miss_a_ <= cache_miss_b;
    end
  end

  SRAM2RW32x32 l2_sram (
      .A1(addrA),
      .A2(addrB),
      .CE1(clk_i),
      .CE2(clk_i),
      .WEB1(1'b1),
      .WEB2(~we_a_i), // ~wr_valid
      .OEB1(1'b0),
      .OEB2(1'b0),
      .CSB1(1'b0),
      .CSB2(1'b0),
      .I1(),
      .I2(wdata_a_i), // wr_buf
      .O1(l2_rdata_A),
      .O2(l2_rdata_B)
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
     // cache_1_index_1 <= '{default:'1};
     // cache_1_index <= '{default:'1};
      counter_a <= '{default:'0};  
    end else begin
      //for (int r = 0; r < CACHE_LEN; r++)
      //  cache_1_index_1[r] <= cache_1_index[r];
      if( cache_miss_a_ ) // 
          counter_a <= counter_a >= CACHE_LEN-1 ? 0: counter_a + 1;
      cache_1_index[counter_a] <= cache_miss_b && raddr_b_i != 0 ? 
                                  raddr_b_i : cache_1_index[counter_a];
    end
  end

  //always_comb begin : tag_c_decoder
  //  for (int unsigned i = 0; i < CACHE_LEN; i++) begin
      //  cache_a_match_comb[i] = (cache_1_index_1[i] == raddr_a_i) ? 1 : 0;
      //  cache_b_match_comb[i] = (cache_1_index_1[i] == raddr_b_i) ? 1 : 0;
      //  cache_c_match_comb[i] = cache_1_index[i] == waddr_a_i  ?  write_enable : 1'b0;
      //  cache_miss_a_dec[i] = counter_a == i  ?  cache_miss_a_ : 1'b0;
  //  end
 // end

  // The for-loop creates multiple assign statements
  genvar i;
  generate
    for ( i = 0; i < CACHE_LEN; i++ ) begin
    //  assign cache_a_match_comb[i] = (cache_1_index_1[i] == raddr_a_i  ) ? 1 : 0;
  //    assign cache_b_match_comb[i] = ~fetch_l2_b & (cache_1_index[i] == raddr_b_i) & ~cache_miss_a_ ? 1 : 0;
      assign cache_c_match_comb[i] = (cache_1_index[i] == waddr_a_i ) ? we_a_i : 0;
      assign cache_miss_a_dec[i] = counter_a == i  ?  cache_miss_a_ : 1'b0;

/*      comparator comp3(
        .A(cache_1_index[i] & we_a_i),
        .B(waddr_a_i), 
        .equal_signal(cache_c_match_comb[i])
     );*/
     comparator comp1(
        .A(cache_1_index[i]),
        .B(raddr_b_i ),
        .equal_signal( cache_b_match_comb_[i]  )
     );
     assign cache_b_match_comb[i] = ~fetch_l2_b & cache_b_match_comb_[i] & ~cache_miss_a_;

     /* comparator comp1(
        .A(cache_1_index[i]),
        .B(raddr_b_i),
        .equal_signal(cache_b_match_comb[i])
     );

      */
/*      comparator comp2(
        .A(cache_1_index_1[i]),
        .B(raddr_b_i), 
        .equal_signal(cache_b_match_comb[i])
     );
      comparator comp3(
        .A(cache_1_index[i] & we_a_i),
        .B(waddr_a_i), 
        .equal_signal(cache_c_match_comb[i])
     );
     */
    end
  endgenerate
/*
  generate
    for ( i = CACHE_LEN - 1; i >= 0 ; i-- ) begin
     assign tag_a[i] = cache_a_match_comb[i] == 1'b1 ? i : tag_a[i+1];
     assign tag_b[i] = cache_b_match_comb[i] == 1'b1 ? i : tag_b[i+1];
     assign tag_c[i] = cache_c_match_comb[i] == 1'b1 ? i : tag_c[i+1];
    end
  endgenerate
*/
//assign cache_a_match = |cache_a_match_comb;
assign cache_b_match = |cache_b_match_comb;

always @( * ) begin
  reg_address_a = '0;
  reg_address_b = '0;
  temp_reg_b = l2_rdata_B;
  cache_miss_a = 0;
  cache_miss_b = 0;
  cache_miss_c = 0;

  temp_reg_a = raddr_a_i == reg_waddr && reg_waddr != '0 ? reg_wdata : l2_rdata_A;

  for (int r = 0 ; r < CACHE_LEN; r++) begin //rf_reg_tmp[tag_a[0]]
    temp_reg_b = cache_b_match_comb[r] ? rf_reg_tmp[r] : temp_reg_b;
    cache_miss_b = cache_b_match_comb[r] ? 1 : cache_miss_b;  
  end
  cache_miss_b = raddr_b_i != 0 && cache_b_match == 0 ? 1: 0;
  //cache_miss_a = new_inst ? cache_miss_a : 0;
  cache_miss_b = new_inst && !immediate_inst_i ? cache_miss_b : 0;
  cache_miss_b = ~fetch_l2_b ? cache_miss_b : 0;
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

  assign rdata_a_o = raddr_a_i == 5'(0) ? rf_reg[0] : temp_reg_a;
  assign rdata_b_o = raddr_b_i == 5'(0) ? rf_reg[0] : temp_reg_b;

  assign reg_stall_o = cache_miss_b;//pe;

endmodule
