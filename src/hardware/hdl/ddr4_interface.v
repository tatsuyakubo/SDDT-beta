`include "parameters.vh"
`include "project.vh"

module ddr4_interface #(
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
  // System signals
  input  wire                      c0_sys_clk_p,
  input  wire                      c0_sys_clk_n,
  input  wire                      sys_rst,
  
  // Clock and reset outputs
  output wire                      c0_ddr4_clk,
  output wire                      c0_ddr4_rst,
  output wire                      c0_init_calib_complete,
  output wire                      dbg_clk,
  output wire [511:0]              dbg_bus,
  
  // DDR4 SDRAM interface
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
  
  // DDR command interface
  input  wire [3:0]                ddr_write,
  input  wire [3:0]                ddr_read,
  input  wire [3:0]                ddr_pre,
  input  wire [3:0]                ddr_act,
  input  wire [3:0]                ddr_ref,
  input  wire [3:0]                ddr_zq,
  input  wire [3:0]                ddr_nop,
  input  wire [3:0]                ddr_ap,
  input  wire [3:0]                ddr_pall,
  input  wire [3:0]                ddr_half_bl,
  input  wire [4*BG_WIDTH-1:0]     ddr_bg,
  input  wire [4*BANK_WIDTH-1:0]   ddr_bank,
  input  wire [4*COL_WIDTH-1:0]    ddr_col,
  input  wire [4*ROW_WIDTH-1:0]    ddr_row,
  input  wire [511:0]              ddr_wdata,
  
  // Read data interface
  output wire [511:0]              rdData,
  output wire [0:0]                rdDataEn,
  
  // For DLL toggler clock mux
  `ifdef ENABLE_DLL_TOGGLER
  output wire                      ddr4_ui_clk,
  output wire                      c0_ddr4_dll_off_clk,
  `endif
  
  // CAS signals for external use
  output wire [0:0]                mcRdCAS,
  output wire [0:0]                mcWrCAS
);

  // Internal wires for PHY <-> DDR adapter
  wire [4:0]             dBufAdr;
  wire [DQ_WIDTH*8-1:0]  wrData;
  wire [DQ_WIDTH-1:0]    wrDataMask;
  wire [4:0]             rdDataAddr;
  wire [0:0]             rdDataEnd;
  wire [0:0]             per_rd_done;
  wire [0:0]             rmw_rd_done;
  wire [4:0]             wrDataAddr;
  wire [0:0]             wrDataEn;
  wire [7:0]             mc_ACT_n;
  wire [135:0]           mc_ADR;
  wire [15:0]            mc_BA;
  wire [15:0]            mc_BG;
  wire [CKE_WIDTH*8-1:0] mc_CKE;
  wire [CS_WIDTH*8-1:0]  mc_CS_n;
  wire [ODT_WIDTH*8-1:0] mc_ODT;
  wire [1:0]             mcCasSlot;
  wire                   mcCasSlot2;
  wire                   gt_data_ready;
  wire [4:0]             winBuf;
  wire [1:0]             winRank;
  wire [5:0]             tCWL;
  
  // Internal clock wire
  wire         c0_ddr4_clk_internal;
  wire         c0_ddr4_rst_internal;
  wire         c0_init_calib_complete_internal;
  wire         c0_ddr4_clk_mux;
  wire [7:0]   dllt_mc_ACT_n;
  wire [135:0] dllt_mc_ADR;
  wire [15:0]  dllt_mc_BA;
  wire [15:0]  dllt_mc_BG;
  wire [7:0]   dllt_mc_CKE;
  wire [7:0]   dllt_mc_CS_n;
  wire         clk_sel;
  wire         dllt_done;
  wire         toggle_dll;
  wire         dllt_active;
  
  `ifdef ENABLE_DLL_TOGGLER
  wire ddr4_ui_clk_internal;
  wire c0_ddr4_dll_off_clk_internal;
  assign ddr4_ui_clk = ddr4_ui_clk_internal;
  assign c0_ddr4_dll_off_clk = c0_ddr4_dll_off_clk_internal;
  
  // DLL toggler (internalized)
  reg dllt_active_reg = 1'b0;
  assign dllt_active = dllt_active_reg;

`ifdef DLL_TOGGLE_ON_RESET
  reg toggle_dll_pulse = 1'b1;
  always @(posedge c0_ddr4_clk_mux) begin
    if (toggle_dll_pulse) begin
      toggle_dll_pulse <= 1'b0;
    end
  end
  assign toggle_dll = toggle_dll_pulse;
