`include "defines.v"

module flash_top(
    //wishbone总线接口
    wb_clk_i,
    wb_rst_i,
    wb_adr_i,
    wb_dat_o,
    wb_dat_i,
    wb_sel_i,
    wb_we_i,
    wb_stb_i,
    wb_cyc_i,
    wb_ack_o,
    //FLash芯片接口
    flash_adr_o,
    flash_dat_i,
    flash_rst,
    flash_oe,
    flash_ce,
    flash_we
);

    input wire                      wb_clk_i;
    input wire                      wb_rst_i;
    input wire[31:0]                wb_adr_i;
    output reg[31:0]                wb_dat_o;
    input wire[31:0]                wb_dat_i;
    input wire[3:0]                 wb_sel_i;
    input wire                      wb_we_i;
    input wire                      wb_stb_i;
    input wire                      wb_cyc_i;
    output reg                      wb_ack_o;
    output reg[31:0]                flash_adr_o;
    input wire[7:0]                 flash_dat_i;
    output wire                     flash_rst;
    output wire                     flash_oe;
    output wire                     flash_ce;
    output wire                     flash_we;
    
    reg[3:0]                        waitstate;
    wire[1:0]                       adr_low;
    
    //如果Wishbone总线开始操作周期,那么设置变量wb_acc为1
    //而且，如果是读操作，那么涉案hi变量wb_rd为1
    wire wb_acc = wb_cyc_i & wb_stb_i;//WISHBONE access
    wire wb_rd = wb_acc & !wb_we_i;//WISHBONE read access
    
    //当变量wb_acc为1、wb_rd为1时，表示开始对Flash芯片的读操作
    //所以设置flash_ce、flash_oe都为0，也就是设置为有效
    assign flash_ce = !wb_acc;
    assign flash_oe = !wb_rd;
    
    //因为不涉及对Flash芯片的写操作.所以输出信号flash_we始终设置为1
    assign flash_we = 1'b1;
    
    assign flash_rst =  !wb_rst_i;
    
    always @(posedge wb_clk_i)begin
        if(wb_rst_i == 1'b1)begin
            waitstate<=4'h0;
            wb_ack_o<=1'b0;
        end else if(wb_acc == 1'b0)begin//wb_acc为0,表示没有访问请求
            waitstate<=4'h0;
            wb_ack_o<=1'b0;
            wb_dat_o<=32'h00000000;
        end else if(waitstate == 4'h0)begin//否则，有访问请求，开始读操作
            wb_ack_o<=1'b0;
            if(wb_acc)begin
                waitstate<=waitstate + 4'h1;
            end
            //给出要读取的第一个字节的地址
            flash_adr_o<={10'b0000000000,wb_adr_i[21:2],2'b00};
        end else begin
            //每个时钟周期将waitstate的值加1
            waitstate<=waitstate + 4'h1;
            
            if(waitstate == 4'h3)begin
                //经过3个时钟周期后，第一个字节读到，保存到wb_dat_o[31:24]
                wb_dat_o[31:24]<=flash_dat_i;
                //给出要读取的第二个字节的地址
                flash_adr_o<={10'b0000000000,wb_adr_i[21:2],2'b01};
            end else if(waitstate == 4'h6)begin
                //经过3个时钟周期后，第二个字节读到,保存到wb_dat_o[23:16]
                wb_dat_o[23:16]<=flash_dat_i;
                //给出要读取的第三个字节的地址
                flash_adr_o<={10'b0000000000,wb_adr_i[21:2],2'b10};
            end else if(waitstate == 4'h9)begin
                //经过3个时钟周期后，第三个字节读到,保存到wb_dat_o[15:8]
                wb_dat_o[15:8]<=flash_dat_i;
                //给出要读取的第四个字节的地址
                flash_adr_o<={10'b0000000000,wb_adr_i[21:2],2'b11};
            end else if(waitstate == 4'hc)begin
                //经过3个时钟周期后，第四个字节读到,保存到wb_dat_o[7:0]
                wb_dat_o[7:0]<=flash_dat_i;
                //wb_ack_o赋值为1，作为Wishbone总线操作的响应
                wb_ack_o<=1'b1;
            end else if(waitstate == 4'hd)begin
                //经过1个时钟周期后，wb_ack_o赋值为0，Wishbone总线操作结束
                wb_ack_o<=1'b0;
                waitstate<=4'h0;
            end
        end
    end
    

endmodule
