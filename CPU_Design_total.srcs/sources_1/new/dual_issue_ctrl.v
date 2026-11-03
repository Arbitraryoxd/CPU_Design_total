`include "defines.v"

module dual_issue_ctrl(
    rst,
    q_count,
    is_in_delayslot_i,
    pipe_stall,
    flush,
    id0_wreg,
    id0_wd,
    id0_aluop,
    id0_alusel,
    id0_branch_flag,
    id0_excepttype,
    id0_stallreq,
    id0_reg1_read,
    id0_reg1_addr,
    id0_reg2_read,
    id0_reg2_addr,
    id1_wreg,
    id1_wd,
    id1_aluop,
    id1_alusel,
    id1_branch_flag,
    id1_excepttype,
    id1_stallreq,
    id1_reg1_read,
    id1_reg1_addr,
    id1_reg2_read,
    id1_reg2_addr,
    issue_valid,
    pair_issue,
    consume_count,
    wait_for_pair
);

    input wire              rst;
    input wire[1:0]         q_count;
    input wire              is_in_delayslot_i;
    input wire              pipe_stall;
    input wire              flush;

    input wire              id0_wreg;
    input wire[`RegAddrBus] id0_wd;
    input wire[`AluOpBus]   id0_aluop;
    input wire[`AluSelBus]  id0_alusel;
    input wire              id0_branch_flag;
    input wire[31:0]        id0_excepttype;
    input wire              id0_stallreq;
    input wire              id0_reg1_read;
    input wire[`RegAddrBus] id0_reg1_addr;
    input wire              id0_reg2_read;
    input wire[`RegAddrBus] id0_reg2_addr;

    input wire              id1_wreg;
    input wire[`RegAddrBus] id1_wd;
    input wire[`AluOpBus]   id1_aluop;
    input wire[`AluSelBus]  id1_alusel;
    input wire              id1_branch_flag;
    input wire[31:0]        id1_excepttype;
    input wire              id1_stallreq;
    input wire              id1_reg1_read;
    input wire[`RegAddrBus] id1_reg1_addr;
    input wire              id1_reg2_read;
    input wire[`RegAddrBus] id1_reg2_addr;

    output reg              issue_valid;
    output reg              pair_issue;
    output reg[1:0]         consume_count;
    output reg              wait_for_pair;

    wire id0_safe_alu;
    wire id1_safe_alu;
    wire pair_dependency;
    wire pair_same_destination;
    wire pair_candidate;

    function safe_alu;
        input wreg;
        input[`AluOpBus] aluop;
        input[`AluSelBus] alusel;
        input branch_flag;
        input[31:0] excepttype;
        input stallreq;
        begin
            safe_alu = (wreg == `WriteEnable) &&
                       (branch_flag == `NotBranch) &&
                       (excepttype == `ZeroWord) &&
                       (stallreq == `NoStop) &&
                       ((alusel == `EXE_RES_LOGIC) ||
                        (alusel == `EXE_RES_SHIFT) ||
                        (alusel == `EXE_RES_ARITHMETIC)) &&
                       (aluop != `EXE_ADD_OP) &&
                       (aluop != `EXE_SUB_OP) &&
                       (aluop != `EXE_ADDI_OP);
        end
    endfunction

    assign id0_safe_alu = safe_alu(
        id0_wreg,
        id0_aluop,
        id0_alusel,
        id0_branch_flag,
        id0_excepttype,
        id0_stallreq
    );

    assign id1_safe_alu = safe_alu(
        id1_wreg,
        id1_aluop,
        id1_alusel,
        id1_branch_flag,
        id1_excepttype,
        id1_stallreq
    );

    assign pair_dependency =
        (id0_wreg == `WriteEnable) &&
        (id0_wd != `NOPRegAddr) &&
        (((id1_reg1_read == 1'b1) && (id1_reg1_addr == id0_wd)) ||
         ((id1_reg2_read == 1'b1) && (id1_reg2_addr == id0_wd)));

    assign pair_same_destination =
        (id0_wreg == `WriteEnable) &&
        (id1_wreg == `WriteEnable) &&
        (id0_wd != `NOPRegAddr) &&
        (id0_wd == id1_wd);

    assign pair_candidate =
        (is_in_delayslot_i == `NotInDelaySlot) &&
        id0_safe_alu &&
        id1_safe_alu &&
        (~pair_dependency) &&
        (~pair_same_destination);

    always @(*) begin
        issue_valid = 1'b0;
        pair_issue = 1'b0;
        consume_count = 2'b00;
        wait_for_pair = 1'b0;

        if((rst == `RstDisable) && (flush == 1'b0)) begin
            if(pipe_stall == `Stop) begin
                consume_count = 2'b00;
            end else if(q_count >= 2'b10) begin
                if(pair_candidate == 1'b1) begin
                    consume_count = 2'b10;
                    pair_issue = 1'b1;
                end else begin
                    consume_count = 2'b01;
                end
            end else if(q_count == 2'b01) begin
                if((id0_branch_flag == `Branch) && (is_in_delayslot_i == `NotInDelaySlot)) begin
                    consume_count = 2'b00;
                end else if((id0_safe_alu == 1'b1) &&
                            (is_in_delayslot_i == `NotInDelaySlot)) begin
                    consume_count = 2'b00;
                    wait_for_pair = 1'b1;
                end else begin
                    consume_count = 2'b01;
                end
            end
        end

        issue_valid = (consume_count != 2'b00);
    end

endmodule
