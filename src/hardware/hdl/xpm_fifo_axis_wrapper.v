module xpm_fifo_axis_wrapper #(
    parameter FIFO_DEPTH = 512,
    parameter TDATA_WIDTH = 512
)(
    input clk,
    input rst,

    input [TDATA_WIDTH-1:0] S_AXIS_TDATA,
    input S_AXIS_TVALID,
    output S_AXIS_TREADY,

    output [TDATA_WIDTH-1:0] M_AXIS_TDATA,
    output [TDATA_WIDTH/8-1:0] M_AXIS_TKEEP,
    output M_AXIS_TLAST,
    output M_AXIS_TVALID,
    input M_AXIS_TREADY,
    
    output [$clog2(FIFO_DEPTH):0] wr_data_count
);
    assign M_AXIS_TLAST = 1'b1;
    assign M_AXIS_TKEEP = {TDATA_WIDTH/8{1'b1}};
    
    // --------------------------------------------------------
    // Xilinx XPM_FIFO_AXIS Instantiation
    // --------------------------------------------------------
    xpm_fifo_axis #(
        .FIFO_DEPTH(FIFO_DEPTH),
        .TDATA_WIDTH(TDATA_WIDTH),
        .FIFO_MEMORY_TYPE("auto"),
        .PACKET_FIFO("false"),
        .USE_ADV_FEATURES("0000000000000100"), // write data count
        .WR_DATA_COUNT_WIDTH($clog2(FIFO_DEPTH)+1)
    ) axis_fifo_inst (
        .s_aclk(clk),
        .s_aresetn(!rst),

        // Slave Interface (Input)
        .s_axis_tdata(S_AXIS_TDATA),
        .s_axis_tvalid(S_AXIS_TVALID),
        .s_axis_tready(S_AXIS_TREADY),
        .s_axis_tlast(1'b1),
        .s_axis_tkeep({TDATA_WIDTH/8{1'b1}}),
        .s_axis_tstrb({TDATA_WIDTH/8{1'b1}}),
        .s_axis_tuser(1'b0),
        .s_axis_tid(1'b0),
        .s_axis_tdest(1'b0),

        // Master Interface (Output)
        .m_axis_tdata(M_AXIS_TDATA),
        .m_axis_tvalid(M_AXIS_TVALID),
        .m_axis_tready(M_AXIS_TREADY),
        .m_axis_tlast(),
        .m_axis_tkeep(),
        
        // Unused outputs
        .m_axis_tstrb(),
        .m_axis_tuser(),
        .m_axis_tid(),
        .m_axis_tdest(),
        
        // Write data count
        .wr_data_count_axis(wr_data_count)
    );

endmodule
