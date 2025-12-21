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
  
  // // =========================================================================
  // // AXI Stream C2H (Card to Host - Read Data Output to DMA S2MM)
  // // =========================================================================
  // output wire [511:0]                 M_AXIS_C2H_tdata,
  // output wire                         M_AXIS_C2H_tvalid,
  // output wire [63:0]                  M_AXIS_C2H_tkeep,
  // output wire                         M_AXIS_C2H_tlast,
  // input  wire                         M_AXIS_C2H_tready,
  
  // // =========================================================================
  // // AXI Stream H2C Interface 0 (Host to Card - Write Data Input from DMA MM2S_0)
  // // =========================================================================
  // input  wire [511:0]                 S_AXIS_H2C_0_tdata,
  // input  wire                         S_AXIS_H2C_0_tvalid,
  // output wire                         S_AXIS_H2C_0_tready,
  
  // =========================================================================
  // AXI Stream Command Interface
  // =========================================================================
  input  wire [127:0]              S_AXIS_CMD_tdata,
  input  wire                      S_AXIS_CMD_tvalid,
  output wire                      S_AXIS_CMD_tready,
  
  // =========================================================================
  // Debug Signals
  // =========================================================================
  input  wire [31:0]               control,
  output reg  [31:0]               state
);

  // =========================================================================
  // Internal Signals
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
  wire         m_axis_cmd_tready;
  wire [127:0] m_axis_tmp_tdata;
  wire         m_axis_tmp_tvalid;

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
    .TDATA_WIDTH(CMD_FIFO_WIDTH),
    .USE_ADV_FEATURES("1004"), // Valid and enable wr_data_count
    .WR_DATA_COUNT_WIDTH(CMD_FIFO_COUNT_WIDTH)
  )
  cmd_fifo (
    // Master interface
    .m_aclk(c0_ddr4_clk),
    .m_axis_tready(m_axis_cmd_tready),
    .m_axis_tdata(m_axis_cmd_tdata),
    .m_axis_tvalid(m_axis_cmd_tvalid),
    // Slave interface
    .s_aclk(axi_aclk),
    .s_aresetn(axi_aresetn & ~c0_ddr4_rst & c0_init_calib_complete),
    .s_axis_tready(S_AXIS_CMD_tready),
    .s_axis_tdata(S_AXIS_CMD_tdata),
    .s_axis_tvalid(S_AXIS_CMD_tvalid),
    // Status signals
    .wr_data_count_axis(cmd_fifo_wr_data_count)
  );

  // =========================================================================
  // Tmp FIFO (Sync)
  // =========================================================================
  localparam TMP_FIFO_DEPTH = 16;
  localparam TMP_FIFO_WIDTH = 128;
  localparam TMP_FIFO_COUNT_WIDTH = $clog2(TMP_FIFO_DEPTH)+1;
  wire [TMP_FIFO_COUNT_WIDTH-1:0] tmp_fifo_wr_data_count;
  xpm_fifo_axis #(
    .CLOCKING_MODE("common_clock"),
    .FIFO_DEPTH(TMP_FIFO_DEPTH),
    .TDATA_WIDTH(TMP_FIFO_WIDTH),
    .USE_ADV_FEATURES("1004"), // Valid and enable wr_data_count
    .WR_DATA_COUNT_WIDTH(TMP_FIFO_COUNT_WIDTH)
  )
  tmp_fifo (
    // Master interface
    .m_axis_tready(1'b0),
    .m_axis_tdata(),
    .m_axis_tvalid(),
    // Slave interface
    .s_aclk(c0_ddr4_clk),
    .s_aresetn(~c0_ddr4_rst & c0_init_calib_complete),
    .s_axis_tready(m_axis_cmd_tready),
    .s_axis_tdata(m_axis_cmd_tdata),
    .s_axis_tvalid(m_axis_cmd_tvalid),
    // Status signals
    .wr_data_count_axis(tmp_fifo_wr_data_count)
  );

  // Combine command and temporary FIFO write data counts
  assign state_i = {{(16-TMP_FIFO_COUNT_WIDTH){1'b0}}, tmp_fifo_wr_data_count, {(16-CMD_FIFO_COUNT_WIDTH){1'b0}}, cmd_fifo_wr_data_count};

  // =========================================================================
  // DDR Interface Instance
  // =========================================================================
  wire         dbg_clk;
  wire [511:0] dbg_bus;
  wire [511:0] rdData;
  wire [0:0]   rdDataEn;
  `ifdef ENABLE_DLL_TOGGLER
  wire         ddr4_ui_clk;
  wire         c0_ddr4_dll_off_clk;
  `endif
  wire         mcRdCAS;
  wire         mcWrCAS;
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
    .ddr_write              (4'b0000),
    .ddr_read               (4'b0000),
    .ddr_pre                (4'b0000),
    .ddr_act                (4'b0000),
    .ddr_ref                (4'b0000),
    .ddr_zq                 (4'b0000),
    .ddr_nop                (4'b1111),
    .ddr_ap                 (4'b0000),
    .ddr_pall               (4'b0000),
    .ddr_half_bl            (4'b0000),
    .ddr_bg                 (8'b0),
    .ddr_bank               (8'b0),
    .ddr_col                (40'b0),
    .ddr_row                (68'b0),
    .ddr_wdata              (512'b0),
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


  // // =========================================================================
  // // Internal wires: DDR Interface <-> CMD Scheduler
  // // =========================================================================
  
  // wire                       c0_ddr4_clk_i;
  // wire                       c0_ddr4_rst_i;
  // wire                       c0_init_calib_complete_i;
  // wire                       dbg_clk_internal;
  // wire [511:0]               dbg_bus_internal;

  // assign c0_ddr4_clk              = c0_ddr4_clk_i;
  // assign c0_ddr4_rst              = c0_ddr4_rst_i;
  // assign c0_init_calib_complete   = c0_init_calib_complete_i;
  // assign dbg_clk                  = dbg_clk_internal;
  // assign dbg_bus                  = dbg_bus_internal;

  // // DDR command interface
  // wire [3:0]                ddr_write;
  // wire [3:0]                ddr_read;
  // wire [3:0]                ddr_pre;
  // wire [3:0]                ddr_act;
  // wire [3:0]                ddr_ref;
  // wire [3:0]                ddr_zq;
  // wire [3:0]                ddr_nop;
  // wire [3:0]                ddr_ap;
  // wire [3:0]                ddr_pall;
  // wire [3:0]                ddr_half_bl;
  // wire [4*BG_WIDTH-1:0]     ddr_bg;
  // wire [4*BANK_WIDTH-1:0]   ddr_bank;
  // wire [4*COL_WIDTH-1:0]    ddr_col;
  // wire [4*ROW_WIDTH-1:0]    ddr_row;
  // wire [511:0]              ddr_wdata;
  
  // // Read data interface
  // wire [511:0]              rdData;
  // wire [0:0]                rdDataEn;
  
  // // CAS signals (exposed for potential external use)
  // wire [0:0]                mcRdCAS;
  // wire [0:0]                mcWrCAS;

  // // =========================================================================
  // // SDDT Core Instance (axi4_read_data, axi4_write_data, axi4_instr)
  // // =========================================================================
  // cmd_scheduler cmd_scheduler_i (
  //   // Clock and Reset
  //   .clk                  (c0_ddr4_clk_i),
  //   .rst                  (c0_ddr4_rst_i),
    
  //   // DDR Read Data Interface (from DDR Interface)
  //   .ddr_rd_data              (rdData),
  //   .ddr_rd_valid             (rdDataEn),
    
  //   // DDR Write Data Interface (to DDR Interface)
  //   .ddr_wdata            (ddr_wdata),
    
  //   // DDR Command Interface (to DDR Interface)
  //   .ddr_write            (ddr_write),
  //   .ddr_read             (ddr_read),
  //   .ddr_pre              (ddr_pre),
  //   .ddr_act              (ddr_act),
  //   .ddr_ref              (ddr_ref),
  //   .ddr_zq               (ddr_zq),
  //   .ddr_nop              (ddr_nop),
  //   .ddr_ap               (ddr_ap),
  //   .ddr_half_bl          (ddr_half_bl),
  //   .ddr_pall             (ddr_pall),
  //   .ddr_bg               (ddr_bg),
  //   .ddr_bank             (ddr_bank),
  //   .ddr_col              (ddr_col),
  //   .ddr_row              (ddr_row),
    
  //   // AXI Stream C2H (to DMA S2MM)
  //   .M_AXIS_C2H_tdata     (M_AXIS_C2H_tdata),
  //   .M_AXIS_C2H_tvalid    (M_AXIS_C2H_tvalid),
  //   .M_AXIS_C2H_tkeep     (M_AXIS_C2H_tkeep),
  //   .M_AXIS_C2H_tlast     (M_AXIS_C2H_tlast),
  //   .M_AXIS_C2H_tready    (M_AXIS_C2H_tready),
    
  //   // AXI Stream H2C Interface 0 (from DMA MM2S_0 - Write Data)
  //   .S_AXIS_H2C_0_tdata   (S_AXIS_H2C_0_tdata),
  //   .S_AXIS_H2C_0_tvalid  (S_AXIS_H2C_0_tvalid),
  //   .S_AXIS_H2C_0_tready  (S_AXIS_H2C_0_tready),
    
  //   // AXI Stream Command Interface
  //   .S_AXIS_CMD_tdata   (S_AXIS_CMD_tdata),
  //   .S_AXIS_CMD_tvalid  (S_AXIS_CMD_tvalid),
  //   .S_AXIS_CMD_tready  (S_AXIS_CMD_tready),
    
  //   // Debug ports
  //   .err                  (err),
  //   .latest_buf           (latest_buf),
  //   .wdata_count          (wdata_count),
  //   .rdata_count          (rdata_count)
  // );

endmodule
