`include "parameters.vh"
`include "project.vh"

module sddt_core #(
  parameter DQ_WIDTH = `DQ_WIDTH,
  parameter CKE_WIDTH = `CKE_WIDTH,
  parameter CS_WIDTH = `CS_WIDTH,
  parameter ODT_WIDTH = `ODT_WIDTH,
  parameter ROW_ADDR_WIDTH = `ROW_ADDR_WIDTH,
  parameter CK_WIDTH = `CK_WIDTH,
  parameter BG_WIDTH = `BG_WIDTH,
  parameter BANK_WIDTH = `BANK_WIDTH,
  parameter COL_WIDTH = `COL_WIDTH,
  parameter ROW_WIDTH = `ROW_WIDTH
) (
  // =========================================================================
  // System Signals
  // =========================================================================
  input  wire                      c0_sys_clk_p,
  input  wire                      c0_sys_clk_n,
  input  wire                      sys_rst,
  input  wire                      axi_aclk,
  input  wire                      axi_aresetn,
  
  // =========================================================================
  // DDR4 SDRAM interface
  // =========================================================================
  output wire                      c0_ddr4_act_n,
  output wire [ROW_ADDR_WIDTH-1:0] c0_ddr4_adr,
  output wire [1:0]                c0_ddr4_ba,
  output wire [1:0]                c0_ddr4_bg,
  output wire [CKE_WIDTH-1:0]      c0_ddr4_cke,
  output wire [ODT_WIDTH-1:0]      c0_ddr4_odt,
  output wire [CS_WIDTH-1:0]       c0_ddr4_cs_n,
  output wire [CK_WIDTH-1:0]       c0_ddr4_ck_t,
  output wire [CK_WIDTH-1:0]       c0_ddr4_ck_c,
  output wire                      c0_ddr4_reset_n,
  inout  wire [7:0]                c0_ddr4_dqs_c,
  inout  wire [7:0]                c0_ddr4_dqs_t,
  inout  wire [63:0]               c0_ddr4_dq,
  inout  wire [7:0]                c0_ddr4_dm_dbi_n,
  output wire                      c0_ddr4_parity,
  
  // =========================================================================
  // AXI Stream Command Interface
  // =========================================================================
  input  wire [127:0]              S_AXIS_CMD_tdata,
  input  wire                      S_AXIS_CMD_tvalid,
  output wire                      S_AXIS_CMD_tready,
  
  // =========================================================================
  // AXI Stream Write Data Interface
  // =========================================================================
  input  wire [511:0]              S_AXIS_WDATA_tdata,
  input  wire                      S_AXIS_WDATA_tvalid,
  output wire                      S_AXIS_WDATA_tready,
  
  // =========================================================================
  // AXI Stream Read Data Interface
  // =========================================================================
  output wire [511:0]              M_AXIS_RDATA_tdata,
  output wire [63:0]               M_AXIS_RDATA_tkeep,
  output wire                      M_AXIS_RDATA_tlast,
  output wire                      M_AXIS_RDATA_tvalid,
  input  wire                      M_AXIS_RDATA_tready,
  
  // =========================================================================
  // Debug Signals
  // =========================================================================
  input  wire [31:0]               control,
  output reg  [31:0]               state
);

  // =========================================================================
  // Clock and Reset Signals
  // =========================================================================
  wire         c0_ddr4_clk;
  wire         c0_ddr4_rst;
  wire         c0_init_calib_complete;
  // CDC for control signal
  reg  [31:0]  control_r;
  reg  [31:0]  _control_sync1;
  reg  [31:0]  _control_sync2;
  always @(posedge c0_ddr4_clk) begin
    if (c0_ddr4_rst || ~c0_init_calib_complete) begin
      _control_sync1 <= 32'b0;
      _control_sync2 <= 32'b0;
      control_r <= 32'b0;
    end else begin
      _control_sync1 <= control;
      _control_sync2 <= _control_sync1;
      control_r <= _control_sync2;
    end
  end
  // CDC for state signal
  wire [31:0] state_i;
  reg [31:0] _state_sync1;
  reg [31:0] _state_sync2;
  always @(posedge axi_aclk) begin
    if (~axi_aresetn) begin
      _state_sync1 <= 32'b0;
      _state_sync2 <= 32'b0;
      state <= 32'b0;
    end else begin
      _state_sync1 <= state_i;
      _state_sync2 <= _state_sync1;
      state <= _state_sync2;
    end
  end

  // =========================================================================
  // Internal Wires
  // =========================================================================
  // Command FIFO <-> Scheduler
  wire         axis_cmd2scheduler_tready;
  wire [127:0] axis_cmd2scheduler_tdata;
  wire         axis_cmd2scheduler_tvalid;
  wire         axis_cmd2scheduler_tlast;
  // Write Data FIFO <-> Scheduler
  wire         axis_wdata2scheduler_tready;
  wire [511:0] axis_wdata2scheduler_tdata;
  wire         axis_wdata2scheduler_tvalid;
  // Scheduler <-> Decoder
  wire [639:0] scheduler2decoder_data;
  wire         scheduler2decoder_valid;
  // Decoder <-> DDR4 Interface
  wire [3:0]              ddr_write;
  wire [3:0]              ddr_read;
  wire [3:0]              ddr_pre;
  wire [3:0]              ddr_act;
  wire [3:0]              ddr_ref;
  wire [3:0]              ddr_zq;
  wire [3:0]              ddr_nop;
  wire [3:0]              ddr_ap;
  wire [3:0]              ddr_half_bl;
  wire [3:0]              ddr_pall;
  wire [4*BG_WIDTH-1:0]   ddr_bg;
  wire [4*BANK_WIDTH-1:0] ddr_bank;
  wire [4*COL_WIDTH-1:0]  ddr_col;
  wire [4*ROW_WIDTH-1:0]  ddr_row;
  wire [511:0]            ddr_wdata;
  wire [511:0]            rdData;
  wire [0:0]              rdDataEn;

  // =========================================================================
  // Command FIFO (Async)
  // =========================================================================
  localparam CMD_FIFO_DEPTH = 16;
  localparam CMD_FIFO_WIDTH = 128;
  localparam CMD_FIFO_COUNT_WIDTH = $clog2(CMD_FIFO_DEPTH)+1;
  wire [CMD_FIFO_COUNT_WIDTH-1:0] cmd_fifo_wr_data_count;
  xpm_fifo_axis #(
    .CLOCKING_MODE("independent_clock"),
    .FIFO_DEPTH(CMD_FIFO_DEPTH),
    .PACKET_FIFO("true"),
    .TDATA_WIDTH(CMD_FIFO_WIDTH),
    .USE_ADV_FEATURES("1004"), // Valid and enable wr_data_count
    .WR_DATA_COUNT_WIDTH(CMD_FIFO_COUNT_WIDTH)
  )
  cmd_fifo (
    // Master interface
    .m_aclk(c0_ddr4_clk),
    .m_axis_tready(axis_cmd2scheduler_tready),
    .m_axis_tdata(axis_cmd2scheduler_tdata),
    .m_axis_tvalid(axis_cmd2scheduler_tvalid),
    .m_axis_tlast(axis_cmd2scheduler_tlast),
    // Slave interface
    .s_aclk(axi_aclk),
    .s_aresetn(axi_aresetn),
    .s_axis_tready(S_AXIS_CMD_tready),
    .s_axis_tdata(S_AXIS_CMD_tdata),
    .s_axis_tvalid(S_AXIS_CMD_tvalid),
    .s_axis_tlast(~S_AXIS_CMD_tdata[127]),
    // Status signals
    .wr_data_count_axis(cmd_fifo_wr_data_count)
  );

  // =========================================================================
  // Write Data FIFO (Async)
  // =========================================================================
  localparam WDATA_FIFO_DEPTH = 16;
  localparam WDATA_FIFO_WIDTH = 512;
  localparam WDATA_FIFO_COUNT_WIDTH = $clog2(WDATA_FIFO_DEPTH)+1;
  wire [WDATA_FIFO_COUNT_WIDTH-1:0] wdata_fifo_wr_data_count;
  xpm_fifo_axis #(
    .CLOCKING_MODE("independent_clock"),
    .FIFO_DEPTH(WDATA_FIFO_DEPTH),
    .TDATA_WIDTH(WDATA_FIFO_WIDTH),
    .USE_ADV_FEATURES("1004"), // Valid and enable wr_data_count
    .WR_DATA_COUNT_WIDTH(WDATA_FIFO_COUNT_WIDTH)
  )
  wdata_fifo (
    // Master interface
    .m_aclk(c0_ddr4_clk),
    .m_axis_tready(axis_wdata2scheduler_tready),
    .m_axis_tdata(axis_wdata2scheduler_tdata),
    .m_axis_tvalid(axis_wdata2scheduler_tvalid),
    // Slave interface
    .s_aclk(axi_aclk),
    .s_aresetn(axi_aresetn),
    .s_axis_tready(S_AXIS_WDATA_tready),
    .s_axis_tdata(S_AXIS_WDATA_tdata),
    .s_axis_tvalid(S_AXIS_WDATA_tvalid),
    // Status signals
    .wr_data_count_axis(wdata_fifo_wr_data_count)
  );

  // =========================================================================
  // Scheduler
  // =========================================================================
  scheduler #(
    .INSTR_WIDTH(CMD_FIFO_WIDTH), // 128
    .WDATA_WIDTH(WDATA_FIFO_WIDTH), // 512
    .MERGED_WIDTH(CMD_FIFO_WIDTH + WDATA_FIFO_WIDTH) // 640
  )
  scheduler_i (
    .clk(c0_ddr4_clk),
    .rst(c0_ddr4_rst || ~c0_init_calib_complete),
    // Command
    .S_AXIS_INSTR_TDATA(axis_cmd2scheduler_tdata),
    .S_AXIS_INSTR_TVALID(axis_cmd2scheduler_tvalid),
    .S_AXIS_INSTR_TREADY(axis_cmd2scheduler_tready),
    .S_AXIS_INSTR_TLAST(axis_cmd2scheduler_tlast),
    // Write data
    .S_AXIS_WDATA_TDATA(axis_wdata2scheduler_tdata),
    .S_AXIS_WDATA_TVALID(axis_wdata2scheduler_tvalid),
    .S_AXIS_WDATA_TREADY(axis_wdata2scheduler_tready),
    // Timing -> DDR4 Interface
    .merged_output_data(scheduler2decoder_data),
    .merged_output_valid(scheduler2decoder_valid)
  );

  // =========================================================================
  // Decoder
  // =========================================================================
  decoder #(
    .BG_WIDTH(BG_WIDTH),
    .BANK_WIDTH(BANK_WIDTH),
    .COL_WIDTH(COL_WIDTH),
    .ROW_WIDTH(ROW_WIDTH),
    .INSTR_WIDTH(CMD_FIFO_WIDTH), // 128
    .WDATA_WIDTH(WDATA_FIFO_WIDTH), // 512
    .MERGED_WIDTH(CMD_FIFO_WIDTH + WDATA_FIFO_WIDTH) // 640
  )
  decoder_i (
    .clk(c0_ddr4_clk),
    .rst(c0_ddr4_rst || ~c0_init_calib_complete),
    // Scheduler -> Decoder
    .input_data(scheduler2decoder_data),
    .input_valid(scheduler2decoder_valid),
    // Decoder -> DDR4
    .ddr_write(ddr_write),
    .ddr_read(ddr_read),
    .ddr_pre(ddr_pre),
    .ddr_act(ddr_act),
    .ddr_ref(ddr_ref),
    .ddr_zq(ddr_zq),
    .ddr_nop(ddr_nop),
    .ddr_ap(ddr_ap),
    .ddr_half_bl(ddr_half_bl),
    .ddr_pall(ddr_pall),
    .ddr_bg(ddr_bg),
    .ddr_bank(ddr_bank),
    .ddr_col(ddr_col),
    .ddr_row(ddr_row),
    .ddr_wdata(ddr_wdata)
  );

  // =========================================================================
  // DDR Interface Instance
  // =========================================================================
  wire         dbg_clk;
  wire [511:0] dbg_bus;
  `ifdef ENABLE_DLL_TOGGLER
  wire         ddr4_ui_clk;
  wire         c0_ddr4_dll_off_clk;
  `endif
  wire [0:0]   mcRdCAS;
  wire [0:0]   mcWrCAS;
  ddr4_interface #(
    .DQ_WIDTH       (DQ_WIDTH),
    .CKE_WIDTH      (CKE_WIDTH),
    .CS_WIDTH       (CS_WIDTH),
    .ODT_WIDTH      (ODT_WIDTH),
    .ROW_ADDR_WIDTH (ROW_ADDR_WIDTH),
    .CK_WIDTH       (CK_WIDTH),
    .BG_WIDTH       (BG_WIDTH),
    .BANK_WIDTH     (BANK_WIDTH),
    .COL_WIDTH      (COL_WIDTH),
    .ROW_WIDTH      (ROW_WIDTH)
  ) ddr4_interface_i (
    // System signals
    .c0_sys_clk_p           (c0_sys_clk_p),
    .c0_sys_clk_n           (c0_sys_clk_n),
    .sys_rst                (sys_rst),
    // Clock and reset outputs
    .c0_ddr4_clk            (c0_ddr4_clk),
    .c0_ddr4_rst            (c0_ddr4_rst),
    .c0_init_calib_complete (c0_init_calib_complete),
    .dbg_clk                (dbg_clk),
    .dbg_bus                (dbg_bus),
    // DDR4 SDRAM interface
    .c0_ddr4_act_n          (c0_ddr4_act_n),
    .c0_ddr4_adr            (c0_ddr4_adr),
    .c0_ddr4_ba             (c0_ddr4_ba),
    .c0_ddr4_bg             (c0_ddr4_bg),
    .c0_ddr4_cke            (c0_ddr4_cke),
    .c0_ddr4_odt            (c0_ddr4_odt),
    .c0_ddr4_cs_n           (c0_ddr4_cs_n),
    .c0_ddr4_ck_t           (c0_ddr4_ck_t),
    .c0_ddr4_ck_c           (c0_ddr4_ck_c),
    .c0_ddr4_reset_n        (c0_ddr4_reset_n),
    .c0_ddr4_parity         (c0_ddr4_parity),
    .c0_ddr4_dq             (c0_ddr4_dq),
    .c0_ddr4_dqs_c          (c0_ddr4_dqs_c),
    .c0_ddr4_dqs_t          (c0_ddr4_dqs_t),
    .c0_ddr4_dm_dbi_n       (c0_ddr4_dm_dbi_n),
    // DDR command interface (from cmd_scheduler)
    .ddr_write              (ddr_write),
    .ddr_read               (ddr_read),
    .ddr_pre                (ddr_pre),
    .ddr_act                (ddr_act),
    .ddr_ref                (ddr_ref),
    .ddr_zq                 (ddr_zq),
    .ddr_nop                (ddr_nop),
    .ddr_ap                 (ddr_ap),
    .ddr_pall               (ddr_pall),
    .ddr_half_bl            (ddr_half_bl),
    .ddr_bg                 (ddr_bg),
    .ddr_bank               (ddr_bank),
    .ddr_col                (ddr_col),
    .ddr_row                (ddr_row),
    .ddr_wdata              (ddr_wdata),
    // Read data interface (to cmd_scheduler)
    .rdData                 (rdData),
    .rdDataEn               (rdDataEn),
    // For DLL toggler clock mux
    `ifdef ENABLE_DLL_TOGGLER
    .ddr4_ui_clk            (ddr4_ui_clk),
    .c0_ddr4_dll_off_clk    (c0_ddr4_dll_off_clk),
    `endif
    // CAS signals
    .mcRdCAS                (mcRdCAS),
    .mcWrCAS                (mcWrCAS)
  );

  // =========================================================================
  // Read Data FIFO (Async)
  // =========================================================================
  localparam RDATA_FIFO_DEPTH = 16;
  localparam RDATA_FIFO_WIDTH = 512;
  localparam RDATA_FIFO_COUNT_WIDTH = $clog2(RDATA_FIFO_DEPTH)+1;
  wire [RDATA_FIFO_COUNT_WIDTH-1:0] rdata_fifo_wr_data_count;

  // // -------------------------------------------------------------------------
  // // TLAST Batching Logic
  // // -------------------------------------------------------------------------
  // reg [15:0] outstanding_reads;
  // // Because there is a possibility that 4 read commands are issued in one cycle, we sum them up.
  // wire [2:0] current_reads = ddr_read[0] + ddr_read[1] + ddr_read[2] + ddr_read[3];
  // always @(posedge c0_ddr4_clk) begin
  //   if (c0_ddr4_rst || ~c0_init_calib_complete) begin
  //     outstanding_reads <= 16'd0;
  //   end else begin
  //     // Add the issued read count and subtract the returned data count.
  //     outstanding_reads <= outstanding_reads + current_reads - rdDataEn[0];
  //   end
  // end
  // // Set TLAST when the returned data is the last data in all the issued reads.
  // wire rdata_s_axis_tlast = rdDataEn[0] && (outstanding_reads + current_reads == 16'd1);
  // // -------------------------------------------------------------------------

  xpm_fifo_axis #(
    .CLOCKING_MODE("independent_clock"),
    .FIFO_DEPTH(RDATA_FIFO_DEPTH),
    .TDATA_WIDTH(RDATA_FIFO_WIDTH),
    .USE_ADV_FEATURES("1004"), // Valid and enable wr_data_count
    .WR_DATA_COUNT_WIDTH(RDATA_FIFO_COUNT_WIDTH)
  )
  rdata_fifo (
    // Master interface
    .m_aclk(axi_aclk),
    .m_axis_tready(M_AXIS_RDATA_tready),
    .m_axis_tdata(M_AXIS_RDATA_tdata),
    .m_axis_tkeep(M_AXIS_RDATA_tkeep),
    .m_axis_tlast(M_AXIS_RDATA_tlast),
    .m_axis_tvalid(M_AXIS_RDATA_tvalid),
    // Slave interface
    .s_aclk(c0_ddr4_clk),
    .s_aresetn(~c0_ddr4_rst & c0_init_calib_complete),
    .s_axis_tready(),
    .s_axis_tdata(rdData),
    .s_axis_tlast(1'b1),
    .s_axis_tkeep({64{1'b1}}),
    .s_axis_tvalid(rdDataEn[0]),
    // Status signals
    .wr_data_count_axis(rdata_fifo_wr_data_count)
  );

  // State output
  assign state_i = {
    8'b0,
    { {(8-CMD_FIFO_COUNT_WIDTH){1'b0}}, cmd_fifo_wr_data_count },
    { {(8-WDATA_FIFO_COUNT_WIDTH){1'b0}}, wdata_fifo_wr_data_count },
    { {(8-RDATA_FIFO_COUNT_WIDTH){1'b0}}, rdata_fifo_wr_data_count }
  };

endmodule
