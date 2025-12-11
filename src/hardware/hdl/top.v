`include "parameters.vh"
`include "project.vh"

module top #(parameter tCK = 1500, SIM = "false")
  (
  // common signals
  input c0_sys_clk_p,
  input c0_sys_clk_n,
  input sys_rst,
  
  // iob <> ddr4 sdram ip signals
  output             c0_ddr4_act_n,
  output [`ROW_ADDR_WIDTH-1:0]      c0_ddr4_adr,
  output [1:0]       c0_ddr4_ba,
  output [1:0]       c0_ddr4_bg,
  output [`CKE_WIDTH-1:0]       c0_ddr4_cke,
  output [`ODT_WIDTH-1:0]       c0_ddr4_odt,
  output [`CS_WIDTH-1:0]        c0_ddr4_cs_n,
  output [`CK_WIDTH-1:0]       c0_ddr4_ck_t,
  output [`CK_WIDTH-1:0]       c0_ddr4_ck_c,
  output             c0_ddr4_reset_n,

  `ifdef RDIMM_x4
  inout  [17:0]      c0_ddr4_dqs_c,
  inout  [17:0]      c0_ddr4_dqs_t,
  inout  [71:0]      c0_ddr4_dq,
  output             c0_ddr4_parity,
  `elsif UDIMM_x8
  inout  [7:0]      c0_ddr4_dqs_c,
  inout  [7:0]      c0_ddr4_dqs_t,
  inout  [63:0]     c0_ddr4_dq,
  inout  [7:0]      c0_ddr4_dm_dbi_n,  
  output            c0_ddr4_parity,
  `elsif RDIMM_x8
  inout  [8:0]      c0_ddr4_dqs_c,
  inout  [8:0]      c0_ddr4_dqs_t,
  inout  [71:0]     c0_ddr4_dq,
  inout  [8:0]      c0_ddr4_dm_dbi_n,
  output            c0_ddr4_parity,  
  `endif

  output [3:0] user_led

  );
  
  `ifdef RDIMM_x4
  assign c0_ddr4_odt[1] = 1'b0;
  assign c0_ddr4_cs_n[1] = 1'b1;
  assign c0_ddr4_cke[1] = 1'b0;
  `elsif RDIMM_x8
  assign c0_ddr4_odt[1] = 1'b0;
  assign c0_ddr4_cs_n[1] = 1'b1;
  assign c0_ddr4_cke[1] = 1'b0;
  //assign c0_ddr4_parity = 1'b0;
  `elsif UDIMM_x8
  assign c0_ddr4_odt[1] = 1'b0;
  assign c0_ddr4_cs_n[1] = 1'b1;
  assign c0_ddr4_cke[1] = 1'b0;
  assign c0_ddr4_parity = 1'b0;
  `endif
  // Frontend control signals
  wire softmc_fin;
  wire user_rst;  
  
  // Frontend <-> Fetch signals
  wire [`IMEM_ADDR_WIDTH-1:0] fr_addr_in;
  wire                        fr_valid_in;
  wire [`INSTR_WIDTH-1:0]     fr_data_out;
  wire                        fr_valid_out;
  wire [`IMEM_ADDR_WIDTH-1:0] fr_addr_out;
  wire                        fr_ready_out;

  // Frontend <-> misc. control signals
  wire                        per_rd_init;
  wire                        per_zq_init;
  wire                        per_ref_init;
  wire                        rbe_switch_mode;
  wire                        toggle_dll;  

  // AXI streaming ports
  wire [511:0]   s_axis_h2c_tdata_0,xdma_h2c_tdata_0;
  wire                              s_axis_h2c_tlast_0, xdma_h2c_tlast_0;
  wire                              s_axis_h2c_tvalid_0, xdma_h2c_tvalid_0;
  wire                              s_axis_h2c_tready_0, xdma_h2c_tready_0;
  wire [511:0]   m_axis_c2h_tdata_0, xdma_c2h_tdata_0; 
  wire                              m_axis_c2h_tlast_0, xdma_c2h_tlast_0;
  wire                              m_axis_c2h_tvalid_0, xdma_c2h_tvalid_0;
  wire                              m_axis_c2h_tready_0, xdma_c2h_tready_0;
  wire [512/8-1:0] m_axis_c2h_tkeep_0, xdma_c2h_tkeep_0;
 
  // ddr_pipeline <-> outer module if
  wire [3:0]                ddr_write;
  wire [3:0]                ddr_read;
  wire [3:0]                ddr_pre;
  wire [3:0]                ddr_act;
  wire [3:0]                ddr_ref;
  wire [3:0]                ddr_zq;
  wire [3:0]                ddr_nop;
  wire [3:0]                ddr_ap;
  wire [3:0]                ddr_pall;
  wire [3:0]                ddr_half_bl;
  wire [4*`BG_WIDTH-1:0]    ddr_bg;
  wire [4*`BANK_WIDTH-1:0]  ddr_bank;
  wire [4*`COL_WIDTH-1:0]   ddr_col;
  wire [4*`ROW_WIDTH-1:0]   ddr_row;
  wire [511:0]              ddr_wdata;
 
  // periodic maintenance signals
  wire                      ddr_maint_read;
 
  // phy <-> ddr adapter and xdma app signals
  // dlltoggler
`ifdef ENABLE_DLL_TOGGLER
  wire clk_sel;
`else
  wire clk_sel = 1'b0;
`endif

  wire [7:0]                dllt_mc_ACT_n;
  wire [135:0]              dllt_mc_ADR;
  wire [15:0]               dllt_mc_BA;
  wire [15:0]               dllt_mc_BG;
  wire [7:0]                dllt_mc_CKE;
  wire [7:0]                dllt_mc_CS_n;
  wire                      dllt_done;
  // ddr adapter 
  wire [4:0]                dBufAdr;
  wire [`DQ_WIDTH*8-1:0]    wrData;
  wire [`DQ_WIDTH-1:0]      wrDataMask;
  wire [511:0]              rdData;
  wire [4:0]                rdDataAddr;
  wire [0:0]                rdDataEn;
  wire [0:0]                rdDataEnd;
  wire [0:0]                per_rd_done;
  wire [0:0]                rmw_rd_done;
  wire [4:0]                wrDataAddr;
  wire [0:0]                wrDataEn;
  wire [7:0]                mc_ACT_n;
  wire [135:0]              mc_ADR;
  wire [15:0]               mc_BA;
  wire [15:0]               mc_BG;
  wire [`CKE_WIDTH*8-1:0]                mc_CKE;
  wire [`CS_WIDTH*8-1:0]                mc_CS_n;
  wire [`ODT_WIDTH*8-1:0]                mc_ODT;
  wire [0:0]                mcRdCAS;
  wire [0:0]                mcWrCAS;
  wire [0:0]                winInjTxn;
  wire [0:0]                winRmw;
  wire [4:0]                winBuf;
  wire [1:0]                winRank;
  wire [5:0]                tCWL;
  wire                      dbg_clk;
  wire                      c0_wr_rd_complete;
  wire                      c0_ddr4_clk;
  wire                      c0_ddr4_dll_off_clk;
  wire                      ddr4_ui_clk;
  wire                      c0_ddr4_rst;
  wire [511:0]              dbg_bus;        
  wire [1:0]                mcCasSlot;
  wire                      mcCasSlot2;
  wire                      gt_data_ready;
  
  wire         read_seq_incoming; // next few instructions will read from DRAM
  wire [11:0]  incoming_reads;    // how many reads next few instructions will issue
  wire [11:0]  buffer_space;      // remaining buffer size
 
  //wire sys_rst = ~sys_rst_l; // low active signal
  wire c0_init_calib_complete;
  
  // There is a possibility that these signals are on
  // the critical path as observed in 
  // the previous iteration of SoftMC
  reg c0_init_calib_complete_r, sys_rst_r;
  wire iq_full, processing_iseq, rdback_fifo_empty;
  
  always @(posedge c0_ddr4_clk) begin
    c0_init_calib_complete_r <= c0_init_calib_complete;
    sys_rst_r <= sys_rst;  
  end
  
  reg dllt_active = 1'b0;
  
  `ifdef ENABLE_DLL_TOGGLER
  always @(posedge c0_ddr4_clk) begin
    if(toggle_dll) begin
      dllt_active <= ~dllt_active;
    end
    if(dllt_done) begin
      dllt_active <= ~dllt_active;
    end
  end
  `endif

  `ifdef RDIMM_x4
  phy_ddr4 phy_ddr4_i(
    .sys_rst                  (sys_rst),
    .c0_sys_clk_p             (c0_sys_clk_p),
    .c0_sys_clk_n             (c0_sys_clk_n),
    
    `ifdef ENABLE_DLL_TOGGLER
    .c0_ddr4_ui_clk           (ddr4_ui_clk),
    .addn_ui_clkout1          (c0_ddr4_dll_off_clk),
    `else
    .c0_ddr4_ui_clk           (c0_ddr4_clk),
    `endif
    .c0_ddr4_ui_clk_sync_rst  (c0_ddr4_rst),
    .c0_init_calib_complete   (c0_init_calib_complete),
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
    .c0_ddr4_parity            (c0_ddr4_parity),
    .c0_ddr4_dq               (c0_ddr4_dq),
    .c0_ddr4_dqs_c            (c0_ddr4_dqs_c),
    .c0_ddr4_dqs_t            (c0_ddr4_dqs_t),
    
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
    
    .mc_ACT_n                 (dllt_active ? dllt_mc_ACT_n : mc_ACT_n),
    .mc_ADR                   (dllt_active ? dllt_mc_ADR : mc_ADR),
    .mc_BA                    (dllt_active ? dllt_mc_BA : mc_BA),
    .mc_BG                    (dllt_active ? dllt_mc_BG : mc_BG),
    // DRAM CKE. 8 bits for each DRAM pin. The mc_CKE signal is always set to '1'.
    .mc_CKE                   (dllt_active ? dllt_mc_CKE : {8{1'b1}}),
    .mc_CS_n                  (dllt_active ? dllt_mc_CS_n : mc_CS_n),
    .mc_ODT                   (mc_ODT),
    // CAS command slot select. Slot0 is enabled for example design.
    .mcCasSlot                (dllt_active ? 0 : mcCasSlot),
    // CAS slot 2 select.  mcCasSlot2 serves a similar purpose as the mcCasSlot[1:0] signal, but mcCasSlot2 is used in timing 
    // critical logic in the Phy. Slot0 is enabled for example design.
    .mcCasSlot2               (dllt_active ? 0 : mcCasSlot2),
    .mcRdCAS                  (dllt_active ? 0 : mcRdCAS),
    .mcWrCAS                  (dllt_active ? 0 : mcWrCAS),
    // Optional read command type indication. The winInjTxn signal is set to '0' for example design.
    .winInjTxn                ({1{1'b0}}),
    // Optional read command type indication. The winRmw signal is set to '0' for example design.
    .winRmw                   ({1{1'b0}}),
    // Update VT Tracking. The gt_data_ready signal is set to '0' in this example design.
    // This signal must be asserted periodically to keep the DQS Gate aligned as voltage and temperature drift.
    // For more information, Refer to PG150 document.
    .gt_data_ready            (gt_data_ready),
    .winBuf                   (winBuf),
    .winRank                  (winRank),
    .tCWL                     (tCWL),
    // Debug Port
    .dbg_bus                  (dbg_bus)                                    
  );
  `elsif UDIMM_x8
   phy_ddr4_udimm phy_ddr4_i(
    .sys_rst                  (sys_rst),
    .c0_sys_clk_p             (c0_sys_clk_p),
    .c0_sys_clk_n             (c0_sys_clk_n),
  
    `ifdef ENABLE_DLL_TOGGLER
    .c0_ddr4_ui_clk           (ddr4_ui_clk),
    .addn_ui_clkout1          (c0_ddr4_dll_off_clk),
    `else
    .c0_ddr4_ui_clk           (c0_ddr4_clk),
    `endif
    .c0_ddr4_ui_clk_sync_rst  (c0_ddr4_rst),
    .c0_init_calib_complete   (c0_init_calib_complete),
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
    //.ddr4_par              (c0_ddr4_parity),
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
    // DRAM CKE. 8 bits for each DRAM pin. The mc_CKE signal is always set to '1'.
    .mc_CKE                   (dllt_active ? dllt_mc_CKE : {8{1'b1}}),
    .mc_CS_n                  (dllt_active ? dllt_mc_CS_n : mc_CS_n),
    .mc_ODT                   (mc_ODT),
    // CAS command slot select. Slot0 is enabled for example design.
    .mcCasSlot                (dllt_active ? 0 : mcCasSlot),
    // CAS slot 2 select.  mcCasSlot2 serves a similar purpose as the mcCasSlot[1:0] signal, but mcCasSlot2 is used in timing 
    // critical logic in the Phy. Slot0 is enabled for example design.
    .mcCasSlot2               (dllt_active ? 0 : mcCasSlot2),
    .mcRdCAS                  (dllt_active ? 0 : mcRdCAS),
    .mcWrCAS                  (dllt_active ? 0 : mcWrCAS),
    // Optional read command type indication. The winInjTxn signal is set to '0' for example design.
    .winInjTxn                ({1{1'b0}}),
    // Optional read command type indication. The winRmw signal is set to '0' for example design.
    .winRmw                   ({1{1'b0}}),
    // Update VT Tracking. The gt_data_ready signal is set to '0' in this example design.
    // This signal must be asserted periodically to keep the DQS Gate aligned as voltage and temperature drift.
    // For more information, Refer to PG150 document.
    .gt_data_ready            (gt_data_ready),
    .winBuf                   (winBuf),
    .winRank                  (winRank),
    .tCWL                     (tCWL),
    // Debug Port
    .dbg_bus                  (dbg_bus)                                    
  );
  `elsif RDIMM_x8
   phy_rdimm_x8_dual phy_ddr4_i(
    .sys_rst                  (sys_rst),
    .c0_sys_clk_p             (c0_sys_clk_p),
    .c0_sys_clk_n             (c0_sys_clk_n),
    
    `ifdef ENABLE_DLL_TOGGLER
    .c0_ddr4_ui_clk           (ddr4_ui_clk),
    .addn_ui_clkout1          (c0_ddr4_dll_off_clk),
    `else
    .c0_ddr4_ui_clk           (c0_ddr4_clk),
    `endif
    .c0_ddr4_ui_clk_sync_rst  (c0_ddr4_rst),
    .c0_init_calib_complete   (c0_init_calib_complete),
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
    .c0_ddr4_parity           (c0_ddr4_parity),
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
    // DRAM CKE. 8 bits for each DRAM pin. The mc_CKE signal is always set to '1'.
    .mc_CKE                   (dllt_active ? dllt_mc_CKE : {8{1'b1}}),
    .mc_CS_n                  (dllt_active ? dllt_mc_CS_n : mc_CS_n),
    .mc_ODT                   (mc_ODT),
    // CAS command slot select. Slot0 is enabled for example design.
    .mcCasSlot                (dllt_active ? 0 : mcCasSlot),
    // CAS slot 2 select.  mcCasSlot2 serves a similar purpose as the mcCasSlot[1:0] signal, but mcCasSlot2 is used in timing 
    // critical logic in the Phy. Slot0 is enabled for example design.
    .mcCasSlot2               (dllt_active ? 0 : mcCasSlot2),
    .mcRdCAS                  (dllt_active ? 0 : mcRdCAS),
    .mcWrCAS                  (dllt_active ? 0 : mcWrCAS),
    // Optional read command type indication. The winInjTxn signal is set to '0' for example design.
    .winInjTxn                ({1{1'b0}}),
    // Optional read command type indication. The winRmw signal is set to '0' for example design.
    .winRmw                   ({1{1'b0}}),
    // Update VT Tracking. The gt_data_ready signal is set to '0' in this example design.
    // This signal must be asserted periodically to keep the DQS Gate aligned as voltage and temperature drift.
    // For more information, Refer to PG150 document.
    .gt_data_ready            (gt_data_ready),
    .winBuf                   (winBuf),
    .winRank                  (winRank),
    .tCWL                     (tCWL),
    // Debug Port
    .dbg_bus                  (dbg_bus)                                    
  );  
  `endif
  
  `ifdef ENABLE_DLL_TOGGLER
  //BUFGMUX:GeneralClockMuxBuffer
  //UltraScale
  //XilinxHDLLibrariesGuide, version2014.4
  BUFGMUX#(.CLK_SEL_TYPE("SYNC")  //ASYNC,SYNC
  )BUFGMUX_inst(
    .O(c0_ddr4_clk),        //1-bitoutput:Clockoutput
    .I0(ddr4_ui_clk),    //1-bitinput:Clockinput(S=0)
    .I1(c0_ddr4_dll_off_clk),   //1-bitinput:Clockinput(S=1)
    .S(clk_sel)            //1-bitinput:Clockselect
    );
    //End of BUFGMUX_inst instantiation
  `endif
 
 
  wire frontend_ready;
  
  assign user_rst = 1'b0;
  assign dllt_begin = 1'b0;
  assign frontend_ready = 1'b0; // todo
  assign per_rd_init = 1'b0;
  assign per_zq_init = 1'b0;
  assign per_ref_init = 1'b0;
  assign rbe_switch_mode = 1'b0;

  ddr4_adapter#(
    .DQ_WIDTH(`DQ_WIDTH)
  ) ddr4_adapter
  (
   .clk(c0_ddr4_clk),
   .rst(c0_ddr4_rst || user_rst),
   .init_calib_complete(c0_init_calib_complete_r),
   //.io_config_strobe,
   //.io_config,
   .dBufAdr(dBufAdr),   // Reserved. Should be tied low.
   .wrData(wrData),    // DRAM write data. There are 8 bits for each DQ lane on the DRAM bus.
   .wrDataMask(wrDataMask),// DRAM write DM/DBI port.There is one bit for each byte of the wrData port.
   .wrDataEn(wrDataEn),  // Write data Enable. The Phy will assert this port for one cycle for each write CAS command.
   .mc_ACT_n(mc_ACT_n),  // DRAM ACT_n command signal for four DRAM clock cycles.
   .mc_ADR(mc_ADR),    // DRAM address. There are 8 bits in the fabric interface for each address bit on the DRAM bus.
   .mc_BA(mc_BA),     // DRAM bank address. 8 bits for each DRAM bank address.
   .mc_BG(mc_BG),     // DRAM bank group address.
   .mc_CS_n(mc_CS_n),   // DRAM CS_n
   //.mc_ODT(mc_ODT),    // DRAM ODT
   .mcRdCAS(mcRdCAS),   // Read CAS command issued.
   .mcWrCAS(mcWrCAS),   // Write CAS command issued.
   .winRank(winRank),   // Target rank for CAS commands. This value indicates which rank a CAS command is issued to.
   .winBuf(winBuf),    // Optional control signal. When either mcRdCAS or mcWrCAS is asserted, the Phy will store the value on the winBuf signal.  
   //.rdData(rdData),    // DRAM read data.
   .rdDataEn(rdDataEn),  // Read data valid. This signal asserts for one fabric cycle for each completed read operation.
   .rdDataEnd(rdDataEnd),  // Unused.  Tied high.
   .mcCasSlot(mcCasSlot),
   .mcCasSlot2(mcCasSlot2),
   .gt_data_ready(gt_data_ready),
   .ddr_write(ddr_write),  
   .ddr_read(ddr_read),  
   .ddr_pre(ddr_pre),    
   .ddr_act(ddr_act),    
   .ddr_ref(ddr_ref),    
   .ddr_zq(ddr_zq),    
   .ddr_nop(ddr_nop),    
   .ddr_ap(ddr_ap),    
   .ddr_pall(ddr_pall),    
   .ddr_half_bl(ddr_half_bl),
   .ddr_bg(ddr_bg),    
   .ddr_bank(ddr_bank),  
   .ddr_col(ddr_col),    
   .ddr_row(ddr_row),    
   .ddr_wdata(ddr_wdata),
 
   .ddr_maint_read(per_rd_init)
  );
  
    localparam          ODTWRDEL                = 5'd9;
    localparam          ODTWRDUR                = 4'd6;
    localparam          ODTWRODEL               = 5'd9;
    localparam          ODTWRODUR               = 4'd6;
    localparam          ODTRDDEL                = 5'd10;
    localparam          ODTRDDUR                = 4'd6;
    localparam          ODTRDODEL               = 5'd9;
    localparam          ODTRDODUR               = 4'd6;
    localparam          ODTNOP                  = 16'h0000;
    localparam        ODTWR                     = 16'h0001;
    localparam        ODTRD                     = 16'h0000; 
    
    wire tranSentC;
    assign tranSentC = mcRdCAS | mcWrCAS;
 
  //synthesis translate_on
  //*******************************************************************************
  ddr4_mc_odt # (
    .ODTWR     (ODTWR)
    ,.ODTWRDEL  (ODTWRDEL)
    ,.ODTWRDUR  (ODTWRDUR)
    ,.ODTWRODEL (ODTWRODEL)
    ,.ODTWRODUR (ODTWRODUR)
   
    ,.ODTRD     (ODTRD)
    ,.ODTRDDEL  (ODTRDDEL)
    ,.ODTRDDUR  (ODTRDDUR)
    ,.ODTRDODEL (ODTRDODEL)
    ,.ODTRDODUR (ODTRDODUR)
   
    ,.ODTNOP    (ODTNOP)
    ,.ODTBITS   (`ODT_WIDTH)
    ,.TCQ       (0.1)
  )u_ddr_tb_odt(
    .clk       (c0_ddr4_clk)
    ,.rst       (c0_ddr4_rst)
    ,.mc_ODT    (mc_ODT)
    ,.casSlot   (mcCasSlot)
    ,.casSlot2  (mcCasSlot2)
    ,.rank      (winRank)
    ,.winRead   (mcRdCAS)
    ,.winWrite  (mcWrCAS)
    ,.tranSentC (tranSentC)
  );
 
  wire sys_clk, sys_clk_gt;
  wire [2:0]    msi_vector_width;
  wire          msi_enable;
  wire          user_lnk_up, usr_irq_req, usr_irq_ack;

  wire [511:0]M_AXIS_MM2S_0_tdata;
  wire [31:0]M_AXIS_MM2S_0_tkeep;
  wire M_AXIS_MM2S_0_tlast;
  wire M_AXIS_MM2S_0_tready;
  wire M_AXIS_MM2S_0_tvalid;
  wire [511:0]S_AXIS_S2MM_0_tdata;
  wire [512/8-1:0]S_AXIS_S2MM_0_tkeep;
  wire S_AXIS_S2MM_0_tlast;
  wire S_AXIS_S2MM_0_tready;
  wire S_AXIS_S2MM_0_tvalid;
  wire axi_resetn;
  wire [31:0] axi_gpio_in;
  wire [31:0] axi_gpio_in2;
  wire [31:0] axi_gpio_out;
  wire [511:0] M_AXIS_MM2S_1_tdata, s_axis_h2c_tdata_1;
  wire M_AXIS_MM2S_1_tready, s_axis_h2c_tready_1;
  wire M_AXIS_MM2S_1_tvalid, s_axis_h2c_tvalid_1;

  design_1 design_1_i
       (.M_AXIS_MM2S_0_tdata(M_AXIS_MM2S_0_tdata),
        // .M_AXIS_MM2S_0_tkeep(M_AXIS_MM2S_0_tkeep),
        // .M_AXIS_MM2S_0_tlast(M_AXIS_MM2S_0_tlast),
        .M_AXIS_MM2S_0_tready(M_AXIS_MM2S_0_tready),
        .M_AXIS_MM2S_0_tvalid(M_AXIS_MM2S_0_tvalid),
        .M_AXIS_MM2S_1_tdata(M_AXIS_MM2S_1_tdata),
        .M_AXIS_MM2S_1_tready(M_AXIS_MM2S_1_tready),
        .M_AXIS_MM2S_1_tvalid(M_AXIS_MM2S_1_tvalid),
        .S_AXIS_S2MM_0_tdata(S_AXIS_S2MM_0_tdata),
        .S_AXIS_S2MM_0_tkeep(S_AXIS_S2MM_0_tkeep),
        .S_AXIS_S2MM_0_tlast(S_AXIS_S2MM_0_tlast),
        .S_AXIS_S2MM_0_tready(S_AXIS_S2MM_0_tready),
        .S_AXIS_S2MM_0_tvalid(S_AXIS_S2MM_0_tvalid),
        .axi_resetn(axi_resetn),
        .c0_ddr4_clk(c0_ddr4_clk),
        .axi_gpio_in(axi_gpio_in),
        .axi_gpio_in2(axi_gpio_in2),
        .axi_gpio_out(axi_gpio_out));

  // ila_dma_axis ila_dma_axis_i
  //      (.clk(c0_ddr4_clk),
  //       .probe0(M_AXIS_MM2S_0_tdata),
  //       .probe1(M_AXIS_MM2S_0_tkeep),
  //       .probe2(M_AXIS_MM2S_0_tlast),
  //       .probe3(M_AXIS_MM2S_0_tready),
  //       .probe4(M_AXIS_MM2S_0_tvalid),
  //       .probe5(S_AXIS_S2MM_0_tdata),
  //       .probe6(S_AXIS_S2MM_0_tkeep),
  //       .probe7(S_AXIS_S2MM_0_tlast),
  //       .probe8(S_AXIS_S2MM_0_tready),
  //       .probe9(S_AXIS_S2MM_0_tvalid)
	// );

  // maxis_test #(
  //   .BITWIDTH(512)
  // ) maxis_test (
  //   .clk(c0_ddr4_clk),
  //   .rst(~axi_resetn),
  //   .M_AXIS_TDATA(S_AXIS_S2MM_0_tdata),
  //   .M_AXIS_TVALID(S_AXIS_S2MM_0_tvalid),
  //   .M_AXIS_TKEEP(S_AXIS_S2MM_0_tkeep),
  //   .M_AXIS_TLAST(S_AXIS_S2MM_0_tlast),
  //   .M_AXIS_TREADY(S_AXIS_S2MM_0_tready)
  // );

  // assign m_axis_c2h_tready_0 = 1'b1;
  // Clock converters removed - signals connected directly
  // c2h (c2h -> S2MM) direct connection
  assign S_AXIS_S2MM_0_tvalid = m_axis_c2h_tvalid_0;
  assign S_AXIS_S2MM_0_tlast = m_axis_c2h_tlast_0;
  assign S_AXIS_S2MM_0_tdata = m_axis_c2h_tdata_0;
  assign S_AXIS_S2MM_0_tkeep = m_axis_c2h_tkeep_0;
  assign m_axis_c2h_tready_0 = S_AXIS_S2MM_0_tready;
  
  // h2c interface 0 (MM2S -> h2c) direct connection
  assign s_axis_h2c_tvalid_0 = M_AXIS_MM2S_0_tvalid;
  assign s_axis_h2c_tdata_0 = M_AXIS_MM2S_0_tdata;
  assign M_AXIS_MM2S_0_tready = s_axis_h2c_tready_0;

  // h2c interface 1 (MM2S -> h2c) direct connection
  assign s_axis_h2c_tvalid_1 = M_AXIS_MM2S_1_tvalid;
  assign s_axis_h2c_tdata_1 = M_AXIS_MM2S_1_tdata;
  assign M_AXIS_MM2S_1_tready = s_axis_h2c_tready_1;


  assign buffer_space = 11'b0;

  `ifdef ENABLE_DLL_TOGGLER
  dll_toggler dllt
   (
     .clk(c0_ddr4_clk),
     .rst(c0_ddr4_rst || user_rst || ~c0_init_calib_complete_r),
     .toggle_valid(toggle_dll),
     .mc_ACT_n(dllt_mc_ACT_n),  // DRAM ACT_n command signal for four DRAM clock cycles.
     .mc_ADR(dllt_mc_ADR),    // DRAM address. There are 8 bits in the fabric interface for each address bit on the DRAM bus.
     .mc_BA(dllt_mc_BA),     // DRAM bank address. 8 bits for each DRAM bank address.
     .mc_BG(dllt_mc_BG),     // DRAM bank group address.
     .mc_CS_n(dllt_mc_CS_n),   // DRAM CS_n    
     .mc_CKE(dllt_mc_CKE),
     .clk_sel(clk_sel),
     .dllt_done(dllt_done)
   );
   `endif


    reg [31:0] c0_ddr4_clk_counter;
    always @(posedge c0_ddr4_clk) begin
	c0_ddr4_clk_counter <= c0_ddr4_clk_counter + 1;
    end
    assign user_led = c0_ddr4_clk_counter[23:20];

  axi4_read_data axi4_read_data(
    .clk(c0_ddr4_clk),
    .rst(c0_ddr4_rst),
    .err(axi_gpio_in[0]), // Debug
    .latest_buf(axi_gpio_in[24:17]),
    .rd_data(rdData),
    .rd_valid(rdDataEn),
    .M_AXIS_TDATA(m_axis_c2h_tdata_0),
    .M_AXIS_TVALID(m_axis_c2h_tvalid_0),
    .M_AXIS_TKEEP(m_axis_c2h_tkeep_0),
    .M_AXIS_TLAST(m_axis_c2h_tlast_0),
    .M_AXIS_TREADY(m_axis_c2h_tready_0)
  );

  reg [7:0] latest_valid_data;
  reg [7:0] latest_handshake_data;
  reg [7:0] handshake_counter;
  reg [7:0] read_en_counter;
  reg [7:0] read_cmd_counter;
  always @(posedge c0_ddr4_clk) begin
    if (c0_ddr4_rst) begin
      latest_valid_data <= 8'd0;
      latest_handshake_data <= 8'd0;
      handshake_counter <= 8'd0;
      read_en_counter <= 8'd0;
      read_cmd_counter <= 8'd0;
    end else begin
      if (m_axis_c2h_tvalid_0) begin
        latest_valid_data <= m_axis_c2h_tdata_0[7:0];
      end
      if (m_axis_c2h_tvalid_0 && m_axis_c2h_tready_0) begin
        latest_handshake_data <= m_axis_c2h_tdata_0[7:0];
        handshake_counter <= handshake_counter + 1;
      end
      if (rdDataEn) begin
        read_en_counter <= read_en_counter + 1;
      end
      // increment read_cmd_counter by the number of 1 bits in ddr_Read
      read_cmd_counter <= read_cmd_counter + ddr_read[0] + ddr_read[1] + ddr_read[2] + ddr_read[3];
    end
  end

  assign axi_gpio_in[8:1] = handshake_counter; // Debug
  assign axi_gpio_in[16:9] = read_en_counter; // Debug
  assign axi_gpio_in2[7:0] = read_cmd_counter; // Debug

  axi4_write_data axi4_write_data(
    .clk(c0_ddr4_clk),
    .rst(c0_ddr4_rst),
    .S_AXIS_TDATA(s_axis_h2c_tdata_0),
    .S_AXIS_TVALID(s_axis_h2c_tvalid_0),
    .S_AXIS_TREADY(s_axis_h2c_tready_0),
    .ddr_wdata(ddr_wdata)
  );
  // assign axi_gpio_in[10:3] = ddr_wdata[7:0]; // Debug

  axi4_instr axi4_instr(
    .clk(c0_ddr4_clk),
    .rst(c0_ddr4_rst),
    .S_AXIS_TDATA(s_axis_h2c_tdata_1),
    .S_AXIS_TVALID(s_axis_h2c_tvalid_1),
    .S_AXIS_TREADY(s_axis_h2c_tready_1),
    // .latest_instr_id(axi_gpio_in[2:0]), // Debug
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
    .ddr_row(ddr_row)
  );

  reg [8:0] debug1, debug2;
  reg [15:0] debug3;
  always @(posedge c0_ddr4_clk) begin
    if (c0_ddr4_rst) begin
      debug1 <= 9'd0;
      debug2 <= 9'd0;
      debug3 <= 16'd0;
    end else begin
      debug1[8:1] <= {ddr_pre, ddr_nop};
      debug1[0] <= (ddr_nop != 4'b1111);
      debug2 <= debug1;

      if (debug1[0]) begin
        debug3 <= {debug2[8:1], debug1[8:1]};
      end
    end
  end

  assign axi_gpio_in2[23:8] = debug3[15:0]; // Debug
  assign axi_gpio_in2[27:24] = ddr_nop; // Debug
  assign axi_gpio_in2[31] = 1'b1;
endmodule
