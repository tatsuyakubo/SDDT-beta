module axi4_read_data(
    input clk,
    input rst,

    // DDR4_Adapter -> axi4_read_data
    input [511:0] rd_data,
    input rd_valid,

    output reg err,
    output [15:0] latest_buf,

    output [511:0] M_AXIS_TDATA,
    output [512/8-1:0] M_AXIS_TKEEP,
    output M_AXIS_TVALID,
    output M_AXIS_TLAST,
    input M_AXIS_TREADY
);
    reg [511:0] buffer;
    reg buffer_full;
    assign M_AXIS_TDATA = buffer_full ? buffer : rd_data;
    assign M_AXIS_TVALID = buffer_full ? 1'b1 : rd_valid;
    assign M_AXIS_TKEEP = { (512/8){1'b1} };
    assign M_AXIS_TLAST = 1'b1; // Always (for AXI DMA)


    assign latest_buf = buffer[15:0]; // Debug

    always @(posedge clk) begin
        if (rst) begin
            buffer <= 512'b0;
            buffer_full <= 1'b0;
            // Debug
            err <= 1'b0;
        end else if (rd_valid) begin
            if (buffer_full) begin
                err <= 1'b1;
            end
            if (!M_AXIS_TREADY) begin
                buffer_full <= 1'b1;
            end
            buffer <= rd_data;
        end else if (M_AXIS_TREADY) begin
            if (buffer_full) begin
                buffer_full <= 1'b0;
            end
        end
    end
endmodule
