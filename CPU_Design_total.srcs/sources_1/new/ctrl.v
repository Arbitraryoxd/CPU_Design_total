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
        stall = 6'b000000;
        flush = 1'b0;
        new_pc = `ZeroWord;

        if(rst == `RstEnable)begin
            stall = 6'b000000;
            flush = 1'b0;
            new_pc = `ZeroWord;
        end else if(excepttype_i != `ZeroWord)begin
            flush = 1'b1;
            stall = 6'b000000;
            case(excepttype_i)
                32'h00000001: new_pc = 32'h00000020;
                32'h00000008: new_pc = 32'h00000040;
                32'h0000000a: new_pc = 32'h00000040;
                32'h0000000d: new_pc = 32'h00000040;
                32'h0000000c: new_pc = 32'h00000040;
                32'h0000000e: new_pc = cp0_epc_i;
                default:      new_pc = `ZeroWord;
            endcase
        end else if(stallreq_from_mem == `Stop)begin
            stall = 6'b011111;
        end else if(stallreq_from_ex == `Stop)begin
            stall = 6'b001111;
        end else if(stallreq_from_id == `Stop)begin
            stall = 6'b000111;
        end else if(stallreq_from_if == `Stop)begin
            // The fetch queue decouples instruction delivery from the rest
            // of the pipeline, so a bus wait only holds the PC.
            stall = 6'b000001;
        end
    end
    
endmodule
