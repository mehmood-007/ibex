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

    // PC to identify new instrctions
    input  logic [31:0]               pc_id_i,

    // immediate instrction flag
    input  logic                      immediate_inst_i,

    // reg stall
    output logic reg_stall_o
);
  parameter int CACHE_LEN = 4;
  localparam int unsigned ADDR_WIDTH = RV32E ? 4 : 5;
  //localparam int unsigned NUM_WORDS  = $clog2(CACHE_LEN);
  localparam int unsigned NUM_WORDS  = 2**ADDR_WIDTH;

  logic [31:0]  reg_stall;
  logic [31:0]  reg_stall_;
  
  logic [CACHE_LEN-1:0][4:0] cache_1_index ;
  logic [CACHE_LEN-1:0][4:0] cache_1_index_1 ;
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
  logic [CACHE_LEN-1:0] cache_c_match_comb;
  logic write_enable;

  wire [$clog2(CACHE_LEN)-1:0] tag_a [CACHE_LEN:0];
  wire [$clog2(CACHE_LEN)-1:0] tag_b [CACHE_LEN:0];
  wire [$clog2(CACHE_LEN)-1:0] tag_c [CACHE_LEN:0] ;

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

  logic [NUM_WORDS-1:0] counter_a;
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

  always_comb begin : we_a_decoder
    for (int unsigned i = 1; i < NUM_WORDS; i++) begin
      we_a_dec[i] = waddr_a_i == 5'(i) ?  we_a_i : 1'b0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        temp_pc_id <= '{default:'0};
    end
    else begin
        temp_pc_id <= temp_pc_id != pc_id_i && !write_stall_1 ? pc_id_i : temp_pc_id; 
    end
  end

  assign new_inst = temp_pc_id != pc_id_i && !write_stall_1 ? 1 : 0;
  assign write_enable = |we_a_dec;

  assign addrA = raddr_a_i;
  // sel_op_b ?  : 0;
  assign addrB = !cache_miss_a && !cache_miss_b ? waddr : raddr_b_i;
  // sel_op_a ?

  assign sel_op_a = cache_miss_a && cache_miss_b ? 1 :
                  cache_miss_a ? 1 : 0;

  assign sel_op_b = cache_miss_a && cache_miss_b ? 0 :
                    cache_miss_b || sel_sec_op ? 1 : 0;

  // loop from 1 to NUM_WORDS-1 as R0 is nil
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rf_reg_tmp <= '{default:'0};
      reg_stall_ <= '{default:'0};
      write_stall_1 <= 0;
    end
    else begin
        if ( cache_miss_a_ )
            rf_reg_tmp[counter_a] <= l2_rdata_A;
        else if ( write_stall_1 && |cache_c_match_comb)
            rf_reg_tmp[tag_c[0]] <= wr_buf;
        write_stall_1 <= write_stall;
    end
  end
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sel_sec_op <= 0;
      cache_miss_a_ <= 0;
    end else begin
      sel_sec_op <= (cache_miss_a && cache_miss_b) ? 1 : 0;
      cache_miss_a_ <= cache_miss_a;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)
        waddr <= '0;
    else
        waddr <= waddr_a_i;
  end

