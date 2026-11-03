`include "defines.v"

module hilo_reg(//两个特殊寄存器HILO,不过定义在EX阶段
    clk,
    rst,
    //写端口
    we,
    hi_i,
    lo_i,
    //读端口
    hi_o,
    lo_o
);
    
    input wire                  clk;
    input wire                  rst;
    //写端口
    input wire                  we;
    input wire[`RegBus]         hi_i;
    input wire[`RegBus]         lo_i;
    //读端口
    output reg[`RegBus]         hi_o;
    output reg[`RegBus]         lo_o;
    
    always @(posedge clk)begin
        if(rst==`RstEnable)begin
            hi_o<=`ZeroWord;
            lo_o<=`ZeroWord;
        end else if((we==`WriteEnable))begin//应该还要修改的
            hi_o<=hi_i;
            lo_o<=lo_i;
        end
    end

endmodule
