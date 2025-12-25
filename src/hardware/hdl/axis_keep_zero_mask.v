`timescale 1ns / 1ps

module axis_keep_zero_mask #(
    parameter TDATA_WIDTH = 32,
    parameter TKEEP_WIDTH = TDATA_WIDTH / 8
)(
    // AXI Stream Slave Interface (Input)
    input  wire [TDATA_WIDTH-1:0]   s_axis_tdata,
    input  wire [TKEEP_WIDTH-1:0]   s_axis_tkeep,
    input  wire                     s_axis_tlast,
    input  wire                     s_axis_tvalid,
    output wire                     s_axis_tready,
    // (Optional: TSTRB, TUSER, TID, TDEST are passed through if needed)

    // AXI Stream Master Interface (Output)
    output wire [TDATA_WIDTH-1:0]   m_axis_tdata,
    output wire [TKEEP_WIDTH-1:0]   m_axis_tkeep,
    output wire                     m_axis_tlast,
    output wire                     m_axis_tvalid,
    input  wire                     m_axis_tready
);

    //=========================================================================
    // Internal Signals
    //=========================================================================
    wire [TDATA_WIDTH-1:0] zero_mask;

    //=========================================================================
    // Mask Generation
    //=========================================================================
    // TKEEPの各ビットを8倍に拡張してマスクを作成します。
    // 例: TKEEP=4'b0011 -> mask=32'h0000FFFF
    
    genvar i;
    generate
        for (i = 0; i < TKEEP_WIDTH; i = i + 1) begin : gen_mask
            assign zero_mask[i*8 +: 8] = {8{s_axis_tkeep[i]}};
        end
    endgenerate

    //=========================================================================
    // Data Masking
    //=========================================================================
    // 入力データとマスクのANDを取ることで、TKEEP=0の部分を0にします。
    assign m_axis_tdata = s_axis_tdata & zero_mask;

    //=========================================================================
    // Pass-through Signals
    //=========================================================================
    // データ以外の制御信号はそのまま通過させます。
    assign m_axis_tkeep  = s_axis_tkeep;
    assign m_axis_tlast  = s_axis_tlast;
    assign m_axis_tvalid = s_axis_tvalid;
    assign s_axis_tready = m_axis_tready;

endmodule
