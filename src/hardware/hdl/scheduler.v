`timescale 1ns/1ps

//=============================================================================
// Scheduler
// 
// Independently accepts DDR4 command and write data streams for maximum
// throughput. Both streams are always ready to receive new data.
//
// Behavior:
//   - DDR4 command and write data are captured independently
//   - If DDR4 command contains WR command: use stored wdata (or wait if not available)
//   - If DDR4 command does NOT contain WR command: output immediately with zero wdata
//   - wdata is consumed only when WR command is present
//
// This design allows wdata to be pre-loaded before the WR command arrives,
// minimizing latency.
//
// Input format:
//   - S_AXIS_CMD 128-bit DDR4 command data (4 x 32-bit commands)
//   - S_AXIS_WDATA: 512-bit write data
//
// Output format (640-bit):
//   [127:0]   - DDR4 command data
//   [639:128] - Write data (zero if no WR command)
//=============================================================================

module scheduler #(
    parameter CMD_WIDTH = 128,
    parameter WDATA_WIDTH = 512,
    parameter OUTPUT_WIDTH = CMD_WIDTH + WDATA_WIDTH  // 640
)(
    input  wire                     clk,
    input  wire                     rst,
    
    // AXI Stream Slave - DDR4 command input (from host)
    input  wire [CMD_WIDTH-1:0]   S_AXIS_CMD_TDATA,
    input  wire                     S_AXIS_CMD_TVALID,
    output wire                     S_AXIS_CMD_TREADY,
    input  wire                     S_AXIS_CMD_TLAST,
    
    // AXI Stream Slave - Write data input (from host)
    input  wire [WDATA_WIDTH-1:0]   S_AXIS_WDATA_TDATA,
    input  wire                     S_AXIS_WDATA_TVALID,
    output wire                     S_AXIS_WDATA_TREADY,
    
    // Output without backpressure (to decoder)
    output wire [OUTPUT_WIDTH-1:0]  output_data,
    output wire                     output_valid
);

    //=========================================================================
    // Command type encoding
    //=========================================================================
    localparam CMD_WR = 3'd4;

    //=========================================================================
    // Internal registers
    //=========================================================================
    reg [CMD_WIDTH-1:0]   cmd_reg;
    reg [WDATA_WIDTH-1:0]   wdata_reg;
    reg                     cmd_valid_reg;
    reg                     wdata_valid_reg;
    
    //=========================================================================
    // WR command detection in registered DDR4 command
    //=========================================================================
    wire has_wr_cmd;
    assign has_wr_cmd = (cmd_reg[2:0]   == CMD_WR) ||
                        (cmd_reg[34:32] == CMD_WR) ||
                        (cmd_reg[66:64] == CMD_WR) ||
                        (cmd_reg[98:96] == CMD_WR);
    
    //=========================================================================
    // Output control logic
    //=========================================================================
    wire wdata_consumed;
    
    // Output is valid when:
    // - DDR4 command is valid AND
    // - Either no WR command (don't need wdata) OR wdata is available
    assign output_valid = cmd_valid_reg && (!has_wr_cmd || wdata_valid_reg);
    
    // wdata is consumed when output handshake occurs AND DDR4 command has WR command
    assign wdata_consumed = output_valid && has_wr_cmd;
    
    //=========================================================================
    // Ready signals - Independent acceptance
    //=========================================================================
    
    // Accept new DDR4 command when:
    // - No DDR4 command stored, OR
    // - Output occurs in this cycle (current DDR4 command being sent out)
    assign S_AXIS_CMD_TREADY = !cmd_valid_reg || output_valid;
    
    // Accept new wdata when:
    // - No wdata stored, OR
    // - wdata is being consumed (WR command being sent out)
    assign S_AXIS_WDATA_TREADY = !wdata_valid_reg || wdata_consumed;
    
    //=========================================================================
    // Output signals
    //=========================================================================
    // Output DDR4 command and write data
    // If no WR command, write data portion is zero
    assign output_data = {(has_wr_cmd ? wdata_reg : {WDATA_WIDTH{1'b0}}), cmd_reg};
    
    //=========================================================================
    // Register capture logic
    //=========================================================================
    
    always @(posedge clk) begin
        if (rst) begin
            cmd_reg <= {CMD_WIDTH{1'b0}};
            wdata_reg <= {WDATA_WIDTH{1'b0}};
            cmd_valid_reg <= 1'b0;
            wdata_valid_reg <= 1'b0;
        end else begin
            //=================================================================
            // DDR4 command register management
            //=================================================================
            if (S_AXIS_CMD_TVALID && S_AXIS_CMD_TREADY) begin
                // Capture new DDR4 command
                cmd_reg <= S_AXIS_CMD_TDATA;
                cmd_valid_reg <= 1'b1;
            end else if (output_valid) begin
                // DDR4 command sent out, clear valid
                cmd_valid_reg <= 1'b0;
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
    reg [31:0] cmd_count;
    reg [31:0] wdata_count;
    reg [31:0] output_count;
    reg [31:0] wr_cmd_count;
    reg [31:0] wait_cycles;  // Cycles waiting for wdata
    
    always @(posedge clk) begin
        if (rst) begin
            cmd_count <= 0;
            wdata_count <= 0;
            output_count <= 0;
            wr_cmd_count <= 0;
            wait_cycles <= 0;
        end else begin
            if (S_AXIS_CMD_TVALID && S_AXIS_CMD_TREADY)
                cmd_count <= cmd_count + 1;
            if (S_AXIS_WDATA_TVALID && S_AXIS_WDATA_TREADY)
                wdata_count <= wdata_count + 1;
            if (output_valid)
                output_count <= output_count + 1;
            if (output_valid && has_wr_cmd)
                wr_cmd_count <= wr_cmd_count + 1;
            if (cmd_valid_reg && has_wr_cmd && !wdata_valid_reg)
                wait_cycles <= wait_cycles + 1;
        end
    end
    `endif

endmodule
