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
  `elsif UDIMM_x8
  assign c0_ddr4_odt[1] = 1'b0;
  assign c0_ddr4_cs_n[1] = 1'b1;
  assign c0_ddr4_cke[1] = 1'b0;
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

  // AXI streaming ports (directly between design_1 and sddt_core)
  wire [511:0]   m_axis_c2h_tdata;
  wire           m_axis_c2h_tlast;
  wire           m_axis_c2h_tvalid;
  wire           m_axis_c2h_tready;
  wire [63:0]    m_axis_c2h_tkeep;
 
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
  wire ddr4_ui_clk;
  wire c0_ddr4_dll_off_clk;
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

  // Read data from PHY wrapper
  wire [511:0]              rdData;
  wire [0:0]                rdDataEn;
  
  // CAS signals from PHY wrapper
  wire [0:0]                mcRdCAS;
  wire [0:0]                mcWrCAS;
  
  wire                      dbg_clk;
  wire                      c0_wr_rd_complete;
  wire                      c0_ddr4_clk;
  wire                      c0_ddr4_rst;
  wire [511:0]              dbg_bus;        
  wire                      gt_data_ready;
  
  wire         read_seq_incoming;
  wire [11:0]  incoming_reads;
  wire [11:0]  buffer_space;
 
  wire c0_init_calib_complete;
  
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

  // =========================================================================
  // PHY Wrapper Instance (contains phy_ddr4_i, ddr4_adapter, u_ddr_tb_odt)
  // =========================================================================
  phy_wrapper #(
    .DQ_WIDTH(`DQ_WIDTH),
    .CKE_WIDTH(`CKE_WIDTH),
    .CS_WIDTH(`CS_WIDTH),
    .ODT_WIDTH(`ODT_WIDTH),
    .ROW_ADDR_WIDTH(`ROW_ADDR_WIDTH),
    .CK_WIDTH(`CK_WIDTH),
    .BG_WIDTH(`BG_WIDTH),
    .BANK_WIDTH(`BANK_WIDTH),
    .COL_WIDTH(`COL_WIDTH),
    .ROW_WIDTH(`ROW_WIDTH)
  ) phy_wrapper_i (
    // System signals
    .sys_rst              (sys_rst),
    .c0_sys_clk_p         (c0_sys_clk_p),
    .c0_sys_clk_n         (c0_sys_clk_n),
    .user_rst             (user_rst),
    
    // Clock and reset outputs
    `ifdef ENABLE_DLL_TOGGLER
    .c0_ddr4_clk          (c0_ddr4_clk),
    .ddr4_ui_clk          (ddr4_ui_clk),
    .c0_ddr4_dll_off_clk  (c0_ddr4_dll_off_clk),
    `else
    .c0_ddr4_clk          (c0_ddr4_clk),
    `endif
    .c0_ddr4_rst          (c0_ddr4_rst),
    .c0_init_calib_complete(c0_init_calib_complete),
    .dbg_clk              (dbg_clk),
    .dbg_bus              (dbg_bus),
    
    // DDR4 SDRAM interface
    .c0_ddr4_act_n        (c0_ddr4_act_n),
    .c0_ddr4_adr          (c0_ddr4_adr),
    .c0_ddr4_ba           (c0_ddr4_ba),
    .c0_ddr4_bg           (c0_ddr4_bg),
    .c0_ddr4_cke          (c0_ddr4_cke[0]),
    .c0_ddr4_odt          (c0_ddr4_odt[0]),
    .c0_ddr4_cs_n         (c0_ddr4_cs_n[0]),
    .c0_ddr4_ck_t         (c0_ddr4_ck_t),
    .c0_ddr4_ck_c         (c0_ddr4_ck_c),
    .c0_ddr4_reset_n      (c0_ddr4_reset_n),
    `ifdef RDIMM_x4
    .c0_ddr4_parity       (c0_ddr4_parity),
    .c0_ddr4_dq           (c0_ddr4_dq),
    .c0_ddr4_dqs_c        (c0_ddr4_dqs_c),
    .c0_ddr4_dqs_t        (c0_ddr4_dqs_t),
    `elsif UDIMM_x8
    .c0_ddr4_parity       (c0_ddr4_parity),
    .c0_ddr4_dq           (c0_ddr4_dq),
    .c0_ddr4_dqs_c        (c0_ddr4_dqs_c),
    .c0_ddr4_dqs_t        (c0_ddr4_dqs_t),
    .c0_ddr4_dm_dbi_n     (c0_ddr4_dm_dbi_n),
    `elsif RDIMM_x8
    .c0_ddr4_parity       (c0_ddr4_parity),
    .c0_ddr4_dq           (c0_ddr4_dq),
    .c0_ddr4_dqs_c        (c0_ddr4_dqs_c),
    .c0_ddr4_dqs_t        (c0_ddr4_dqs_t),
    .c0_ddr4_dm_dbi_n     (c0_ddr4_dm_dbi_n),
    `endif
    
    // DDR command interface
    .ddr_write            (ddr_write),
    .ddr_read             (ddr_read),
    .ddr_pre              (ddr_pre),
    .ddr_act              (ddr_act),
    .ddr_ref              (ddr_ref),
    .ddr_zq               (ddr_zq),
    .ddr_nop              (ddr_nop),
    .ddr_ap               (ddr_ap),
    .ddr_pall             (ddr_pall),
    .ddr_half_bl          (ddr_half_bl),
    .ddr_bg               (ddr_bg),
    .ddr_bank             (ddr_bank),
    .ddr_col              (ddr_col),
    .ddr_row              (ddr_row),
    .ddr_wdata            (ddr_wdata),
    
    // Periodic maintenance
    .per_rd_init          (per_rd_init),
    
    // Read data interface
    .rdData               (rdData),
    .rdDataEn             (rdDataEn),
    
    // DLL toggler interface
    .dllt_active          (dllt_active),
    .dllt_mc_ACT_n        (dllt_mc_ACT_n),
    .dllt_mc_ADR          (dllt_mc_ADR),
    .dllt_mc_BA           (dllt_mc_BA),
    .dllt_mc_BG           (dllt_mc_BG),
    .dllt_mc_CKE          (dllt_mc_CKE),
    .dllt_mc_CS_n         (dllt_mc_CS_n),
    
    // CAS signals
    .mcRdCAS              (mcRdCAS),
    .mcWrCAS              (mcWrCAS)
  );
  
  `ifdef ENABLE_DLL_TOGGLER
  BUFGMUX #(.CLK_SEL_TYPE("SYNC"))
  BUFGMUX_inst (
    .O  (c0_ddr4_clk),
    .I0 (ddr4_ui_clk),
    .I1 (c0_ddr4_dll_off_clk),
    .S  (clk_sel)
  );
  `endif
 
  wire frontend_ready;
  
  assign user_rst = 1'b0;
  assign dllt_begin = 1'b0;
  assign frontend_ready = 1'b0;
  assign per_rd_init = 1'b0;
  assign per_zq_init = 1'b0;
  assign per_ref_init = 1'b0;
  assign rbe_switch_mode = 1'b0;

  wire sys_clk, sys_clk_gt;
  wire [2:0]    msi_vector_width;
  wire          msi_enable;
  wire          user_lnk_up, usr_irq_req, usr_irq_ack;

  // Design_1 <-> SDDT Core interface wires
  wire [511:0] M_AXIS_MM2S_0_tdata;
  wire         M_AXIS_MM2S_0_tready;
  wire         M_AXIS_MM2S_0_tvalid;
  wire [511:0] S_AXIS_S2MM_0_tdata;
  wire [63:0]  S_AXIS_S2MM_0_tkeep;
  wire         S_AXIS_S2MM_0_tlast;
  wire         S_AXIS_S2MM_0_tready;
  wire         S_AXIS_S2MM_0_tvalid;
  wire         axi_resetn;
  wire [31:0]  axi_gpio_in;
  wire [31:0]  axi_gpio_in2;
  wire [31:0]  axi_gpio_out;
  wire [511:0] M_AXIS_MM2S_1_tdata;
  wire         M_AXIS_MM2S_1_tready;
  wire         M_AXIS_MM2S_1_tvalid;

  // SDDT Core debug signals
  wire         sddt_err;
  wire [7:0]   sddt_latest_buf;

  // =========================================================================
  // Design_1 Instance (DMA Controller)
  // =========================================================================
  design_1 design_1_i (
    .M_AXIS_MM2S_0_tdata  (M_AXIS_MM2S_0_tdata),
    .M_AXIS_MM2S_0_tready (M_AXIS_MM2S_0_tready),
    .M_AXIS_MM2S_0_tvalid (M_AXIS_MM2S_0_tvalid),
    .M_AXIS_MM2S_1_tdata  (M_AXIS_MM2S_1_tdata),
    .M_AXIS_MM2S_1_tready (M_AXIS_MM2S_1_tready),
    .M_AXIS_MM2S_1_tvalid (M_AXIS_MM2S_1_tvalid),
    .S_AXIS_S2MM_0_tdata  (S_AXIS_S2MM_0_tdata),
    .S_AXIS_S2MM_0_tkeep  (S_AXIS_S2MM_0_tkeep),
    .S_AXIS_S2MM_0_tlast  (S_AXIS_S2MM_0_tlast),
    .S_AXIS_S2MM_0_tready (S_AXIS_S2MM_0_tready),
    .S_AXIS_S2MM_0_tvalid (S_AXIS_S2MM_0_tvalid),
    .axi_resetn           (axi_resetn),
    .c0_ddr4_clk          (c0_ddr4_clk),
    .axi_gpio_in          (axi_gpio_in),
    .axi_gpio_in2         (axi_gpio_in2),
    .axi_gpio_out         (axi_gpio_out)
  );

  // =========================================================================
  // SDDT Core Instance (contains axi4_read_data, axi4_write_data, axi4_instr)
  // =========================================================================
  sddt_core sddt_core_i (
    // Clock and Reset
    .clk                  (c0_ddr4_clk),
    .rst                  (c0_ddr4_rst),
    
    // DDR Read Data Interface (from PHY)
    .rd_data              (rdData),
    .rd_valid             (rdDataEn),
    
    // DDR Write Data Interface (to PHY)
    .ddr_wdata            (ddr_wdata),
    
    // DDR Command Interface (to PHY)
    .ddr_write            (ddr_write),
    .ddr_read             (ddr_read),
    .ddr_pre              (ddr_pre),
    .ddr_act              (ddr_act),
    .ddr_ref              (ddr_ref),
    .ddr_zq               (ddr_zq),
    .ddr_nop              (ddr_nop),
    .ddr_ap               (ddr_ap),
    .ddr_half_bl          (ddr_half_bl),
    .ddr_pall             (ddr_pall),
    .ddr_bg               (ddr_bg),
    .ddr_bank             (ddr_bank),
    .ddr_col              (ddr_col),
    .ddr_row              (ddr_row),
    
    // AXI Stream C2H (to DMA S2MM)
    .M_AXIS_C2H_tdata     (S_AXIS_S2MM_0_tdata),
    .M_AXIS_C2H_tvalid    (S_AXIS_S2MM_0_tvalid),
    .M_AXIS_C2H_tkeep     (S_AXIS_S2MM_0_tkeep),
    .M_AXIS_C2H_tlast     (S_AXIS_S2MM_0_tlast),
    .M_AXIS_C2H_tready    (S_AXIS_S2MM_0_tready),
    
    // AXI Stream H2C Interface 0 (from DMA MM2S_0 - Write Data)
    .S_AXIS_H2C_0_tdata   (M_AXIS_MM2S_0_tdata),
    .S_AXIS_H2C_0_tvalid  (M_AXIS_MM2S_0_tvalid),
    .S_AXIS_H2C_0_tready  (M_AXIS_MM2S_0_tready),
    
    // AXI Stream H2C Interface 1 (from DMA MM2S_1 - Instructions)
    .S_AXIS_H2C_1_tdata   (M_AXIS_MM2S_1_tdata),
    .S_AXIS_H2C_1_tvalid  (M_AXIS_MM2S_1_tvalid),
    .S_AXIS_H2C_1_tready  (M_AXIS_MM2S_1_tready),
    
    // Debug ports
    .err                  (sddt_err),
    .latest_buf           (sddt_latest_buf)
  );

  assign buffer_space = 11'b0;

  `ifdef ENABLE_DLL_TOGGLER
  dll_toggler dllt (
    .clk          (c0_ddr4_clk),
    .rst          (c0_ddr4_rst || user_rst || ~c0_init_calib_complete_r),
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
  `endif

  // =========================================================================
  // User LED - Clock Counter
  // =========================================================================
  reg [31:0] c0_ddr4_clk_counter;
  always @(posedge c0_ddr4_clk) begin
    c0_ddr4_clk_counter <= c0_ddr4_clk_counter + 1;
  end
  assign user_led = c0_ddr4_clk_counter[23:20];

  // =========================================================================
  // Debug Logic
  // =========================================================================
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
      if (S_AXIS_S2MM_0_tvalid) begin
        latest_valid_data <= S_AXIS_S2MM_0_tdata[7:0];
      end
      if (S_AXIS_S2MM_0_tvalid && S_AXIS_S2MM_0_tready) begin
        latest_handshake_data <= S_AXIS_S2MM_0_tdata[7:0];
        handshake_counter <= handshake_counter + 1;
      end
      if (rdDataEn) begin
        read_en_counter <= read_en_counter + 1;
      end
      read_cmd_counter <= read_cmd_counter + ddr_read[0] + ddr_read[1] + ddr_read[2] + ddr_read[3];
    end
  end

  // GPIO debug assignments
  assign axi_gpio_in[0] = sddt_err;
  assign axi_gpio_in[8:1] = handshake_counter;
  assign axi_gpio_in[16:9] = read_en_counter;
  assign axi_gpio_in[24:17] = sddt_latest_buf;
  assign axi_gpio_in[31:25] = 7'b0;
  
  assign axi_gpio_in2[7:0] = read_cmd_counter;

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

  assign axi_gpio_in2[23:8] = debug3[15:0];
  assign axi_gpio_in2[27:24] = ddr_nop;
  assign axi_gpio_in2[31] = 1'b1;

endmodule
