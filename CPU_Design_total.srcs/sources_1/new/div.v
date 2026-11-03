`include "defines.v"

module div(
    clk,
    rst,
    signed_div_i,
    opdata1_i,
    opdata2_i,
    start_i,
    annul_i,
    result_o,
    ready_o
);

    input wire                  clk;
    input wire                  rst;
    input wire                  signed_div_i;//表示是否是有符号除法
    input wire[31:0]            opdata1_i;//被除数
    input wire[31:0]            opdata2_i;//除数
    input wire                  start_i;//是否开始除法运算，由EX模块输出
    input wire                  annul_i;//是否取消除法运算，为1表示取消除法运算,目前没有中断系统，不用过于深入
  
    output reg[63:0]            result_o;//除法运算结果
    output reg                  ready_o;//除法运算是否结束
  
    wire[32:0]                  div_temp;//用这个来判断每一轮的商是0还是1
    reg[5:0]                    cnt;//记录试商法进行了几轮
    reg[64:0]                   dividend;//最终充当被除数，但是低32位也用来放最终的商，高32位也用来放余数,多出来的第33位不用管
    reg[1:0]                    state;//状态机,四种状态，开始状态，除法进行状态，除法结束状态，除数为0状态
    reg[31:0]                   divisor;//最终充当除数
    reg[31:0]                   temp_op1;//经过处理后的被除数
    reg[31:0]                   temp_op2;//经过处理后的除数
  
    //div_temp中保存的是高32位减去除数的结果,以此便可判断后面是添0还是添1
    assign div_temp={1'b0,dividend[63:32]}-{1'b0,divisor};
  
    //状态机情况说明
    //DivFree表示开始进行除法运算,若除数为0，则进入DivByZero状态后就结束
    //若除数不为0，进入DivOn状态,
    always @(posedge clk)begin
        if(rst==`RstEnable)begin
            state<=`DivFree;
            ready_o<=`DivResultNotReady;
            result_o<={`ZeroWord,`ZeroWord};
        end else begin
            case(state)
                `DivFree:begin//DivFree状态
                    if(start_i==`DivStart && annul_i == 1'b0)begin
                        if(opdata2_i==`ZeroWord)begin//除数为0
                            state<=`DivByZero;
                        end else begin//除数不为0
                            state<=`DivOn;
                            cnt<=6'b000000;
                            //如果除数或者被除数是负数，那就将其转化成补码形式
                            if(signed_div_i==1'b1 && opdata1_i[31] ==1'b1)begin
                                temp_op1=~opdata1_i+1;
                            end else begin
                                temp_op1=opdata1_i;
                            end
                            if(signed_div_i == 1'b1 && opdata2_i[31] == 1'b1 ) begin 
                                temp_op2 = ~opdata2_i + 1; // 除数取补码
                            end else begin 
                                temp_op2 = opdata2_i;
                            end
                            dividend<={`ZeroWord,`ZeroWord};
                            dividend[32:1]<=temp_op1;//左移了一位
                            divisor<=temp_op2;
                        end 
                    end else begin//没有开始除法运算,也就是没有进入`DivStart状态
                        ready_o<=`DivResultNotReady;
                        result_o<={`ZeroWord,`ZeroWord};
                    end
                end
                //若进入DivByZero状态,那么直接进入DivEnd状态，除法结束，且结果为0
                `DivByZero:begin//DivByZero状态
                    dividend<={`ZeroWord,`ZeroWord};
                    state<=`DivEnd;
                end
                //DivOn状态,如果输入信号为annul_i为1，表示取消除法运算,那么回到DivFree状态
                //如果annul_i为0,且cnt不为32时，那么继续除法，根据减法结果div_temp决定dividend是1还是0
                //当cnt为32时，若为有符号除法，商和余数都要取补码
                `DivOn:begin
                    if(annul_i==1'b0)begin
                        if(cnt!=6'b100000)begin//如果cnt没到32
                            //如果试减的结果为负,那么全体左移一位，并且后面取0
                            //如果试减的结果为正，那么移位后,高32位取减了之后的div_temp,后面取1
                            if(div_temp[32]==1'b1)begin
                                dividend<={dividend[63:0],1'b0};
                            end else begin
                                dividend<={div_temp[31:0],dividend[31:0],1'b1};
                            end
                            cnt<=cnt+1;
                        end else begin//如果cnt为32,那么输出商和余数，cnt清零，并且进入DivEnd状态
                            //那单独商取负余数取正的情况或者相反情况是什么时候?
                            if((signed_div_i==1'b1) && (opdata1_i[31] ^ opdata2_i[31] == 1'b1))begin//如果除数和被除数符号相反，那么商要取补码，也就是负数
                                dividend[31:0]<=(~dividend[31:0]+1);
                            end
                            if((signed_div_i==1'b1) && (opdata1_i[31] ^ dividend[64]))begin//如果
                                dividend[64:33]<=(~dividend[64:33]+1);
                            end
                            state<=`DivEnd;
                            cnt<=6'b0;
                        end
                    end else begin
                        state<=`DivFree;
                    end
                end
                `DivEnd:begin//DivEnd状态,商和余数输出，输出结束信号
                    result_o<={dividend[64:33],dividend[31:0]};
                    ready_o<=`DivResultReady;
                    //verilog是if优先级比较高
                    if(start_i==`DivStop)begin
                        state<=`DivFree;
                        ready_o<=`DivResultNotReady;
                        result_o<={`ZeroWord,`ZeroWord};
                    end
                end
                default:begin
                end
            endcase
        end
    end
  
endmodule