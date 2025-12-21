`timescale 1ns/1ps
`default_nettype none

module axi4_instr #(parameter
    BG_WIDTH = 2, BANK_WIDTH = 2, COL_WIDTH = 10, ROW_WIDTH = 17
)
(
    input wire clk,
    input wire rst,
    // AXI -> Instr
    input wire [127:0] S_AXIS_TDATA,
    input wire S_AXIS_TVALID,
    output logic S_AXIS_TREADY,
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
    output reg [4*ROW_WIDTH-1:0]    ddr_row,
    // Debug
    output logic [2:0] latest_instr_id
);

    reg [127:0] latest_instrs;

    // AXI4-Stream slave interface - always ready to receive
    assign S_AXIS_TREADY = 1'b1;

    assign latest_instr_id = latest_instrs[2:0];

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            latest_instrs <= 'd0;
            {ddr_write, ddr_read, ddr_pre, ddr_act, ddr_ref, ddr_zq, ddr_nop, ddr_ap, ddr_half_bl, ddr_pall,
            ddr_bg, ddr_bank, ddr_col, ddr_row} <= '0;
        end else begin
            // Receive data every cycle
            if (S_AXIS_TVALID) begin
                latest_instrs <= S_AXIS_TDATA;
            end else begin
                latest_instrs <= 'd0;
            end

            // Process latest_instrs every cycle
            // initialize all outputs to zero
            {ddr_write, ddr_read, ddr_pre, ddr_act, ddr_ref, ddr_zq, ddr_nop, ddr_ap, ddr_half_bl, ddr_pall,
            ddr_bg, ddr_bank, ddr_col, ddr_row} <= '0;
            for (i = 0; i < 4; i = i + 1) begin
                ddr_bank[i*BANK_WIDTH+:BANK_WIDTH] <= latest_instrs[i*32+3+:BANK_WIDTH];
                ddr_bg[i*BG_WIDTH+:BG_WIDTH] <= latest_instrs[i*32+3+BANK_WIDTH+:BG_WIDTH];
                ddr_row[i*ROW_WIDTH+:ROW_WIDTH] <= latest_instrs[i*32+3+BANK_WIDTH+BG_WIDTH+:ROW_WIDTH];
                ddr_col[i*COL_WIDTH+:COL_WIDTH] <= latest_instrs[i*32+3+BANK_WIDTH+BG_WIDTH+:COL_WIDTH];
                ddr_pall[i] <= latest_instrs[i*32+3+BANK_WIDTH+BG_WIDTH+:1];
                if (latest_instrs[i*32+:3] == 3'd0) begin
                    // NOP
                    ddr_nop[i] <= 1'b1;
                end else if (latest_instrs[i*32+:3] == 3'd1) begin
                    // Precharge
                    ddr_pre[i] <= 1'b1;
                end else if (latest_instrs[i*32+:3] == 3'd2) begin
                    // Activate
                    ddr_act[i] <= 1'b1;
                end else if (latest_instrs[i*32+:3] == 3'd3) begin
                    // Read
                    ddr_read[i] <= 1'b1;
                end else if (latest_instrs[i*32+:3] == 3'd4) begin
                    // Write
                    ddr_write[i] <= 1'b1;
                end else if (latest_instrs[i*32+:3] == 3'd5) begin
                    // Refresh
                    ddr_ref[i] <= 1'b1;
                end
            end
        end
    end
endmodule
