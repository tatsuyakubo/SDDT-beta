module axi4_write_data(
    input clk,
    input rst,

    input [511:0] S_AXIS_TDATA,
    input S_AXIS_TVALID,
    output S_AXIS_TREADY,

    output reg [511:0] ddr_wdata
);
    // AXI4-Stream slave interface
    assign S_AXIS_TREADY = 1'b1; // Always ready to accept data

    always @(posedge clk) begin
        if (rst) begin
            ddr_wdata <= 512'b0;
        end else if (S_AXIS_TVALID) begin
            ddr_wdata <= S_AXIS_TDATA;
        end
    end
endmodule
