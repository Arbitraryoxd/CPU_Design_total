`include "defines.v"

module ctrl(
    rst,
    stallreq_from_if,
    stallreq_from_id,
    stallreq_from_ex,
    stallreq_from_mem,
    excepttype_i,
    cp0_epc_i,
    new_pc,
    flush,
    stall
);
    
    input wire                      rst;
    input wire                      stallreq_from_if;
    input wire                      stallreq_from_id;
    input wire                      stallreq_from_ex;
    input wire                      stallreq_from_mem;
    input wire[31:0]                excepttype_i;
    input wire[`RegBus]             cp0_epc_i;
    
    output reg[`RegBus]             new_pc;
    output reg                      flush;//发生异常则寄存器除WB阶段其他全部清零
    output reg[5:0]                 stall;//输出5段流水，6个部分的暂停，其中取指阶段有PC和IF
    
    always @(*)begin
        if(rst == `RstEnable)begin
            stall<=6'b000000;
            flush<=1'b0;
            new_pc<=`ZeroWord;
        end else if(excepttype_i != `ZeroWord)begin//不为0，表示发生异常
            flush<=1'b1;
            stall<=6'b000000;
            case(excepttype_i)
                32'h00000001:begin//中断
                    new_pc<=32'h00000020;
                end
                32'h00000008:begin//系统调用syscall
                    new_pc<=32'h00000040;
                end
                32'h0000000a:begin//无效指令异常
                    new_pc<=32'h00000040;
                end
                32'h0000000d:begin//自陷异常
                    new_pc<=32'h00000040;
                end
                32'h0000000c:begin//溢出异常
                    new_pc<=32'h00000040;
                end
                32'h0000000e:begin//异常返回指令
                    new_pc<=cp0_epc_i;
                end
                default:begin
                end
            endcase
        end else if(stallreq_from_mem == `Stop)begin//访存阶段请求暂停
            stall<=6'b011111;
            flush <= 1'b0;
        end else if(stallreq_from_ex == `Stop)begin
            stall<=6'b001111;
            flush <= 1'b0;
        end else if(stallreq_from_id == `Stop)begin
            stall<=6'b000111;
            flush <= 1'b0;
        end else if(stallreq_from_if == `Stop)begin
            stall<=6'b000111;
            flush <= 1'b0;
        end else begin
            stall<=6'b000000;
            flush <= 1'b0;
            new_pc<=`ZeroWord;
        end
    end
    
endmodule