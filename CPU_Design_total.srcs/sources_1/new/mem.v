`include "defines.v"

module mem(
    rst,
    wd_i,
    wreg_i,
    wdata_i,
    hi_i,
    lo_i,
    whilo_i,
    aluop_i,
    mem_addr_i,
    reg2_i,
    mem_data_i,
    LLbit_i,
    wb_LLbit_we_i,
    wb_LLbit_value_i,
    cp0_reg_we_i,
    cp0_reg_write_addr_i,
    cp0_reg_data_i,
    excepttype_i,
    is_in_delayslot_i,
    current_inst_address_i,
    cp0_status_i,
    cp0_cause_i,
    cp0_epc_i,
    wb_cp0_reg_we,
    wb_cp0_reg_write_addr,
    wb_cp0_reg_data,
    cp0_reg_we_o,
    cp0_reg_write_addr_o,
    cp0_reg_data_o,
    wd_o,
    wreg_o,
    wdata_o,
    hi_o,
    lo_o,
    whilo_o,
    mem_addr_o,
    mem_sel_o,
    mem_data_o,
    mem_ce_o,
    mem_we_o,
    LLbit_we_o,
    LLbit_value_o,
    excepttype_o,
    cp0_epc_o,
    is_in_delayslot_o,
    current_inst_address_o
);

    input wire                  rst;
    //来自执行阶段的信息
    input wire[`RegAddrBus]     wd_i;
    input wire                  wreg_i;
    input wire[`RegBus]         wdata_i;
    input wire[`RegBus]         hi_i;
    input wire[`RegBus]         lo_i;
    input wire                  whilo_i;
    input wire[`AluOpBus]       aluop_i;
    input wire[`RegBus]         mem_addr_i;
    input wire[`RegBus]         reg2_i;
    input wire[`RegBus]         mem_data_i;
    input wire                  LLbit_i;
    input wire                  wb_LLbit_we_i;
    input wire                  wb_LLbit_value_i;
    input wire                  cp0_reg_we_i;
    input wire[4:0]             cp0_reg_write_addr_i;
    input wire[`RegBus]         cp0_reg_data_i;
    input wire[31:0]            excepttype_i;
    input wire                  is_in_delayslot_i;
    input wire[`RegBus]         current_inst_address_i;
    input wire[`RegBus]         cp0_status_i;
    input wire[`RegBus]         cp0_cause_i;
    input wire[`RegBus]         cp0_epc_i;
    input wire                  wb_cp0_reg_we;
    input wire[4:0]             wb_cp0_reg_write_addr;
    input wire[`RegBus]         wb_cp0_reg_data;
    //访存阶段的结果
    output reg                  cp0_reg_we_o;
    output reg[4:0]             cp0_reg_write_addr_o;
    output reg[`RegBus]         cp0_reg_data_o;
    output reg[`RegAddrBus]     wd_o;
    output reg                  wreg_o;
    output reg[`RegBus]         wdata_o;
    output reg[`RegBus]         hi_o;
    output reg[`RegBus]         lo_o;
    output reg                  whilo_o;
    output reg[`RegBus]         mem_addr_o;
    output reg[3:0]             mem_sel_o;
    output reg[`RegBus]         mem_data_o;
    output reg                  mem_ce_o;
    output wire                 mem_we_o;
    output reg                  LLbit_we_o;
    output reg                  LLbit_value_o;
    output reg[31:0]            excepttype_o;
    output wire[`RegBus]        cp0_epc_o;
    output wire                 is_in_delayslot_o;
    output wire[`RegBus]        current_inst_address_o;

    wire[`RegBus]               zero32;
    reg                         mem_we;
    //保存LLbit寄存器的最新值
    reg                         LLbit;

    reg[`RegBus]                cp0_status;//用来保存CP0中Status寄存器的最新值
    reg[`RegBus]                cp0_cause;//用来保存CP0中Cause寄存器的最新值
    reg[`RegBus]                cp0_epc;//用来保存CP0中EPC寄存器的最新值

    //外部数据存储器RAM的读、写信号
    assign zero32=`ZeroWord;

    assign is_in_delayslot_o=is_in_delayslot_i;
    
    assign current_inst_address_o=current_inst_address_i;

    //将EPC寄存器的最新值通过接口cp0_epc_o输出
    assign cp0_epc_o=cp0_epc;
    
    //mem_we_o表示是否对数据寄存器进行写操作
    //|xxx和~xxx一样是对自身按位操作
    //如果发生了异常，那么需要取消对数据存储器的写操作
    assign mem_we_o=mem_we & (~(|excepttype_o));

    //为了防止数据相关(sc指令之前可能修改寄存器)，如果回写阶段指令要写LLbit，那么回写阶段要写入的值就是LLbit寄存器的最新值,
    //反之LLbit模块给出的值LLbit_i是最新值
    always @(*)begin
        if(rst==`RstEnable)begin
            LLbit<=1'b0;
        end else begin
            if(wb_LLbit_we_i==1'b1)begin//回写阶段的指令要写LLbit
                LLbit<=wb_LLbit_value_i;
            end else begin
                LLbit<=LLbit_i;
            end
        end
    end

    //得到CP0中Status寄存器的最新值,为了处理数据相关问题,得到的始终是最新的Status寄存器的值
    //若回写阶段的指令要写Status寄存器，那么写入的值就是Status寄存器的最新值,反之，从CP0模块通过cp0_status_i接口传入的数据就是Status寄存器的最新值
    always @(*)begin
        if(rst==`RstEnable)begin
            cp0_status<=`ZeroWord;
        end else if((wb_cp0_reg_we == `WriteEnable) && (wb_cp0_reg_write_addr == `CP0_REG_STATUS))begin
            cp0_status<=wb_cp0_reg_data;
        end else begin
            cp0_status<=cp0_status_i;
        end
    end

    //得到CP0中EPC寄存器的最新值
    always @(*)begin
        if(rst==`RstEnable)begin
            cp0_epc<=`ZeroWord;
        end else if((wb_cp0_reg_we == `WriteEnable) && (wb_cp0_reg_write_addr == `CP0_REG_EPC))begin
            cp0_epc<=wb_cp0_reg_data;
        end else begin
            cp0_epc<=cp0_epc_i;
        end
    end

    //得到CP0中Cause寄存器的最新值
    always @(*)begin
        if(rst==`RstEnable)begin
            cp0_cause<=`ZeroWord;
        end else if((wb_cp0_reg_we == `WriteEnable) && (wb_cp0_reg_write_addr == `CP0_REG_CAUSE))begin
            cp0_cause[9:8]<=wb_cp0_reg_data[9:8];//IP[1:0]字段是可写的
            cp0_cause[22]<=wb_cp0_reg_data[22];//WP字段是可写的
            cp0_cause[23]<=wb_cp0_reg_data[23];//IV字段是可写的
        end else begin
            cp0_cause<=cp0_cause_i;
        end
    end

    //给出最终的异常类型,队列法,从前到后优先级逐渐降低
    always @(*)begin
        if(rst==`RstEnable)begin
            excepttype_o<=`ZeroWord;
        end else begin//8+5种中断类型
            excepttype_o<=`ZeroWord;
            if(current_inst_address_i != `ZeroWord)begin
                //1.处于开中断 2.中断使能 3.按位相与(status的表示是否可屏蔽，1表示不屏蔽，cause的低2位表示软件中断)
                if(((cp0_cause[15:8] & (cp0_status[15:8])) != 8'b00) && (cp0_status[1] == 1'b0) && (cp0_status[0] == 1'b1))begin
                    excepttype_o<=32'h00000001;//interrupt
                end else if(excepttype_i[8] == 1'b1)begin
                    excepttype_o<=32'h00000008;//syscall
                end else if(excepttype_i[9] == 1'b1)begin
                    excepttype_o<=32'h0000000a;//inst_invalid
                end else if(excepttype_i[10] == 1'b1)begin
                    excepttype_o<=32'h0000000d;//trap;
                end else if(excepttype_i[11] == 1'b1)begin
                    excepttype_o<=32'h0000000c;//ov;
                end else if(excepttype_i[12] == 1'b1)begin
                    excepttype_o<=32'h0000000e;//eret
                end
            end
        end
    end

    always @(*)begin
        if(rst==`RstEnable)begin
            wd_o<=`NOPRegAddr;
            wreg_o<=`WriteDisable;
            wdata_o<=`ZeroWord;
            hi_o<=`ZeroWord;
            lo_o<=`ZeroWord;
            whilo_o<=`WriteDisable;
            mem_addr_o<=`ZeroWord;
            mem_we<=`WriteDisable;
            mem_sel_o<=4'b0000;
            mem_data_o<=`ZeroWord;
            mem_ce_o<=`ChipDisable;
            LLbit_we_o<=1'b0;
            LLbit_value_o<=1'b0;
            cp0_reg_we_o <= `WriteDisable;
		    cp0_reg_write_addr_o <= 5'b00000;
		    cp0_reg_data_o <= `ZeroWord;
        end else begin
            wd_o<=wd_i;
            wreg_o<=wreg_i;
            wdata_o<=wdata_i;
            hi_o<=hi_i;
            lo_o<=lo_i;
            whilo_o<=whilo_i;
            mem_we<=`WriteDisable;
            mem_addr_o<=`ZeroWord;
            mem_sel_o<=4'b1111;
            mem_ce_o<=`ChipDisable;
            LLbit_we_o<=1'b0;
            LLbit_value_o<=1'b0;
            cp0_reg_we_o <= cp0_reg_we_i;
		    cp0_reg_write_addr_o <= cp0_reg_write_addr_i;
		    cp0_reg_data_o <= cp0_reg_data_i;	
            case(aluop_i)
                `EXE_LB_OP:begin//lb指令
                    mem_addr_o<=mem_addr_i;
                    mem_we<=`WriteDisable;
                    mem_ce_o<=`ChipEnable;
                    //将指定字节取出到寄存器的低位
                    case(mem_addr_i[1:0])
                        2'b00:begin
                            wdata_o<={{24{mem_data_i[31]}},mem_data_i[31:24]};
                            mem_sel_o<=4'b1000;
                        end
                        2'b01:begin
                            wdata_o<={{24{mem_data_i[23]}},mem_data_i[23:16]};
                            mem_sel_o<=4'b0100;
                        end
                        2'b10:begin
                            wdata_o<={{24{mem_data_i[15]}},mem_data_i[15:8]};
                            mem_sel_o<=4'b0010;
                        end
                        2'b11:begin
                            wdata_o<={{24{mem_data_i[7]}},mem_data_i[7:0]};
                            mem_sel_o<=4'b0001;
                        end
                        default:begin
                            wdata_o<=`ZeroWord;
                        end
                    endcase
                end
                `EXE_LBU_OP:begin//lbu指令
                    mem_addr_o<=mem_addr_i;
                    mem_we<=`WriteDisable;
                    mem_ce_o<=`ChipEnable;
                    //将指定字节取出到寄存器的低位
                    case(mem_addr_i[1:0])
                        2'b00:begin
                            wdata_o<={{24{1'b0}},mem_data_i[31:24]};
                            mem_sel_o<=4'b1000;
                        end
                        2'b01:begin
                            wdata_o<={{24{1'b0}},mem_data_i[23:16]};
                            mem_sel_o<=4'b0100;
                        end
                        2'b10:begin
                            wdata_o<={{24{1'b0}},mem_data_i[15:8]};
                            mem_sel_o<=4'b0010;
                        end
                        2'b00:begin
                            wdata_o<={{24{1'b0}},mem_data_i[7:0]};
                            mem_sel_o<=4'b0001;
                        end
                        default:begin
                            wdata_o<=`ZeroWord;
                        end
                    endcase
                end
                `EXE_LH_OP:begin//lh指令
                    mem_addr_o<=mem_addr_i;
                    mem_we<=`WriteDisable;
                    mem_ce_o<=`ChipEnable;
                    case(mem_addr_i[1:0])
                        2'b00:begin
                            wdata_o<={{16{mem_data_i[31]}},mem_data_i[31:16]};
                            mem_sel_o<=4'b1100;
                        end
                        2'b10:begin
                            wdata_o<={{16{mem_data_i[15]}},mem_data_i[15:0]};
                            mem_sel_o<=4'b0011;
                        end
                        default:begin
                            wdata_o<=`ZeroWord;
                        end
                    endcase
                end
                `EXE_LHU_OP:begin//lhu指令
                    mem_addr_o<=mem_addr_i;
                    mem_we<=`WriteDisable;
                    mem_ce_o<=`ChipEnable;
                    case(mem_addr_i[1:0])
                        2'b00:begin
                            wdata_o<={{16{1'b0}},mem_data_i[31:16]};
                            mem_sel_o<=4'b1100;
                        end
                        2'b10:begin
                            wdata_o<={{16{1'b0}},mem_data_i[15:0]};
                            mem_sel_o<=4'b0011;
                        end
                        default:begin
                            wdata_o<=`ZeroWord;
                        end
                    endcase
                end
                `EXE_LW_OP:begin//lw指令
                    mem_addr_o <= mem_addr_i; 
                    mem_we <= `WriteDisable; 
                    wdata_o <= mem_data_i; 
                    mem_sel_o <= 4'b1111; 
                    mem_ce_o <= `ChipEnable;
                end
                `EXE_LWL_OP:begin//lwl指令
                    mem_addr_o <= {mem_addr_i[31:2],2'b00};
                    mem_we<=`WriteDisable;
                    mem_sel_o<=4'b1111;
                    mem_ce_o<=`ChipEnable;
                    //将内存RAM后面的内容放到寄存器左边，以左为准，右放左
                    case(mem_addr_i[1:0])
                        2'b00:begin
                            wdata_o<=mem_data_i[31:0];
                        end
                        2'b01:begin
                            wdata_o<={mem_data_i[23:0],reg2_i[7:0]};
                        end
                        2'b10:begin
                            wdata_o<={mem_data_i[15:0],reg2_i[15:0]};
                        end
                        2'b11:begin
                            wdata_o<={mem_data_i[7:0],reg2_i[23:0]};
                        end
                        default:begin
                            wdata_o<=`ZeroWord;
                        end
                    endcase
                end
                `EXE_LWR_OP:begin//lwr指令
                    mem_addr_o <= {mem_addr_i[31:2],2'b00};
                    mem_we<=`WriteDisable;
                    mem_sel_o<=4'b1111;
                    mem_ce_o<=`ChipEnable;
                    //将内存RAM后面的内容放到寄存器右边,以左为准，左放右
                    case(mem_addr_i[1:0])
                        2'b00:begin
                            wdata_o<={reg2_i[31:8],mem_data_i[31:24]};
                        end
                        2'b01:begin
                            wdata_o<={reg2_i[31:16],mem_data_i[31:16]};
                        end
                        2'b10:begin
                            wdata_o<={reg2_i[31:24],mem_data_i[31:8]};
                        end
                        2'b11:begin
                            wdata_o<=mem_data_i;
                        end
                        default:begin
                            wdata_o<=`ZeroWord;
                        end
                    endcase
                end
                `EXE_SB_OP:begin//sb指令
                    mem_addr_o <= mem_addr_i; 
                    mem_we <= `WriteEnable; 
                    //并不代表真的全写，因为位置还要挑选
                    mem_data_o <= {reg2_i[7:0],reg2_i[7:0],reg2_i[7:0],reg2_i[7:0]}; 
                    mem_ce_o <= `ChipEnable; 
                    case (mem_addr_i[1:0]) 
                        2'b00: begin 
                            mem_sel_o <= 4'b1000; 
                        end
                        2'b01: begin 
                            mem_sel_o <= 4'b0100; 
                        end 
                        2'b10: begin 
                            mem_sel_o <= 4'b0010; 
                        end 
                        2'b11: begin 
                            mem_sel_o <= 4'b0001; 
                        end 
                        default: begin 
                            mem_sel_o <= 4'b0000; 
                        end 
                    endcase
                end
                `EXE_SH_OP:begin//sh指令
                    mem_addr_o<=mem_addr_i;
                    mem_we<=`WriteEnable;
                    mem_data_o<={reg2_i[15:0],reg2_i[15:0]};
                    mem_ce_o<=`ChipEnable; 
                    case(mem_addr_i[1:0])
                        2'b00:begin
                            mem_sel_o<=4'b1100;
                        end
                        2'b10:begin
                            mem_sel_o<=4'b0011;
                        end
                        default:begin
                            mem_sel_o<=4'b0000;
                        end
                    endcase
                end
                `EXE_SW_OP:begin//sw指令
                    mem_addr_o<=mem_addr_i;
                    mem_we<=`WriteEnable;
                    mem_data_o<=reg2_i;
                    mem_sel_o<=4'b1111;
                    mem_ce_o<=`ChipEnable;
                end
                `EXE_SWL_OP:begin//swl指令
                    //以左为准，左放右
                    mem_addr_o<={mem_addr_i[31:2],2'b00};
                    mem_we<=`WriteEnable;
                    mem_ce_o<=`ChipEnable;
                    case(mem_addr_i[1:0])
                        2'b00:begin
                            mem_sel_o<=4'b1111;
                            mem_data_o<=reg2_i;
                        end
                        2'b01:begin
                            mem_sel_o<=4'b0111;
                            mem_data_o<={zero32[7:0],reg2_i[31:8]};
                        end
                        2'b10:begin
                            mem_sel_o<=4'b0011;
                            mem_data_o<={zero32[15:0],reg2_i[31:16]};
                        end
                        2'b11:begin
                            mem_sel_o<=4'b0001;
                            mem_data_o<={zero32[23:0],reg2_i[31:24]};
                        end
                        default:begin
                            mem_sel_o<=4'b0000;
                        end
                    endcase
                end
                `EXE_SWR_OP:begin//swr指令
                    //以左为准，右放左
                    mem_addr_o<={mem_addr_i[31:2],2'b00};
                    mem_we<=`WriteEnable;
                    mem_ce_o<=`ChipEnable;
                    case(mem_addr_i[1:0])
                        2'b00:begin
                            mem_sel_o<=4'b1000;
                            mem_data_o<={reg2_i[7:0],zero32[23:0]};
                        end
                        2'b01:begin
                            mem_sel_o<=4'b1100;
                            mem_data_o<={reg2_i[15:0],zero32[15:0]};
                        end
                        2'b10:begin
                            mem_sel_o<=4'b1110;
                            mem_data_o<={reg2_i[23:0],zero32[7:0]};
                        end
                        2'b11:begin
                            mem_sel_o<=4'b1111;
                            mem_data_o<=reg2_i[31:0];
                        end
                        default:begin
                            mem_sel_o<=4'b0000;
                        end
                    endcase
                end
                `EXE_LL_OP:begin//ll指令
                    mem_addr_o<=mem_addr_i;
                    mem_we<=`WriteDisable;
                    wdata_o<=mem_data_i;
                    LLbit_we_o<=1'b1;
                    LLbit_value_o<=1'b1;
                    mem_sel_o<=4'b1111;
                    mem_ce_o<=`ChipEnable;
                end
                `EXE_SC_OP:begin//sc指令
                //如果没有异常，则正常修改,如果有异常，那么输出异常
                    if(LLbit == 1'b1) begin 
                        LLbit_we_o <= 1'b1; 
                        LLbit_value_o <= 1'b0; 
                        mem_addr_o <= mem_addr_i; 
                        mem_we <= `WriteEnable; 
                        mem_data_o <= reg2_i; 
                        wdata_o <= 32'b1; 
                        mem_sel_o <= 4'b1111; 
                        mem_ce_o <= `ChipEnable; 
                    end else begin 
                        wdata_o <= 32'b0; 
                    end
                end
                default:begin
                end
            endcase
        end
    end
    
endmodule