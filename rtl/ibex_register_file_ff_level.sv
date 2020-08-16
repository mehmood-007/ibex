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


    // write stall
   // output logic write_stall_o,

  //  input logic instr_id_done_i

);

  logic write_stall_o;
  logic [31:0] reg_count [0:NUM_WORDS-1];
  
  logic [NUM_WORDS-1:0][5:0] r_reg;
  logic [NUM_WORDS-1:0][5:0] _r_reg;
  logic [NUM_WORDS-1:1][5:0] w_reg;
  
  logic [31:0]  reg_stall;
  logic [31:0]  reg_stall_;
  

  localparam int unsigned ADDR_WIDTH = RV32E ? 4 : 5;
  localparam int unsigned NUM_WORDS  = 2**ADDR_WIDTH;

  logic [NUM_WORDS-1:0][DataWidth-1:0] rf_reg;
  logic [NUM_WORDS-1:1][DataWidth-1:0] rf_reg_tmp;
  logic [NUM_WORDS-1:1]                we_a_dec;
  logic reg_access;
  logic [4:0] temp_addr_a;
  logic [4:0] temp_addr_b;
  logic [4:0] temp_waddr_a;
 // int reg_queue[$:32];

  logic [31:0] reg_queue_1[3:0];
  logic [31:0] reg_queue_2[27:1];

  int idx_rd;
  logic cache_miss_a;
  logic cache_miss_b;
  logic cache_miss_c;
  logic [NUM_WORDS-1:0] cache_miss_c_1 ;

  always_comb begin : we_a_decoder
    for (int unsigned i = 1; i < NUM_WORDS; i++) begin
      we_a_dec[i] = waddr_a_i == 5'(i) ?  we_a_i : 1'b0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        temp_addr_a <= '{default:'0};
        temp_addr_b <= '{default:'0};
        temp_waddr_a <= '{default:'0};
    end
    else begin
        temp_addr_a <= temp_addr_a != raddr_a_i ? raddr_a_i : temp_addr_a;
        temp_addr_b <= temp_addr_b != raddr_b_i ? raddr_b_i : temp_addr_b;
        temp_waddr_a <= temp_waddr_a != waddr_a_i ? waddr_a_i : temp_waddr_a;
       // temp_we_a_dec <= temp_we_a_dec != |we_a_dec ? |we_a_dec : temp_we_a_dec;
    end
  end
logic write_stall;
logic write_stall_1;
  // loop from 1 to NUM_WORDS-1 as R0 is nil
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rf_reg_tmp <= '{default:'0};
      reg_count <= '{default:'0};
      //_r_reg <= '{default:6'h3f};
      w_reg <= '{default:6'h3f};
      reg_stall_ <= '{default:'0};
      cache_miss_c_1 <= '{default:'0};
      write_stall_1 <= 0;
      reg_reset();
    end else begin
      for (int r = 1; r < NUM_WORDS; r++) begin
        if (we_a_dec[r] ) begin // && write_stall_1 == 0
          rf_reg_tmp[r] <= wdata_a_i;
          reg_count[r] <= reg_count[r] + 1;
          w_reg[r] <= r;
          reg_file_write( r, wdata_a_i );
          // _r_reg[r] <= 6'h3f;
        end
        else begin
          w_reg[r] <= 6'h3f;
             // if( temp_addr_a != raddr_a_i || temp_addr_b != raddr_b_i ) begin
            // _r_reg[r] <= (raddr_a_i == 5'(r) || raddr_b_i == 5'(r)) ? r : 6'h3f;
           //  w_reg[r] <= 6'h3f;
          // end
        end
        reg_stall_[r] <= reg_stall[r];
        write_stall_1 <= write_stall;
      end 
           
    end
  end

  //assign cache_miss_c = 0;//|cache_miss_c_1;
    // Write through write
    task reg_file_write(  int addr, int data );
    int idx;
    if( addr == 12 || addr == 14 || addr == 15 )
    begin  reg_queue_1[addr-12] = data;

    end
    else if (addr == 13) begin
      reg_queue_1[addr-12] = data;
    end
    else begin
      idx = addr == 2 ? 2 : addr >= 16 ? 11 + (addr-15) : addr;
      reg_queue_2[idx] = data;
    end
    endtask
    task reg_reset( );
      integer j;
        for( j = 1; j < 32; j++) begin
          reg_queue_1[j] = 0;reg_queue_2[j] = 0;
        end
    endtask

 logic [DataWidth-1:0] temp_data_a;
 logic [DataWidth-1:0] temp_data_b;

 // r_reg_count[r] <= (raddr_a_i == 5'(r) || raddr_b_i == 5'(r)) ? (r_reg_count[r] + 1) : r_reg_count[r];

