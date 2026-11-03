module clock_converter(
    input wire sdr_clk_o,  // 单端时钟输入
    output wire ddr3_ck_p, // 差分时钟正相
    output wire ddr3_ck_n  // 差分时钟反相
);

// 使用 MMCM 生成差分时钟
    wire                        mmcm_clk_out;
    wire                        mmcm_clk_fb;

    MMCME2_BASE #(
        .CLKIN1_PERIOD(10.0),
        .CLKFBOUT_MULT_F(10.0),
        .CLKOUT0_DIVIDE_F(10.0)
    ) mmcm_inst (
        .CLKIN1(sdr_clk_o),
        .CLKFBIN(mmcm_clk_fb),
        .CLKFBOUT(mmcm_clk_fb),
        .CLKOUT0(mmcm_clk_out),
        .PWRDWN(1'b0),
        .RST(1'b0)
    );

    // 使用 OBUFDS 原语生成差分时钟
    OBUFDS #(
        .IOSTANDARD("DIFF_SSTL15")
    ) obufds_inst (
        .O (ddr3_ck_p),
        .OB (ddr3_ck_n),
        .I (mmcm_clk_out)
    );

endmodule