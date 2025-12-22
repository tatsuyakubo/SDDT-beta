module xpm_fifo_axis_wrapper (
    input aclk,
    input aresetn,

    input [TDATA_WIDTH-1:0] S_AXIS_TDATA,
    input [TDATA_WIDTH/8-1:0] S_AXIS_TKEEP,
    input S_AXIS_TLAST,
    input S_AXIS_TVALID,
    output S_AXIS_TREADY,

    output [TDATA_WIDTH-1:0] M_AXIS_TDATA,
    output [TDATA_WIDTH/8-1:0] M_AXIS_TKEEP,
    output M_AXIS_TLAST,
    output M_AXIS_TVALID,
    input M_AXIS_TREADY,
    
    output [31:0] data_count
);
    parameter FIFO_DEPTH = 256;
    parameter TDATA_WIDTH = 128;
    parameter COUNT_WIDTH = $clog2(FIFO_DEPTH)+1;

    wire [COUNT_WIDTH-1:0] wr_data_count_axis;
    assign data_count = {{(32-COUNT_WIDTH){1'b0}}, wr_data_count_axis};

    // --------------------------------------------------------
    // Xilinx XPM_FIFO_AXIS Instantiation
    // --------------------------------------------------------
    xpm_fifo_axis #(
    .CASCADE_HEIGHT(0),                         // DECIMAL
    .CDC_SYNC_STAGES(2),                        // DECIMAL
    .CLOCKING_MODE("common_clock"),             // String
    .ECC_MODE("no_ecc"),                        // String
    .EN_SIM_ASSERT_ERR("warning"),              // String
    .FIFO_DEPTH(FIFO_DEPTH),                    // DECIMAL
    .FIFO_MEMORY_TYPE("auto"),                  // String
    .PACKET_FIFO("false"),                      // String
    .PROG_EMPTY_THRESH(10),                     // DECIMAL
    .PROG_FULL_THRESH(10),                      // DECIMAL
    .RD_DATA_COUNT_WIDTH(1),                    // DECIMAL
    .RELATED_CLOCKS(0),                         // DECIMAL
    .SIM_ASSERT_CHK(0),                         // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
    .TDATA_WIDTH(TDATA_WIDTH),                  // DECIMAL
    .TDEST_WIDTH(1),                            // DECIMAL
    .TID_WIDTH(1),                              // DECIMAL
    .TUSER_WIDTH(1),                            // DECIMAL
    .USE_ADV_FEATURES("1004"),                  // String; 1004: Valid and enable wr_data_count
    .WR_DATA_COUNT_WIDTH(COUNT_WIDTH)           // DECIMAL
    )
    xpm_fifo_axis_i (
      // Master Interface
      .m_aclk(aclk),                           // 1-bit input: Master Interface Clock: All signals on master interface are sampled on the rising edge
                                                  // of this clock.
      .m_axis_tready(M_AXIS_TREADY),           // 1-bit input: TREADY: Indicates that the slave can accept a transfer in the current cycle.
      .m_axis_tdata(M_AXIS_TDATA),             // TDATA_WIDTH-bit output: TDATA: The primary payload that is used to provide the data that is passing
                                                  // across the interface. The width of the data payload is an integer number of bytes.
      .m_axis_tdest(),                         // TDEST_WIDTH-bit output: TDEST: Provides routing information for the data stream.
      .m_axis_tid(),                           // TID_WIDTH-bit output: TID: The data stream identifier that indicates different streams of data.
      .m_axis_tkeep(M_AXIS_TKEEP),             // TDATA_WIDTH/8-bit output: TKEEP: The byte qualifier that indicates whether the content of the
                                                  // associated byte of TDATA is processed as part of the data stream. Associated bytes that have the
                                                  // TKEEP byte qualifier deasserted are null bytes and can be removed from the data stream. For a
                                                  // 64-bit DATA, bit 0 corresponds to the least significant byte on DATA, and bit 7 corresponds to the
                                                  // most significant byte. For example: KEEP[0] = 1b, DATA[7:0] is not a NULL byte KEEP[7] = 0b,
                                                  // DATA[63:56] is a NULL byte
      .m_axis_tlast(M_AXIS_TLAST),             // 1-bit output: TLAST: Indicates the boundary of a packet.
      .m_axis_tstrb(),                         // TDATA_WIDTH/8-bit output: TSTRB: The byte qualifier that indicates whether the content of the
                                                  // associated byte of TDATA is processed as a data byte or a position byte. For a 64-bit DATA, bit 0
                                                  // corresponds to the least significant byte on DATA, and bit 0 corresponds to the least significant
                                                  // byte on DATA, and bit 7 corresponds to the most significant byte. For example: STROBE[0] = 1b,
                                                  // DATA[7:0] is valid STROBE[7] = 0b, DATA[63:56] is not valid
      .m_axis_tuser(),                         // TUSER_WIDTH-bit output: TUSER: The user-defined sideband information that can be transmitted
                                                  // alongside the data stream.
      .m_axis_tvalid(M_AXIS_TVALID),           // 1-bit output: TVALID: Indicates that the master is driving a valid transfer. A transfer takes place
                                                  // when both TVALID and TREADY are asserted
      // Slave Interface
      .s_aclk(aclk),                           // 1-bit input: Slave Interface Clock: All signals on slave interface are sampled on the rising edge
                                                  // of this clock.
      .s_aresetn(aresetn),                     // 1-bit input: Active low asynchronous reset.
      .s_axis_tready(S_AXIS_TREADY),           // 1-bit output: TREADY: Indicates that the slave can accept a transfer in the current cycle.
      .s_axis_tdata(S_AXIS_TDATA),             // TDATA_WIDTH-bit input: TDATA: The primary payload that is used to provide the data that is passing
                                                  // across the interface. The width of the data payload is an integer number of bytes.
      .s_axis_tdest(),                         // TDEST_WIDTH-bit input: TDEST: Provides routing information for the data stream.
      .s_axis_tid(),                           // TID_WIDTH-bit input: TID: The data stream identifier that indicates different streams of data.
      .s_axis_tkeep(S_AXIS_TKEEP),             // TDATA_WIDTH/8-bit input: TKEEP: The byte qualifier that indicates whether the content of the
                                                  // associated byte of TDATA is processed as part of the data stream. Associated bytes that have the
                                                  // TKEEP byte qualifier deasserted are null bytes and can be removed from the data stream. For a
                                                  // 64-bit DATA, bit 0 corresponds to the least significant byte on DATA, and bit 7 corresponds to the
                                                  // most significant byte. For example: KEEP[0] = 1b, DATA[7:0] is not a NULL byte KEEP[7] = 0b,
                                                  // DATA[63:56] is a NULL byte
      .s_axis_tlast(S_AXIS_TLAST),             // 1-bit input: TLAST: Indicates the boundary of a packet.
      .s_axis_tstrb(),                         // TDATA_WIDTH/8-bit input: TSTRB: The byte qualifier that indicates whether the content of the
                                                  // associated byte of TDATA is processed as a data byte or a position byte. For a 64-bit DATA, bit 0
                                                  // corresponds to the least significant byte on DATA, and bit 0 corresponds to the least significant
                                                  // byte on DATA, and bit 7 corresponds to the most significant byte. For example: STROBE[0] = 1b,
                                                  // DATA[7:0] is valid STROBE[7] = 0b, DATA[63:56] is not valid
      .s_axis_tuser(),                         // TUSER_WIDTH-bit input: TUSER: The user-defined sideband information that can be transmitted
                                                  // alongside the data stream.
      .s_axis_tvalid(S_AXIS_TVALID),           // 1-bit input: TVALID: Indicates that the master is driving a valid transfer. A transfer takes place
                                                  // when both TVALID and TREADY are asserted
      // Status signals
      .rd_data_count_axis(),                   // RD_DATA_COUNT_WIDTH-bit output: Read Data Count- This bus indicates the number of words available
                                                  // for reading in the FIFO.
      .wr_data_count_axis(wr_data_count_axis), // WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates the number of words written
                                                  // into the FIFO.
      .almost_empty_axis(),                    // 1-bit output: Almost Empty : When asserted, this signal indicates that only one more read can be
                                                  // performed before the FIFO goes to empty.
      .almost_full_axis(),                     // 1-bit output: Almost Full: When asserted, this signal indicates that only one more write can be
                                                  // performed before the FIFO is full.
      .prog_empty_axis(),                      // 1-bit output: Programmable Empty- This signal is asserted when the number of words in the FIFO is
                                                  // less than or equal to the programmable empty threshold value. It is de-asserted when the number of
                                                  // words in the FIFO exceeds the programmable empty threshold value.
      .prog_full_axis(),                       // 1-bit output: Programmable Full: This signal is asserted when the number of words in the FIFO is
                                                  // greater than or equal to the programmable full threshold value. It is de-asserted when the number
                                                  // of words in the FIFO is less than the programmable full threshold value.
      .sbiterr_axis(),                         // 1-bit output: Single Bit Error- Indicates that the ECC decoder detected and fixed a single-bit
                                                  // error.
      .dbiterr_axis(),                         // 1-bit output: Double Bit Error- Indicates that the ECC decoder detected a double-bit error and data
                                                  // in the FIFO core is corrupted.
      .injectdbiterr_axis(),                   // 1-bit input: Double Bit Error Injection- Injects a double bit error if the ECC feature is used.
      .injectsbiterr_axis()                    // 1-bit input: Single Bit Error Injection- Injects a single bit error if the ECC feature is used.
    );
    // End of xpm_fifo_axis_inst instantiation

endmodule
