`include "defines.v"

module wishbone_bus_if(
    clk,
    rst,
    stall_i,
    flush_i,
    cpu_ce_i,
    cpu_data_i,
    cpu_addr_i,
    cpu_we_i,
    cpu_sel_i,
    cpu_data_o,
    wishbone_data_i,
    wishbone_ack_i,
    wishbone_addr_o,
    wishbone_data_o,
    wishbone_we_o,
    wishbone_sel_o,
    wishbone_stb_o,
    wishbone_cyc_o,
    stallreq
);

    input wire                  clk;
    input wire                  rst;
    //来自CTRL模块
    input wire[5:0]             stall_i;            //CTRL模块传入的流水线暂停信号
    input wire                  flush_i;            //CTRL模块传入的流水线清除信号
    //CPU侧的接口
    input wire                  cpu_ce_i;           //来自处理器的访问请求信号
    input wire[`RegBus]         cpu_data_i;         //来自处理器的数据
    input wire[`RegBus]         cpu_addr_i;         //来自处理器的地址信号
    input wire                  cpu_we_i;           //来自处理器的写操作指示信号
    input wire[3:0]             cpu_sel_i;          //来自处理器的字节选择信号
    output reg[`RegBus]         cpu_data_o;         //输出到处理器的数据
    //Wighbone侧的接口
    input wire[`RegBus]         wishbone_data_i;    //Wishbone总线输入的数据
    input wire                  wishbone_ack_i;     //Wishbone总线输入的响应
    output reg[`RegBus]         wishbone_addr_o;    //Wishbone总线输出的地址
    output reg[`RegBus]         wishbone_data_o;    //Wishbone总线输出的数据
    output reg                  wishbone_we_o;      //Wishbone总线写使能信号
    output reg[3:0]             wishbone_sel_o;     //Wishbone总线字节选择信号
    output reg                  wishbone_stb_o;     //Wishbone总线选通信号
    output reg                  wishbone_cyc_o;     //Wishbone总线周期信号
    output reg                  stallreq;           //请求流水线暂停的信号
    
    
    
    reg[1:0]                    wishbone_state;//保存Wighbone总线接口模块的状态
    reg[`RegBus]                rd_buf;//寄存通过Wishbone总线访问到的数据
    
    //控制状态转化的时序电路
    always @(posedge clk)begin
        if(rst == `RstEnable)begin
            wishbone_state<=`WB_IDLE;//进入WB_IDLE状态
            wishbone_addr_o<=`ZeroWord;
            wishbone_data_o<=`ZeroWord;
            wishbone_we_o<=`WriteDisable;
            wishbone_sel_o<=4'b0000;
            wishbone_stb_o<=1'b0;
            wishbone_cyc_o<=1'b0;
            rd_buf<=`ZeroWord;
        end else begin
            case(wishbone_state)
                `WB_IDLE:begin//WB_IDLE状态
                    if((cpu_ce_i == 1'b1) && (flush_i == `False_v))begin
                        wishbone_stb_o<=1'b1;
                        wishbone_cyc_o<=1'b1;
                        wishbone_addr_o<=cpu_addr_i;
                        wishbone_data_o<=cpu_data_i;
                        wishbone_we_o<=cpu_we_i;
                        wishbone_sel_o<=cpu_sel_i;
                        wishbone_state<=`WB_BUSY;   //进入WB_BUSY状态
                        rd_buf<=`ZeroWord;
                    end
                end
                `WB_BUSY:begin//WB_BUSY状态
                    if(wishbone_ack_i == 1'b1)begin//收到了总线应答信号则进入WB_IDLE状态
                        wishbone_stb_o<=1'b0;
                        wishbone_cyc_o<=1'b0;
                        wishbone_addr_o<=`ZeroWord;
                        wishbone_data_o<=`ZeroWord;
                        wishbone_we_o<=`WriteDisable;
                        wishbone_sel_o<=4'b0000;
                        wishbone_state<=`WB_IDLE;
                        if(cpu_we_i == `WriteDisable)begin
                            rd_buf<=wishbone_data_i;
                        end
                        if(stall_i != 6'b000000)begin//一旦发生了暂停，立刻切换状态
                            wishbone_state<=`WB_WAIT_FOR_STALL;//进入WB_WAIT_FOR_STALL状态
                        end
                    end else if(flush_i == `True_v)begin//如果流水线清除,直接返回IDLE状态
                        wishbone_stb_o<=1'b0;
                        wishbone_cyc_o<=1'b0;
                        wishbone_addr_o<=`ZeroWord;
                        wishbone_data_o<=`ZeroWord;
                        wishbone_we_o<=`WriteDisable;
                        wishbone_sel_o<=4'b0000;
                        wishbone_state<=`WB_IDLE;
                        rd_buf<=`ZeroWord;
                    end
                end
                `WB_WAIT_FOR_STALL:begin//进入WB_WAIT_FOR_STALL状态
                    //WAITFORSTALL状态时，保存一切状态，但是stall_i只要为0，立刻恢复
                    if(stall_i == 6'b000000)begin
                        wishbone_state<=`WB_IDLE;
                    end
                end
                default:begin
                end
            endcase
        end
    end
    
    //给处理器接口信号赋值的组合电路
    always @(*)begin
        if(rst == `RstEnable)begin
            stallreq<=`NoStop;//不进行暂停请求
            cpu_data_o<=`ZeroWord;
        end else begin
            stallreq<=`NoStop;
            case(wishbone_state)
                `WB_IDLE:begin//WB_IDLE状态
                    if((cpu_ce_i == 1'b1) && (flush_i == `False_v))begin
                        stallreq<=`Stop;
                        cpu_data_o<=`ZeroWord;
                    end
                end
                `WB_BUSY:begin//WB_BUSY状态
                    if(wishbone_ack_i == 1'b1)begin
                        stallreq<=`NoStop;
                        if(wishbone_we_o == `WriteDisable)begin
                            cpu_data_o<=wishbone_data_i;
                        end else begin
                            cpu_data_o<=`ZeroWord;
                        end
                    end else begin
                        stallreq<=`Stop;
                        cpu_data_o<=`ZeroWord;
                    end
                end
                `WB_WAIT_FOR_STALL:begin//WB_WAIT_FOR_STALL状态
                    stallreq<=`NoStop;
                    cpu_data_o<=rd_buf;
                end
                default:begin
                end
            endcase
        end
    end
    
endmodule

