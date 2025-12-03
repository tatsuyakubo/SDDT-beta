set_property DRIVE 8 [get_ports c0_ddr4_reset_n]
create_clock -period 3.333 [get_ports c0_sys_clk_p]
set_clock_groups -asynchronous -group [get_clocks c0_sys_clk_p -include_generated_clocks]
#create_clock -period 10.000 -name refclk_100 [get_ports clk_ref_p]
#set_clock_groups -asynchronous -group [get_clocks refclk_100 -include_generated_clocks]

set_property -dict {PACKAGE_PIN AC17  IOSTANDARD SSTL12_DCI} [get_ports c0_ddr4_act_n    ]; #

set_property -dict {PACKAGE_PIN AH16  IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_adr[0]   ]; #
set_property -dict {PACKAGE_PIN AG14  IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_adr[1]   ]; #
set_property -dict {PACKAGE_PIN AG15  IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_adr[2]   ]; #
set_property -dict {PACKAGE_PIN AF15  IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_adr[3]   ]; #
set_property -dict {PACKAGE_PIN AF16  IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_adr[4]   ]; #
set_property -dict {PACKAGE_PIN AJ14  IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_adr[5]   ]; #
set_property -dict {PACKAGE_PIN AH14  IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_adr[6]   ]; #
set_property -dict {PACKAGE_PIN AF17  IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_adr[7]   ]; #
set_property -dict {PACKAGE_PIN AK17  IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_adr[8]   ]; #
set_property -dict {PACKAGE_PIN AJ17  IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_adr[9]   ]; #
set_property -dict {PACKAGE_PIN AK14  IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_adr[10]  ]; #
set_property -dict {PACKAGE_PIN AK15  IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_adr[11]  ]; #
set_property -dict {PACKAGE_PIN AL18  IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_adr[12]  ]; #
set_property -dict {PACKAGE_PIN AK18  IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_adr[13]  ]; #
set_property -dict {PACKAGE_PIN AA16  IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_adr[14]  ]; #
set_property -dict {PACKAGE_PIN AA14  IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_adr[15]  ]; #
set_property -dict {PACKAGE_PIN AD15  IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_adr[16]  ]; #

set_property -dict {PACKAGE_PIN AE24 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[0]    ];
set_property -dict {PACKAGE_PIN AE23 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[1]    ];
set_property -dict {PACKAGE_PIN AF22 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[2]    ];
set_property -dict {PACKAGE_PIN AF21 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[3]    ];
set_property -dict {PACKAGE_PIN AG20 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[4]    ];
set_property -dict {PACKAGE_PIN AG19 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[5]    ];
set_property -dict {PACKAGE_PIN AH21 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[6]    ];
set_property -dict {PACKAGE_PIN AG21 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[7]    ];
set_property -dict {PACKAGE_PIN AA20 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[8]    ];
set_property -dict {PACKAGE_PIN AA19 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[9]    ];
set_property -dict {PACKAGE_PIN AD19 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[10]   ];
set_property -dict {PACKAGE_PIN AC18 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[11]   ];
set_property -dict {PACKAGE_PIN AE20 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[12]   ];
set_property -dict {PACKAGE_PIN AD20 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[13]   ];
set_property -dict {PACKAGE_PIN AC19 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[14]   ];
set_property -dict {PACKAGE_PIN AB19 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[15]   ];

set_property -dict {PACKAGE_PIN AJ22  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[16]   ];
set_property -dict {PACKAGE_PIN AJ21  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[17]   ];
set_property -dict {PACKAGE_PIN AK20  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[18]   ];
set_property -dict {PACKAGE_PIN AJ20  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[19]   ];
set_property -dict {PACKAGE_PIN AK19  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[20]   ];
set_property -dict {PACKAGE_PIN AJ19  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[21]   ];
set_property -dict {PACKAGE_PIN AL23  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[22]   ];
set_property -dict {PACKAGE_PIN AL22  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[23]   ];
set_property -dict {PACKAGE_PIN AN23  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[24]   ];
set_property -dict {PACKAGE_PIN AM23  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[25]   ];
set_property -dict {PACKAGE_PIN AP23  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[26]   ];
set_property -dict {PACKAGE_PIN AN22  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[27]   ];
set_property -dict {PACKAGE_PIN AP22  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[28]   ];
set_property -dict {PACKAGE_PIN AP21  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[29]   ];
set_property -dict {PACKAGE_PIN AN19  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[30]   ];
set_property -dict {PACKAGE_PIN AM19  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[31]   ];

