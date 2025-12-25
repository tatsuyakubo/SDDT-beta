`timescale 1ns / 1ps

module axi4_mm2s_bridge_128 # (
    parameter integer C_S_AXI_DATA_WIDTH = 128,
    parameter integer C_S_AXI_ADDR_WIDTH = 32,
    // When set to 1, propagate the AXI burst boundary (WLAST) as the Stream TLAST signal.
    // When set to 0, TLAST is always 0 (treated as one long stream). In cases like instruction FIFOs, setting this to 0 is often safer.
    parameter integer C_PROPAGATE_TLAST  = 0 
)(
    // Clock and Reset
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXI:M_AXIS, ASSOCIATED_RESET S_AXI_ARESETN" *)
    input wire  S_AXI_ACLK,
    input wire  S_AXI_ARESETN,

    // AXI4-Full Slave (Write Only)
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    input wire [7 : 0] S_AXI_AWLEN,
    input wire [2 : 0] S_AXI_AWSIZE,
    input wire [1 : 0] S_AXI_AWBURST,
    input wire  S_AXI_AWLOCK,
    input wire [3 : 0] S_AXI_AWCACHE,
    input wire [2 : 0] S_AXI_AWPROT,
    input wire  S_AXI_AWVALID,
    output wire S_AXI_AWREADY,

    input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    input wire  S_AXI_WLAST,
    input wire  S_AXI_WVALID,
    output wire S_AXI_WREADY,

    output wire [1 : 0] S_AXI_BRESP,
    output wire S_AXI_BVALID,
    input wire  S_AXI_BREADY,

    // Read Channels (Stubbed)
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

    // AXI4-Stream Master
    output reg [C_S_AXI_DATA_WIDTH-1 : 0] M_AXIS_TDATA,
    output reg [(C_S_AXI_DATA_WIDTH/8)-1 : 0] M_AXIS_TKEEP,
    output reg  M_AXIS_TLAST,
    output reg  M_AXIS_TVALID,
    input wire  M_AXIS_TREADY
);

    // =========================================================================
    // 1. Write Address (AW) - Always Accept (Improvement #1)
    // =========================================================================
    // We ignore the address logic entirely to maximize throughput.
    // The CPU can send addresses as fast as it wants.
    assign S_AXI_AWREADY = 1'b1;


    // =========================================================================
    // 2. Write Data (W) -> Stream with Pipeline (Improvement #2)
    // =========================================================================
    // Simple Register Slice to break timing paths.
    
    // Internal wires for handshake
    wire w_handshake = S_AXI_WVALID && S_AXI_WREADY;
    wire m_handshake = M_AXIS_TVALID && M_AXIS_TREADY;

    // We can accept data if the downstream (after register) is ready,
    // OR if the register is currently empty (bubbles).
    // Simple Skid Buffer logic is better, but here is a simple valid/ready pipeline.
    
    // Since we need S_AXI_WREADY to be high to accept data, 
    // we tie it to the "buffer not full" condition.
    // To keep it extremely simple and fast: 
    // We pass S_AXI_WREADY <= M_AXIS_TREADY directly (combinational backpressure),
    // but we register the DATA payload.
    
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            M_AXIS_TVALID <= 1'b0;
            M_AXIS_TDATA  <= 0;
            M_AXIS_TKEEP  <= 0;
            M_AXIS_TLAST  <= 0;
        end else begin
            // If Slave is ready (M_AXIS_TREADY) or we are not valid yet
            if (M_AXIS_TREADY || !M_AXIS_TVALID) begin
                M_AXIS_TVALID <= S_AXI_WVALID;
                M_AXIS_TDATA  <= S_AXI_WDATA;
                M_AXIS_TKEEP  <= S_AXI_WSTRB;
                
                case (C_PROPAGATE_TLAST)
                    0: M_AXIS_TLAST <= 1'b0;
                    1: M_AXIS_TLAST <= S_AXI_WLAST;
                    2: M_AXIS_TLAST <= !S_AXI_WDATA[C_S_AXI_DATA_WIDTH-1];
                    default: M_AXIS_TLAST <= 1'b0;
                endcase
            end
        end
    end

    // Backpressure logic:
    // Ideally, we should use a Skid Buffer for full bandwidth.
    // However, for this bridge, connecting Ready directly to the next stage's Ready
    // (with the register delay accounted for) is slightly risky for "valid then wait".
    // A robust simple mapping:
    // The CPU sees WREADY only if the output register can take data.
    assign S_AXI_WREADY = M_AXIS_TREADY || !M_AXIS_TVALID;


    // =========================================================================
    // 3. Write Response (B) - Credit Counter (Improvement #1)
    // =========================================================================
    // Every time we finish a W-Burst (WLAST && Handshake), we owe one B-Response.
    
    reg [7:0] b_credits; // Can store up to 255 outstanding transactions
    
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            b_credits <= 0;
        end else begin
            // Increment credit on accepted WLAST
            if (S_AXI_WVALID && S_AXI_WREADY && S_AXI_WLAST) begin
                if (!(S_AXI_BVALID && S_AXI_BREADY)) 
                    b_credits <= b_credits + 1;
                // else: increment and decrement cancel out -> no change
            end 
            // Decrement credit on accepted BRESP
            else if (S_AXI_BVALID && S_AXI_BREADY) begin
                b_credits <= b_credits - 1;
            end
        end
    end

    // Assert BVALID if we have credits
    assign S_AXI_BVALID = (b_credits > 0);
    assign S_AXI_BRESP  = 2'b00; // OKAY


    // =========================================================================
    // 4. Read Logic (Stub)
    // =========================================================================
    assign S_AXI_ARREADY = 1'b1;
    assign S_AXI_RDATA   = {C_S_AXI_DATA_WIDTH{1'b0}};
    assign S_AXI_RRESP   = 2'b00;
    assign S_AXI_RLAST   = 1'b1;
    
    reg rvalid_reg;
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) rvalid_reg <= 1'b0;
        else if (S_AXI_ARVALID) rvalid_reg <= 1'b1;
        else if (S_AXI_RREADY)  rvalid_reg <= 1'b0;
    end
    assign S_AXI_RVALID = rvalid_reg;

endmodule