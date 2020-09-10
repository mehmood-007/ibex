/**
 * RISC-V register file L2
 *
 * Register file with 31 or 15x 32 bit wide registers. Register 0 is fixed to 0.
 * This register file is based on flip flops. Use this register file when
 * targeting FPGA synthesis or Verilator simulation.
 */
module ibex_l2_register_file #(
    parameter int unsigned DataWidth         = 32
) (
    // Clock and Reset
    input  logic                 clk_i,
    input  logic                 rst_ni,

    // Addr
    // Data
    input  logic [4:0]           addr_i,
    input  logic [DataWidth-1:0] wdata_i,
    output logic [DataWidth-1:0] rdata_o,
    input  logic                 we_i

);

  localparam int unsigned SIZE_REG = 4;
  parameter int unsigned NUM_WORDS = 32-SIZE_REG;
  logic [NUM_WORDS-1:1][DataWidth-1:0] rf_reg;
  logic [NUM_WORDS-1:1]                we_dec;
  logic [DataWidth-1:0] rdata;

  always_comb begin : we_decoder
    for (int unsigned i = 1; i < NUM_WORDS; i++) begin
      we_dec[i] = (addr_i == 5'(i)) ?  we_i : 1'b0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        rf_reg <= '{default:'0};
    end else begin
      for (int r = 1; r < NUM_WORDS; r++) begin
        if ( we_dec[r] )
          rf_reg[r] <= wdata_i;
      end
    end
  end
/*
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        rdata <= '{default:'0};
    end else begin
      for (int r = 1; r < NUM_WORDS; r++) begin
        if ( addr_i == 5'(r) ) begin 
          rdata <= rf_reg[r];
        end
      end
    end
  end
*/
  assign rdata_o = rf_reg[addr_i];

endmodule
