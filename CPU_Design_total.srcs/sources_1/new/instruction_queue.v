`include "defines.v"

module instruction_queue(
    clk,
    rst,
    flush,
    push_en,
    push_pc,
    push_inst,
    consume_count,
    q_count,
    pc0,
    inst0,
    pc1,
    inst1
);

    input wire                  clk;
    input wire                  rst;
    input wire                  flush;
    input wire                  push_en;
    input wire[`InstAddrBus]    push_pc;
    input wire[`InstBus]        push_inst;
    input wire[1:0]             consume_count;

    output reg[1:0]             q_count;
    output reg[`InstAddrBus]    pc0;
    output reg[`InstBus]        inst0;
    output reg[`InstAddrBus]    pc1;
    output reg[`InstBus]        inst1;

    reg[`InstAddrBus]           next_pc;
    reg[`InstBus]               next_inst;

    always @(posedge clk) begin
        if((rst == `RstEnable) || (flush == 1'b1)) begin
            q_count <= 2'b00;
            pc0 <= `ZeroWord;
            inst0 <= `ZeroWord;
            pc1 <= `ZeroWord;
            inst1 <= `ZeroWord;
        end else begin
            next_pc = push_pc;
            next_inst = push_inst;

            case(consume_count)
                2'b00: begin
                    if((push_en == 1'b1) && (q_count < 2'b10)) begin
                        if(q_count == 2'b00) begin
                            pc0 <= next_pc;
                            inst0 <= next_inst;
                        end else begin
                            pc1 <= next_pc;
                            inst1 <= next_inst;
                        end
                        q_count <= q_count + 1'b1;
                    end
                end
                2'b01: begin
                    if(q_count == 2'b01) begin
                        if(push_en == 1'b1) begin
                            pc0 <= next_pc;
                            inst0 <= next_inst;
                            q_count <= 2'b01;
                        end else begin
                            pc0 <= `ZeroWord;
                            inst0 <= `ZeroWord;
                            q_count <= 2'b00;
                        end
                    end else if(q_count == 2'b10) begin
                        pc0 <= pc1;
                        inst0 <= inst1;
                        if(push_en == 1'b1) begin
                            pc1 <= next_pc;
                            inst1 <= next_inst;
                            q_count <= 2'b10;
                        end else begin
                            pc1 <= `ZeroWord;
                            inst1 <= `ZeroWord;
                            q_count <= 2'b01;
                        end
                    end
                end
                2'b10: begin
                    if(q_count == 2'b10) begin
                        if(push_en == 1'b1) begin
                            pc0 <= next_pc;
                            inst0 <= next_inst;
                            pc1 <= `ZeroWord;
                            inst1 <= `ZeroWord;
                            q_count <= 2'b01;
                        end else begin
                            pc0 <= `ZeroWord;
                            inst0 <= `ZeroWord;
                            pc1 <= `ZeroWord;
                            inst1 <= `ZeroWord;
                            q_count <= 2'b00;
                        end
                    end
                end
                default: begin
                    q_count <= 2'b00;
                end
            endcase
        end
    end

endmodule
