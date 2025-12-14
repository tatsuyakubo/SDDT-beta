`timescale 1ns/1ps

module axi4_instr #(
    parameter BG_WIDTH = 2,
    parameter BANK_WIDTH = 2,
    parameter COL_WIDTH = 10,
    parameter ROW_WIDTH = 17
)
(
    input wire clk,
    input wire rst,
    // AXI -> Instr
    input wire [127:0] S_AXIS_TDATA,
    input wire S_AXIS_TVALID,
    output wire S_AXIS_TREADY,
    // Debug
    output wire [2:0] latest_instr_id,
    // Instr -> DDR4_Adapter
    output reg [3:0]                ddr_write,
    output reg [3:0]                ddr_read,
    output reg [3:0]                ddr_pre,
    output reg [3:0]                ddr_act,
    output reg [3:0]                ddr_ref,
    output reg [3:0]                ddr_zq,
    output reg [3:0]                ddr_nop,
    output reg [3:0]                ddr_ap,
    output reg [3:0]                ddr_half_bl,
    output reg [3:0]                ddr_pall,
    output reg [4*BG_WIDTH-1:0]     ddr_bg, 
    output reg [4*BANK_WIDTH-1:0]   ddr_bank,
    output reg [4*COL_WIDTH-1:0]    ddr_col,
    output reg [4*ROW_WIDTH-1:0]    ddr_row
);

    // ローカルパラメータで出力バス幅を計算
    localparam TOTAL_WIDTH = 40 + 4*BG_WIDTH + 4*BANK_WIDTH + 4*COL_WIDTH + 4*ROW_WIDTH;

    reg [127:0] latest_instrs;
    
    // AXI4-Stream slave interface - always ready to receive
    assign S_AXIS_TREADY = 1'b1;
    assign latest_instr_id = latest_instrs[2:0];
    
    integer i;
    
    always @(posedge clk) begin
        if (rst) begin
            latest_instrs <= 128'd0;
            ddr_write <= 4'd0;
            ddr_read <= 4'd0;
            ddr_pre <= 4'd0;
            ddr_act <= 4'd0;
            ddr_ref <= 4'd0;
            ddr_zq <= 4'd0;
            ddr_nop <= 4'd0;
            ddr_ap <= 4'd0;
            ddr_half_bl <= 4'd0;
            ddr_pall <= 4'd0;
            ddr_bg <= {(4*BG_WIDTH){1'b0}};
            ddr_bank <= {(4*BANK_WIDTH){1'b0}};
            ddr_col <= {(4*COL_WIDTH){1'b0}};
            ddr_row <= {(4*ROW_WIDTH){1'b0}};
        end else begin
            // Receive data every cycle
            if (S_AXIS_TVALID) begin
                latest_instrs <= S_AXIS_TDATA;
            end else begin
                latest_instrs <= 128'd0;
            end
            
            // Process latest_instrs every cycle
            // initialize all outputs to zero
            ddr_write <= 4'd0;
            ddr_read <= 4'd0;
            ddr_pre <= 4'd0;
            ddr_act <= 4'd0;
            ddr_ref <= 4'd0;
            ddr_zq <= 4'd0;
            ddr_nop <= 4'd0;
            ddr_ap <= 4'd0;
            ddr_half_bl <= 4'd0;
            ddr_pall <= 4'd0;
            ddr_bg <= {(4*BG_WIDTH){1'b0}};
            ddr_bank <= {(4*BANK_WIDTH){1'b0}};
            ddr_col <= {(4*COL_WIDTH){1'b0}};
            ddr_row <= {(4*ROW_WIDTH){1'b0}};
            
            for (i = 0; i < 4; i = i + 1) begin
                ddr_bank[i*BANK_WIDTH +: BANK_WIDTH] <= latest_instrs[i*32+3 +: BANK_WIDTH];
                ddr_bg[i*BG_WIDTH +: BG_WIDTH] <= latest_instrs[i*32+3+BANK_WIDTH +: BG_WIDTH];
                ddr_row[i*ROW_WIDTH +: ROW_WIDTH] <= latest_instrs[i*32+3+BANK_WIDTH+BG_WIDTH +: ROW_WIDTH];
                ddr_col[i*COL_WIDTH +: COL_WIDTH] <= latest_instrs[i*32+3+BANK_WIDTH+BG_WIDTH +: COL_WIDTH];
                ddr_pall[i] <= latest_instrs[i*32+3+BANK_WIDTH+BG_WIDTH];
                
                if (latest_instrs[i*32 +: 3] == 3'd0) begin
                    // NOP
                    ddr_nop[i] <= 1'b1;
                end else if (latest_instrs[i*32 +: 3] == 3'd1) begin
                    // Precharge
                    ddr_pre[i] <= 1'b1;
                end else if (latest_instrs[i*32 +: 3] == 3'd2) begin
                    // Activate
                    ddr_act[i] <= 1'b1;
                end else if (latest_instrs[i*32 +: 3] == 3'd3) begin
                    // Read
                    ddr_read[i] <= 1'b1;
                end else if (latest_instrs[i*32 +: 3] == 3'd4) begin
                    // Write
                    ddr_write[i] <= 1'b1;
                end else if (latest_instrs[i*32 +: 3] == 3'd5) begin
                    // Refresh
                    ddr_ref[i] <= 1'b1;
                end
            end
        end
    end

endmodule