/*
always @(raddr_a_i or raddr_b_i) begin
    cache_miss = 0;
    for ( integer i = 1; i < NUM_WORDS; i++ ) begin: test      
      idx_rd = i >= 17 ? 12 + (i - 16) : i;
      if( raddr_a_i == 5'(i)  ) begin
        if ( i == 13 || i == 14 || i == 15 || i == 16  ) begin
          temp_data_a = reg_queue_1[i-13];
        end
        else begin
          cache_miss = 1;
          temp_data_a = reg_queue_2[idx_rd];
        end
      end
      if( raddr_b_i == 5'(i) ) begin // (|reg_stall_) == 0 
        if( i == 13 || i == 14 || i == 15 || i == 16 ) begin
          temp_data_b = reg_queue_1[i-13];
        end
        else  begin
          cache_miss = 1;//reg_stall[i] = 1;
          temp_data_b = reg_queue_2[idx_rd];
        end
      end
    end
    if( temp_addr_a != raddr_a_i || temp_addr_b != raddr_b_i )  begin
      if(cache_miss)
        reg_stall[raddr_a_i] = 1;
      else
        reg_stall[raddr_a_i] = reg_stall_[raddr_a_i];
    end
    else
        reg_stall = '0;
end
*/

always @(raddr_a_i or raddr_b_i or waddr_a_i) begin
    cache_miss_a = 0;
    cache_miss_b = 0;
    cache_miss_c = 0;
    write_stall = 0;
    for ( integer i = 1; i < NUM_WORDS; i++ ) begin: test      
     idx_rd = i == 2 ? 2 : i >= 16 ? 11 + (i-15) : i;
      if( raddr_a_i == 5'(i)  ) begin
        if( i == 12 || i == 14 || i == 15 )
          temp_data_a = reg_queue_1[i-12];
        else if (i == 13)
          temp_data_a = reg_queue_1[1];   
        else begin
          cache_miss_a = 1;
          temp_data_a = reg_queue_2[idx_rd];
        end
      end
      if( raddr_b_i == 5'(i) ) begin // (|reg_stall_) == 0 
       idx_rd = i == 2 ? 2 : i >= 16 ? 11 + (i-15) : i;
        if( i == 12 || i == 14 || i == 15 )
          temp_data_b = reg_queue_1[i-12];
        else if(i == 13)
          temp_data_b = reg_queue_1[1];   
        else  begin
          cache_miss_b = 1;//reg_stall[i] = 1;
          temp_data_b = reg_queue_2[idx_rd];
        end
      end
      if( waddr_a_i == 5'(i) && |we_a_dec) begin // (|reg_stall_) == 0 
        if( i == 12 || i == 14 || i == 15 )
          cache_miss_c = 0;
        else if(i == 13)
          cache_miss_c = 0;
        else
          cache_miss_c = 1;
      end
    end
    cache_miss_a = temp_addr_a != raddr_a_i ? cache_miss_a : 0;
    cache_miss_b = temp_addr_b != raddr_b_i ? cache_miss_b : 0;
      
        //reg_stall = '0;
    write_stall = cache_miss_c && !cnt ? 1 : 0;  
end
logic cnt, temp;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        cnt <= 0; temp <= 0;
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

/*
  if( condition == 1) begin
  genvar i;
      for ( i = 1; i < NUM_WORDS; i++) begin
          
      end
  end */
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

//  assign rf_reg[NUM_WORDS-1:1] = rf_reg_tmp[NUM_WORDS-1:1];

  //assign reg_count[31:1] = _reg_count[31:1];

 // assign r_reg[NUM_WORDS-1:1] = _r_reg[NUM_WORDS-1:1];

//  assign r_reg[NUM_WORDS-1:0] = _r_reg[NUM_WORDS-1:0];

//  assign r_reg[0] = (raddr_a_i == 5'(0) || raddr_b_i == 5'(0) ) ? 6'h00 : 6'h3f;
 // assign rf_reg[31:0][12:1] = reg_queue_2[31:0][12:1];//_r_reg[NUM_WORDS-1:0];
//  assign rf_reg[17:13] = reg_queue_1[3:0];//_r_reg[NUM_WORDS-1:0];
//  assign rf_reg[31:18] = 32'(reg_queue_2[26:13]);//_r_reg[NUM_WORDS-1:0];

  //assign rdata_a_o =  rf_reg[raddr_a_i];
  //assign rdata_b_o =  rf_reg[raddr_b_i];
  assign rdata_a_o =  raddr_a_i == 5'(0) || (reg_stall_o && cache_miss_a) ? 6'h00 : temp_data_a;
  assign rdata_b_o =  raddr_b_i == 5'(0) || reg_stall_o ? 6'h00 : temp_data_b;
 
  logic reg_stall_t;
  logic reg_stall_long; 
  logic [3:0] cnt_stall;
   logic [3:0] cnt_stall_1;
  logic [3:0] cycle_count;
//(cache_miss_a && cache_miss_b ) ? 2
 /* assign reg_stall_t = ( reg_stall_long) || |reg_stall ;
  assign cnt_stall =  cache_miss_c ? 0 :
                     (cache_miss_a && cache_miss_b) ? 1 :// || (cache_miss_b && cache_miss_c) || (cache_miss_a && cache_miss_c) ? 1 :
                     (cache_miss_a || cache_miss_b) ? 0 : 0;

  always_ff @(posedge clk_i or negedge rst_ni) begin 
    if (!rst_ni) begin
      cnt_stall_1 <= '0;
    end else begin
       if( temp_addr_a != raddr_a_i || temp_addr_b != raddr_b_i || temp_waddr_a != waddr_a_i)  begin
          cnt_stall_1 <= cnt_stall;  
       end
       else
          cnt_stall_1 <= cnt_stall_1 != '0 ? cnt_stall_1 - 1 : cnt_stall_1; 
       //else if ()
    end
  end
  */
/*
logic cnt_1, cnt_2, temp_1;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        cnt_1 <= 0; 
        temp_1 <= 0;
        cnt_2 <= 0;
    end
    else begin
      if( (cache_miss_a || cache_miss_b) && !cnt_1) begin
        cnt_1 <= ~cnt_1;
        temp_1 <= 1;
      end
      else if( (cache_miss_a && cache_miss_b) && !cnt_2) begin
        cnt_2 <= ~cnt_2;
        temp_1 <= 1;
      end
      else
        temp <= 0;
    end
  end
*/
  logic sig_dly, pe, pe2, sig;
  logic two_op_signal;

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

/*
  always_ff @(posedge clk_i or negedge rst_ni) begin 
    if (!rst_ni) begin
      reg_stall_long <= '0;
      cycle_count  <= '0;
    end else begin
      if( cycle_count != cnt_stall &&  cnt_stall != 0 ) begin
        cycle_count <= cycle_count + 1;
        reg_stall_long <= 1;
      end else begin
        reg_stall_long <= 0;
        cycle_count  <=  |reg_stall ? '0 : 0;
      end
    end
  end
*/
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

  assign write_stall_o = pe ? shift_1 : 
                         pe2 ? shift_2 : write_stall_1;

  assign reg_stall_o = pe || pe2 || write_stall_o ;
  
  assign reg_access_o = reg_access;
  
endmodule