// Store data in buffers
  always_ff @(posedge clk_i or negedge rst_ni) begin: buffers
    if (!rst_ni) begin
    //    rd_buf_a <= '{default:'0};
    //    rd_valid_a <= 0;
    //    rd_buf_b <= '{default:'0};
    //    rd_valid_b <= 0;
        wr_buf <= '{default:'0};
        wr_valid <= 0;
    end else begin
    //    rd_buf_a <= l2_rdata_A;// : rd_buf_a;
    //    rd_buf_b <= l2_rdata_B;// : rd_buf_b;
    //    rd_valid_a <= sel_op_a ? 1 : 
    //                  pe || pe2 ? rd_valid_a : 
    //                  0;
    //    rd_valid_b <= sel_op_b ? 1 : 
    //                 pe || pe2 ? rd_valid_b : 
    //                  0;
        wr_buf  <= cache_miss_c ? wdata_a_i : wr_buf;
        wr_valid <= cache_miss_c ? 1 : 0;
    end
  end
  /*
    // L2 register access
    ibex_l2_register_file l2 (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        .addr_i     (addr),
        .wdata_i    (wr_buf),
        .rdata_o    (l2_rdata),
        .we_i       (wr_valid)
    );
  */
  SRAM2RW32x32 l2_sram (
      .A1(addrA),
      .A2(addrB),
      .CE1(clk_i),
      .CE2(clk_i),
      .WEB1(1'b1),
      .WEB2(~write_enable), // ~wr_valid
      .OEB1(1'b0),
      .OEB2(1'b0),
      .CSB1(1'b0),
      .CSB2(1'b0),
      .I1(),
      .I2(wdata_a_i), // wr_buf
      .O1(l2_rdata_A),
      .O2(l2_rdata_B)
  );


/*
  // Writing data to cache
  task write_through_cache( logic[4:0] addr, logic[31:0] data );
     // as_mem.delete(0);
    int cache_match;
    registers [addr] = data;
    foreach ( cache_1_index[k] ) begin
      if( cache_1_index[k] == addr ) begin  
        cache_1[k] = 32'(data); cache_match = 1;
      end
        //$display("Cache hit -> tag = %d, index = %d", tag, reg_address_a);
      else cache_match = 0;
    end 
    if(!cache_match) begin
      //cache_1_index[counter_a] = addr;
      cache_1[counter_a+1] = data;
    end
  endtask
*/

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cache_1_index_1 <= '{default:'0};
      counter_a <= '{default:'0};  
     // counter_b <= '{default:'0};
     // counter_c <= '{default:'0};
    end else begin
      for (int r = 0; r < CACHE_LEN; r++) begin
        cache_1_index_1[r] <= cache_1_index[r];
      end
/*        if( |cache_a_match_comb == 0 && raddr_a_i != '0 && 
            |cache_b_match_comb == 0 && raddr_b_i != '0 && 
            !immediate_inst_i ) begin
          counter_a <= counter_a >= CACHE_LEN-1 ? 0 : counter_a + 1;
          counter_b <= counter_a >= CACHE_LEN-1 ? 0 : counter_a + 2;
        end
        else*/
        if( cache_miss_a_ ) begin
          counter_a <= counter_a >= CACHE_LEN-1 ? 0 : counter_a + 1;
         // counter_b <= counter_a >= CACHE_LEN-1 ? 0 : counter_a + 1;
        end
      /*
        else if( |cache_b_match_comb == 0 && raddr_b_i != '0 && !immediate_inst_i ) begin
          counter_b <= counter_b >= CACHE_LEN-1 ? 0 : counter_b + 1;
          counter_a <= counter_b >= CACHE_LEN-1 ? 0 : counter_b + 1;
        end
        else if(cache_miss_c) begin
          counter_a <= counter_a >= CACHE_LEN-1 ? 0 : counter_a + 1;
          //counter_a <= counter_b >= CACHE_LEN-1 ? 0 : counter_b + 1;    
        end
      */
    end
  end
  
  assign tag_c[CACHE_LEN] = 2'b11;
  assign tag_a[CACHE_LEN] = 2'b11;
  assign tag_b[CACHE_LEN] = 2'b11;
  // The for-loop creates multiple assign statements
  genvar i;
  generate
    for ( i = 0; i < CACHE_LEN; i++ ) begin
      assign cache_a_match_comb[i] = (cache_1_index_1[i] == raddr_a_i && raddr_a_i != '0 && !write_stall_1 ) ? 1 : 0;
      assign cache_b_match_comb[i] = (cache_1_index_1[i] == raddr_b_i && raddr_b_i != '0 && !write_stall_1 ) ? 1 : 0;
      assign cache_c_match_comb[i] = (cache_1_index_1[i] == waddr && write_stall_1) ? 1 : 0;

//      assign tag_a[i] = (cache_1_index[i] == raddr_a_i && raddr_a_i != '0) ? i : tag_a[i+1];
//      assign tag_b[i] = (cache_1_index[i] == raddr_b_i && raddr_b_i != '0) ? i : tag_b[i+1];
//      assign tag_c[i] = (cache_1_index[i] == waddr) ? i : tag_c[i+1];
    end
  endgenerate

  generate
    for ( i = CACHE_LEN - 1; i >= 0 ; i-- ) begin
      assign tag_a[i][1:0] = cache_a_match_comb[i] == 1'b1 ? i : tag_a[i+1][1:0];
      assign tag_b[i][1:0] = cache_b_match_comb[i] == 1'b1 ? i : tag_b[i+1][1:0];
      assign tag_c[i][1:0] = cache_c_match_comb[i] == 1'b1 ? i : tag_c[i+1][1:0];
    end
  endgenerate

/*
wire [15:0] _o_idx [0:$bits(occup_t)];
assign _o_idx[$bits(occup_t)] = 'h1fff;

genvar i;
generate
    for(i = $bits(occup_t)-1; i >= 0; i--)
    begin
        assign _o_idx[i][15:0] = 
               _mp_occup[i] == 0 
               ? i : _o_idx[i+1][15:0];
    end
endgenerate
*/
assign cache_a_match = |cache_a_match_comb;
assign cache_b_match = new_inst && |cache_b_match_comb;
assign cache_c_match = 0;//|cache_c_match_comb;

always @( * ) begin
  reg_address_a = '0;
  reg_address_b = '0;
  temp_reg_a = l2_rdata_A;;
  temp_reg_b = l2_rdata_B;;
  cache_miss_a = 0;
  cache_miss_b = 0;
  cache_miss_c = 0;

  if( cache_a_match == 1 )
    temp_reg_a = rf_reg_tmp[tag_a[0]];
  else if( cache_a_match == 0 && raddr_a_i != 0 && !write_stall_1) begin // doesn't exist in cache
    cache_miss_a = 1;
     // cache_1[counter_a] = temp_reg_a;
    //  $display( "Cache miss, addr-A %d-> %d ", reg_address_a, counter_a );
  end 

  if( cache_b_match == 1 )
    temp_reg_b =  rf_reg_tmp[tag_b[0]];
  else if( cache_b_match == 0 && raddr_b_i != 5'h0 && !immediate_inst_i) begin // doesn't exist in cache
    cache_miss_b = 1;
   // cache_1_index[counter_b] = raddr_b_i;
   // cache_1[counter_b] = temp_reg_b;
   // counter_a = counter_ >= CACHE_LEN ? '0 : counter_ + 1;
    // $display( "Cache miss, addr-B %d-> %d ", reg_address_b, counter_a );
   // counter = counter >= 1 ? 0 : counter + 1;
  // $display( "Cache miss, stall %d, addr %d ", reg_stall[reg_address_a], reg_address_a );
  end
  // cache_c_match == 0 &&
  cache_miss_c = waddr_a_i != 0 && write_enable ? 1 : 0;

  if(cache_miss_c) begin
   // cache_1_index[counter_a] = waddr_a_i;
   // cache_1[counter_a] = temp_reg_b;
  end
  cache_miss_a = new_inst ? cache_miss_a : 0;
  cache_miss_b = new_inst && !immediate_inst_i ? cache_miss_b : 0;
end

assign L1_sig_wr = ~cache_miss_c;
assign write_stall = cache_miss_c && !cnt ? 1 : 0;

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
      cnt <= 0; 
      temp <= 0;
  end
  else begin
    if(write_stall && !cnt) begin
      cnt <= ~cnt;
      temp <= 1;
    end
    else if(!write_stall) begin
      cnt <= 0;
    end
    else
      temp <= 0;
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

 // assign rf_reg[NUM_WORDS-1:1] = rf_reg_tmp[NUM_WORDS-1:1];

    //assign reg_count[31:1] = _reg_count[31:1];
   //  assign r_reg[0] = (raddr_a_i == 5'(0)  || raddr_b_i == 5'(0) ) ? 6'h00 : 6'h3f;
  // assign r_reg[NUM_WORDS-1:1] = _r_reg[NUM_WORDS-1:1];
 // assign r_reg[NUM_WORDS-1:0] = _r_reg[NUM_WORDS-1:0];
// assign rdata_a_o =  raddr_a_i == 0 ? 0:
  assign rdata_a_o =  raddr_a_i == 5'(0) ? rf_reg[0] : temp_reg_a ;//rd_buf_a;
      //                  rd_valid_a ? rd_buf_a : 
     //                 rf_reg_tmp[tag_a];
  
  assign rdata_b_o =  raddr_b_i == 5'(0) ? rf_reg[0] : temp_reg_b;//rd_buf_b;
   //                     rd_valid_b ? rd_buf_b : 
  //                    rf_reg_tmp[tag_b];

  assign sig = cache_miss_a || cache_miss_b;
  // This always block ensures that sig_dly is exactly 1 clock behind sig
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sig_dly <= 0;
      two_op_signal <= 0;
    end
    else begin
    	sig_dly <= sig;
      two_op_signal <= cache_miss_a && cache_miss_b;
    end
	end

   // Combinational logic where sig is AND with delayed, inverted version of sig
  // Assign statement assigns the evaluated expression in the RHS to the internal net pe
	assign pe = sig & ~sig_dly;
	assign pe2 = 0;//two_op_signal;

  assign cache_1_index[counter_a] = cache_a_match == 0 && raddr_a_i != 0 && !write_stall_1 && !pe? 
                                    raddr_a_i : cache_1_index[counter_a];

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

  assign write_stall_o =  pe ? shift_1 :
                          pe2 ? shift_2 : write_stall_1;

  assign reg_stall_o = pe || pe2 || write_stall_o;

endmodule​