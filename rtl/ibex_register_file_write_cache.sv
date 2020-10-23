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
    output logic reg_access_o,

    // reg stall
    output logic reg_stall_o


);
  logic [31:0] reg_count [0:NUM_WORDS-1];
  
  logic [NUM_WORDS-1:0][5:0] r_reg;
  //logic [NUM_WORDS-1:0][5:0] _r_reg;
  logic [NUM_WORDS-1:1][5:0] w_reg;
  
  logic [31:0]  reg_stall;
  logic [31:0]  reg_stall_;
  
  parameter int CACHE_LEN = 4;


  integer registers [32];
  integer cache_1 [CACHE_LEN];
  logic [CACHE_LEN-1:0][4:0] cache_1_index ;
  logic [CACHE_LEN-1:0][4:0] cache_1_index_1 ;
  // int qu[$];

  localparam int unsigned ADDR_WIDTH = RV32E ? 4 : 5;
  localparam int unsigned NUM_WORDS  = 2**ADDR_WIDTH;

  logic [NUM_WORDS-1:0][DataWidth-1:0] rf_reg;
  logic [NUM_WORDS-1:1][DataWidth-1:0] rf_reg_tmp;
  logic [NUM_WORDS-1:1]                we_a_dec;
  logic reg_access;
  logic [4:0] temp_addr_a;
  logic [4:0] temp_addr_b;

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



  always_comb begin : we_a_decoder
    for (int unsigned i = 1; i < NUM_WORDS; i++) begin
      we_a_dec[i] = waddr_a_i == 5'(i) ?  we_a_i : 1'b0;
    end
  end

   always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        temp_addr_a <= '{default:'0};
        temp_addr_b <= '{default:'0};
    end
    else begin
        temp_addr_a <= temp_addr_a != raddr_a_i ? raddr_a_i : temp_addr_a;
        temp_addr_b <= temp_addr_b != raddr_b_i ? raddr_b_i : temp_addr_b;
    end
  end

logic write_stall_1, write_stall;

logic [4:0] counter;
logic [31:0] counter_;

logic [$clog2(CACHE_LEN)-1:0] counter_a;
logic [$clog2(CACHE_LEN)-1:0] counter_b;
logic [$clog2(CACHE_LEN)-1:0] counter_c;

  // loop from 1 to NUM_WORDS-1 as R0 is nil
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rf_reg_tmp <= '{default:'0};
      reg_count <= '{default:'0};
      //_r_reg <= '{default:6'h3f};
      w_reg <= '{default:6'h3f};
      reg_stall_ <= '{default:'0};
      write_stall_1 <= 0;
    end else begin
      for (int r = 1; r < NUM_WORDS; r++) begin
        if (we_a_dec[r]) begin
          rf_reg_tmp[r] <= wdata_a_i;
          reg_count[r] <= reg_count[r] + 1;
          w_reg[r] <= r;
          write_through_cache ( r, wdata_a_i );
        end
        else begin
          w_reg[r] <= 6'h3f;
        end
      end
        write_stall_1 <= write_stall;
    end
  end
    // r_reg_count[r] <= (raddr_a_i == 5'(r) || raddr_b_i == 5'(r)) ? (r_reg_count[r] + 1) : r_reg_count[r];

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


logic [$clog2(CACHE_LEN)-1:0] tag_a;
logic [$clog2(CACHE_LEN)-1:0] tag_b;
logic [4:0] reg_address_a;
logic [4:0] reg_address_b;
logic cache_miss_a, cache_miss_b, cache_miss_c;

logic [31:0] cache_miss_count;
logic [31:0] cache_miss_count_;

