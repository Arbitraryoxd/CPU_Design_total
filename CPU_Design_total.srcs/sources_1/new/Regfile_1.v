`include "defines.v"

module Regfile_1(
    rst,
    clk,
    waddr,
    wdata,
    we,
    waddr2,
    wdata2,
    we2,
    raddr1,
    re1,
    rdata1,
    raddr2,
    re2,
    rdata2,
    raddr3,
    re3,
    rdata3,
    raddr4,
    re4,
    rdata4
);
    input wire                  clk;
    input wire                  rst;
    //写端口
    input wire                  we;
    input wire[`RegAddrBus]     waddr;
    input wire[`RegBus]         wdata;
    //第二个写端口，供双发射的第二条指令写回
    input wire                  we2;
    input wire[`RegAddrBus]     waddr2;
    input wire[`RegBus]         wdata2;
    //读端口1
    input wire                  re1;     
    input wire[`RegAddrBus]     raddr1;
    output reg[`RegBus]         rdata1;
    //读端口2
    input wire                  re2;
    input wire[`RegAddrBus]     raddr2;
    output reg[`RegBus]         rdata2;
    //第二发射通道的两个读端口
    input wire                  re3;
    input wire[`RegAddrBus]     raddr3;
    output reg[`RegBus]         rdata3;
    input wire                  re4;
    input wire[`RegAddrBus]     raddr4;
    output reg[`RegBus]         rdata4;
  
    //32位寄存器的数量
    reg[`RegBus]                regs[0:`RegNum-1];
  
    //写操作
    always @(posedge clk)begin
        if(rst==`RstDisable)begin
            if((we==`WriteEnable) && (waddr!=`RegNumLog2'h0))begin
                regs[waddr]<=wdata;
            end
            //同一周期两个写端口有效时，第二条指令的结果最后写入。
            if((we2==`WriteEnable) && (waddr2!=`RegNumLog2'h0))begin
                regs[waddr2]<=wdata2;
            end
        end
    end
  
    //读操作1
    always @(*)begin
        if(rst==`RstEnable)begin
            rdata1<=`ZeroWord;
        end else if(raddr1==`RegNumLog2'h0)begin
            rdata1<=`ZeroWord;
        end else if((raddr1==waddr2) && (we2==`WriteEnable) && (re1==`ReadEnable))begin
            rdata1<=wdata2;
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
        end else if((raddr2==waddr2) && (we2==`WriteEnable) && (re2==`ReadEnable))begin
            rdata2<=wdata2;
        end else if((raddr2==waddr) && (we==`WriteEnable) && (re2==`ReadEnable))begin   //如果写使能和读使能同时有效，且读的地址刚好是写的地址时，直接读出写入的数据
            rdata2<=wdata;                      //为了解决数据相关，这是直接相等，与我上下沿的设计不同
        end else if(re2==`ReadEnable)begin      //如果写使能有效，就输出对应结果
            rdata2<=regs[raddr2];
        end else begin      //如果写使能无效，则输出0
            rdata2<=`ZeroWord;
        end
    end

    //第二发射通道的读端口3
    always @(*)begin
        if(rst==`RstEnable)begin
            rdata3<=`ZeroWord;
        end else if(raddr3==`RegNumLog2'h0)begin
            rdata3<=`ZeroWord;
        end else if((raddr3==waddr2) && (we2==`WriteEnable) && (re3==`ReadEnable))begin
            rdata3<=wdata2;
        end else if((raddr3==waddr) && (we==`WriteEnable) && (re3==`ReadEnable))begin
            rdata3<=wdata;
        end else if(re3==`ReadEnable)begin
            rdata3<=regs[raddr3];
        end else begin
            rdata3<=`ZeroWord;
        end
    end

    //第二发射通道的读端口4
    always @(*)begin
        if(rst==`RstEnable)begin
            rdata4<=`ZeroWord;
        end else if(raddr4==`RegNumLog2'h0)begin
            rdata4<=`ZeroWord;
        end else if((raddr4==waddr2) && (we2==`WriteEnable) && (re4==`ReadEnable))begin
            rdata4<=wdata2;
        end else if((raddr4==waddr) && (we==`WriteEnable) && (re4==`ReadEnable))begin
            rdata4<=wdata;
        end else if(re4==`ReadEnable)begin
            rdata4<=regs[raddr4];
        end else begin
            rdata4<=`ZeroWord;
        end
    end
  
endmodule
