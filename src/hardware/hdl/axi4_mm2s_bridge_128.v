`timescale 1ns / 1ps

module axi4_mm2s_bridge_128 # (
    // Zynq UltraScale+ HP port width is 128-bit
    parameter integer C_S_AXI_DATA_WIDTH = 128,
    parameter integer C_S_AXI_ADDR_WIDTH = 32 // ZUS+ Address width
)(
    // Clock and Reset
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXI:M_AXIS, ASSOCIATED_RESET S_AXI_ARESETN" *)
    input wire  S_AXI_ACLK,
    input wire  S_AXI_ARESETN,

    // ---------------------------------------------------------
    // AXI4-Full Slave Interface (Write Channel)
    // ---------------------------------------------------------
    // Write Address Channel
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    input wire [7 : 0] S_AXI_AWLEN,
    input wire [2 : 0] S_AXI_AWSIZE,
    input wire [1 : 0] S_AXI_AWBURST,
    input wire  S_AXI_AWLOCK,
    input wire [3 : 0] S_AXI_AWCACHE,
    input wire [2 : 0] S_AXI_AWPROT,
    input wire  S_AXI_AWVALID,
    output wire S_AXI_AWREADY,

    // Write Data Channel
    input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    input wire  S_AXI_WLAST,
    input wire  S_AXI_WVALID,
    output wire S_AXI_WREADY,

    // Write Response Channel
    output wire [1 : 0] S_AXI_BRESP,
    output wire S_AXI_BVALID,
    input wire  S_AXI_BREADY,

    // ---------------------------------------------------------
    // AXI4-Full Slave Interface (Read Channel - Unused/Stubbed)
    // ---------------------------------------------------------
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    input wire [7 : 0] S_AXI_ARLEN,
    input wire [2 : 0] S_AXI_ARSIZE,
    input wire [1 : 0] S_AXI_ARBURST,
    input wire  S_AXI_ARLOCK,
    input wire [3 : 0] S_AXI_ARCACHE,
    input wire [2 : 0] S_AXI_ARPROT,
    input wire  S_AXI_ARVALID,
    output wire S_AXI_ARREADY,
    
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    output wire [1 : 0] S_AXI_RRESP,
    output wire  S_AXI_RLAST,
    output wire  S_AXI_RVALID,
    input wire  S_AXI_RREADY,

    // ---------------------------------------------------------
    // AXI4-Stream Master Interface (Connect to FIFO)
    // ---------------------------------------------------------
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] M_AXIS_TDATA,
    output wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] M_AXIS_TKEEP,
    output wire  M_AXIS_TLAST,
    output wire  M_AXIS_TVALID,
    input wire   M_AXIS_TREADY
);

    // =========================================================================
    // Write Logic (MMIO -> Stream Bridge)
    // =========================================================================

    // 1. Write Address Channel (AW)
    // We ignore the address but must acknowledge the command to comply with AXI.
    // Ideally, we accept AW immediately.
    // For safety, we only accept AW if we are not currently waiting for a B-response completion,
    // though for high throughput overlapping is preferred. Here we use a simple approach.
    
    reg aw_en;
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN)
            aw_en <= 1'b1;
        else if (S_AXI_AWVALID && S_AXI_AWREADY)
            aw_en <= 1'b0; // Latched address
        else if (S_AXI_BVALID && S_AXI_BREADY)
            aw_en <= 1'b1; // Transaction complete, ready for next address
    end
    
    // Simple logic: Always ready to take address if we aren't stuck.
    // Note: CPU WC buffers might send multiple AWs before data finishes, 
    // so strictly blocking AW might hurt performance. 
    // However, keeping it simple (1 transaction at a time) is safest for a bridge.
    // If you need "outstanding transactions", you need a FIFO for AW channel.
    // For this bridge, let's allow AW to be accepted anytime BVALID isn't high.
    assign S_AXI_AWREADY = !S_AXI_BVALID; // Simplified flow control

    // 2. Write Data Channel (W) -> Stream Mapping
    // Pass data directly to Stream. 
    // Only accept W data from CPU if the Stream Destination (FIFO) is Ready.
    
    assign M_AXIS_TDATA  = S_AXI_WDATA;
    assign M_AXIS_TKEEP  = S_AXI_WSTRB; // Map Write Strobe to Keep
    assign M_AXIS_TVALID = S_AXI_WVALID;
    assign M_AXIS_TLAST  = S_AXI_WLAST; // Important: AXI Burst boundary becomes Packet boundary
    
    // Backpressure: If FIFO is full (TREADY=0), tell CPU to wait (WREADY=0)
    assign S_AXI_WREADY  = M_AXIS_TREADY;

    // 3. Write Response Channel (B)
    // AXI requires a response (BRESP) after the last data beat (WLAST) is accepted.
    
    reg bvalid_reg;
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            bvalid_reg <= 1'b0;
        end else begin
            // If we successfully transferred the LAST beat of a burst...
            if (S_AXI_WVALID && S_AXI_WREADY && S_AXI_WLAST) begin
                bvalid_reg <= 1'b1; // Assert Response Valid
            end else if (S_AXI_BREADY && bvalid_reg) begin
                bvalid_reg <= 1'b0; // De-assert after CPU accepts it
            end
        end
    end

    assign S_AXI_BVALID = bvalid_reg;
    assign S_AXI_BRESP  = 2'b00; // OKAY response

    // =========================================================================
    // Read Logic (Stub / Error)
    // =========================================================================
    // Since this is a write-only bridge, we stub out reads.
    // Returning an error (SLVERR = 2'b10) or OKAY with 0 data.
    
    assign S_AXI_ARREADY = 1'b1; // Always accept address to prevent hanging
    assign S_AXI_RDATA   = {C_S_AXI_DATA_WIDTH{1'b0}};
    assign S_AXI_RRESP   = 2'b00; // OKAY
    assign S_AXI_RLAST   = 1'b1;  // Single beat
    
    // Generate valid response immediately after address
    reg rvalid_reg;
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN)
            rvalid_reg <= 1'b0;
        else if (S_AXI_ARVALID && S_AXI_ARREADY)
            rvalid_reg <= 1'b1;
        else if (S_AXI_RREADY && rvalid_reg)
            rvalid_reg <= 1'b0;
    end
    assign S_AXI_RVALID = rvalid_reg;

endmodule
