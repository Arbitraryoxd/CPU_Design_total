`include "defines.v"

module Regfile_1(
    rst,
    clk,
    waddr,
    wdata,
    we,
    raddr1,
    re1,
    rdata1,
    raddr2,
    re2,
    rdata2
);
    input wire                  clk;
    input wire                  rst;
    //写端口
    input wire                  we;
    input wire[`RegAddrBus]     waddr;
    input wire[`RegBus]         wdata;
    //读端口1
    input wire                  re1;     
    input wire[`RegAddrBus]     raddr1;
    output reg[`RegBus]         rdata1;
    //读端口2
    input wire                  re2;
    input wire[`RegAddrBus]     raddr2;
    output reg[`RegBus]         rdata2;
  
    //32位寄存器的数量
    reg[`RegBus]                regs[0:`RegNum-1];
  
    //写操作
    always @(posedge clk)begin
        if(rst==`RstDisable)begin
            if((we==`WriteEnable) && (waddr!=`RegNumLog2'h0))begin
                regs[waddr]<=wdata;
            end
        end
    end
  
    //读操作1
    always @(*)begin
        if(rst==`RstEnable)begin
            rdata1<=`ZeroWord;
        end else if(raddr1==`RegNumLog2'h0)begin
            rdata1<=`ZeroWord;
        end else if((raddr1==waddr) && (we==`WriteEnable) && (re1==`ReadEnable))begin   //如果写使能和读使能同时有效，且读的地址刚好是写的地址时，直接读出写入的数据
            rdata1<=wdata;                      //为了解决数据相关，这是直接相等，与我上下沿的设计不同
        end else if(re1==`ReadEnable)begin      //如果写使能有效，就输出对应结果
            rdata1<=regs[raddr1];
        end else begin      //如果写使能无效，则输出0
            rdata1<=`ZeroWord;
        end
    end
  
    //读操作2
    always @(*)begin
        if(rst==`RstEnable)begin
            rdata2<=`ZeroWord;
        end else if(raddr2==`RegNumLog2'h0)begin
            rdata2<=`ZeroWord;
        end else if((raddr2==waddr) && (we==`WriteEnable) && (re2==`ReadEnable))begin   //如果写使能和读使能同时有效，且读的地址刚好是写的地址时，直接读出写入的数据
            rdata2<=wdata;                      //为了解决数据相关，这是直接相等，与我上下沿的设计不同
        end else if(re2==`ReadEnable)begin      //如果写使能有效，就输出对应结果
            rdata2<=regs[raddr2];
        end else begin      //如果写使能无效，则输出0
            rdata2<=`ZeroWord;
        end
    end
  
endmodule