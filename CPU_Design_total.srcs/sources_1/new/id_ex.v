`include "defines.v"

module id_ex(
    rst,
    clk,
    id_alusel,
    id_aluop,
    id_reg1,
    id_reg2,
    id_wd,
    id_wreg,
    stall,
    id_link_address,
    id_is_in_delayslot,
    next_inst_in_delayslot_i,
    id_inst,
    flush,
    id_current_inst_address,
    id_excepttype,
    ex_current_inst_address,
    ex_excepttype,
    ex_inst,
    ex_link_address,
    ex_is_in_delayslot,
    is_in_delayslot_o,
    ex_alusel,
    ex_aluop,
    ex_reg1,
    ex_reg2,
    ex_wd,
    ex_wreg
);

    input wire                  clk;
    input wire                  rst;
    //从译码阶段传来的信息
    input wire[`AluOpBus]       id_aluop;
    input wire[`AluSelBus]      id_alusel;
    input wire[`RegBus]         id_reg1;
    input wire[`RegBus]         id_reg2;
    input wire[`RegAddrBus]     id_wd;
    input wire                  id_wreg;
    //来自控制模块CTRL，控制暂停
    input wire[5:0]             stall;
    //来自ID阶段的转移指令的信息
    input wire[`RegBus]         id_link_address;//用来保存返回的地址
    input wire                  id_is_in_delayslot;
    input wire                  next_inst_in_delayslot_i;
    input wire[`RegBus]         id_inst;//来自ID模块的指令信号
    input wire                  flush;
    input wire[`RegBus]         id_current_inst_address;
    input wire[31:0]            id_excepttype;
    
    output reg[`RegBus]         ex_current_inst_address;
    output reg[31:0]            ex_excepttype;
    output reg[`RegBus]         ex_inst;//传递到EX模块的指令信号
    output reg[`RegBus]         ex_link_address;
    output reg                  ex_is_in_delayslot;
    output reg                  is_in_delayslot_o;
    //输出到执行阶段的信息
    output reg[`AluOpBus]       ex_aluop;
    output reg[`AluSelBus]      ex_alusel;
    output reg[`RegBus]         ex_reg1;
    output reg[`RegBus]         ex_reg2;
    output reg[`RegAddrBus]     ex_wd;
    output reg                  ex_wreg;
    
    always @(posedge clk)begin
        if(rst==`RstEnable)begin
            ex_aluop<=`EXE_NOP_OP;
            ex_alusel<=`EXE_RES_NOP;
            ex_reg1<=`ZeroWord;
            ex_reg2<=`ZeroWord;
            ex_wd<=`NOPRegAddr;
            ex_wreg<=`WriteDisable;
            ex_link_address<=`ZeroWord;
            ex_is_in_delayslot<=`NotInDelaySlot;
            is_in_delayslot_o<=`NotInDelaySlot;
            ex_inst<=`ZeroWord;
            ex_excepttype<=`ZeroWord;
            ex_current_inst_address<=`ZeroWord;
        end else if(flush == 1'b1)begin//flush==1'b1时，清除流水线
            ex_aluop<=`EXE_NOP_OP;
            ex_alusel<=`EXE_RES_NOP;
            ex_reg1<=`ZeroWord;
            ex_reg2<=`ZeroWord;
            ex_wd<=`NOPRegAddr;
            ex_wreg<=`WriteDisable;
            ex_link_address<=`ZeroWord;
            ex_is_in_delayslot<=`NotInDelaySlot;
            is_in_delayslot_o<=`NotInDelaySlot;
            ex_inst<=`ZeroWord;
            ex_excepttype<=`ZeroWord;
            ex_current_inst_address<=`ZeroWord;
        end else if(stall[2]==`Stop && stall[3]==`NoStop)begin
            ex_aluop<=`EXE_NOP_OP;
            ex_alusel<=`EXE_RES_NOP;
            ex_reg1<=`ZeroWord;
            ex_reg2<=`ZeroWord;
            ex_wd<=`NOPRegAddr;
            ex_wreg<=`WriteDisable;
            ex_link_address<=`ZeroWord;
            ex_is_in_delayslot<=`NotInDelaySlot;
            ex_inst<=`ZeroWord;
            ex_excepttype<=`ZeroWord;
            ex_current_inst_address<=`ZeroWord;
            //is_in_delayslot_o<=`NotInDelaySlot;
            //应该是不用担心这种情况，用了延迟槽后转移指令后现在不会插入空泡了
        end else if(stall[2]==`NoStop)begin
            ex_aluop<=id_aluop;
            ex_alusel<=id_alusel;
            ex_reg1<=id_reg1;
            ex_reg2<=id_reg2;
            ex_wd<=id_wd;
            ex_wreg<=id_wreg;
            ex_link_address<=id_link_address;
            ex_is_in_delayslot<=id_is_in_delayslot;
            is_in_delayslot_o<=next_inst_in_delayslot_i;
            ex_inst<=id_inst;
            ex_excepttype<=id_excepttype;
            ex_current_inst_address<=id_current_inst_address;
        end
    end
    
endmodule