`else
  assign toggle_dll = 1'b0;
`endif

  always @(posedge c0_ddr4_clk_mux) begin
    if (toggle_dll) begin
      dllt_active_reg <= ~dllt_active_reg;
    end
    if (dllt_done) begin
      dllt_active_reg <= ~dllt_active_reg;
    end
  end

  dll_toggler dllt (
    .clk          (c0_ddr4_clk_mux),
    .rst          (c0_ddr4_rst_internal || ~c0_init_calib_complete_internal),
    .toggle_valid (toggle_dll),
    .mc_ACT_n     (dllt_mc_ACT_n),
    .mc_ADR       (dllt_mc_ADR),
    .mc_BA        (dllt_mc_BA),
    .mc_BG        (dllt_mc_BG),
    .mc_CS_n      (dllt_mc_CS_n),
    .mc_CKE       (dllt_mc_CKE),
    .clk_sel      (clk_sel),
    .dllt_done    (dllt_done)
  );

  BUFGMUX #(.CLK_SEL_TYPE("SYNC"))
  BUFGMUX_inst (
    .O  (c0_ddr4_clk_mux),
    .I0 (ddr4_ui_clk_internal),
    .I1 (c0_ddr4_dll_off_clk_internal),
    .S  (clk_sel)
  );
  `else
  assign dllt_active      = 1'b0;
  assign dllt_mc_ACT_n    = 8'd0;
  assign dllt_mc_ADR      = 136'd0;
  assign dllt_mc_BA       = 16'd0;
  assign dllt_mc_BG       = 16'd0;
  assign dllt_mc_CKE      = 8'd0;
  assign dllt_mc_CS_n     = 8'd0;
  assign clk_sel          = 1'b0;
  assign dllt_done        = 1'b0;
  assign toggle_dll       = 1'b0;
  assign c0_ddr4_clk_mux  = c0_ddr4_clk_internal;
  `endif
  
  // Output assignments
`ifdef ENABLE_DLL_TOGGLER
  assign c0_ddr4_clk = c0_ddr4_clk_mux;
`else
  assign c0_ddr4_clk = c0_ddr4_clk_internal;
