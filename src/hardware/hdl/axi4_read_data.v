module axi4_read_data(
    input clk,
    input rst,

    // DDR4 Interface -> AXI4 Read Data
    input [511:0] ddr_rd_data,
    input ddr_rd_valid,

    // AXI4 Stream Master Interface -> DMA S2MM
    output [511:0] M_AXIS_TDATA,
    output [63:0]  M_AXIS_TKEEP,
    output M_AXIS_TVALID,
    output M_AXIS_TLAST,
    input  M_AXIS_TREADY,

    // Debug
    output overflow_err,
    output [15:0] latest_data_monitor
);

    // TLAST control:
    // For data stream transfers, TLAST should indicate "the last transfer" in the stream.
    // Here, we simplify by always setting TLAST to 1 so that the DMA can detect transfer completion.
    // In practice, the DMA finishes when it receives the number of bytes specified by LENGTH.
    wire s_axis_tlast = 1'b1;  // Always set to 1 (indicates every transfer is the last data)

    // Warning when the FIFO is almost full (DDR data cannot be stopped due to critical error)
    wire fifo_full;
    wire fifo_overflow;
    
    // Debug
    assign overflow_err = fifo_overflow;
    assign latest_data_monitor = M_AXIS_TDATA[15:0];

    // --------------------------------------------------------
    // Xilinx XPM_FIFO_AXIS Instantiation
    // --------------------------------------------------------
    xpm_fifo_axis #(
        .FIFO_DEPTH(512),
        .TDATA_WIDTH(512),
        .FIFO_MEMORY_TYPE("auto"),
        .PACKET_FIFO("false")
    ) axis_fifo_inst (
        .s_aclk(clk),
        .s_aresetn(!rst),

        // Slave Interface (Input from DDR)
        .s_axis_tdata(ddr_rd_data),
        .s_axis_tvalid(ddr_rd_valid),
        .s_axis_tready(),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tkeep({64{1'b1}}),
        .s_axis_tstrb({64{1'b1}}),
        .s_axis_tuser(1'b0),
        .s_axis_tid(1'b0),
        .s_axis_tdest(1'b0),

        // Master Interface (Output to DMA)
        .m_axis_tdata(M_AXIS_TDATA),
        .m_axis_tvalid(M_AXIS_TVALID),
        .m_axis_tready(M_AXIS_TREADY),
        .m_axis_tlast(M_AXIS_TLAST),
        .m_axis_tkeep(M_AXIS_TKEEP),
        
        // Unused outputs
        .m_axis_tstrb(),
        .m_axis_tuser(),
        .m_axis_tid(),
        .m_axis_tdest()
        
        // // Status signals
        // .prog_full_axis(),
        // .wr_data_count_axis(),
        // .rd_data_count_axis()
    );

endmodule