set_property -dict {PACKAGE_PIN AC13  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[32]   ];
set_property -dict {PACKAGE_PIN AB13  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[33]   ];
set_property -dict {PACKAGE_PIN AF12  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[34]   ];
set_property -dict {PACKAGE_PIN AE12  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[35]   ];
set_property -dict {PACKAGE_PIN AF13  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[36]   ];
set_property -dict {PACKAGE_PIN AE13  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[37]   ];
set_property -dict {PACKAGE_PIN AE14  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[38]   ];
set_property -dict {PACKAGE_PIN AD14  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[39]   ];
set_property -dict {PACKAGE_PIN AG8   IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[40]   ];
set_property -dict {PACKAGE_PIN AF8   IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[41]   ];
set_property -dict {PACKAGE_PIN AG10  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[42]   ];
set_property -dict {PACKAGE_PIN AG11  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[43]   ];
set_property -dict {PACKAGE_PIN AH13  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[44]   ];
set_property -dict {PACKAGE_PIN AG13  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[45]   ];
set_property -dict {PACKAGE_PIN AJ11  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[46]   ];
set_property -dict {PACKAGE_PIN AH11  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[47]   ];

set_property -dict {PACKAGE_PIN AK9  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[48]   ];
set_property -dict {PACKAGE_PIN AJ9  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[49]   ];
set_property -dict {PACKAGE_PIN AK10 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[50]   ];
set_property -dict {PACKAGE_PIN AJ10 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[51]   ];
set_property -dict {PACKAGE_PIN AL12 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[52]   ];
set_property -dict {PACKAGE_PIN AK12 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[53]   ];
set_property -dict {PACKAGE_PIN AL10 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[54]   ];
set_property -dict {PACKAGE_PIN AL11 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[55]   ];
set_property -dict {PACKAGE_PIN AM8  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[56]   ];
set_property -dict {PACKAGE_PIN AM9  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[57]   ];
set_property -dict {PACKAGE_PIN AM10 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[58]   ];
set_property -dict {PACKAGE_PIN AM11 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[59]   ];
set_property -dict {PACKAGE_PIN AP11 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[60]   ];
set_property -dict {PACKAGE_PIN AN11 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[61]   ];
set_property -dict {PACKAGE_PIN AP9  IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[62]   ];
set_property -dict {PACKAGE_PIN AP10 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dq[63]   ];



set_property -dict {PACKAGE_PIN AH22 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dm_dbi_n[0]];
set_property -dict {PACKAGE_PIN AE18 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dm_dbi_n[1]];
set_property -dict {PACKAGE_PIN AL20 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dm_dbi_n[2]];
set_property -dict {PACKAGE_PIN AP19 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dm_dbi_n[3]];
set_property -dict {PACKAGE_PIN AF11 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dm_dbi_n[4]];
set_property -dict {PACKAGE_PIN AH12 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dm_dbi_n[5]];
set_property -dict {PACKAGE_PIN AK13 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dm_dbi_n[6]];
set_property -dict {PACKAGE_PIN AN12 IOSTANDARD POD12_DCI } [get_ports c0_ddr4_dm_dbi_n[7]];


