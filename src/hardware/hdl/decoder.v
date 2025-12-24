`timescale 1ns/1ps

//=============================================================================
// Decoder
// 
// Receives 640-bit data from scheduler and decodes it into
// DDR4 commands and write data.
//
// Input format (640-bit):
//   [127:0]   - DDR4 command data (4 x 32-bit commands)
//   [639:128] - Write data (512-bit)
//
// DDR4 command format (each 32-bit slot):
//   [2:0]   - Command type (0=NOP, 1=PRE, 2=ACT, 3=RD, 4=WR, 5=REF)
//   [4:3]   - Bank address
//   [6:5]   - Bank group
//   [23:7]  - Row address (for ACT) / Column address (for RD/WR)
//   [7]     - PALL (precharge all) flag
//=============================================================================

module decoder #(
    parameter BG_WIDTH   = 2,
    parameter BANK_WIDTH = 2,
    parameter COL_WIDTH  = 10,
    parameter ROW_WIDTH  = 17,
    parameter CMD_WIDTH = 128,
    parameter WDATA_WIDTH = 512,
    parameter INPUT_WIDTH = CMD_WIDTH + WDATA_WIDTH  // 640
)(
    input  wire                     clk,
    input  wire                     rst,
    
    // AXI Stream Slave - Input (from scheduler)
    input  wire [INPUT_WIDTH-1:0]   input_data,
    input  wire                     input_valid,
    
    // DDR4 Command outputs
    output reg  [3:0]               ddr_write,
    output reg  [3:0]               ddr_read,
    output reg  [3:0]               ddr_pre,
    output reg  [3:0]               ddr_act,
    output reg  [3:0]               ddr_ref,
    output reg  [3:0]               ddr_zq,
    output reg  [3:0]               ddr_nop,
    output reg  [3:0]               ddr_ap,
    output reg  [3:0]               ddr_half_bl,
    output reg  [3:0]               ddr_pall,
    output reg  [4*BG_WIDTH-1:0]    ddr_bg,
    output reg  [4*BANK_WIDTH-1:0]  ddr_bank,
    output reg  [4*COL_WIDTH-1:0]   ddr_col,
    output reg  [4*ROW_WIDTH-1:0]   ddr_row,
    
    // DDR4 Write data output
    output reg  [511:0]             ddr_wdata
);

    //=========================================================================
    // Command type encoding
    //=========================================================================
    localparam CMD_NOP  = 3'd0;
    localparam CMD_PRE  = 3'd1;
    localparam CMD_ACT  = 3'd2;
    localparam CMD_RD   = 3'd3;
    localparam CMD_WR   = 3'd4;
    localparam CMD_REF  = 3'd5;
    localparam CMD_ZQ   = 3'd6;

    //=========================================================================
    // Internal signals
    //=========================================================================
    wire [CMD_WIDTH-1:0] cmd_data;
    wire [WDATA_WIDTH-1:0] write_data;
    
    // Extract DDR4 command and write data from input
    assign cmd_data = input_data[CMD_WIDTH-1:0];
    assign write_data = input_data[INPUT_WIDTH-1:CMD_WIDTH];
    
    //=========================================================================
    // Decode DDR4 command and write data
    //=========================================================================
    integer i;
    
    always @(posedge clk) begin
        if (rst) begin
            ddr_write   <= 4'd0;
            ddr_read    <= 4'd0;
            ddr_pre     <= 4'd0;
            ddr_act     <= 4'd0;
            ddr_ref     <= 4'd0;
            ddr_zq      <= 4'd0;
            ddr_nop     <= 4'd0;
            ddr_ap      <= 4'd0;
            ddr_half_bl <= 4'd0;
            ddr_pall    <= 4'd0;
            ddr_bg      <= {(4*BG_WIDTH){1'b0}};
            ddr_bank    <= {(4*BANK_WIDTH){1'b0}};
            ddr_col     <= {(4*COL_WIDTH){1'b0}};
            ddr_row     <= {(4*ROW_WIDTH){1'b0}};
            ddr_wdata   <= 512'b0;
        end else begin
            // Initialize all outputs to zero each cycle
            ddr_write   <= 4'd0;
            ddr_read    <= 4'd0;
            ddr_pre     <= 4'd0;
            ddr_act     <= 4'd0;
            ddr_ref     <= 4'd0;
            ddr_zq      <= 4'd0;
            ddr_nop     <= 4'd0;
            ddr_ap      <= 4'd0;
            ddr_half_bl <= 4'd0;
            ddr_pall    <= 4'd0;
            ddr_bg      <= {(4*BG_WIDTH){1'b0}};
            ddr_bank    <= {(4*BANK_WIDTH){1'b0}};
            ddr_col     <= {(4*COL_WIDTH){1'b0}};
            ddr_row     <= {(4*ROW_WIDTH){1'b0}};
            
            if (input_valid) begin
                // Capture write data
                ddr_wdata <= write_data;
                
                // Decode each of the 4 DDR4 command slots
                for (i = 0; i < 4; i = i + 1) begin
                    // Extract address fields
                    ddr_bank[i*BANK_WIDTH +: BANK_WIDTH] <= cmd_data[i*32+3 +: BANK_WIDTH];
                    ddr_bg[i*BG_WIDTH +: BG_WIDTH]       <= cmd_data[i*32+3+BANK_WIDTH +: BG_WIDTH];
                    ddr_row[i*ROW_WIDTH +: ROW_WIDTH]    <= cmd_data[i*32+3+BANK_WIDTH+BG_WIDTH +: ROW_WIDTH];
                    ddr_col[i*COL_WIDTH +: COL_WIDTH]    <= cmd_data[i*32+3+BANK_WIDTH+BG_WIDTH +: COL_WIDTH];
                    ddr_pall[i]                          <= cmd_data[i*32+3+BANK_WIDTH+BG_WIDTH];
                    
                    // Decode command type
                    case (cmd_data[i*32 +: 3])
                        CMD_NOP: ddr_nop[i]   <= 1'b1;
                        CMD_PRE: ddr_pre[i]   <= 1'b1;
                        CMD_ACT: ddr_act[i]   <= 1'b1;
                        CMD_RD:  ddr_read[i]  <= 1'b1;
                        CMD_WR:  ddr_write[i] <= 1'b1;
                        CMD_REF: ddr_ref[i]   <= 1'b1;
                        CMD_ZQ:  ddr_zq[i]    <= 1'b1;
                        default: ddr_nop[i]   <= 1'b1;
                    endcase
                end
            end
        end
    end

endmodule
