`include "defines.v"

module ex(
    rst,

    alusel_i,
    aluop_i,
    reg1_i,
    reg2_i,
    wd_i,
    wreg_i,
    //HILO模块和MEM阶段传回的值
    hi_i,
    lo_i,

    wb_hi_i,
    wb_lo_i,
    wb_whilo_i,

    mem_hi_i,
    mem_lo_i,
    mem_whilo_i,

    hilo_temp_i,
    cnt_i,

    div_result_i,
    div_ready_i,   
  
    link_address_i,
    is_in_delayslot_i, 
    inst_i,
    
    excepttype_i,
    current_inst_address_i,
    aluop_o,
    mem_addr_o,
    reg2_o,
    
    mem_cp0_reg_we,
    mem_cp0_reg_write_addr,
    mem_cp0_reg_data,
    wb_cp0_reg_we,
    wb_cp0_reg_write_addr,
    wb_cp0_reg_data,
    cp0_reg_data_i,
    cp0_reg_read_addr_o,
    cp0_reg_we_o,
    cp0_reg_write_addr_o,
    cp0_reg_data_o,
    
    excepttype_o,
    is_in_delayslot_o,
    current_inst_address_o,
    
    wd_o,
    wreg_o,
    wdata_o,

    hi_o,
    lo_o,
    whilo_o,

    hilo_temp_o,
    cnt_o,

    div_opdata1_o,
    div_opdata2_o,
    div_start_o,
    signed_div_o,

    stallreq
);

    input wire              rst;
    //译码阶段送到执行阶段的信息
    input wire[`AluOpBus]   aluop_i;        //决定运算的功能
    input wire[`AluSelBus]  alusel_i;       //新东西
    input wire[`RegBus]     reg1_i;
    input wire[`RegBus]     reg2_i;
    input wire[`RegAddrBus] wd_i;
    input wire              wreg_i;
    //HILO阶段传回的值
    //HILO模块给出的HI、LO的值
    input wire[`RegBus]     hi_i;
    input wire[`RegBus]     lo_i;
    //回写阶段的指令是否要写HI、LO，用于检测HI、LO寄存器带来的数据相关问题
    input wire[`RegBus]     wb_hi_i;
    input wire[`RegBus]     wb_lo_i;
    input wire              wb_whilo_i;
    //访存阶段的指令是否要写HI、LO，用于检测HI、LO寄存器带来的数据相关问题
    input wire[`RegBus]     mem_hi_i;
    input wire[`RegBus]     mem_lo_i;
    input wire              mem_whilo_i;
    //计数和HILO寄存器暂存的输入接口
    input wire[`DoubleRegBus]hilo_temp_i;
    input wire[1:0]         cnt_i;
    //来自除法模块的输入
    input wire[`DoubleRegBus]div_result_i;
    input wire              div_ready_i;
    //处于执行阶段的转移指令要保存的返回地址
    input wire[`RegBus]     link_address_i;
    //当前执行阶段的指令是否位于延迟槽
    input wire              is_in_delayslot_i;
    input wire[`RegBus]     inst_i;
    
    input wire[31:0]        excepttype_i;
    input wire[`RegBus]     current_inst_address_i;
    //访存阶段的指令是否写CP0寄存器，用来检测数据相关
    input wire              mem_cp0_reg_we;
    input wire[4:0]         mem_cp0_reg_write_addr;
    input wire[`RegBus]     mem_cp0_reg_data;
    //回写阶段的指令是否要写CP0中的寄存器，也是用来检测数据相关
    input wire              wb_cp0_reg_we;
    input wire[4:0]         wb_cp0_reg_write_addr;
    input wire[`RegBus]     wb_cp0_reg_data;
    //与CP0直接相连，用于读取其中指定寄存器的值
    input wire[`RegBus]     cp0_reg_data_i;
    output reg[4:0]         cp0_reg_read_addr_o;
    //向流水线下一级传递，用于写CP0中的指定寄存器
    output reg              cp0_reg_we_o;
    output reg[4:0]         cp0_reg_write_addr_o;
    output reg[`RegBus]     cp0_reg_data_o;
    
    output wire[31:0]       excepttype_o;
    output wire             is_in_delayslot_o;
    output wire[`RegBus]    current_inst_address_o;
    //为加载、存储指令准备的接口
    output wire[`AluOpBus]  aluop_o;
    output wire[`RegBus]    mem_addr_o;
    output wire[`RegBus]    reg2_o;
    //计数和HILO寄存器暂存的输出接口
    output reg[`DoubleRegBus]hilo_temp_o;
    output reg[1:0]         cnt_o;
    //处于执行阶段的指令对HI、LO寄存器的写操作请求
    output reg[`RegBus]     hi_o;
    output reg[`RegBus]     lo_o;
    output reg              whilo_o;
    //执行的结果
    output reg[`RegAddrBus] wd_o;
    output reg              wreg_o;
    output reg[`RegBus]     wdata_o;
    //去到除法模块的输出
    output reg[`RegBus]     div_opdata1_o;
    output reg[`RegBus]     div_opdata2_o;
    output reg              div_start_o;
    output reg              signed_div_o;

    output reg              stallreq;

    reg[`RegBus]            logicout;   //保存逻辑运算的结果
    reg[`RegBus]            shiftres;   //保存移位运算结果
    reg[`RegBus]            moveres;    //移动操作的结果
    reg[`RegBus]            arithmeticres;//保存算术运算的结果
    reg[`DoubleRegBus]      mulres;     //保存乘法结果,宽度为64位

    reg[`RegBus]            HI;         //保存HI寄存器的最新值
    reg[`RegBus]            LO;         //保存LO寄存器的最新值

    wire                    ov_sum;     //保存溢出情况,OF
    wire                    reg1_eq_reg2;//第一个操作数是否等于第二个操作数
    wire                    reg1_lt_reg2;//第一个操作数是否小于第二个操作数
    wire[`RegBus]           reg2_i_mux; //保存输入的第二个操作数reg2_i的补码
    wire[`RegBus]           reg1_i_not; //保存输入的第一个操作数reg1_i取反后的值
    wire[`RegBus]           result_sum; //保存加法结果
    wire[`RegBus]           opdata1_mult;//乘法操作中的被乘数
    wire[`RegBus]           opdata2_mult;//乘法操作中的乘数
    wire[`DoubleRegBus]     hilo_temp;  //临时保存乘法结果,宽度为64位
    reg[`DoubleRegBus]      hilo_temp1; //暂存第一次乘法的结果，后使用此结果进行加减法
    //乘累减、乘累加，就是先计算加、减，后用乘法结果充当减数或加数
    reg                     stallreq_for_madd_msub;
    //由于除法导致流水线暂停
    reg                     stallreq_for_div;
    
    reg                     trapassert;//新定义变量,表示是否有自陷异常
    reg                     ovassert;//新定义变量,表示是否有溢出异常

    //如果是减法或是有符号运算,那么reg2_i_mux就取补码，否则就取原码
    assign reg2_i_mux=((aluop_i==`EXE_SUB_OP) ||
                       (aluop_i==`EXE_SUBU_OP) ||
                       (aluop_i==`EXE_SLT_OP)) ||
                       (aluop_i==`EXE_TLT_OP) ||
                       (aluop_i==`EXE_TLTI_OP) ||
                       (aluop_i==`EXE_TGE_OP) ||
                       (aluop_i==`EXE_TGEI_OP) ?
                       (~reg2_i)+1 : reg2_i;//补码：取反加一

    //可以得到加法，减法，比较运算或有符号自陷指令的结果
    assign result_sum=reg1_i+reg2_i_mux;

    //判断移除逻辑A.二者为正数,相加为负数即为溢出   B.二者为负数,相加为正数即为溢出
    assign ov_sum=((!reg1_i[31] && !reg2_i_mux[31]) && result_sum[31])||
                  ((reg1_i[31] && reg2_i_mux[31]) && (!result_sum[31]));

    //两种情况:有符号数比较和无符号数比较,运算符可直接解决无符号数的情况
    //有符号数有三种情况：A.负数肯定比正数小，判断符号即可 
    //BC.正数与正数，负数与负数，需要借助减法来判断
    assign reg1_lt_reg2=((aluop_i == `EXE_SLT_OP) ||
                         (aluop_i == `EXE_TLT_OP) ||
                         (aluop_i == `EXE_TLTI_OP) ||
                         (aluop_i == `EXE_TGE_OP) ||
                         (aluop_i == `EXE_TGEI_OP))?
                        ((reg1_i[31] && !reg2_i[31]) ||
                        (!reg1_i[31] && !reg2_i[31] && result_sum[31]) ||
                        (reg1_i[31] && reg2_i[31] && result_sum[31]))
                        :(reg1_i < reg2_i);

    //对操作数1逐位取反,赋给reg1_i_not
    assign reg1_i_not=~reg1_i;

    //取得乘法的被乘数和乘数,现在是原码，依据最高位决定是否为补码
    //madd和msub指令也要用到有符号乘法指令
    assign opdata1_mult=(((aluop_i==`EXE_MUL_OP) ||
                         (aluop_i==`EXE_MULT_OP) ||
                         (aluop_i==`EXE_MADD_OP) ||
                         (aluop_i==`EXE_MSUB_OP)) &&
                         (reg1_i[31]==1'b1))? 
                         (~reg1_i + 1):reg1_i;

    assign opdata2_mult=(((aluop_i==`EXE_MUL_OP) ||
                         (aluop_i==`EXE_MULT_OP) ||
                         (aluop_i==`EXE_MADD_OP) ||
                         (aluop_i==`EXE_MSUB_OP)) &&
                         (reg2_i[31]==1'b1))?
                         (~reg2_i + 1):reg2_i;

    assign aluop_o=aluop_i;
  
    //这里的reg1_i就是基址寄存器,所以这里是基址寻址
    assign mem_addr_o=reg1_i + {{16{inst_i[15]}},inst_i[15:0]};

    //reg2_i的值是存储指令要存储的寄存器的数据
    assign reg2_o=reg2_i;
    
    //执行阶段输出的异常信息就是译码姐u但的异常信息加上自陷异常、溢出异常的信息，其中第10bit表示是否有自陷异常,第11bit表示是否有溢出异常
    assign excepttype_o={excepttype_i[31:12],ovassert,trapassert,excepttype_i[9:8],8'h00};

    //当前指令在延迟槽中,直接输出
    assign is_in_delayslot_o=is_in_delayslot_i;
    
    //直接输出当前处于执行阶段的地址
    assign current_inst_address_o=current_inst_address_i;

    //进行逻辑运算
    always @(*)begin
        if(rst==`RstEnable)begin
            logicout<=`ZeroWord;
        end else begin
            case(aluop_i)
                `EXE_OR_OP:begin//逻辑或运算
                    logicout<=reg1_i | reg2_i;
                end
                `EXE_AND_OP:begin//逻辑与运算
                    logicout<=reg1_i & reg2_i;
                end
                `EXE_NOR_OP:begin//逻辑或非运算
                    logicout<=~(reg1_i | reg2_i);
                end
                `EXE_XOR_OP:begin//逻辑异或运算
                    logicout<=reg1_i ^ reg2_i;
                end
                default:begin
                    logicout<=`ZeroWord;
                end
            endcase    
        end
    end

    //进行移位运算
    always @(*)begin
        if(rst==`RstEnable)begin
            shiftres<=`ZeroWord;
        end else begin
            case(aluop_i)
                `EXE_SLL_OP:begin//逻辑左移
                    shiftres<=reg2_i<<reg1_i[4:0];
                end
                `EXE_SRL_OP:begin//逻辑右移
                    shiftres<=reg2_i>>reg1_i[4:0];
                end
                `EXE_SRA_OP:begin//算术右移,具体实现:保留32-n位的符号位，数字右移n位，再相或即可
                    shiftres<=({32{reg2_i[31]}}<<(6'd32-{1'b0,reg1_i[4:0]})) | reg2_i>>reg1_i[4:0];
                end
                default:begin
                    shiftres<=`ZeroWord;
                end
            endcase
        end
    end

    //进行算术运算操作
    always @(*)begin
        if(rst==`RstEnable)begin
            arithmeticres<=`ZeroWord;
        end else begin
            case(aluop_i)
                `EXE_SLT_OP,`EXE_SLTU_OP:begin
                    arithmeticres<=reg1_lt_reg2;//比较运算
                end
                `EXE_ADD_OP,`EXE_ADDU_OP,`EXE_ADDI_OP,`EXE_ADDIU_OP:begin//四种加法运算
                    arithmeticres<=result_sum;
                end
                `EXE_SUB_OP,`EXE_SUBU_OP:begin//减法运算
                    arithmeticres<=result_sum;
                end
                `EXE_CLZ_OP:begin//计数运算,前面有几个0,使用原码进行计数
                    arithmeticres<=reg1_i[31]?0:reg1_i[30]?1:
                                   reg1_i[29]?2:reg1_i[28]?3:
                                   reg1_i[27]?4:reg1_i[26]?5:
                                   reg1_i[25]?6:reg1_i[24]?7:
                                   reg1_i[23]?8:reg1_i[22]?9:
                                   reg1_i[21]?10:reg1_i[20]?11:
                                   reg1_i[19]?12:reg1_i[18]?13:
                                   reg1_i[17]?14:reg1_i[16]?15:
                                   reg1_i[15]?16:reg1_i[14]?17:
                                   reg1_i[13]?18:reg1_i[12]?19:
                                   reg1_i[11]?20:reg1_i[10]?21:
                                   reg1_i[9]?22:reg1_i[8]?23:
                                   reg1_i[7]?24:reg1_i[6]?25:
                                   reg1_i[5]?26:reg1_i[4]?27:
                                   reg1_i[3]?28:reg1_i[2]?29:
                                   reg1_i[1]?30:reg1_i[0]?31:32;
                end
                `EXE_CLO_OP:begin//计数运算,前面有几个1,用反码计算
                    arithmeticres<=(reg1_i_not[31]?0:
                                   reg1_i_not[30]?1:
                                   reg1_i_not[29]?2:
                                   reg1_i_not[28]?3:
                                   reg1_i_not[27]?4:
                                   reg1_i_not[26]?5:
                                   reg1_i_not[25]?6:
                                   reg1_i_not[24]?7:
                                   reg1_i_not[23]?8:
                                   reg1_i_not[22]?9:
                                   reg1_i_not[21]?10:
                                   reg1_i_not[20]?11:
                                   reg1_i_not[19]?12:
                                   reg1_i_not[18]?13:
                                   reg1_i_not[17]?14:
                                   reg1_i_not[16]?15:
                                   reg1_i_not[15]?16:
                                   reg1_i_not[14]?17:
                                   reg1_i_not[13]?18:
                                   reg1_i_not[12]?19:
                                   reg1_i_not[11]?20:
                                   reg1_i_not[10]?21:
                                   reg1_i_not[9]?22:
                                   reg1_i_not[8]?23:
                                   reg1_i_not[7]?24:
                                   reg1_i_not[6]?25:
                                   reg1_i_not[5]?26:
                                   reg1_i_not[4]?27:
                                   reg1_i_not[3]?28:
                                   reg1_i_not[2]?29:
                                   reg1_i_not[1]?30:
                                   reg1_i_not[0]?31:32);
                end
                default:begin
                    arithmeticres<=`ZeroWord;
                end
            endcase
        end
    end

    //判断是否发生自陷异常
    always @(*)begin
        if(rst==`RstEnable)begin
            trapassert<=`TrapNotAssert;//默认没有自陷异常
        end else begin
            trapassert<=`TrapNotAssert;
            case(aluop_i)
                `EXE_TEQ_OP,`EXE_TEQI_OP:begin//teq、teqi指令
                    if(reg1_i == reg2_i)begin
                        trapassert<=`TrapAssert;
                    end
                end
                `EXE_TGE_OP,`EXE_TGEI_OP,`EXE_TGEIU_OP,`EXE_TGEU_OP:begin//tge、tgei、tgeiu、tgeu指令
                    if(~reg1_lt_reg2)begin
                        trapassert<=`TrapAssert;
                    end
                end
                `EXE_TLT_OP, `EXE_TLTI_OP, `EXE_TLTIU_OP, `EXE_TLTU_OP:begin//tlt、tlti、tltiu、tltu指令
                    if(reg1_lt_reg2)begin
                        trapassert<=`TrapAssert; 
                    end 
                end
                `EXE_TNE_OP,`EXE_TNEI_OP:begin//tne、tnei指令
                    if(reg1_i != reg2_i)begin
                        trapassert<=`TrapAssert;
                    end
                end
                default:begin
                    trapassert<=`TrapNotAssert;
                end
            endcase
        end
    end

    //得到临时乘法的结果,保存在hilo_temp中
    assign hilo_temp=opdata1_mult * opdata2_mult;

    //修正临时乘法的结果A.如果是无符号乘法指令multu,maddu,msubu,hilo_temp的值即为最终结果
    //B.如果是有符号乘法指令mult,mul,madd,msub,如果一正一负，那么就取hilo_temp的补码,如果同号,hilo_temp的值即为最终结果
    //进行乘法操作
    always @(*)begin
        if(rst==`RstEnable)begin
            mulres<={`ZeroWord,`ZeroWord};
        end else if((aluop_i==`EXE_MULT_OP) ||
                     (aluop_i==`EXE_MUL_OP) ||
                     (aluop_i==`EXE_MADD_OP)||
                     (aluop_i==`EXE_MSUB_OP))begin
            if(reg1_i[31] ^ reg2_i[31] == 1'b1)begin//异或为1时，说明异号
                mulres<=~hilo_temp+1;
            end else begin
                mulres<=hilo_temp;
            end
        end else begin
            mulres<=hilo_temp;
        end
    end

    //得到HI、LO寄存器的值，解决数据相关问题
    always @(*)begin
        if(rst==`RstEnable)begin
            {HI,LO}<={`ZeroWord,`ZeroWord};
        end else if(mem_whilo_i==`WriteEnable)begin//访存阶段的指令要写HI、LO寄存器
            {HI,LO}<={mem_hi_i,mem_lo_i};
        end else if(wb_whilo_i==`WriteEnable)begin//回写阶段的指令要写HI、LO寄存器
            {HI,LO}<={wb_hi_i,wb_lo_i};
        end else begin//如mfhi和mflo指令
            {HI,LO}<={hi_i,lo_i};
        end
    end

    //目前直接让ex阶段的请求暂停stallreq等于stallreq_for_madd_msub
    always @(*)begin
        stallreq=stallreq_for_madd_msub || stallreq_for_div;
    end

        //MADD、MADDU、MSUB、MSUBU指令

    always @(*)begin
        if(rst==`RstEnable)begin
            hilo_temp_o<={`ZeroWord,`ZeroWord};
            cnt_o<=2'b00;
            stallreq_for_madd_msub<=`NoStop;
        end else begin
            case(aluop_i)
                `EXE_MADD_OP,`EXE_MADDU_OP:begin//madd、maddu指令
                    if(cnt_i==2'b00)begin//状态机,cnt_i==00时,使用乘法,cnt_i==01时，使用加法
                        hilo_temp_o<=mulres;
                        cnt_o<=2'b01;
                        hilo_temp1<={`ZeroWord,`ZeroWord};
                        stallreq_for_madd_msub<=`Stop;
                    end else if(cnt_i==2'b01)begin
                        hilo_temp_o<={`ZeroWord,`ZeroWord};
                        cnt_o<=2'b10;
                        hilo_temp1<=hilo_temp_i + {HI,LO};
                        stallreq_for_madd_msub<=`NoStop;
                    end
                end
                `EXE_MSUB_OP,`EXE_MSUBU_OP:begin//msub、msubu指令
                    if(cnt_i==2'b00)begin
                        hilo_temp_o<=~mulres+1;
                        cnt_o<=2'b01;
                        stallreq_for_madd_msub<=`Stop;
                    end else if(cnt_i==2'b01)begin
                        hilo_temp_o<={`ZeroWord,`ZeroWord};
                        cnt_o<=2'b10;
                        hilo_temp1<=hilo_temp_i+{HI,LO};
                        stallreq_for_madd_msub<=`NoStop;
                    end
                end
                default:begin//其他情况下，流水线不暂停
                    hilo_temp_o<={`ZeroWord,`ZeroWord};
                    cnt_o<=2'b00;
                    stallreq_for_madd_msub<=`NoStop;
                end
            endcase
        end
    end

    //进行移动操作
    always @(*)begin
        if(rst==`RstEnable)begin
            moveres<=`ZeroWord;
        end else begin
            moveres<=`ZeroWord;
            case(aluop_i)
                `EXE_MFHI_OP:begin//如果是mfhi指令,那么将HI的值作为移动操作的结果
                    moveres<=HI;
                end
                `EXE_MFLO_OP:begin//如果是mflo指令,那么将LO的值作为移动操作的结果
                    moveres<=LO;
                end
                `EXE_MOVZ_OP:begin//如果是movz指令，那么将reg1_i的值作为移动操作的结果
                    moveres<=reg1_i;
                end
                `EXE_MOVN_OP:begin//如果是movn指令，那么将reg1_i的值作为移动操作的结果
                    moveres<=reg1_i;
                end
                `EXE_MFC0_OP:begin
                    cp0_reg_read_addr_o<=inst_i[15:11];//要从CP0中读取寄存器的地址
                    moveres<=cp0_reg_data_i;//读取到的CP0中指定寄存器的值
                    //判断是否存在数据相关，没有数据相关则正常流水即可
                    if(mem_cp0_reg_we == `WriteEnable && mem_cp0_reg_write_addr == inst_i[15:11])begin
                        moveres<=mem_cp0_reg_data;//若与访存阶段存在数据相关，则直接将mem阶段的结果输出到EX阶段
                    end else if(wb_cp0_reg_we == `WriteEnable && wb_cp0_reg_write_addr == inst_i[15:11])begin
                        moveres<=wb_cp0_reg_data;//与回写阶段存在数据相关
                    end
                end
                default:begin
                end
            endcase
        end
    end

    //进行除法模块控制的信息,标明除法指令输出的除数，被除数，有无符号除法，除法模块使能,请求暂停
    always @(*)begin
        if(rst==`RstEnable)begin
            stallreq_for_div<=`NoStop;
            div_opdata1_o<=`ZeroWord;
            div_opdata2_o<=`ZeroWord;
            div_start_o<=`DivStop;
            signed_div_o<=1'b0;
        end else begin
            stallreq_for_div<=`NoStop;
            div_opdata1_o<=`ZeroWord;
            div_opdata2_o<=`ZeroWord;
            div_start_o<=`DivStop;
            signed_div_o<=1'b0;
            //case的优先级比较高
            case(aluop_i)
                `EXE_DIV_OP:begin//div指令
                    if(div_ready_i == `DivResultNotReady)begin
                        div_opdata1_o<=reg1_i;//被除数
                        div_opdata2_o<=reg2_i;//除数
                        div_start_o<=`DivStart;//开始除法运算
                        signed_div_o<=1'b1;//是有符号除法
                        stallreq_for_div<=`Stop;//请求流水线暂停
                    end else if(div_ready_i == `DivResultReady)begin
                        div_opdata1_o<=reg1_i;//被除数
                        div_opdata2_o<=reg2_i;//除数
                        div_start_o<=`DivStop;//停止除法运算
                        signed_div_o<=1'b1;
                        stallreq_for_div<=`NoStop;//不再请求流水线暂停
                    end else begin
                        div_opdata1_o<=`ZeroWord;
                        div_opdata2_o<=`ZeroWord;
                        div_start_o<=`DivStop;
                        signed_div_o<=1'b0;//1还是0无所谓了，反正div_ready_i没有其他情况
                        stallreq_for_div<=`NoStop;
                    end
                end
                `EXE_DIVU_OP:begin//divu指令
                    if(div_ready_i == `DivResultNotReady)begin
                        div_opdata1_o<=reg1_i;
                        div_opdata2_o<=reg2_i;
                        div_start_o<=`DivStart;
                        signed_div_o<=1'b0;     //无符号除法
                        stallreq_for_div<=`Stop;
                    end else if(div_ready_i == `DivResultReady)begin
                        div_opdata1_o<=reg1_i;
                        div_opdata2_o<=reg2_i;
                        div_start_o<=`DivStop;
                        div_start_o<=1'b0;
                        stallreq_for_div<=`NoStop;
                    end else begin
                        div_opdata1_o<=`ZeroWord;
                        div_opdata2_o<=`ZeroWord;
                        div_start_o<=`DivStop;
                        signed_div_o<=1'b0;
                        stallreq_for_div<=`NoStop;
                    end
                end
                default:begin
                end
            endcase
        end
    end

    //根据alusel_i指示的运算类型，选择一个运算结果作为最终结果
    always@(*)begin
        wd_o<=wd_i;
        //如果发生溢出,那么设置wreg_o为WriteDisable,表示不写目的寄存器
        if(((aluop_i==`EXE_ADD_OP)||
           (aluop_i==`EXE_ADDI_OP)||
           (aluop_i==`EXE_SUB_OP))&& (ov_sum==1'b1))begin
            wreg_o<=`WriteDisable;
            ovassert<=1'b1;//发生了溢出异常
        end else begin
            wreg_o<=wreg_i;
            ovassert<=1'b0;//没有发生溢出异常
        end
        case(alusel_i)      //用来区分逻辑和移位运算
            `EXE_RES_LOGIC:begin        //选择逻辑运算结果为最终运算结果
                wdata_o<=logicout;      
            end
            `EXE_RES_SHIFT:begin        //选择移位运算结果为最终运算结果
                wdata_o<=shiftres;      
            end
            `EXE_RES_MOVE:begin         //选择移动操作结果为最终运算结果
                wdata_o<=moveres;
            end
            `EXE_RES_ARITHMETIC:begin   //选择乘法外的简单算术操作指令
                wdata_o<=arithmeticres;
            end
            `EXE_RES_MUL:begin          //选择乘法指令mul,特殊,只输出低32位,mult和multu的结果在HILO取
                wdata_o<=mulres[31:0];
            end
            `EXE_RES_JUMP_BRANCH:begin  //选择转移指令中指出的地址写入寄存器
                wdata_o<=link_address_i;
            end
            default:begin
                wdata_o<=`ZeroWord;
            end
        endcase
    end

    //如果是mthi、mtlo指令,需要给出whilo_o、hi_o、lo_o的值
    always @ (*) begin
		if(rst == `RstEnable) begin
			whilo_o <= `WriteDisable;
			hi_o <= `ZeroWord;
			lo_o <= `ZeroWord;		
	    end else if((aluop_i == `EXE_DIV_OP) || (aluop_i == `EXE_DIVU_OP))begin
	        whilo_o<=`WriteEnable;
	        hi_o <= div_result_i[63:32];
	        lo_o <= div_result_i[31:0];
		end else if((aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MULTU_OP)) begin
			whilo_o <= `WriteEnable;
			hi_o <= mulres[63:32];
			lo_o <= mulres[31:0];			
		end else if((aluop_i == `EXE_MADD_OP) || (aluop_i == `EXE_MADDU_OP)) begin
			whilo_o <= `WriteEnable;
			hi_o <= hilo_temp1[63:32];
			lo_o <= hilo_temp1[31:0];
		end else if((aluop_i == `EXE_MSUB_OP) || (aluop_i == `EXE_MSUBU_OP)) begin
			whilo_o <= `WriteEnable;
			hi_o <= hilo_temp1[63:32];
			lo_o <= hilo_temp1[31:0];			
		end else if(aluop_i == `EXE_MTHI_OP) begin
			whilo_o <= `WriteEnable;
			hi_o <= reg1_i;
			lo_o <= LO;
		end else if(aluop_i == `EXE_MTLO_OP) begin
			whilo_o <= `WriteEnable;
			hi_o <= HI;
			lo_o <= reg1_i;
		end else begin
			whilo_o <= `WriteDisable;
			hi_o <= `ZeroWord;
			lo_o <= `ZeroWord;
		end				
	end	

    //给出mtc0指令的执行结果
    always @(*)begin
        if(rst == `RstEnable)begin
            cp0_reg_write_addr_o<=5'b00000;
            cp0_reg_we_o<=`WriteDisable;
            cp0_reg_data_o<=`ZeroWord;
        end else if(aluop_o == `EXE_MTC0_OP)begin//是mtc0指令
            cp0_reg_write_addr_o<=inst_i[15:11];
            cp0_reg_we_o<=`WriteEnable;
            cp0_reg_data_o<=reg1_i;
        end else begin
            cp0_reg_write_addr_o<=5'b00000;
            cp0_reg_we_o<=`WriteDisable;
            cp0_reg_data_o<=`ZeroWord;
        end
    end

endmodule