`endif
  assign c0_ddr4_rst = c0_ddr4_rst_internal;
  assign c0_init_calib_complete = c0_init_calib_complete_internal;

  // =========================================================================
  // PHY DDR4 Instance
  // =========================================================================
  // UDIMM_x8
  phy_ddr4_udimm phy_ddr4_i (
    .sys_rst                  (sys_rst),
    .c0_sys_clk_p             (c0_sys_clk_p),
    .c0_sys_clk_n             (c0_sys_clk_n),
    
    `ifdef ENABLE_DLL_TOGGLER
    .c0_ddr4_ui_clk           (ddr4_ui_clk_internal),
    .addn_ui_clkout1          (c0_ddr4_dll_off_clk_internal),
    `else
    .c0_ddr4_ui_clk           (c0_ddr4_clk_internal),
    `endif
    .c0_ddr4_ui_clk_sync_rst  (c0_ddr4_rst_internal),
    .c0_init_calib_complete   (c0_init_calib_complete_internal),
    .dbg_clk                  (dbg_clk),
    .c0_ddr4_act_n            (c0_ddr4_act_n),
    .c0_ddr4_adr              (c0_ddr4_adr),
    .c0_ddr4_ba               (c0_ddr4_ba),
    .c0_ddr4_bg               (c0_ddr4_bg),
    .c0_ddr4_cke              (c0_ddr4_cke[0]),
    .c0_ddr4_odt              (c0_ddr4_odt[0]),
    .c0_ddr4_cs_n             (c0_ddr4_cs_n[0]),
    .c0_ddr4_ck_t             (c0_ddr4_ck_t),
    .c0_ddr4_ck_c             (c0_ddr4_ck_c),
    .c0_ddr4_reset_n          (c0_ddr4_reset_n),
    .c0_ddr4_dq               (c0_ddr4_dq),
    .c0_ddr4_dqs_c            (c0_ddr4_dqs_c),
    .c0_ddr4_dqs_t            (c0_ddr4_dqs_t),
    .c0_ddr4_dm_dbi_n         (c0_ddr4_dm_dbi_n),
    
    .dBufAdr                  (dBufAdr),
    .wrData                   (wrData),
    .rdData                   (rdData),
    .rdDataAddr               (rdDataAddr),
    .rdDataEn                 (rdDataEn),
    .rdDataEnd                (rdDataEnd),
    .per_rd_done              (per_rd_done),
    .rmw_rd_done              (rmw_rd_done),
    .wrDataAddr               (wrDataAddr),
    .wrDataEn                 (wrDataEn),
    .wrDataMask               (wrDataMask),
    
    .mc_ACT_n                 (dllt_active ? dllt_mc_ACT_n : mc_ACT_n),
    .mc_ADR                   (dllt_active ? dllt_mc_ADR : mc_ADR),
    .mc_BA                    (dllt_active ? dllt_mc_BA : mc_BA),
    .mc_BG                    (dllt_active ? dllt_mc_BG : mc_BG),
    .mc_CKE                   (dllt_active ? dllt_mc_CKE : {8{1'b1}}),
    .mc_CS_n                  (dllt_active ? dllt_mc_CS_n : mc_CS_n),
    .mc_ODT                   (mc_ODT),
    .mcCasSlot                (dllt_active ? 2'b0 : mcCasSlot),
    .mcCasSlot2               (dllt_active ? 1'b0 : mcCasSlot2),
    .mcRdCAS                  (dllt_active ? 1'b0 : mcRdCAS),
    .mcWrCAS                  (dllt_active ? 1'b0 : mcWrCAS),
    .winInjTxn                ({1{1'b0}}),
    .winRmw                   ({1{1'b0}}),
    .gt_data_ready            (gt_data_ready),
    .winBuf                   (winBuf),
    .winRank                  (winRank),
    .tCWL                     (tCWL),
    .dbg_bus                  (dbg_bus)
  );
  // UDIMM does not use parity signal, tie it to 0
  assign c0_ddr4_parity = 1'b0;
  assign c0_ddr4_odt[1] = 1'b0;
  assign c0_ddr4_cs_n[1] = 1'b1;
  assign c0_ddr4_cke[1] = 1'b0;

  // =========================================================================
  // DDR4 Adapter Instance
  // =========================================================================
  ddr4_adapter #(
    .DQ_WIDTH(DQ_WIDTH)
  ) ddr4_adapter_i (
    .clk                 (c0_ddr4_clk_internal),
    .rst                 (c0_ddr4_rst_internal),
    .init_calib_complete (c0_init_calib_complete_internal),
    .dBufAdr             (dBufAdr),
    .wrData              (wrData),
    .wrDataMask          (wrDataMask),
    .wrDataEn            (wrDataEn),
    .mc_ACT_n            (mc_ACT_n),
    .mc_ADR              (mc_ADR),
    .mc_BA               (mc_BA),
    .mc_BG               (mc_BG),
    .mc_CS_n             (mc_CS_n),
    .mcRdCAS             (mcRdCAS),
    .mcWrCAS             (mcWrCAS),
    .winRank             (winRank),
    .winBuf              (winBuf),
    .rdDataEn            (rdDataEn),
    .rdDataEnd           (rdDataEnd),
    .mcCasSlot           (mcCasSlot),
    .mcCasSlot2          (mcCasSlot2),
    .gt_data_ready       (gt_data_ready),
    .ddr_write           (ddr_write),
    .ddr_read            (ddr_read),
    .ddr_pre             (ddr_pre),
    .ddr_act             (ddr_act),
    .ddr_ref             (ddr_ref),
    .ddr_zq              (ddr_zq),
    .ddr_nop             (ddr_nop),
    .ddr_ap              (ddr_ap),
    .ddr_pall            (ddr_pall),
    .ddr_half_bl         (ddr_half_bl),
    .ddr_bg              (ddr_bg),
    .ddr_bank            (ddr_bank),
    .ddr_col             (ddr_col),
    .ddr_row             (ddr_row),
    .ddr_wdata           (ddr_wdata),
    .ddr_maint_read      (1'b0)
  );

  // =========================================================================
  // ODT Controller Instance
  // =========================================================================
  localparam ODTWRDEL   = 5'd9;
  localparam ODTWRDUR   = 4'd6;
  localparam ODTWRODEL  = 5'd9;
  localparam ODTWRODUR  = 4'd6;
  localparam ODTRDDEL   = 5'd10;
  localparam ODTRDDUR   = 4'd6;
  localparam ODTRDODEL  = 5'd9;
  localparam ODTRDODUR  = 4'd6;
  localparam ODTNOP     = 16'h0000;
  localparam ODTWR      = 16'h0001;
  localparam ODTRD      = 16'h0000;
  
  wire tranSentC;
  assign tranSentC = mcRdCAS | mcWrCAS;

  ddr4_mc_odt #(
    .ODTWR     (ODTWR),
    .ODTWRDEL  (ODTWRDEL),
    .ODTWRDUR  (ODTWRDUR),
    .ODTWRODEL (ODTWRODEL),
    .ODTWRODUR (ODTWRODUR),
    .ODTRD     (ODTRD),
    .ODTRDDEL  (ODTRDDEL),
    .ODTRDDUR  (ODTRDDUR),
    .ODTRDODEL (ODTRDODEL),
    .ODTRDODUR (ODTRDODUR),
    .ODTNOP    (ODTNOP),
    .ODTBITS   (ODT_WIDTH),
    .TCQ       (0.1)
  ) u_ddr_tb_odt (
    .clk       (c0_ddr4_clk_internal),
    .rst       (c0_ddr4_rst_internal),
    .mc_ODT    (mc_ODT),
    .casSlot   (mcCasSlot),
    .casSlot2  (mcCasSlot2),
    .rank      (winRank),
    .winRead   (mcRdCAS),
    .winWrite  (mcWrCAS),
    .tranSentC (tranSentC)
  );

endmodule
