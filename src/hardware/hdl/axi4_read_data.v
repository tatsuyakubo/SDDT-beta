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

    // TLASTの制御:
    // データストリーム転送の場合、TLASTは「転送の最後」を示すべきですが、
    // ここでは単純化のため常に1にします（DMAが転送完了を検出できるように）。
    // ただし、実際にはDMAはLENGTHで指定されたバイト数を受け取れば完了します。
    wire s_axis_tlast = 1'b1;  // 常に1に設定（各転送が最後のデータであることを示す）

    // FIFOが満杯になりそうなときの警告（DDRからのデータは止められないため致命的）
    wire fifo_full;
    wire fifo_overflow;
    
    // Debug用
    assign overflow_err = fifo_overflow;
    assign latest_data_monitor = M_AXIS_TDATA[15:0];

    // --------------------------------------------------------
    // Xilinx XPM_FIFO_AXIS Instantiation
    // --------------------------------------------------------
    // DDRのバーストを受け止めるため、ある程度の深さ(DEPTH)が必要です。
    // ここでは適度なサイズ(512深度)を設定していますが、BRAMリソースに応じて調整してください。
    // 同期FIFOの場合、m_aclkとs_aclkを同じ信号に接続します。
    
    xpm_fifo_axis #(
        // CLOCK_DOMAINパラメータは削除（同期FIFOの場合は不要）
        .FIFO_DEPTH(512),         // バッファ深度 (DDRバースト対策)
        .TDATA_WIDTH(512),        // データ幅
        .FIFO_MEMORY_TYPE("auto"),
        .PACKET_FIFO("false"),
        .USE_ADV_FEATURES("1000") // overflow flag有効化
    ) axis_fifo_inst (
        .s_aclk(clk),              // 入力側クロック
        .s_aresetn(!rst),          // 入力側リセット（アクティブロー）

        // Slave Interface (Input from DDR)
        .s_axis_tdata(ddr_rd_data),
        .s_axis_tvalid(ddr_rd_valid),
        .s_axis_tready(),          // DDR側にはReadyを返せない（無視する）
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
        .m_axis_tdest(),
        
        // Status signals
        .prog_full_axis(),
        .wr_data_count_axis(),
        .rd_data_count_axis()
    );

endmodule
