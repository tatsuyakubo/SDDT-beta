`include "parameters.vh"
`include "project.vh"

module top #(parameter tCK = 1500, SIM = "false")
  (
  // // common signals
  // input c0_sys_clk_p,
  // input c0_sys_clk_n,
  // input sys_rst,
  
  // // iob <> ddr4 sdram ip signals
  // output             c0_ddr4_act_n,
  // output [`ROW_ADDR_WIDTH-1:0]      c0_ddr4_adr,
  // output [1:0]       c0_ddr4_ba,
  // output [1:0]       c0_ddr4_bg,
  // output [`CKE_WIDTH-1:0]       c0_ddr4_cke,
  // output [`ODT_WIDTH-1:0]       c0_ddr4_odt,
  // output [`CS_WIDTH-1:0]        c0_ddr4_cs_n,
  // output [`CK_WIDTH-1:0]       c0_ddr4_ck_t,
  // output [`CK_WIDTH-1:0]       c0_ddr4_ck_c,
  // output             c0_ddr4_reset_n,

  // // UDIMM_x8
  // inout  [7:0]      c0_ddr4_dqs_c,
  // inout  [7:0]      c0_ddr4_dqs_t,
  // inout  [63:0]     c0_ddr4_dq,
  // inout  [7:0]      c0_ddr4_dm_dbi_n,  
  // output            c0_ddr4_parity,

  // output [3:0] user_led
  );
  
  // // UDIMM_x8
  // assign c0_ddr4_odt[1] = 1'b0;
  // assign c0_ddr4_cs_n[1] = 1'b1;
  // assign c0_ddr4_cke[1] = 1'b0;

  // PS Interface <->
  wire [127:0] M_AXIS_CMD_tdata;
  wire M_AXIS_CMD_tready;
  wire M_AXIS_CMD_tvalid;
  wire axi_aclk;
  wire [0:0] axi_resetn;
  wire [31:0] gpio2_io_i;

  // =========================================================================
  // PS Interface Instance
  // =========================================================================
  ps_interface ps_interface_i (
  .M_AXIS_CMD_tdata(M_AXIS_CMD_tdata),
  .M_AXIS_CMD_tready(M_AXIS_CMD_tready),
  .M_AXIS_CMD_tvalid(M_AXIS_CMD_tvalid),
  .axi_aclk(axi_aclk),
  .axi_resetn(axi_resetn),
  .gpio2_io_i(gpio2_io_i)
  );

  // =========================================================================
  // Xilinx XPM_FIFO_AXIS Instance
  // =========================================================================
  localparam FIFO_DEPTH = 16;
  localparam CMD_WIDTH = 128;
  localparam COUNT_WIDTH = $clog2(FIFO_DEPTH)+1;
  wire [COUNT_WIDTH-1:0] wr_data_count_axis;
  assign gpio2_io_i = {16'd13, {(16-COUNT_WIDTH){1'b0}}, wr_data_count_axis};
  xpm_fifo_axis #(
  .CLOCKING_MODE("independent_clock"),        // String
  .FIFO_DEPTH(FIFO_DEPTH),                    // DECIMAL
  .TDATA_WIDTH(CMD_WIDTH),                    // DECIMAL
  .USE_ADV_FEATURES("1004"),                  // String; 1004: Valid and enable wr_data_count
  .WR_DATA_COUNT_WIDTH(COUNT_WIDTH)           // DECIMAL
  )
  xpm_fifo_axis_i (
  // Master Interface
  .m_aclk(axi_aclk),                       // 1-bit input: Master Interface Clock: All signals on master interface are sampled on the rising edge
                                              // of this clock.
  .m_axis_tready(1'b0),                    // 1-bit input: TREADY: Indicates that the slave can accept a transfer in the current cycle.
  .m_axis_tdata(),                         // TDATA_WIDTH-bit output: TDATA: The primary payload that is used to provide the data that is passing
                                              // across the interface. The width of the data payload is an integer number of bytes.
  .m_axis_tvalid(),                        // 1-bit output: TVALID: Indicates that the master is driving a valid transfer. A transfer takes place
                                              // when both TVALID and TREADY are asserted
  // Slave Interface
  .s_aclk(axi_aclk),                       // 1-bit input: Slave Interface Clock: All signals on slave interface are sampled on the rising edge
                                              // of this clock.
  .s_aresetn(axi_resetn),                  // 1-bit input: Active low asynchronous reset.
  .s_axis_tready(M_AXIS_CMD_tready),       // 1-bit output: TREADY: Indicates that the slave can accept a transfer in the current cycle.
  .s_axis_tdata(M_AXIS_CMD_tdata),         // TDATA_WIDTH-bit input: TDATA: The primary payload that is used to provide the data that is passing
                                              // across the interface. The width of the data payload is an integer number of bytes.
  .s_axis_tvalid(M_AXIS_CMD_tvalid),       // 1-bit input: TVALID: Indicates that the master is driving a valid transfer. A transfer takes place
                                              // when both TVALID and TREADY are asserted
  // Status signals
  .wr_data_count_axis(wr_data_count_axis)  // WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates the number of words written
  );


  // // Frontend control signals
  // wire softmc_fin;
  // wire user_rst;  
  
  // // Frontend <-> misc. control signals
  // wire                        per_rd_init;
  // wire                        per_zq_init;
  // wire                        per_ref_init;
  // wire                        rbe_switch_mode;

  // // Clock and reset from sddt_core
  // wire                      dbg_clk;
  // wire                      c0_ddr4_clk;
  // wire                      c0_ddr4_rst;
  // wire [511:0]              dbg_bus;        
  // wire                      c0_init_calib_complete;
  
  // // Calibration complete register
  // reg c0_init_calib_complete_r, sys_rst_r;
  
  // always @(posedge c0_ddr4_clk) begin
  //   c0_init_calib_complete_r <= c0_init_calib_complete;
  //   sys_rst_r <= sys_rst;  
  // end
  
  // // PS Interface <-> SDDT Core interface wires
  // wire [511:0] M_AXIS_MM2S_0_tdata;
  // wire         M_AXIS_MM2S_0_tready;
  // wire         M_AXIS_MM2S_0_tvalid;
  // wire [511:0] S_AXIS_S2MM_0_tdata;
  // wire [63:0]  S_AXIS_S2MM_0_tkeep;
  // wire         S_AXIS_S2MM_0_tlast;
  // wire         S_AXIS_S2MM_0_tready;
  // wire         S_AXIS_S2MM_0_tvalid;
  // wire         axi_resetn;
  // wire [31:0]  axi_gpio_in;
  // wire [31:0]  axi_gpio_in2;
  // wire [31:0]  axi_gpio_out;
  // wire [127:0] M_AXIS_CMD_tdata;
  // wire         M_AXIS_CMD_tready;
  // wire         M_AXIS_CMD_tvalid;

  // // SDDT Core debug signals
  // wire         sddt_err;
  // wire [7:0]   sddt_latest_buf;
  // wire [9:0]   sddt_wdata_count;
  // wire [9:0]   sddt_rdata_count;

  // // =========================================================================
  // // SDDT Core Instance 
  // // (contains ddr_interface + cmd_scheduler)
  // // =========================================================================
  // sddt_core #(
  //   .DQ_WIDTH(`DQ_WIDTH),
  //   .CKE_WIDTH(`CKE_WIDTH),
  //   .CS_WIDTH(`CS_WIDTH),
  //   .ODT_WIDTH(`ODT_WIDTH),
  //   .ROW_ADDR_WIDTH(`ROW_ADDR_WIDTH),
  //   .CK_WIDTH(`CK_WIDTH),
  //   .BG_WIDTH(`BG_WIDTH),
  //   .BANK_WIDTH(`BANK_WIDTH),
  //   .COL_WIDTH(`COL_WIDTH),
  //   .ROW_WIDTH(`ROW_WIDTH)
  // ) sddt_core_i (
  //   // System signals
  //   .sys_rst              (sys_rst),
  //   .c0_sys_clk_p         (c0_sys_clk_p),
  //   .c0_sys_clk_n         (c0_sys_clk_n),
  //   .user_rst             (user_rst),
    
  //   // Clock and reset outputs
  //   .c0_ddr4_clk          (c0_ddr4_clk),
  //   .c0_ddr4_rst          (c0_ddr4_rst),
  //   .c0_init_calib_complete(c0_init_calib_complete),
  //   .dbg_clk              (dbg_clk),
  //   .dbg_bus              (dbg_bus),
    
  //   // DDR4 SDRAM interface
  //   .c0_ddr4_act_n        (c0_ddr4_act_n),
  //   .c0_ddr4_adr          (c0_ddr4_adr),
  //   .c0_ddr4_ba           (c0_ddr4_ba),
  //   .c0_ddr4_bg           (c0_ddr4_bg),
  //   .c0_ddr4_cke          (c0_ddr4_cke[0]),
  //   .c0_ddr4_odt          (c0_ddr4_odt[0]),
  //   .c0_ddr4_cs_n         (c0_ddr4_cs_n[0]),
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
    
  //   // Periodic maintenance
  //   .per_rd_init          (per_rd_init),
    
  //   // AXI Stream C2H (to DMA S2MM)
  //   .M_AXIS_C2H_tdata     (S_AXIS_S2MM_0_tdata),
  //   .M_AXIS_C2H_tvalid    (S_AXIS_S2MM_0_tvalid),
  //   .M_AXIS_C2H_tkeep     (S_AXIS_S2MM_0_tkeep),
  //   .M_AXIS_C2H_tlast     (S_AXIS_S2MM_0_tlast),
  //   .M_AXIS_C2H_tready    (S_AXIS_S2MM_0_tready),
    
  //   // AXI Stream H2C Interface 0 (from DMA MM2S_0 - Write Data)
  //   .S_AXIS_H2C_0_tdata   (M_AXIS_MM2S_0_tdata),
  //   .S_AXIS_H2C_0_tvalid  (M_AXIS_MM2S_0_tvalid),
  //   .S_AXIS_H2C_0_tready  (M_AXIS_MM2S_0_tready),
    
  //   // AXI Stream Command Interface
  //   .S_AXIS_CMD_tdata   (M_AXIS_CMD_tdata),
  //   .S_AXIS_CMD_tvalid  (M_AXIS_CMD_tvalid),
  //   .S_AXIS_CMD_tready  (M_AXIS_CMD_tready),
    
  //   // Debug ports
  //   .err                  (sddt_err),
  //   .latest_buf           (sddt_latest_buf),
  //   .wdata_count          (sddt_wdata_count),
  //   .rdata_count          (sddt_rdata_count)
  // );
  
  // // Control signal assignments
  // assign user_rst = 1'b0;
  // assign per_rd_init = 1'b0;
  // assign per_zq_init = 1'b0;
  // assign per_ref_init = 1'b0;
  // assign rbe_switch_mode = 1'b0;

  // wire [31:0] cmd_data_fifo_count;

  // // =========================================================================
  // // PS Interface Instance (DMA Controller)
  // // =========================================================================
  // ps_interface ps_interface_i (

  //   .M_AXIS_MM2S_0_tdata  (M_AXIS_MM2S_0_tdata),
  //   .M_AXIS_MM2S_0_tready (M_AXIS_MM2S_0_tready),
  //   .M_AXIS_MM2S_0_tvalid (M_AXIS_MM2S_0_tvalid),

  //   .M_AXIS_CMD_tdata  (M_AXIS_CMD_tdata),
  //   .M_AXIS_CMD_tkeep  (M_AXIS_CMD_tkeep),
  //   .M_AXIS_CMD_tlast  (M_AXIS_CMD_tlast),
  //   .M_AXIS_CMD_tready (M_AXIS_CMD_tready),
  //   .M_AXIS_CMD_tvalid (M_AXIS_CMD_tvalid),
  //   .cmd_data_fifo_count  (cmd_data_fifo_count),

  //   .S_AXIS_S2MM_0_tdata  (S_AXIS_S2MM_0_tdata),
  //   .S_AXIS_S2MM_0_tkeep  (S_AXIS_S2MM_0_tkeep),
  //   .S_AXIS_S2MM_0_tlast  (S_AXIS_S2MM_0_tlast),
  //   .S_AXIS_S2MM_0_tready (S_AXIS_S2MM_0_tready),
  //   .S_AXIS_S2MM_0_tvalid (S_AXIS_S2MM_0_tvalid),
  //   .axi_resetn           (axi_resetn),
  //   .c0_ddr4_clk          (c0_ddr4_clk),
  //   .axi_gpio_in          (axi_gpio_in),
  //   .axi_gpio_in2         (axi_gpio_in2),
  //   .axi_gpio_out         (axi_gpio_out)
  // );

  // // =========================================================================
  // // User LED - Clock Counter
  // // =========================================================================
  // reg [31:0] c0_ddr4_clk_counter;
  // always @(posedge c0_ddr4_clk) begin
  //   c0_ddr4_clk_counter <= c0_ddr4_clk_counter + 1;
  // end
  // assign user_led = c0_ddr4_clk_counter[23:20];

  // // =========================================================================
  // // Debug Logic
  // // =========================================================================
  // reg [7:0] handshake_counter;
  // reg [7:0] read_en_counter;
  
  // always @(posedge c0_ddr4_clk) begin
  //   if (c0_ddr4_rst) begin
  //     handshake_counter <= 8'd0;
  //     read_en_counter <= 8'd0;
  //   end else begin
  //     if (S_AXIS_S2MM_0_tvalid && S_AXIS_S2MM_0_tready) begin
  //       handshake_counter <= handshake_counter + 1;
  //     end
  //   end
  // end

  // // GPIO debug assignments
  // assign axi_gpio_in[0] = sddt_err;
  // assign axi_gpio_in[8:1] = handshake_counter;
  // assign axi_gpio_in[16:9] = 8'b0;
  // assign axi_gpio_in[24:17] = sddt_latest_buf;
  // assign axi_gpio_in[31:25] = 7'b0;
  
  // assign axi_gpio_in2[7:0] = sddt_wdata_count[7:0];
  // assign axi_gpio_in2[15:8] = sddt_rdata_count[7:0];
  // assign axi_gpio_in2[23:16] = cmd_data_fifo_count[7:0];

endmodule