set_property -dict {PACKAGE_PIN AG23 IOSTANDARD DIFF_POD12_DCI } [get_ports c0_ddr4_dqs_c[0]];
set_property -dict {PACKAGE_PIN AF23 IOSTANDARD DIFF_POD12_DCI } [get_ports c0_ddr4_dqs_t[0]];
set_property -dict {PACKAGE_PIN AB18 IOSTANDARD DIFF_POD12_DCI } [get_ports c0_ddr4_dqs_c[1]];
set_property -dict {PACKAGE_PIN AA18 IOSTANDARD DIFF_POD12_DCI } [get_ports c0_ddr4_dqs_t[1]];
set_property -dict {PACKAGE_PIN AK23 IOSTANDARD DIFF_POD12_DCI } [get_ports c0_ddr4_dqs_c[2]];
set_property -dict {PACKAGE_PIN AK22 IOSTANDARD DIFF_POD12_DCI } [get_ports c0_ddr4_dqs_t[2]];
set_property -dict {PACKAGE_PIN AN21 IOSTANDARD DIFF_POD12_DCI } [get_ports c0_ddr4_dqs_c[3]];
set_property -dict {PACKAGE_PIN AM21 IOSTANDARD DIFF_POD12_DCI } [get_ports c0_ddr4_dqs_t[3]];
set_property -dict {PACKAGE_PIN AD12 IOSTANDARD DIFF_POD12_DCI } [get_ports c0_ddr4_dqs_c[4]];
set_property -dict {PACKAGE_PIN AC12 IOSTANDARD DIFF_POD12_DCI } [get_ports c0_ddr4_dqs_t[4]];
set_property -dict {PACKAGE_PIN AH9  IOSTANDARD DIFF_POD12_DCI } [get_ports c0_ddr4_dqs_c[5]];
set_property -dict {PACKAGE_PIN AG9  IOSTANDARD DIFF_POD12_DCI } [get_ports c0_ddr4_dqs_t[5]];
set_property -dict {PACKAGE_PIN AL8  IOSTANDARD DIFF_POD12_DCI } [get_ports c0_ddr4_dqs_c[6]];
set_property -dict {PACKAGE_PIN AK8  IOSTANDARD DIFF_POD12_DCI } [get_ports c0_ddr4_dqs_t[6]];
set_property -dict {PACKAGE_PIN AN8  IOSTANDARD DIFF_POD12_DCI } [get_ports c0_ddr4_dqs_c[7]];
set_property -dict {PACKAGE_PIN AN9  IOSTANDARD DIFF_POD12_DCI } [get_ports c0_ddr4_dqs_t[7]];

set_property -dict {PACKAGE_PIN AL15 IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_ba[0]];
set_property -dict {PACKAGE_PIN AL16 IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_ba[1]];
set_property -dict {PACKAGE_PIN AC16 IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_bg[0]];
set_property -dict {PACKAGE_PIN AB16 IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_bg[1]];

set_property -dict {PACKAGE_PIN AE15 IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_odt[0]];
set_property -dict {PACKAGE_PIN AM16 IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_odt[1]];

set_property -dict {PACKAGE_PIN AG18 IOSTANDARD DIFF_SSTL12_DCI} [get_ports c0_ddr4_ck_c[0]];
set_property -dict {PACKAGE_PIN AF18 IOSTANDARD DIFF_SSTL12_DCI} [get_ports c0_ddr4_ck_t[0]];
# set_property -dict {PACKAGE_PIN AJ16 IOSTANDARD DIFF_SSTL12_DCI} [get_ports c0_ddr4_ck_c[1]];
# set_property -dict {PACKAGE_PIN AJ15 IOSTANDARD DIFF_SSTL12_DCI} [get_ports c0_ddr4_ck_t[1]];

set_property -dict {PACKAGE_PIN AD17  IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_cke[0]];
set_property -dict {PACKAGE_PIN AM15  IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_cke[1]];

set_property -dict {PACKAGE_PIN AA15 IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_cs_n[0]];
set_property -dict {PACKAGE_PIN AL17 IOSTANDARD SSTL12_DCI } [get_ports c0_ddr4_cs_n[1]];

set_property -dict {PACKAGE_PIN AH17  IOSTANDARD DIFF_SSTL12 } [get_ports c0_sys_clk_n    ]; # POD12_DCI?
set_property -dict {PACKAGE_PIN AH18  IOSTANDARD DIFF_SSTL12 } [get_ports c0_sys_clk_p    ]; # POD12_DCI?

set_property -dict {PACKAGE_PIN AD16  IOSTANDARD SSTL12_DCI  } [get_ports c0_ddr4_parity  ];
set_property -dict {PACKAGE_PIN AB14  IOSTANDARD LVCMOS12    } [get_ports c0_ddr4_reset_n ];

set_property -dict {PACKAGE_PIN M11 IOSTANDARD LVCMOS33    } [get_ports sys_rst ]; # CPU_RESET, active high
#set_property -dict {PACKAGE_PIN M11 IOSTANDARD LVCMOS33    } [get_ports sys_rst_l ];

set_property -dict {PACKAGE_PIN D5 IOSTANDARD LVCMOS33 } [get_ports user_led[0]];
set_property -dict {PACKAGE_PIN D6 IOSTANDARD LVCMOS33 } [get_ports user_led[1]];
set_property -dict {PACKAGE_PIN A5 IOSTANDARD LVCMOS33 } [get_ports user_led[2]];
set_property -dict {PACKAGE_PIN B5 IOSTANDARD LVCMOS33 } [get_ports user_led[3]];
      
