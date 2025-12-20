`include "parameters.vh"
`include "project.vh"

module sddt_core (
  // =========================================================================
  // System Signals
  // =========================================================================
  input  wire         axi_aclk,
  input  wire         axi_aresetn,
  // input  wire         sys_rst,
  // input  wire         c0_sys_clk_p,
  // input  wire         c0_sys_clk_n,
  // input  wire         user_rst,
  
  // // =========================================================================
  // // Clock and reset outputs
  // // =========================================================================
  // output wire         c0_ddr4_clk,
  // output wire         c0_ddr4_rst,
  // output wire         c0_init_calib_complete,
  // output wire         dbg_clk,
  // output wire [511:0] dbg_bus,
  
  // // =========================================================================
  // // DDR4 SDRAM interface
  // // =========================================================================
  // output wire                         c0_ddr4_act_n,
  // output wire [ROW_ADDR_WIDTH-1:0]    c0_ddr4_adr,
  // output wire [1:0]                   c0_ddr4_ba,
  // output wire [1:0]                   c0_ddr4_bg,
  // output wire [CKE_WIDTH-1:0]         c0_ddr4_cke,
  // output wire [ODT_WIDTH-1:0]         c0_ddr4_odt,
  // output wire [CS_WIDTH-1:0]          c0_ddr4_cs_n,
  // output wire [CK_WIDTH-1:0]          c0_ddr4_ck_t,
  // output wire [CK_WIDTH-1:0]          c0_ddr4_ck_c,
  // output wire                         c0_ddr4_reset_n,
  
  // `ifdef RDIMM_x4
  // inout  wire [17:0]  c0_ddr4_dqs_c,
  // inout  wire [17:0]  c0_ddr4_dqs_t,
  // inout  wire [71:0]  c0_ddr4_dq,
  // output wire         c0_ddr4_parity,
  // `elsif UDIMM_x8
  // inout  wire [7:0]   c0_ddr4_dqs_c,
  // inout  wire [7:0]   c0_ddr4_dqs_t,
  // inout  wire [63:0]  c0_ddr4_dq,
  // inout  wire [7:0]   c0_ddr4_dm_dbi_n,
  // output wire         c0_ddr4_parity,
  // `elsif RDIMM_x8
  // inout  wire [8:0]   c0_ddr4_dqs_c,
  // inout  wire [8:0]   c0_ddr4_dqs_t,
  // inout  wire [71:0]  c0_ddr4_dq,
  // inout  wire [8:0]   c0_ddr4_dm_dbi_n,
  // output wire         c0_ddr4_parity,
  // `endif
  
  // // =========================================================================
  // // Periodic maintenance
  // // =========================================================================
  // input  wire                         per_rd_init,
  
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
  input  wire [127:0] S_AXIS_CMD_tdata,
  input  wire         S_AXIS_CMD_tvalid,
  output wire         S_AXIS_CMD_tready,
  
  // =========================================================================
  // Debug Signals
  // =========================================================================
  output wire [31:0]  gpio_out
);

  // =========================================================================
  // Internal Wires
  // =========================================================================
  wire [CMD_FIFO_COUNT_WIDTH-1:0] cmd_fifo_wr_data_count;
  assign gpio_out = {16'd13, {(16-CMD_FIFO_COUNT_WIDTH){1'b0}}, cmd_fifo_wr_data_count};

  // =========================================================================
  // Command FIFO
  // =========================================================================
  localparam CMD_FIFO_DEPTH = 16;
  localparam CMD_FIFO_WIDTH = 128;
  localparam CMD_FIFO_COUNT_WIDTH = $clog2(CMD_FIFO_DEPTH)+1;
  xpm_fifo_axis #(
  .CLOCKING_MODE("independent_clock"),
  .FIFO_DEPTH(CMD_FIFO_DEPTH),
  .TDATA_WIDTH(CMD_FIFO_WIDTH),
  .USE_ADV_FEATURES("1004"), // Valid and enable wr_data_count
  .WR_DATA_COUNT_WIDTH(CMD_FIFO_COUNT_WIDTH)
  )
  cmd_fifo (
  // Master Interface
  .m_aclk(axi_aclk),
  .m_axis_tready(1'b0),
  .m_axis_tdata(),
  .m_axis_tvalid(),
  // Slave Interface
  .s_aclk(axi_aclk),
  .s_aresetn(axi_aresetn),
  .s_axis_tready(S_AXIS_CMD_tready),
  .s_axis_tdata(S_AXIS_CMD_tdata),
  .s_axis_tvalid(S_AXIS_CMD_tvalid),
  // Status signals
  .wr_data_count_axis(cmd_fifo_wr_data_count)
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
  // // DDR Interface Instance
  // // =========================================================================
  // ddr4_interface #(
  //   .DQ_WIDTH       (DQ_WIDTH),
  //   .CKE_WIDTH      (CKE_WIDTH),
  //   .CS_WIDTH       (CS_WIDTH),
  //   .ODT_WIDTH      (ODT_WIDTH),
  //   .ROW_ADDR_WIDTH (ROW_ADDR_WIDTH),
  //   .CK_WIDTH       (CK_WIDTH),
  //   .BG_WIDTH       (BG_WIDTH),
  //   .BANK_WIDTH     (BANK_WIDTH),
  //   .COL_WIDTH      (COL_WIDTH),
  //   .ROW_WIDTH      (ROW_WIDTH)
  // ) ddr4_interface_i (
  //   // System signals
  //   .sys_rst              (sys_rst),
  //   .c0_sys_clk_p         (c0_sys_clk_p),
  //   .c0_sys_clk_n         (c0_sys_clk_n),
  //   .user_rst             (user_rst),
    
  //   // Clock and reset outputs
  //   .c0_ddr4_clk          (c0_ddr4_clk_i),
  //   .c0_ddr4_rst          (c0_ddr4_rst_i),
  //   .c0_init_calib_complete(c0_init_calib_complete_i),
  //   .dbg_clk              (dbg_clk_internal),
  //   .dbg_bus              (dbg_bus_internal),
    
  //   // DDR4 SDRAM interface
  //   .c0_ddr4_act_n        (c0_ddr4_act_n),
  //   .c0_ddr4_adr          (c0_ddr4_adr),
  //   .c0_ddr4_ba           (c0_ddr4_ba),
  //   .c0_ddr4_bg           (c0_ddr4_bg),
  //   .c0_ddr4_cke          (c0_ddr4_cke),
  //   .c0_ddr4_odt          (c0_ddr4_odt),
  //   .c0_ddr4_cs_n         (c0_ddr4_cs_n),
  //   .c0_ddr4_ck_t         (c0_ddr4_ck_t),
  //   .c0_ddr4_ck_c         (c0_ddr4_ck_c),
  //   .c0_ddr4_reset_n      (c0_ddr4_reset_n),
  //   `ifdef RDIMM_x4
  //   .c0_ddr4_parity       (c0_ddr4_parity),
  //   .c0_ddr4_dq           (c0_ddr4_dq),
  //   .c0_ddr4_dqs_c        (c0_ddr4_dqs_c),
  //   .c0_ddr4_dqs_t        (c0_ddr4_dqs_t),
  //   `elsif UDIMM_x8
  //   .c0_ddr4_parity       (c0_ddr4_parity),
  //   .c0_ddr4_dq           (c0_ddr4_dq),
  //   .c0_ddr4_dqs_c        (c0_ddr4_dqs_c),
  //   .c0_ddr4_dqs_t        (c0_ddr4_dqs_t),
  //   .c0_ddr4_dm_dbi_n     (c0_ddr4_dm_dbi_n),
  //   `elsif RDIMM_x8
  //   .c0_ddr4_parity       (c0_ddr4_parity),
  //   .c0_ddr4_dq           (c0_ddr4_dq),
  //   .c0_ddr4_dqs_c        (c0_ddr4_dqs_c),
  //   .c0_ddr4_dqs_t        (c0_ddr4_dqs_t),
  //   .c0_ddr4_dm_dbi_n     (c0_ddr4_dm_dbi_n),
  //   `endif
    
  //   // DDR command interface (from cmd_scheduler)
  //   .ddr_write            (ddr_write),
  //   .ddr_read             (ddr_read),
  //   .ddr_pre              (ddr_pre),
  //   .ddr_act              (ddr_act),
  //   .ddr_ref              (ddr_ref),
  //   .ddr_zq               (ddr_zq),
  //   .ddr_nop              (ddr_nop),
  //   .ddr_ap               (ddr_ap),
  //   .ddr_pall             (ddr_pall),
  //   .ddr_half_bl          (ddr_half_bl),
  //   .ddr_bg               (ddr_bg),
  //   .ddr_bank             (ddr_bank),
  //   .ddr_col              (ddr_col),
  //   .ddr_row              (ddr_row),
  //   .ddr_wdata            (ddr_wdata),
    
  //   // Periodic maintenance
  //   .per_rd_init          (per_rd_init),
    
  //   // Read data interface (to cmd_scheduler)
  //   .rdData               (rdData),
  //   .rdDataEn             (rdDataEn),
    
  //   // CAS signals
  //   .mcRdCAS              (mcRdCAS),
  //   .mcWrCAS              (mcWrCAS)
  // );

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
