`include "parameters.vh"
`include "project.vh"

module top #(parameter tCK = 1500, SIM = "false")
  (
  // common signals
  input                        c0_sys_clk_p,
  input                        c0_sys_clk_n,
  input                        sys_rst,
  
  // iob <> ddr4 sdram ip signals
  output                       c0_ddr4_act_n,
  output [`ROW_ADDR_WIDTH-1:0] c0_ddr4_adr,
  output [1:0]                 c0_ddr4_ba,
  output [1:0]                 c0_ddr4_bg,
  output [`CKE_WIDTH-1:0]      c0_ddr4_cke,
  output [`ODT_WIDTH-1:0]      c0_ddr4_odt,
  output [`CS_WIDTH-1:0]       c0_ddr4_cs_n,
  output [`CK_WIDTH-1:0]       c0_ddr4_ck_t,
  output [`CK_WIDTH-1:0]       c0_ddr4_ck_c,
  output                       c0_ddr4_reset_n,
  inout  [7:0]                 c0_ddr4_dqs_c,
  inout  [7:0]                 c0_ddr4_dqs_t,
  inout  [63:0]                c0_ddr4_dq,
  inout  [7:0]                 c0_ddr4_dm_dbi_n,  
  output                       c0_ddr4_parity

  // output [3:0] user_led
  );

  // PS Interface <-> SDDT Core interface wires
  wire         axi_aclk;
  wire         axi_aresetn;
  wire [127:0] axis_cmd_tdata;
  wire         axis_cmd_tready;
  wire         axis_cmd_tvalid;
  wire         axis_cmd_tlast;
  wire [511:0] axis_wdata_tdata;
  wire         axis_wdata_tready;
  wire         axis_wdata_tvalid;
  wire [511:0] axis_rdata_tdata;
  wire [63:0]  axis_rdata_tkeep;
  wire         axis_rdata_tlast;
  wire         axis_rdata_tvalid;
  wire         axis_rdata_tready;
  wire [31:0]  gpio_io_i;
  wire [31:0]  gpio2_io_o;

  // =========================================================================
  // PS Interface Instance
  // =========================================================================
  ps_interface ps_interface_i (
    // System signals
    .axi_aclk(axi_aclk),
    .axi_aresetn(axi_aresetn),
    // AXI Stream Command Interface
    .M_AXIS_CMD_tdata(axis_cmd_tdata),
    .M_AXIS_CMD_tready(axis_cmd_tready),
    .M_AXIS_CMD_tvalid(axis_cmd_tvalid),
    .M_AXIS_CMD_tlast(axis_cmd_tlast),
    // AXI Stream Write Data Interface
    .M_AXIS_WDATA_tdata(axis_wdata_tdata),
    .M_AXIS_WDATA_tready(axis_wdata_tready),
    .M_AXIS_WDATA_tvalid(axis_wdata_tvalid),
    // AXI Stream Read Data Interface
    .S_AXIS_RDATA_tdata(axis_rdata_tdata),
    .S_AXIS_RDATA_tlast(axis_rdata_tlast),
    .S_AXIS_RDATA_tkeep(axis_rdata_tkeep),
    .S_AXIS_RDATA_tvalid(axis_rdata_tvalid),
    .S_AXIS_RDATA_tready(axis_rdata_tready),
    // Debug signals
    .gpio_io_i(gpio_io_i),
    .gpio2_io_o(gpio2_io_o)
  );

  // =========================================================================
  // SDDT Core Instance
  // =========================================================================
  sddt_core sddt_core_i (
    // System signals
    .sys_rst(sys_rst),
    .c0_sys_clk_p(c0_sys_clk_p),
    .c0_sys_clk_n(c0_sys_clk_n),
    .axi_aclk(axi_aclk),
    .axi_aresetn(axi_aresetn),
    // DDR4 SDRAM interface
    .c0_ddr4_act_n(c0_ddr4_act_n),
    .c0_ddr4_adr(c0_ddr4_adr),
    .c0_ddr4_ba(c0_ddr4_ba),
    .c0_ddr4_bg(c0_ddr4_bg),
    .c0_ddr4_cke(c0_ddr4_cke),
    .c0_ddr4_odt(c0_ddr4_odt),
    .c0_ddr4_cs_n(c0_ddr4_cs_n),
    .c0_ddr4_ck_t(c0_ddr4_ck_t),
    .c0_ddr4_ck_c(c0_ddr4_ck_c),
    .c0_ddr4_reset_n(c0_ddr4_reset_n),
    .c0_ddr4_dqs_c(c0_ddr4_dqs_c),
    .c0_ddr4_dqs_t(c0_ddr4_dqs_t),
    .c0_ddr4_dq(c0_ddr4_dq),
    .c0_ddr4_dm_dbi_n(c0_ddr4_dm_dbi_n),
    .c0_ddr4_parity(c0_ddr4_parity),
    // Command FIFO interface
    .S_AXIS_CMD_tdata(axis_cmd_tdata),
    .S_AXIS_CMD_tvalid(axis_cmd_tvalid),
    .S_AXIS_CMD_tready(axis_cmd_tready),
    .S_AXIS_CMD_tlast(axis_cmd_tlast),
    // Write Data FIFO interface
    .S_AXIS_WDATA_tdata(axis_wdata_tdata),
    .S_AXIS_WDATA_tvalid(axis_wdata_tvalid),
    .S_AXIS_WDATA_tready(axis_wdata_tready),
    // Read Data FIFO interface
    .M_AXIS_RDATA_tdata(axis_rdata_tdata),
    .M_AXIS_RDATA_tkeep(axis_rdata_tkeep),
    .M_AXIS_RDATA_tlast(axis_rdata_tlast),
    .M_AXIS_RDATA_tvalid(axis_rdata_tvalid),
    .M_AXIS_RDATA_tready(axis_rdata_tready),
    // Debug signals
    .control(gpio2_io_o),
    .state(gpio_io_i)
  );

endmodule
