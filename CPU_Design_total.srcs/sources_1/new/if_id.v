`include "defines.v"

module if_id(
    clk,
    rst,
    if_pc,
    if_inst,
    flush,
    stall,          //来自控制模块CTRL，控制暂停
    id_pc,
    id_inst
);
    input wire                  clk;
    input wire                  rst;
    input wire[`InstAddrBus]    if_pc;
    input wire[`InstBus]        if_inst;
    input wire                  flush;
    input wire[5:0]             stall;
    output reg[`InstAddrBus]    id_pc;
    output reg[`InstBus]        id_inst;
    
    //stall[0]表示取指地址 PC 是否保持不变，为 1 表示保持不变。
    //stall[1]表示流水线取指阶段是否暂停，为 1 表示暂停。
    //stall[2]表示流水线译码阶段是否暂停，为 1 表示暂停。
    //stall[3]表示流水线执行阶段是否暂停，为 1 表示暂停。
    //stall[4]表示流水线访存阶段是否暂停，为 1 表示暂停。
    //stall[5]表示流水线回写阶段是否暂停，为 1 表示暂停。
    //当前阶段若要暂停，则该阶段的前后寄存器都要为1，比如除法指令，然后自产自销即可实现
    always @(posedge clk)begin
        if(rst==`RstEnable)begin
            id_pc<=`ZeroWord;
            id_inst<=`ZeroWord;
        end else if(flush == 1'b1)begin
            //flush为1时表示异常发生，要清除流水线,所以复位id_pc,id_inst的值
            id_pc<=`ZeroWord;
            id_inst<=`ZeroWord;
        end else if(stall[1]==`Stop && stall[2]==`NoStop)begin
            id_pc<=`ZeroWord;
            id_inst<=`ZeroWord;
        end else if(stall[1]==`NoStop)begin
            id_pc<=if_pc;
            id_inst<=if_inst;
        end
    end
    
endmodule
