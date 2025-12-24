`timescale 1ns/1ps

//=============================================================================
// Scheduler
// 
// Independently accepts instruction and write data streams for maximum
// throughput. Both streams are always ready to receive new data.
//
// Behavior:
//   - Instruction and write data are captured independently
//   - If instruction contains WR command: use stored wdata (or wait if not available)
//   - If instruction does NOT contain WR command: output immediately with zero wdata
//   - wdata is consumed only when WR command is present
//
// This design allows wdata to be pre-loaded before the WR command arrives,
// minimizing latency.
//
// Input format:
//   - S_AXIS_INSTR: 128-bit instruction data (4 x 32-bit commands)
//   - S_AXIS_WDATA: 512-bit write data
//
// Output format (640-bit):
//   [127:0]   - Instruction data
//   [639:128] - Write data (zero if no WR command)
//=============================================================================

module scheduler #(
    parameter INSTR_WIDTH = 128,
    parameter WDATA_WIDTH = 512,
    parameter MERGED_WIDTH = INSTR_WIDTH + WDATA_WIDTH  // 640
)(
    input  wire                     clk,
    input  wire                     rst,
    
    // AXI Stream Slave - Instruction input (from host)
    input  wire [INSTR_WIDTH-1:0]   S_AXIS_INSTR_TDATA,
    input  wire                     S_AXIS_INSTR_TVALID,
    output wire                     S_AXIS_INSTR_TREADY,
    input  wire                     S_AXIS_INSTR_TLAST,
    
    // AXI Stream Slave - Write data input (from host)
    input  wire [WDATA_WIDTH-1:0]   S_AXIS_WDATA_TDATA,
    input  wire                     S_AXIS_WDATA_TVALID,
    output wire                     S_AXIS_WDATA_TREADY,
    
    // Merged output without backpressure (to decoder)
    output wire [MERGED_WIDTH-1:0]  merged_output_data,
    output wire                     merged_output_valid
);

    //=========================================================================
    // Command type encoding
    //=========================================================================
    localparam CMD_WR = 3'd4;

    //=========================================================================
    // Internal registers
    //=========================================================================
    reg [INSTR_WIDTH-1:0]   instr_reg;
    reg [WDATA_WIDTH-1:0]   wdata_reg;
    reg                     instr_valid_reg;
    reg                     wdata_valid_reg;
    
    //=========================================================================
    // WR command detection in registered instruction
    //=========================================================================
    wire has_wr_cmd;
    assign has_wr_cmd = (instr_reg[2:0]   == CMD_WR) ||
                        (instr_reg[34:32] == CMD_WR) ||
                        (instr_reg[66:64] == CMD_WR) ||
                        (instr_reg[98:96] == CMD_WR);
    
    //=========================================================================
    // Output control logic
    //=========================================================================
    wire wdata_consumed;
    
    // Output is valid when:
    // - Instruction is valid AND
    // - Either no WR command (don't need wdata) OR wdata is available
    assign merged_output_valid = instr_valid_reg && (!has_wr_cmd || wdata_valid_reg);
    
    // wdata is consumed when output handshake occurs AND instruction has WR command
    assign wdata_consumed = merged_output_valid && has_wr_cmd;
    
    //=========================================================================
    // Ready signals - Independent acceptance
    //=========================================================================
    
    // Accept new instruction when:
    // - No instruction stored, OR
    // - Output occurs in this cycle (current instruction being sent out)
    assign S_AXIS_INSTR_TREADY = !instr_valid_reg || merged_output_valid;
    
    // Accept new wdata when:
    // - No wdata stored, OR
    // - wdata is being consumed (WR command being sent out)
    assign S_AXIS_WDATA_TREADY = !wdata_valid_reg || wdata_consumed;
    
    //=========================================================================
    // Output signals
    //=========================================================================
    // Merge instruction and write data
    // If no WR command, write data portion is zero
    assign merged_output_data = {(has_wr_cmd ? wdata_reg : {WDATA_WIDTH{1'b0}}), instr_reg};
    
    //=========================================================================
    // Register capture logic
    //=========================================================================
    
    always @(posedge clk) begin
        if (rst) begin
            instr_reg <= {INSTR_WIDTH{1'b0}};
            wdata_reg <= {WDATA_WIDTH{1'b0}};
            instr_valid_reg <= 1'b0;
            wdata_valid_reg <= 1'b0;
        end else begin
            //=================================================================
            // Instruction register management
            //=================================================================
            if (S_AXIS_INSTR_TVALID && S_AXIS_INSTR_TREADY) begin
                // Capture new instruction
                instr_reg <= S_AXIS_INSTR_TDATA;
                instr_valid_reg <= 1'b1;
            end else if (merged_output_valid) begin
                // Instruction sent out, clear valid
                instr_valid_reg <= 1'b0;
            end
            
            //=================================================================
            // Write data register management
            //=================================================================
            if (S_AXIS_WDATA_TVALID && S_AXIS_WDATA_TREADY) begin
                // Capture new write data
                wdata_reg <= S_AXIS_WDATA_TDATA;
                wdata_valid_reg <= 1'b1;
            end else if (wdata_consumed) begin
                // Write data consumed by WR command, clear valid
                wdata_valid_reg <= 1'b0;
            end
        end
    end

    //=========================================================================
    // Debug: Performance counters (optional, can be removed for synthesis)
    //=========================================================================
    `ifdef SIMULATION
    reg [31:0] instr_count;
    reg [31:0] wdata_count;
    reg [31:0] output_count;
    reg [31:0] wr_cmd_count;
    reg [31:0] wait_cycles;  // Cycles waiting for wdata
    
    always @(posedge clk) begin
        if (rst) begin
            instr_count <= 0;
            wdata_count <= 0;
            output_count <= 0;
            wr_cmd_count <= 0;
            wait_cycles <= 0;
        end else begin
            if (S_AXIS_INSTR_TVALID && S_AXIS_INSTR_TREADY)
                instr_count <= instr_count + 1;
            if (S_AXIS_WDATA_TVALID && S_AXIS_WDATA_TREADY)
                wdata_count <= wdata_count + 1;
            if (merged_output_valid)
                output_count <= output_count + 1;
            if (merged_output_valid && has_wr_cmd)
                wr_cmd_count <= wr_cmd_count + 1;
            if (instr_valid_reg && has_wr_cmd && !wdata_valid_reg)
                wait_cycles <= wait_cycles + 1;
        end
    end
    `endif

endmodule
