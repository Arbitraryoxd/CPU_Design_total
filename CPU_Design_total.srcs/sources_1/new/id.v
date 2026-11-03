`include "defines.v"

module id(
    rst,
    pc_i,
    inst_i,
    reg1_data_i,
    reg2_data_i,
    //数据重定向，防止数据相关
    ex_aluop_i,
    ex_wreg_i,
    ex_wdata_i,
    ex_wd_i,
    ex1_aluop_i,
    ex1_wreg_i,
    ex1_wdata_i,
    ex1_wd_i,
    mem_wreg_i,
    mem_wdata_i,
    mem_wd_i,
    mem1_wreg_i,
    mem1_wdata_i,
    mem1_wd_i,

    is_in_delayslot_i,
    next_inst_in_delayslot_o,
    branch_flag_o,
    branch_target_address_o,
    link_addr_o,
    is_in_delayslot_o,

    reg1_read_o,
    reg2_read_o,
    reg1_addr_o,
    reg2_addr_o,
    aluop_o,
    alusel_o,
    reg1_o,
    reg2_o,
    wd_o,
    wreg_o,
    stallreq,
    inst_o,
    excepttype_o,
    current_inst_address_o
);

    input wire                  rst;
    input wire[`InstAddrBus]    pc_i;//以前没用，到转移指令的实现时期就有用了
    input wire[`InstBus]        inst_i;
    //获取Regfile读出的两个端口的数据
    input wire[`RegBus]         reg1_data_i;
    input wire[`RegBus]         reg2_data_i;
    //处于执行阶段的运算结果
    input wire[`AluOpBus]       ex_aluop_i;
    input wire                  ex_wreg_i;
    input wire[`RegBus]         ex_wdata_i;
    input wire[`RegAddrBus]     ex_wd_i;
    //第二执行通道的结果
    input wire[`AluOpBus]       ex1_aluop_i;
    input wire                  ex1_wreg_i;
    input wire[`RegBus]         ex1_wdata_i;
    input wire[`RegAddrBus]     ex1_wd_i;
    //处于访存阶段的运算结果
    input wire                  mem_wreg_i;
    input wire[`RegBus]         mem_wdata_i;
    input wire[`RegAddrBus]     mem_wd_i;
    input wire                  mem1_wreg_i;
    input wire[`RegBus]         mem1_wdata_i;
    input wire[`RegAddrBus]     mem1_wd_i;
    //如果上一条指令是转移指令，那么下一条指令就是延迟槽指令
    input wire                  is_in_delayslot_i;
    output reg                  next_inst_in_delayslot_o;//下一条进入译码阶段的指令是否位于延迟槽
    output reg                  branch_flag_o;//是否发生转移
    output reg[`RegBus]         branch_target_address_o;//转移到的目标地址
    output reg[`RegBus]         link_addr_o;//转移指令要保存的返回地址，如jal和bal,jalr指令
    output reg                  is_in_delayslot_o;

    //输出到Regfile的信息
    output reg                  reg1_read_o;
    output reg                  reg2_read_o;
    output reg[`RegAddrBus]     reg1_addr_o;
    output reg[`RegAddrBus]     reg2_addr_o;
    //送到执行阶段的信息
    output reg[`AluOpBus]       aluop_o;
    output reg[`AluSelBus]      alusel_o;
    output reg[`RegBus]         reg1_o;
    output reg[`RegBus]         reg2_o;     
    output reg[`RegAddrBus]     wd_o;       //要写入的目的寄存器地址
    output reg                  wreg_o;     //是否有要写入的目的寄存器
    output wire                 stallreq;
    //新增加的指令输出接口
    output wire[`RegBus]        inst_o;
    output wire[31:0]           excepttype_o;
    output wire[`RegBus]        current_inst_address_o;

    //拆指令,将指令分解成4个部分
    wire[5:0] op=inst_i[31:26];     //指令码
    wire[4:0] op2=inst_i[10:6];     //若为全0，则为SPECIAL指令
    wire[5:0] op3=inst_i[5:0];      //功能码
    wire[4:0] op4=inst_i[20:16];    //目前没有用

    wire[`RegBus]               pc_plus_8;//保存当前译码阶段指令后面第2条指令的地址
    wire[`RegBus]               pc_plus_4;//保存当前译码阶段指令后面紧接着的指令的地址

    wire[`RegBus]               imm_sll2_signedext;//对应分支指令中offset左移两位，在符号扩展至32位的值

    wire                        pre_inst_is_load;

    //保存指令执行需要的立即数
    reg[`RegBus]                imm;
    //指示指令是否有效
    reg                         instvalid;

    reg                         stallreq_for_reg1_loadrelate;//是否写1号口的时候发生数据相关
    reg                         stallreq_for_reg2_loadrelate;//是否写2号口的时候发生数据相关
    
    reg                         excepttype_is_syscall;//是否是系统调用异常syscall
    reg                         excepttype_is_eret;//是否是异常返回指令eret

    //以此方法可以实现延迟槽
    assign pc_plus_8=pc_i + 8;
    //用pc_i+4可以实现分支的offset相对地址
    assign pc_plus_4=pc_i + 4;
    //分支指令中的offset是相对地址，并且是用补码方法表示
    assign imm_sll2_signedext={{14{inst_i[15]}},inst_i[15:0],2'b00};
    //inst_o直接就是译码阶段的指令,不改动
    assign inst_o=inst_i;
    //为了解决load-used问题先写内存后用,就会出问题，此时需要空一个时钟周期
    assign stallreq=stallreq_for_reg1_loadrelate | stallreq_for_reg2_loadrelate;
    //excepttype_o的低8bit留给外部中断,第8bit表示
    //是否是syscall指令引起的系统调用异常,第9bit表示是否是无效指令引起的异常,第12bit表示是否是eret指令，eret指令可以认为是一种特殊的异常--返回异常
    //高19bit不知道是什么
    assign excepttype_o={19'b0,excepttype_is_eret,2'b0,instvalid,excepttype_is_syscall,8'b0};

    assign pre_inst_is_load=((ex_aluop_i == `EXE_LB_OP) || 
  							 (ex_aluop_i == `EXE_LBU_OP)||
  							 (ex_aluop_i == `EXE_LH_OP) ||
  							 (ex_aluop_i == `EXE_LHU_OP)||
  							 (ex_aluop_i == `EXE_LW_OP) ||
  							 (ex_aluop_i == `EXE_LWR_OP)||
  							 (ex_aluop_i == `EXE_LWL_OP)||
  							 (ex_aluop_i == `EXE_LL_OP) ||
  							 (ex_aluop_i == `EXE_SC_OP)) ? 1'b1 : 1'b0;

    //assign excepttype_is_trapinst=1'b0
    
    assign current_inst_address_o = pc_i;

    //具体的译码操作
    always @(*)begin
        if(rst==`RstEnable)begin
            aluop_o<=`EXE_NOP_OP;//算逻op空指令
            alusel_o<=`EXE_RES_NOP;//算逻sel为000
            wd_o<=`NOPRegAddr;//寄存器地址为0
            wreg_o<=`WriteDisable;//寄存器写禁止
            instvalid<=`InstValid;//指令有效
            reg1_read_o<=1'b0;
            reg2_read_o<=1'b0;
            reg1_addr_o<=`NOPRegAddr;
            reg2_addr_o<=`NOPRegAddr;
            imm<=32'h0;
            link_addr_o<=`ZeroWord;
            branch_target_address_o<=`ZeroWord;
            branch_flag_o<=`NotBranch;
            next_inst_in_delayslot_o<=`NotInDelaySlot;
        end else begin
            aluop_o<=`EXE_NOP_OP;//算逻op空指令
            alusel_o<=`EXE_RES_NOP;//算逻sel为000
            wd_o<=inst_i[15:11];     //写入的目的寄存器的地址
            wreg_o<=`WriteDisable;  //寄存器写禁止
            instvalid<=`InstInvalid;    //指令有效
            reg1_read_o<=1'b0;
            reg2_read_o<=1'b0;
            reg1_addr_o<=inst_i[25:21]; //读端口为1的地址
            reg2_addr_o<=inst_i[20:16]; //读端口为2的地址
            imm<=32'h0;
            link_addr_o<=`ZeroWord;
            branch_target_address_o<=`ZeroWord;
            branch_flag_o<=`NotBranch;
            next_inst_in_delayslot_o<=`NotInDelaySlot;
            excepttype_is_syscall<=`False_v;//默认没有系统调用指令
            excepttype_is_eret<=`False_v;//默认不是eret指令
            instvalid<=`InstInvalid;//默认是无效指令
            case(op)
                `EXE_SPECIAL_INST:begin//若指令码是SPECIAL
                    case(op2)
                        5'b00000:begin
                            case(op3)   //根据功能码判断是哪种指令
                                `EXE_OR:begin//or指令
                                    wreg_o<=`WriteEnable;
                                    aluop_o<=`EXE_OR_OP;
                                    alusel_o<=`EXE_RES_LOGIC;
                                    reg1_read_o<=1'b1;
                                    reg2_read_o<=1'b1;
                                    instvalid<=`InstValid;
                                end
                                `EXE_AND:begin//and指令
                                    wreg_o<=`WriteEnable;
                                    aluop_o<=`EXE_AND_OP;
                                    alusel_o<=`EXE_RES_LOGIC;
                                    reg1_read_o<=1'b1;
                                    reg2_read_o<=1'b1;
                                    instvalid<=`InstValid;
                                end
                                `EXE_XOR:begin//xor指令
                                    wreg_o<=`WriteEnable;
                                    aluop_o<=`EXE_XOR_OP;
                                    alusel_o<=`EXE_RES_LOGIC;
                                    reg1_read_o<=1'b1;
                                    reg2_read_o<=1'b1;
                                    instvalid<=`InstValid;
                                end
                                `EXE_NOR:begin//nor指令
                                    wreg_o<=`WriteEnable;
                                    aluop_o<=`EXE_NOR_OP;
                                    alusel_o<=`EXE_RES_LOGIC;
                                    reg1_read_o<=1'b1;
                                    reg2_read_o<=1'b1;
                                    instvalid<=`InstValid;
                                end
                                `EXE_SLLV:begin//sllv指令
                                    wreg_o<=`WriteEnable;
                                    aluop_o<=`EXE_SLL_OP;
                                    alusel_o<=`EXE_RES_SHIFT;
                                    reg1_read_o<=1'b1;
                                    reg2_read_o<=1'b1;
                                    instvalid<=`InstValid;
                                end
                                `EXE_SRLV:begin//srlv指令
                                    wreg_o<=`WriteEnable;
                                    aluop_o<=`EXE_SRL_OP;
                                    alusel_o<=`EXE_RES_SHIFT;
                                    reg1_read_o<=1'b1;
                                    reg2_read_o<=1'b1;
                                    instvalid<=`InstValid;
                                end
                                `EXE_SRAV:begin//srav指令
                                    wreg_o<=`WriteEnable;
                                    aluop_o<=`EXE_SRA_OP;
                                    alusel_o<=`EXE_RES_SHIFT;
                                    reg1_read_o<=1'b1;
                                    reg2_read_o<=1'b1;
                                    instvalid<=`InstValid;
                                end
                                `EXE_SYNC:begin//sync指令
                                    wreg_o<=`WriteDisable;
                                    aluop_o<=`EXE_NOP_OP;
                                    alusel_o<=`EXE_RES_NOP;
                                    reg1_read_o<=1'b0;
                                    reg2_read_o<=1'b1;
                                    instvalid<=`InstValid;
                                end
                                `EXE_MFHI:begin//mfhi指令
                                    wreg_o<=`WriteEnable;
                                    aluop_o<=`EXE_MFHI_OP;
                                    alusel_o<=`EXE_RES_MOVE;
                                    reg1_read_o<=1'b0;
                                    reg2_read_o<=1'b0;
                                    instvalid<=`InstValid;
                                end
                                `EXE_MFLO:begin//mflo指令
                                    wreg_o<=`WriteEnable;
                                    aluop_o<=`EXE_MFLO_OP;
                                    alusel_o<=`EXE_RES_MOVE;
                                    reg1_read_o<=1'b0;
                                    reg2_read_o<=1'b0;
                                    instvalid=`InstValid;
                                end
                                `EXE_MTHI:begin//mthi指令
                                    wreg_o<=`WriteDisable;
                                    aluop_o<=`EXE_MTHI_OP;
                                    reg1_read_o<=1'b1;
                                    reg2_read_o<=1'b0;
                                    instvalid<=`InstValid;
                                end
                                `EXE_MTLO:begin//mtlo指令
                                    wreg_o<=`WriteDisable;
                                    aluop_o<=`EXE_MTLO_OP;
                                    reg1_read_o<=1'b1;
                                    reg2_read_o<=1'b0;
                                    instvalid<=`InstValid;
                                end
                                `EXE_MOVN:begin//movn指令
                                    aluop_o<=`EXE_MOVN_OP;
                                    alusel_o<=`EXE_RES_MOVE;
                                    reg1_read_o<=1'b1;
                                    reg2_read_o<=1'b1;
                                    instvalid<=`InstValid;
                                    //reg2_o的值就是地址为rt的通用寄存器的值,时刻变化
                                    if(reg2_o!=`ZeroWord)begin
                                        wreg_o<=`WriteEnable;
                                    end else begin
                                        wreg_o<=`WriteDisable;
                                    end
                                end
                                `EXE_MOVZ:begin//movz指令
                                    aluop_o<=`EXE_MOVZ_OP;
                                    alusel_o<=`EXE_RES_MOVE;
                                    reg1_read_o<=1'b1;
                                    reg2_read_o<=1'b1;
                                    instvalid<=`InstValid;
                                    //同上
                                    if(reg2_o==`ZeroWord)begin
                                        wreg_o<=`WriteEnable;
                                    end else begin
                                        wreg_o<=`WriteDisable;
                                    end
                                end
                                `EXE_SLT:begin//slt指令
                                    wreg_o<=`WriteEnable;
                                    aluop_o<=`EXE_SLT_OP;
                                    alusel_o<=`EXE_RES_ARITHMETIC;
                                    reg1_read_o<=1'b1;
                                    reg2_read_o<=1'b1;
                                    instvalid<=`InstValid;
                                end
                                `EXE_SLTU:begin//sltu指令
                                    wreg_o<=`WriteEnable;
                                    aluop_o<=`EXE_SLTU_OP;
                                    alusel_o<=`EXE_RES_ARITHMETIC;
                                    reg1_read_o<=1'b1;
                                    reg2_read_o<=1'b1;
                                    instvalid<=`InstValid;
                                end
                                `EXE_ADD:begin//add指令
                                    wreg_o<=`WriteEnable;
                                    aluop_o<=`EXE_ADD_OP;
                                    alusel_o<=`EXE_RES_ARITHMETIC;
                                    reg1_read_o<=1'b1;
                                    reg2_read_o<=1'b1;
                                    instvalid<=`InstValid;
                                end
                                `EXE_ADDU:begin//addu指令
                                    wreg_o<=`WriteEnable;
                                    aluop_o<=`EXE_ADDU_OP;
                                    alusel_o<=`EXE_RES_ARITHMETIC;
                                    reg1_read_o<=1'b1;
                                    reg2_read_o<=1'b1;
                                    instvalid<=`InstValid;
                                end
                                `EXE_SUB:begin//sub指令
                                    wreg_o<=`WriteEnable;
                                    aluop_o<=`EXE_SUB_OP;
                                    alusel_o<=`EXE_RES_ARITHMETIC;
                                    reg1_read_o<=1'b1;
                                    reg2_read_o<=1'b1;
                                    instvalid<=`InstValid;
                                end
                                `EXE_SUBU:begin//subu指令
                                    wreg_o<=`WriteEnable;
                                    aluop_o<=`EXE_SUBU_OP;
                                    alusel_o<=`EXE_RES_ARITHMETIC;
                                    reg1_read_o<=1'b1;
                                    reg2_read_o<=1'b1;
                                    instvalid<=`InstValid;
                                end
                                `EXE_MULT:begin//mult指令
                                    wreg_o<=`WriteDisable;
                                    aluop_o<=`EXE_MULT_OP;
                                    alusel_o<=`EXE_RES_ARITHMETIC;
                                    reg1_read_o<=1'b1;
                                    reg2_read_o<=1'b1;
                                    instvalid<=`InstValid;
                                end
                                `EXE_MULTU:begin//multu指令
                                    wreg_o<=`WriteDisable;
                                    aluop_o<=`EXE_MULTU_OP;
                                    alusel_o<=`EXE_RES_ARITHMETIC;
                                    reg1_read_o<=1'b1;
                                    reg2_read_o<=1'b1;
                                    instvalid<=`InstValid;
                                end
                                `EXE_DIV:begin//div指令
                                    wreg_o<=`WriteDisable;
                                    aluop_o<=`EXE_DIV_OP;
                                    reg1_read_o<=1'b1;
                                    reg2_read_o<=1'b1;
                                    instvalid<=`InstValid;
                                end
                                `EXE_DIVU:begin//divu指令
                                    wreg_o<=`WriteDisable;
                                    aluop_o<=`EXE_DIVU_OP;
                                    reg1_read_o<=1'b1;
                                    reg2_read_o<=1'b1;
                                    instvalid<=`InstValid;
                                end
                                `EXE_JR:begin//jr指令
                                    wreg_o<=`WriteDisable;
                                    aluop_o<=`EXE_JR_OP;
                                    alusel_o<=`EXE_RES_JUMP_BRANCH;
                                    reg1_read_o<=1'b1;
                                    reg2_read_o<=1'b0;
                                    link_addr_o<=`ZeroWord;
                                    branch_target_address_o<=reg1_o;
                                    branch_flag_o<=`Branch;
                                    next_inst_in_delayslot_o<=`InDelaySlot;
                                    instvalid<=`InstValid;
                                end
                                `EXE_JALR:begin//jalr指令
                                    wreg_o<=`WriteEnable;//写通用寄存器
                                    aluop_o<=`EXE_JALR_OP;
                                    alusel_o<=`EXE_RES_JUMP_BRANCH;//确定分支跳转类别
                                    reg1_read_o<=1'b1;
                                    reg2_read_o<=1'b0;
                                    wd_o<=inst_i[15:11];//需要写回的寄存器，一般是通用寄存器$1-$8
                                    link_addr_o<=pc_plus_8;//默认延迟槽会把pc+4给执行了，所以直接跳转到pc+8
                                    branch_target_address_o<=reg1_o;
                                    branch_flag_o<=`Branch;//给予PC程序计数器分支跳转信号，直接利用branch_target_address的分支地址进行跳转
                                    next_inst_in_delayslot_o<=`InDelaySlot;//下一条指令是延迟槽指令
                                    instvalid<=`InstValid;//指令有效，对应中断指令中的优先级最高的rst中断
                                end
                                `EXE_TEQ:begin//teq指令
                                    wreg_o<=`WriteDisable;
                                    aluop_o<=`EXE_TEQ_OP;
                                    alusel_o<=`EXE_RES_NOP;
                                    reg1_read_o<=1'b1;
                                    reg2_read_o<=1'b1 ;
                                    instvalid<=`InstValid;
                                end
                                `EXE_TGE:begin//tge指令
                                    wreg_o <= `WriteDisable; 
                                    aluop_o <= `EXE_TGE_OP; 
                                    alusel_o <= `EXE_RES_NOP; 
                                    reg1_read_o <= 1'b1; 
                                    reg2_read_o <= 1'b1; 
                                    instvalid <= `InstValid;
                                end
                                `EXE_TGEU:begin//tgeu指令
                                    wreg_o <= `WriteDisable; 
                                    aluop_o <= `EXE_TGEU_OP; 
                                    alusel_o <= `EXE_RES_NOP; 
                                    reg1_read_o <= 1'b1; 
                                    reg2_read_o <= 1'b1; 
                                    instvalid <= `InstValid;
                                end
                                `EXE_TLT:begin//tlt指令
                                    wreg_o <= `WriteDisable; 
                                    aluop_o <= `EXE_TLT_OP; 
                                    alusel_o <= `EXE_RES_NOP; 
                                    reg1_read_o <= 1'b1; 
                                    reg2_read_o <= 1'b1; 
                                    instvalid <= `InstValid;
                                end
                                `EXE_TLTU:begin//tltu指令
                                    wreg_o<=`WriteDisable;
                                    aluop_o<=`EXE_TLTU_OP;
                                    alusel_o<=`EXE_RES_NOP;
                                    reg1_read_o<=1'b1;
                                    reg2_read_o<=1'b1;
                                    instvalid<=`InstValid;
                                end
                                `EXE_TNE:begin//tne指令
                                    wreg_o <= `WriteDisable; 
                                    aluop_o <= `EXE_TNE_OP; 
                                    alusel_o <= `EXE_RES_NOP; 
                                    reg1_read_o <= 1'b1; 
                                    reg2_read_o <= 1'b1; 
                                    instvalid <= `InstValid;
                                end
                                `EXE_SYSCALL:begin//syscall指令
                                    wreg_o <= `WriteDisable; 
                                    aluop_o <= `EXE_SYSCALL_OP; 
                                    alusel_o <= `EXE_RES_NOP; 
                                    reg1_read_o <= 1'b0; 
                                    reg2_read_o <= 1'b0; 
                                    instvalid <= `InstValid; 
                                    excepttype_is_syscall<= `True_v;
                                end
                                default:begin
                                end
                            endcase
                        end
                        default:begin
                        end
                    endcase
                end
                `EXE_ORI:begin//指令码不为0的情况,非SPECIAL指令，ori指令
                    wreg_o<=`WriteEnable;
                    aluop_o<=`EXE_OR_OP;
                    alusel_o<=`EXE_RES_LOGIC;
                    reg1_read_o<=1'b1;
                    reg2_read_o<=1'b0;
                    imm<={16'h0,inst_i[15:0]};
                    wd_o<=inst_i[20:16];
                    instvalid<=`InstValid;
                end
                `EXE_ANDI:begin//andi指令
                    wreg_o<=`WriteEnable;
                    aluop_o<=`EXE_AND_OP;
                    alusel_o<=`EXE_RES_LOGIC;
                    reg1_read_o<=1'b1;
                    reg2_read_o<=1'b0;
                    imm<={16'h0,inst_i[15:0]};
                    wd_o<=inst_i[20:16];
                    instvalid<=`InstValid;
                end
                `EXE_XORI:begin//xori指令
                    wreg_o<=`WriteEnable;
                    aluop_o<=`EXE_XOR_OP;
                    alusel_o<=`EXE_RES_LOGIC;
                    reg1_read_o<=1'b1;
                    reg2_read_o<=1'b0;
                    imm<={16'h0,inst_i[15:0]};
                    wd_o<=inst_i[20:16];
                    instvalid<=`InstValid;
                end
                `EXE_LUI:begin//lui指令
                    wreg_o<=`WriteEnable;
                    aluop_o<=`EXE_OR_OP;
                    alusel_o<=`EXE_RES_LOGIC;
                    reg1_read_o<=1'b1;
                    reg2_read_o<=1'b0;
                    imm<={inst_i[15:0],16'h0};
                    wd_o<=inst_i[20:16];
                    instvalid<=`InstValid;
                end
                `EXE_PREF:begin//pref指令
                    wreg_o<=`WriteDisable;
                    aluop_o<=`EXE_NOP_OP;
                    alusel_o<=`EXE_RES_NOP;
                    reg1_read_o<=1'b0;
                    reg2_read_o<=1'b0;
                    instvalid<=`InstValid;
                end
                `EXE_SLTI:begin//slti指令,立即数采用补码形式,扩展符号位，比较是以有符号比较的形式
                    wreg_o<=`WriteEnable;
                    aluop_o<=`EXE_SLT_OP;
                    alusel_o<=`EXE_RES_ARITHMETIC;
                    reg1_read_o<=1'b1;
                    reg2_read_o<=1'b0;
                    imm<={{16{inst_i[15]}},inst_i[15:0]};
                    wd_o<=inst_i[20:16];
                    instvalid<=`InstValid;
                end
                `EXE_SLTIU:begin//sltiu指令,立即数依然采用补码形式,但是比较是以无符号比较的形式
                    wreg_o<=`WriteEnable;
                    aluop_o<=`EXE_SLTU_OP;
                    alusel_o<=`EXE_RES_ARITHMETIC;
                    reg1_read_o<=1'b1;
                    reg2_read_o<=1'b0;
                    imm<={{16{inst_i[15]}},inst_i[15:0]};
                    wd_o<=inst_i[20:16];
                    instvalid<=`InstValid;
                end
                `EXE_ADDI:begin//addi指令
                    wreg_o<=`WriteEnable;
                    aluop_o<=`EXE_ADDI_OP;
                    alusel_o<=`EXE_RES_ARITHMETIC;
                    reg1_read_o<=1'b1;
                    reg2_read_o<=1'b0;
                    imm<={{16{inst_i[15]}},inst_i[15:0]};
                    wd_o<=inst_i[20:16];
                    instvalid<=`InstValid;
                end
                `EXE_ADDIU:begin//addiu指令
                    wreg_o<=`WriteEnable;
                    aluop_o<=`EXE_ADDIU_OP;
                    alusel_o<=`EXE_RES_ARITHMETIC;
                    reg1_read_o<=1'b1;
                    reg2_read_o<=1'b0;
                    imm<={{16{inst_i[15]}},inst_i[15:0]};
                    wd_o<=inst_i[20:16];
                    instvalid<=`InstValid;
                end
                `EXE_J:begin//j指令
                    wreg_o<=`WriteDisable;
                    aluop_o<=`EXE_J_OP;
                    alusel_o<=`EXE_RES_JUMP_BRANCH;
                    reg1_read_o<=1'b0;
                    reg2_read_o<=1'b0;
                    link_addr_o<=`ZeroWord;
                    branch_flag_o<=`Branch;
                    next_inst_in_delayslot_o<=`InDelaySlot;
                    instvalid<=`InstValid;
                    branch_target_address_o<={pc_plus_4[31:28],inst_i[25:0],2'b00};//跳转到pc+4的256MB的空间范围内的绝对地址
                end
                `EXE_JAL:begin//jal指令
                    wreg_o<=`WriteEnable;
                    aluop_o<=`EXE_JAL_OP;
                    alusel_o<=`EXE_RES_JUMP_BRANCH;
                    reg1_read_o<=1'b0;
                    reg2_read_o<=1'b0;
                    wd_o <= 5'b11111;//写$31号寄存器
                    link_addr_o <= pc_plus_8; 
                    branch_flag_o <= `Branch; 
                    next_inst_in_delayslot_o<=`InDelaySlot;//下一条指令算是延迟槽指令
                    instvalid <= `InstValid; 
                    branch_target_address_o<={pc_plus_4[31:28], inst_i[25:0], 2'b00};
                end
                `EXE_BEQ:begin//beq指令
                    wreg_o<=`WriteDisable;
                    aluop_o<=`EXE_BEQ_OP;
                    alusel_o<=`EXE_RES_JUMP_BRANCH;
                    reg1_read_o<=1'b1;
                    reg2_read_o<=1'b1;//与reg2的内容相比较
                    instvalid<=`InstValid;
                    if(reg1_o==reg2_o)begin//将rs和rt的内容相比较
                        branch_target_address_o<=pc_plus_4 + imm_sll2_signedext;//相对地址的计算方法
                        branch_flag_o<=`Branch;
                        next_inst_in_delayslot_o<=`InDelaySlot;
                    end
                end
                `EXE_BGTZ:begin//bgtz指令
                    //若是reg1是正数，那么只需要判断是不是0，若是负数，直接就不用管
                    wreg_o<=`WriteDisable;
                    aluop_o<=`EXE_BGTZ_OP;
                    alusel_o<=`EXE_RES_JUMP_BRANCH;
                    reg1_read_o<=1'b1;
                    reg2_read_o<=1'b0;
                    instvalid<=`InstValid;
                    if((reg1_o[31]==1'b0)&&(reg1_o!=`ZeroWord))begin
                        branch_target_address_o<=pc_plus_4 + imm_sll2_signedext;//相对地址的计算方法
                        branch_flag_o<=`Branch;
                        next_inst_in_delayslot_o<=`InDelaySlot;
                    end
                end
                `EXE_BLEZ:begin//blez指令
                    //reg1的数小于等于0
                    wreg_o <= `WriteDisable; 
                    aluop_o <= `EXE_BLEZ_OP; 
                    alusel_o <= `EXE_RES_JUMP_BRANCH; 
                    reg1_read_o <= 1'b1; 
                    reg2_read_o <= 1'b0; 
                    instvalid <= `InstValid; 
                    if((reg1_o[31] == 1'b1) || (reg1_o == `ZeroWord)) begin 
                        branch_target_address_o <= pc_plus_4 + imm_sll2_signedext; 
                        branch_flag_o <= `Branch; 
                        next_inst_in_delayslot_o <= `InDelaySlot; 
                    end
                end
                `EXE_BNE:begin//bne指令
                    wreg_o <= `WriteDisable; 
                    aluop_o <= `EXE_BLEZ_OP; 
                    alusel_o <= `EXE_RES_JUMP_BRANCH; 
                    reg1_read_o <= 1'b1; 
                    reg2_read_o <= 1'b1; 
                    instvalid <= `InstValid; 
                    if(reg1_o != reg2_o) begin 
                        branch_target_address_o <= pc_plus_4 + imm_sll2_signedext; 
                        branch_flag_o <= `Branch; 
                        next_inst_in_delayslot_o <= `InDelaySlot; 
                    end
                end
                `EXE_LB:begin//lb指令
                    wreg_o<=`WriteEnable;
                    aluop_o<=`EXE_LB_OP;
                    alusel_o<=`EXE_RES_LOAD_STORE;
                    reg1_read_o<=1'b1;
                    reg2_read_o<=1'b0;
                    wd_o<=inst_i[20:16];
                    instvalid<=`InstValid;
                end
                `EXE_LBU:begin//lbu指令
                    wreg_o<=`WriteEnable;
                    aluop_o<=`EXE_LBU_OP;
                    alusel_o<=`EXE_RES_LOAD_STORE;
                    reg1_read_o<=1'b1;
                    reg2_read_o<=1'b0;
                    wd_o<=inst_i[20:16];
                    instvalid<=`InstValid;
                end
                `EXE_LH: begin // lh 指令
                    wreg_o <= `WriteEnable; 
                    aluop_o <= `EXE_LH_OP; 
                    alusel_o <= `EXE_RES_LOAD_STORE; 
                    reg1_read_o <= 1'b1; 
                    reg2_read_o <= 1'b0; 
                    wd_o <= inst_i[20:16]; 
                    instvalid <= `InstValid; 
                end 
                `EXE_LHU: begin // lhu 指令
                    wreg_o <= `WriteEnable; 
                    aluop_o <= `EXE_LHU_OP; 
                    alusel_o <= `EXE_RES_LOAD_STORE; 
                    reg1_read_o <= 1'b1; 
                    reg2_read_o <= 1'b0; 
                    wd_o <= inst_i[20:16]; 
                    instvalid <= `InstValid; 
                end 
                `EXE_LW: begin // lw 指令
                    wreg_o <= `WriteEnable; 
                    aluop_o <= `EXE_LW_OP; 
                    alusel_o <= `EXE_RES_LOAD_STORE; 
                    reg1_read_o <= 1'b1; 
                    reg2_read_o <= 1'b0; 
                    wd_o <= inst_i[20:16]; 
                    instvalid <= `InstValid; 
                end 
                `EXE_LWL: begin // lwl 指令
                    wreg_o <= `WriteEnable; 
                    aluop_o <= `EXE_LWL_OP; 
                    alusel_o <= `EXE_RES_LOAD_STORE; 
                    reg1_read_o <= 1'b1; 
                    reg2_read_o <= 1'b1; 
                    wd_o <= inst_i[20:16]; 
                    instvalid <= `InstValid; 
                end 
                `EXE_LWR: begin // lwr 指令
                    wreg_o <= `WriteEnable; 
                    aluop_o <= `EXE_LWR_OP; 
                    alusel_o <= `EXE_RES_LOAD_STORE; 
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b1; 
                    wd_o <= inst_i[20:16]; 
                    instvalid <= `InstValid; 
                end
                `EXE_SB: begin // sb 指令
                    wreg_o <= `WriteDisable; 
                    aluop_o <= `EXE_SB_OP; 
                    reg1_read_o <= 1'b1; 
                    reg2_read_o <= 1'b1; 
                    instvalid <= `InstValid; 
                    alusel_o <= `EXE_RES_LOAD_STORE; 
                end 
                `EXE_SH: begin // sh 指令
                    wreg_o <= `WriteDisable; 
                    aluop_o <= `EXE_SH_OP; 
                    reg1_read_o <= 1'b1; 
                    reg2_read_o <= 1'b1; 
                    instvalid <= `InstValid; 
                    alusel_o <= `EXE_RES_LOAD_STORE; 
                end 
                `EXE_SW: begin // sw 指令
                    wreg_o <= `WriteDisable; 
                    aluop_o <= `EXE_SW_OP; 
                    reg1_read_o <= 1'b1; 
                    reg2_read_o <= 1'b1; 
                    instvalid <= `InstValid; 
                    alusel_o <= `EXE_RES_LOAD_STORE; 
                end 
                `EXE_SWL: begin // swl 指令
                    wreg_o <= `WriteDisable; 
                    aluop_o <= `EXE_SWL_OP; 
                    reg1_read_o <= 1'b1; 
                    reg2_read_o <= 1'b1; 
                    instvalid <= `InstValid; 
                    alusel_o <= `EXE_RES_LOAD_STORE; 
                end 
                `EXE_SWR: begin // swr 指令
                    wreg_o <= `WriteDisable; 
                    aluop_o <= `EXE_SWR_OP; 
                    reg1_read_o <= 1'b1; 
                    reg2_read_o <= 1'b1; 
                    instvalid <= `InstValid; 
                    alusel_o <= `EXE_RES_LOAD_STORE; 
                end
                `EXE_LL:begin//ll指令
                    wreg_o <= `WriteEnable; 
                    aluop_o <= `EXE_LL_OP; 
                    alusel_o <= `EXE_RES_LOAD_STORE; 
                    reg1_read_o <= 1'b1; 
                    reg2_read_o <= 1'b0; 
                    wd_o <= inst_i[20:16]; 
                    instvalid <= `InstValid;
                end
                `EXE_SC:begin//sc指令
                    //也需要写通用寄存器，1表示写入成功
                    wreg_o<=`WriteEnable;
                    aluop_o<=`EXE_SC_OP;
                    alusel_o<=`EXE_RES_LOAD_STORE;
                    reg1_read_o<=1'b1;
                    reg2_read_o<=1'b1;
                    wd_o<=inst_i[20:16];
                    instvalid<=`InstValid;
                    alusel_o<=`EXE_RES_LOAD_STORE;
                end
                `EXE_REGIMM_INST:begin//当op==000001时的特殊情况
                    case(op4)
                        `EXE_BGEZ:begin//bgez指令
                            //reg1大于等于0,判断reg1[31]==0即可
                            wreg_o<=`WriteDisable;
                            aluop_o<=`EXE_RES_JUMP_BRANCH;
                            reg1_read_o<=1'b1;
                            reg2_read_o<=1'b0;
                            instvalid<=`InstValid;
                            if(reg1_o[31]==1'b0)begin
                                branch_target_address_o <= pc_plus_4 + imm_sll2_signedext; 
                                branch_flag_o <= `Branch; 
                                next_inst_in_delayslot_o <= `InDelaySlot;
                            end
                        end
                        `EXE_BGEZAL:begin//bgezal指令
                            //reg1大于等于0，并且保存返回地址到寄存器31
                            wreg_o <= `WriteEnable; 
                            aluop_o <= `EXE_BGEZAL_OP; 
                            alusel_o <= `EXE_RES_JUMP_BRANCH; 
                            reg1_read_o <= 1'b1; 
                            reg2_read_o <= 1'b0; 
                            link_addr_o <= pc_plus_8; 
                            wd_o <= 5'b11111; 
                            instvalid <= `InstValid; 
                            if(reg1_o[31] == 1'b0) begin 
                                branch_target_address_o <= pc_plus_4 + imm_sll2_signedext; 
                                branch_flag_o <= `Branch; 
                                next_inst_in_delayslot_o <= `InDelaySlot; 
                            end
                        end
                        `EXE_BLTZ:begin//bltz指令
                            //reg1_o小于0
                            wreg_o <= `WriteDisable; 
                            aluop_o <= `EXE_BGEZAL_OP; 
                            alusel_o <= `EXE_RES_JUMP_BRANCH; 
                            reg1_read_o <= 1'b1; 
                            reg2_read_o <= 1'b0; 
                            instvalid <= `InstValid; 
                            if(reg1_o[31] == 1'b1) begin 
                                branch_target_address_o <=pc_plus_4 + imm_sll2_signedext; 
                                branch_flag_o <= `Branch; 
                                next_inst_in_delayslot_o <= `InDelaySlot; 
                            end
                        end
                        `EXE_BLTZAL:begin//bltzal指令
                            wreg_o <= `WriteEnable; 
                            aluop_o <= `EXE_BGEZAL_OP; 
                            alusel_o <= `EXE_RES_JUMP_BRANCH; 
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b0; 
                            link_addr_o <= pc_plus_8; 
                            wd_o <= 5'b11111; 
                            instvalid <= `InstValid; 
                            if(reg1_o[31] == 1'b1) begin 
                                branch_target_address_o <=pc_plus_4 + imm_sll2_signedext; 
                                branch_flag_o <= `Branch; 
                                next_inst_in_delayslot_o <= `InDelaySlot; 
                            end
                        end
                        `EXE_TEQI:begin//teqi指令
                            wreg_o<=`WriteDisable;
                            aluop_o<=`EXE_TEQI_OP;
                            alusel_o<=`EXE_RES_NOP;
                            reg1_read_o<=1'b1;
                            reg2_read_o<=1'b0;
                            imm<={{16{inst_i[15]}},inst_i[15:0]};
                            instvalid<=`InstValid;
                        end
                        `EXE_TGEI:begin//tgei指令
                            wreg_o<=`WriteDisable;
                            aluop_o<=`EXE_TGEI_OP;
                            alusel_o<=`EXE_RES_NOP;
                            reg1_read_o<=1'b1;
                            reg2_read_o<=1'b0;
                            imm<={{16{inst_i[15]}},inst_i[15:0]};
                            instvalid<=`InstValid;
                        end
                        `EXE_TGEIU:begin//tgeiu指令
                            wreg_o <= `WriteDisable; 
                            aluop_o <= `EXE_TGEIU_OP; 
                            alusel_o <= `EXE_RES_NOP; 
                            reg1_read_o <= 1'b1; 
                            reg2_read_o <= 1'b0; 
                            imm <= {{16{inst_i[15]}}, inst_i[15:0]}; 
                            instvalid <= `InstValid;
                        end
                        `EXE_TLTI:begin//tlti指令
                            wreg_o <= `WriteDisable; 
                            aluop_o <= `EXE_TLTI_OP; 
                            alusel_o <= `EXE_RES_NOP; 
                            reg1_read_o <= 1'b1; 
                            reg2_read_o <= 1'b0; 
                            imm <= {{16{inst_i[15]}}, inst_i[15:0]}; 
                            instvalid <= `InstValid;
                        end
                        `EXE_TLTIU:begin//tltiu指令
                            wreg_o <= `WriteDisable; 
                            aluop_o <= `EXE_TLTIU_OP; 
                            alusel_o <= `EXE_RES_NOP; 
                            reg1_read_o <= 1'b1; 
                            reg2_read_o <= 1'b0; 
                            imm <= {{16{inst_i[15]}}, inst_i[15:0]}; 
                            instvalid <= `InstValid;
                        end
                        `EXE_TNEI:begin//tnei指令
                            wreg_o <= `WriteDisable; 
                            aluop_o <= `EXE_TNEI_OP; 
                            alusel_o <= `EXE_RES_NOP; 
                            reg1_read_o <= 1'b1; 
                            reg2_read_o <= 1'b0; 
                            imm <= {{16{inst_i[15]}}, inst_i[15:0]}; 
                            instvalid <= `InstValid;
                        end
                        default:begin
                        end
                    endcase
                end
                `EXE_SPECIAL2_INST:begin//op==special2时,进一步判断op3
                    case(op3)
                        `EXE_CLZ:begin//clz指令
                            wreg_o<=`WriteEnable;
                            aluop_o<=`EXE_CLZ_OP;
                            alusel_o<=`EXE_RES_ARITHMETIC;
                            reg1_read_o<=1'b1;
                            reg2_read_o<=1'b0;
                            instvalid<=`InstValid;
                        end
                        `EXE_CLO:begin//clo指令
                            wreg_o<=`WriteEnable;
                            aluop_o<=`EXE_CLO_OP;
                            alusel_o<=`EXE_RES_ARITHMETIC;
                            reg1_read_o<=1'b1;
                            reg2_read_o<=1'b0;
                            instvalid<=`InstValid;
                        end
                        `EXE_MUL:begin//mul指令
                            wreg_o<=`WriteEnable;
                            aluop_o<=`EXE_MUL_OP;
                            alusel_o<=`EXE_RES_MUL;
                            reg1_read_o<=1'b1;
                            reg2_read_o<=1'b1;
                            instvalid<=`InstValid;
                        end
                        `EXE_MADD:begin//madd指令
                            wreg_o <= `WriteDisable; 
                            aluop_o <= `EXE_MADD_OP; 
                            alusel_o <= `EXE_RES_MUL; 
                            reg1_read_o <= 1'b1; 
                            reg2_read_o <= 1'b1; 
                            instvalid <= `InstValid;
                        end
                        `EXE_MADDU:begin//maddu指令
                            wreg_o<=`WriteDisable;
                            aluop_o<=`EXE_MADDU_OP;
                            alusel_o<=`EXE_RES_MUL;
                            reg1_read_o<=1'b1;
                            reg2_read_o<=1'b1;
                            instvalid<=`InstValid;
                        end
                        `EXE_MSUB:begin//msub指令
                            wreg_o <= `WriteDisable; 
                            aluop_o <= `EXE_MSUB_OP; 
                            alusel_o <= `EXE_RES_MUL; 
                            reg1_read_o <= 1'b1; 
                            reg2_read_o <= 1'b1; 
                            instvalid <= `InstValid;
                        end
                        `EXE_MSUBU:begin//msubu指令
                            wreg_o <= `WriteDisable; 
                            aluop_o <= `EXE_MSUBU_OP; 
                            alusel_o <= `EXE_RES_MUL; 
                            reg1_read_o <= 1'b1; 
                            reg2_read_o <= 1'b1; 
                            instvalid <= `InstValid;
                        end
                        default:begin
                        end
                    endcase
                end
                default:begin
//                    aluop_o<=`EXE_NOP_OP;//算逻op空指令
//                    alusel_o<=`EXE_RES_NOP;//算逻sel为000
//                    wd_o<=inst_i[15:11];     //写入的目的寄存器的地址
//                    wreg_o<=`WriteDisable;  //寄存器写禁止
//                    instvalid<=`InstInvalid;    //指令无效
//                    reg1_read_o<=1'b0;
//                    reg2_read_o<=1'b0;
//                    reg1_addr_o<=inst_i[25:21]; //读端口为1的地址
//                    reg2_addr_o<=inst_i[20:16]; //读端口为2的地址
//                    imm<=32'h0;
                end
            endcase
            //以下为特殊情况,无法通过操作码功能码的方法判断指令类别
            if(inst_i[31:21]==11'b00000000000)begin//特殊情况,若前11为为0，判断op3字段
                if(op3==`EXE_SLL)begin//sll指令
                    wreg_o<=`WriteEnable;
                    aluop_o<=`EXE_SLL_OP;
                    alusel_o<=`EXE_RES_SHIFT;
                    reg1_read_o<=1'b0;
                    reg2_read_o<=1'b1;
                    imm[4:0]<=inst_i[10:6];
                    wd_o<=inst_i[15:11];
                    instvalid<=`InstValid;
                end else if(op3==`EXE_SRL)begin//srl指令
                    wreg_o<=`WriteEnable;
                    aluop_o<=`EXE_SRL_OP;
                    alusel_o<=`EXE_RES_SHIFT;
                    reg1_read_o<=1'b0;
                    reg2_read_o<=1'b1;
                    imm[4:0]<=inst_i[10:6];
                    wd_o<=inst_i[15:11];
                    instvalid<=`InstValid;
                end else if(op3==`EXE_SRA)begin//sra指令
                    wreg_o<=`WriteEnable;
                    aluop_o<=`EXE_SRA_OP;
                    alusel_o<=`EXE_RES_SHIFT;
                    reg1_read_o<=1'b0;
                    reg2_read_o<=1'b1;
                    imm[4:0]<=inst_i[10:6];
                    wd_o<=inst_i[15:11];
                    instvalid<=`InstValid;
                end
            end
            if(inst_i == `EXE_ERET)begin//eret指令
                wreg_o<=`WriteDisable;
                aluop_o<=`EXE_ERET_OP;
                alusel_o<=`EXE_RES_NOP;
                reg1_read_o<=1'b0;
                reg2_read_o<=1'b0;
                instvalid<=`InstValid;
                excepttype_is_eret<=`True_v;
            end else if(inst_i[31:21] == 11'b01000000000 && inst_i[10:0] == 11'b00000000000) begin//mfc0指令
				aluop_o <= `EXE_MFC0_OP;
				alusel_o <= `EXE_RES_MOVE;
				wd_o <= inst_i[20:16];
				wreg_o <= `WriteEnable;
				instvalid <= `InstValid;	   
				reg1_read_o <= 1'b0;
				reg2_read_o <= 1'b0;		
			end else if(inst_i[31:21] == 11'b01000000100 && inst_i[10:0] == 11'b00000000000) begin//mtc0指令
				aluop_o <= `EXE_MTC0_OP;
				alusel_o <= `EXE_RES_MOVE;//RES_MOVE和RES_NOP都无所谓，因为writedisable,wdata_o是没有用的
				wreg_o <= `WriteDisable;
				instvalid <= `InstValid;
				reg1_read_o <= 1'b1;
				reg1_addr_o <= inst_i[20:16];
				reg2_read_o <= 1'b0;					
			end
            
        end //else
    end     //always

    //is_in_delayslot_o表示当前译码阶段指令是否是延迟槽指令
    always @(*)begin
        if(rst==`RstEnable)begin
            is_in_delayslot_o<=`NotInDelaySlot;
        end else begin
            //直接等于就可以了
            is_in_delayslot_o<=is_in_delayslot_i;
        end
    end

    //确定要运算的源操作数1，为exe阶段做准备，与我的设计有所不同，这里耦合度有点高
    always @(*)begin
        stallreq_for_reg1_loadrelate <= `NoStop;
        if(rst==`RstEnable)begin
            reg1_o<=`ZeroWord;
        end else if(pre_inst_is_load == 1'b1 && ex_wd_i == reg1_addr_o && reg1_read_o == 1'b1 )begin
		    stallreq_for_reg1_loadrelate <= `Stop;
        end else if((reg1_read_o==1'b1)&&(ex1_wreg_i==1'b1)&&(ex1_wd_i==reg1_addr_o))begin
            reg1_o<=ex1_wdata_i;
        end else if((reg1_read_o==1'b1)&&(ex_wreg_i==1'b1)&&(ex_wd_i==reg1_addr_o))begin//如果执行阶段和访存阶段要输出到译码阶段，就直接输出
            reg1_o<=ex_wdata_i;
        end else if((reg1_read_o==1'b1)&&(mem1_wreg_i==1'b1)&&(mem1_wd_i==reg1_addr_o))begin
            reg1_o<=mem1_wdata_i;
        end else if((reg1_read_o==1'b1)&&(mem_wreg_i==1'b1)&&(mem_wd_i==reg1_addr_o))begin
            reg1_o<=mem_wdata_i;
        end else if(reg1_read_o==1'b1)begin
            reg1_o<=reg1_data_i;    //寄存器组的读端口1的输出值
        end else if(reg1_read_o==1'b0)begin
            reg1_o<=imm;
        end else begin
            reg1_o<=`ZeroWord;
        end
    end

    //确定要运算的源操作数2
    always @(*)begin
        stallreq_for_reg2_loadrelate <= `NoStop;
        if(rst==`RstEnable)begin
            reg2_o<=`ZeroWord;
        end else if(pre_inst_is_load == 1'b1 && ex_wd_i == reg2_addr_o && reg2_read_o == 1'b1 ) begin
		    stallreq_for_reg2_loadrelate <= `Stop;
		//如果执行阶段和访存阶段要输出到译码阶段，就直接输出
        end else if((reg2_read_o==1'b1)&&(ex1_wreg_i==1'b1)&&(ex1_wd_i==reg2_addr_o))begin
            reg2_o<=ex1_wdata_i;
        end else if((reg2_read_o==1'b1)&&(ex_wreg_i==1'b1)&&(ex_wd_i==reg2_addr_o))begin
            reg2_o<=ex_wdata_i;
        end else if((reg2_read_o==1'b1)&&(mem1_wreg_i==1'b1)&&(mem1_wd_i==reg2_addr_o))begin
            reg2_o<=mem1_wdata_i;
        end else if((reg2_read_o==1'b1)&&(mem_wreg_i==1'b1)&&(mem_wd_i==reg2_addr_o))begin
            reg2_o<=mem_wdata_i;
        end else if(reg2_read_o==1'b1)begin
            reg2_o<=reg2_data_i;
        end else if(reg2_read_o==1'b0)begin
            reg2_o<=imm;
        end else begin
            reg2_o<=`ZeroWord;
        end
    end

endmodule
