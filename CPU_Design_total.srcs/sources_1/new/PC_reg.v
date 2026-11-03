`include "defines.v"

module pc_reg(
    clk,
    rst,
    stall,
    branch_flag_i,
    branch_target_address_i,
    flush,
    new_pc,
    pc,
    ce          //指令存储器IR使能信号
);

    input wire                      clk;
    input wire                      rst;
    input wire[5:0]                 stall;//来自控制模块CTRL，控制暂停
    //来自译码阶段ID的信息,用于传递跳转指令的绝对地址和相对地址
    input wire                      branch_flag_i;
    input wire[`RegBus]             branch_target_address_i;
    //由于中断而输入的信号
    input wire                      flush;
    input wire[`RegBus]             new_pc;
    
    output reg[`InstAddrBus]        pc;    //pc由IR使能信号控制，与IR绑定，使IR不跳过0号指令
    output reg                      ce;    //控制IR使能
    
    always @(posedge clk)begin
        if(rst==`RstEnable)begin
            ce<=`ChipDisable;
        end else begin
            ce<=`ChipEnable;
        end
    end
    //目前有三种改动PC的情况，A.流水线暂停 B.PC=PC+4 C.跳转指令
    //当stall[0]为0时,正常执行
    always @(posedge clk)begin
        if(ce==`ChipDisable)begin
            pc<=32'h30000000;
        end else begin
            //若flush为1,表示异常发生,将从CTRL模块给出的异常处理进程入口地址new_pc处执行
            if(flush == 1'b1)begin
                pc<=new_pc;
            end else if(stall[0]==`NoStop)begin//流水线暂停的优先级更低
                if(branch_flag_i== `Branch)begin
                    pc<=branch_target_address_i;
                end else begin
                    pc<=pc+4'h4;
                end
            end
        end
    end
    
endmodule