logic [31:0] cache_hit_count;
logic [31:0] cache_hit_count_;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      counter_ <= '0;
      cache_hit_count_ <= '0;
      cache_miss_count_ <= '0;
    end
    else begin
      counter_ <= counter_a;
      cache_hit_count_ <= cache_hit_count;
      cache_miss_count_ <= cache_miss_count;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cache_1_index_1 <= '{default:'0};
      cache_a_match_1 <= '{default:'0};
      cache_c_match_1 <= '{default:'0};
      counter_a <= '{default:'0};  
      counter_b <= '{default:'0};
      counter_c <= '{default:'0};
      cache_miss_count <= '{default:'0};
      cache_hit_count <= '{default:'0};
     // tag_b <= 0;
    // counter_a <= '{default:'0};
   //  tag_a <= 0;
    end else begin
      for (int r = 0; r < CACHE_LEN; r++) begin

          if( |cache_a_match_comb == 0 && raddr_a_i != '0 && |cache_b_match_comb == 0 && raddr_b_i != '0 && raddr_b_i != 5'h1f ) begin
            counter_a <= counter_a >= CACHE_LEN-1 ? 0 : counter_a + 1;
            counter_b <= counter_a >= CACHE_LEN-1 ? 0 : counter_a + 2;
            cache_miss_count <= cache_miss_count + 2;
          end
          else if( |cache_a_match_comb == 0 && raddr_a_i != '0 ) begin
            counter_a <= counter_a >= CACHE_LEN-1 ? 0 : counter_a + 1;
            counter_b <= counter_a >= CACHE_LEN-1 ? 0 : counter_a + 1;
            cache_miss_count <= cache_miss_count + 1;
          end
          else if( |cache_b_match_comb == 0 && raddr_b_i != '0 && raddr_b_i != 5'h1f ) begin
            counter_b <= counter_b >= CACHE_LEN-1 ? 0 : counter_b + 1;
            counter_a <= counter_b >= CACHE_LEN-1 ? 0 : counter_b + 1;
            cache_miss_count <= cache_miss_count + 1;
          end
          else if(cache_miss_c) begin
            counter_a <= counter_a >= CACHE_LEN-1 ? 0 : counter_a + 1;
            cache_miss_count <= cache_miss_count + 1;
            //counter_a <= counter_b >= CACHE_LEN-1 ? 0 : counter_b + 1;    
          end
          else
            cache_hit_count <= cache_hit_count + 1;

          cache_1_index_1[r] <= cache_1_index[r];
      end
    end
  end
  // The for-loop creates 16 assign statements
  genvar i;
  generate
    for ( i = 0; i < CACHE_LEN; i++ ) begin
      assign cache_a_match_comb[i] = (cache_1_index_1[i] == raddr_a_i && raddr_a_i != '0) ? 1 : 0;

      assign cache_b_match_comb[i] = (cache_1_index_1[i] == raddr_b_i && raddr_b_i != '0) ? 1 : 0;

      assign cache_c_match_comb[i] = (cache_1_index_1[i] == waddr_a_i && we_a_dec[waddr_a_i]) ? 1 : 0;

    end
  endgenerate

assign tag_a = 0;//(cache_1_index_1[i] == raddr_a_i && raddr_a_i != '0) ? i : 0;
assign tag_b = 0;//(cache_1_index_1[i] == raddr_b_i && raddr_b_i != '0) ? i : 0;

assign cache_a_match = |cache_a_match_comb;
assign cache_b_match = |cache_b_match_comb;
assign cache_c_match = |cache_c_match_comb;

always @( * ) begin
  reg_address_a = '0;
  reg_address_b = '0;
  temp_reg_a = '0;
  temp_reg_b = '0;
  
  cache_miss_b = 0;
  cache_miss_c = 0;

  if( cache_a_match == 1 ) begin
    temp_reg_a = cache_1[tag_a];
   // $display( "Cached hit %d", tag_a);
  end
  else if( cache_a_match == 0 && raddr_a_i != 0  ) begin // doesn't exist in cache
    temp_reg_a = registers[raddr_a_i];
    cache_1_index[counter_a] = raddr_a_i;
    cache_1[counter_a] = temp_reg_a;
    cache_miss_a = 1;
    //$display( "Cache miss, addr-A %d-> %d ", reg_address_a, counter_a );
  end
  else
    cache_miss_a = 0;

  if( cache_b_match == 1 ) begin
    temp_reg_b =  cache_1[tag_b];
  end

  else if( cache_b_match == 0 && raddr_b_i != 5'h0 && raddr_b_i != 5'h1F ) begin // doesn't exist in cache
    temp_reg_b = registers[raddr_b_i];
    cache_1_index[counter_b] = raddr_b_i;
    cache_1[counter_b] = temp_reg_b;
   // counter_a = counter_ >= CACHE_LEN ? '0 : counter_ + 1;
    cache_miss_b = 1;
    // $display( "Cache miss, addr-B %d-> %d ", reg_address_b, counter_a );
   // counter = counter >= 1 ? 0 : counter + 1;
  // $display( "Cache miss, stall %d, addr %d ", reg_stall[reg_address_a], reg_address_a );
  end
  else if(raddr_b_i == 5'h1F) begin
     temp_reg_b = registers[raddr_b_i];
     cache_miss_b = 0;
  end

  cache_miss_c = cache_c_match == 0 && waddr_a_i != 0 && we_a_dec[waddr_a_i] ? 1 : 0;

  if(cache_miss_c) begin
    cache_1_index[counter_a] = waddr_a_i;
   // cache_1[counter_a] = temp_reg_b;
  end
  cache_miss_a = temp_addr_a != raddr_a_i ? cache_miss_a : 0;
  cache_miss_b = temp_addr_b != raddr_b_i ? cache_miss_b : 0;
end


logic cnt, temp, write_stall_o;
logic sig_dly, pe, pe2, sig;
logic two_op_signal;
logic shift_1, shift_2;

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

  assign rf_reg[NUM_WORDS-1:1] = rf_reg_tmp[NUM_WORDS-1:1];

    //assign reg_count[31:1] = _reg_count[31:1];
   //  assign r_reg[0] = (raddr_a_i == 5'(0)  || raddr_b_i == 5'(0) ) ? 6'h00 : 6'h3f;
  // assign r_reg[NUM_WORDS-1:1] = _r_reg[NUM_WORDS-1:1];
 // assign r_reg[NUM_WORDS-1:0] = _r_reg[NUM_WORDS-1:0];
// assign rdata_a_o =  raddr_a_i == 0 ? 0:
  assign rdata_a_o =  raddr_a_i == 5'(0) ? 6'h00 : registers[raddr_a_i];
  assign rdata_b_o =  raddr_b_i == 5'(0) ? 6'h00 : registers[raddr_b_i];

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
	assign pe2 = two_op_signal;


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

  assign reg_stall_o = 0;//pe || pe2 || write_stall_o;
  assign reg_access_o = reg_access;

endmodule​