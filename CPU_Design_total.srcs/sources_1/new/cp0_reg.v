//`include "defines.v"

//module cp0_reg(
//    clk,
//    rst,
//    we_i,
//    waddr_i,
//    raddr_i,
//    data_i,
//    int_i,
//    excepttype_i,
//    current_inst_addr_i,
//    is_in_delayslot_i,
//    data_o,
//    count_o,
//    compare_o,
//    status_o,
//    cause_o,
//    epc_o,
//    config_o,
//    prid_o,
//    timer_int_o
//);

//    input wire                      clk;
//    input wire                      rst;
//    input wire                      we_i;//是否要写CP0中的寄存器
//    input wire[4:0]                 waddr_i;//要写的CP0中寄存器的地址
//    input wire[4:0]                 raddr_i;//要读取的CP0中寄存器的地址
//    input wire[`RegBus]             data_i;
//    input wire[5:0]                 int_i;//6个外部硬件中断输入
//    input wire[31:0]                excepttype_i;
//    input wire[`RegBus]             current_inst_addr_i;
//    input wire                      is_in_delayslot_i;
    
//    output reg[`RegBus]             data_o;//读出的CP0中某个寄存器的值
//    output reg[`RegBus]             count_o;          //Count寄存器的值
//    output reg[`RegBus]             compare_o;        //Compare寄存器的值
//    output reg[`RegBus]             status_o;         //Status寄存器的值 
//    //EXL字段表示是否处于异常级（Exception Level），当异常发生时，会设置本字段为 1，表示处理
//    //器处于异常级，此时，处理器会进入内核模式下工作，并且禁止中断。
//    output reg[`RegBus]             cause_o;          //Cause寄存器的值
//    output reg[`RegBus]             epc_o;            //EPC寄存器的值
//    output reg[`RegBus]             config_o;         //Config寄存器的值
//    output reg[`RegBus]             prid_o;           //PRId寄存器的值
//    output reg                      timer_int_o;//是否有定时中断发生
    
//    //对CP0中寄存器的写操作
//    always @(posedge clk)begin
//        if(rst==`RstEnable)begin
//            //Count寄存器的初始值,为0,即为总的计数器
//            count_o<=`ZeroWord;
//            //Compare寄存器的初始值,为0，当Compare的值和Count的值一样时，产生定时中断
//            compare_o<=`ZeroWord;
//            //Status寄存器的初始值,31-28位为CU，0001,表示CP0存在
//            //status_o<=32'h10000000;
//            status_o <= 32'b00010000000000000000000000000000;
//            //Cause寄存器的初始值,15-10表示外部硬件中断信息,9-8表示内部软件中断,6-2表示发生的哪种异常
//            cause_o<=`ZeroWord;
//            //EPC寄存器的初始值
//            epc_o<=`ZeroWord;
//            //Config寄存器的初始值，其中BE字段为1，表示工作在大端模式(MSB)
//            //config_o<=32'h00008000;
//            config_o <= 32'b00000000000000001000000000000000;
//            //PRId寄存器的初始值,其中Processor ID是0x48，类型是0x1,表示是基本版本类型,版本号是1.0
//            //prid_o<=32'h004c0102;
//            prid_o <= 32'b00000000010011000000000100000010;
//            //没有定时中断发生
//            timer_int_o<=`InterruptNotAssert;
//        end else begin
//            count_o<=count_o+1;//Count的值在每个时钟周期加1
//            cause_o[15:10]<=int_i;//Cause的第10-15bit保存外部中断声明
//            //当Compare寄存器不为0时，且Count寄存器的值等于Compare寄存器的值时，将输出信号timer_int_o置为1,表示时钟中断发生
//            if(compare_o != `ZeroWord && count_o == compare_o)begin
//                timer_int_o<=`InterruptAssert;
//            end
//            if(we_i==`WriteEnable)begin//PRId和Config寄存器可以不写，因为都是配置寄存器
//                case(waddr_i)
//                    `CP0_REG_COUNT:begin//写Count寄存器
//                        count_o<=data_i;
//                    end
//                    `CP0_REG_COMPARE:begin//写Compare寄存器
//                        compare_o<=data_i;
//                        // 如果这个时钟周期中，不小心时钟中断了，但是指令又要求写CP0的compare寄存器，那么中断的优先级更高
//                        timer_int_o<=`InterruptNotAssert;
//                    end
//                    `CP0_REG_STATUS:begin//写Status寄存器
//                        status_o<=data_i;
//                    end
//                    `CP0_REG_EPC:begin//写EPC寄存器
//                        epc_o<=data_i;
//                    end
//                    `CP0_REG_CAUSE:begin//写Cause寄存器
//                        //Cause寄存器只有IP[1:0]、IV、WP字段是可写的
//                        cause_o[9:8]<=data_i[9:8];
//                        cause_o[23]<=data_i[23];
//                        cause_o[22]<=data_i[22];
//                    end
//                    default:begin
//                    end
//                endcase
//            end
//            case(excepttype_i)
//                32'h00000001:begin//外部中断
//                    if(is_in_delayslot_i == `InDelaySlot)begin//如果在延迟槽中
//                        epc_o<=current_inst_addr_i-4;//返回的pc地址为减4
//                        cause_o[31]<=1'b1;//Cause寄存器的BD字段
//                    end else begin
//                        epc_o<=current_inst_addr_i;
//                        cause_o[31]<=1'b0;
//                    end
//                    status_o[1]<=1'b1;//Status寄存器的EXL字段
//                    cause_o[6:2]<=5'b00000;//Cause寄存器的ExcCode的值
//                end
//                32'h00000008:begin//系统调用异常syscall
//                    if(status_o[1] == 1'b0) begin 
//                        if(is_in_delayslot_i == `InDelaySlot ) begin 
//                            epc_o <= current_inst_addr_i - 4 ; 
//                            cause_o[31] <= 1'b1; 
//                        end else begin 
//                            epc_o <= current_inst_addr_i; 
//                            cause_o[31] <= 1'b0; 
//                        end 
//                    end 
//                    status_o[1] <= 1'b1; 
//                    cause_o[6:2] <= 5'b01000;
//                end
//                32'h0000000a:begin//无效指令异常
//                    if(status_o[1] == 1'b0) begin 
//                        if(is_in_delayslot_i == `InDelaySlot ) begin 
//                            epc_o <= current_inst_addr_i - 4 ; 
//                            cause_o[31] <= 1'b1; 
//                        end else begin 
//                            epc_o <= current_inst_addr_i; 
//                            cause_o[31] <= 1'b0; 
//                        end 
//                    end 
//                    status_o[1] <= 1'b1; 
//                    cause_o[6:2] <= 5'b01010;
//                end
//                32'h0000000d:begin//自陷异常
//                    if(status_o[1] == 1'b0) begin 
//                        if(is_in_delayslot_i == `InDelaySlot ) begin 
//                            epc_o <= current_inst_addr_i - 4 ; 
//                            cause_o[31] <= 1'b1; 
//                        end else begin 
//                            epc_o <= current_inst_addr_i; 
//                            cause_o[31] <= 1'b0; 
//                        end 
//                    end 
//                    status_o[1] <= 1'b1; 
//                    cause_o[6:2] <= 5'b01101;
//                end
//                32'h0000000c:begin//溢出异常
//                    if(status_o[1] == 1'b0) begin 
//                        if(is_in_delayslot_i == `InDelaySlot ) begin 
//                            epc_o <= current_inst_addr_i - 4 ; 
//                            cause_o[31] <= 1'b1; 
//                        end else begin 
//                            epc_o <= current_inst_addr_i; 
//                            cause_o[31] <= 1'b0; 
//                        end 
//                    end 
//                    status_o[1] <= 1'b1; 
//                    cause_o[6:2] <= 5'b01100;
//                end
//                32'h0000000e:begin//异常返回指令eret
//                    status_o[1]<=1'b0;//?
//                end
//            endcase
//        end//if
//    end//always
    
//    //对CP0中寄存器的读操作
//    always @ (*) begin 
//        if(rst == `RstEnable) begin 
//            data_o <= `ZeroWord; 
//        end else begin 
//            case (raddr_i) 
//            `CP0_REG_COUNT: begin //读 Count 寄存器
//                data_o <= count_o ; 
//            end 
//            `CP0_REG_COMPARE: begin //读 Compare 寄存器
//                data_o <= compare_o ; 
//            end 
//            `CP0_REG_STATUS: begin //读 Status 寄存器
//                data_o <= status_o ; 
//            end 
//            `CP0_REG_CAUSE: begin //读 Cause 寄存器
//                data_o <= cause_o ; 
//            end 
//            `CP0_REG_EPC: begin //读 EPC 寄存器
//                data_o <= epc_o ; 
//            end 
//            `CP0_REG_PRId: begin //读 PRId 寄存器
//                data_o <= prid_o ; 
//            end 
//            `CP0_REG_CONFIG: begin //读 Config 寄存器
//                data_o <= config_o ; 
//            end
//            default: begin 
//            end 
//            endcase 
//        end 
//    end
    
//endmodule


`include "defines.v"

module cp0_reg(

	input	wire										clk,
	input wire										rst,
	
	
	input wire                    we_i,
	input wire[4:0]               waddr_i,
	input wire[4:0]               raddr_i,
	input wire[`RegBus]           data_i,
	
	input wire[31:0]              excepttype_i,
	input wire[5:0]               int_i,
	input wire[`RegBus]           current_inst_addr_i,
	input wire                    is_in_delayslot_i,
	
	output reg[`RegBus]           data_o,
	output reg[`RegBus]           count_o,
	output reg[`RegBus]           compare_o,
	output reg[`RegBus]           status_o,
	output reg[`RegBus]           cause_o,
	output reg[`RegBus]           epc_o,
	output reg[`RegBus]           config_o,
	output reg[`RegBus]           prid_o,
	
	output reg                   timer_int_o    
	
);

	always @ (posedge clk) begin
		if(rst == `RstEnable) begin
			count_o <= `ZeroWord;
			compare_o <= `ZeroWord;
			status_o <= 32'b00010000000000000000000000000000;
			cause_o <= `ZeroWord;
			epc_o <= `ZeroWord;
			config_o <= 32'b00000000000000001000000000000000;
			prid_o <= 32'b00000000010011000000000100000010;
      timer_int_o <= `InterruptNotAssert;
		end else begin
		  count_o <= count_o + 1 ;
		  cause_o[15:10] <= int_i;
		
			if(compare_o != `ZeroWord && count_o == compare_o) begin
				timer_int_o <= `InterruptAssert;
			end
					
			if(we_i == `WriteEnable) begin
				case (waddr_i) 
					`CP0_REG_COUNT:		begin
						count_o <= data_i;
					end
					`CP0_REG_COMPARE:	begin
						compare_o <= data_i;
						//count_o <= `ZeroWord;
            timer_int_o <= `InterruptNotAssert;
					end
					`CP0_REG_STATUS:	begin
						status_o <= data_i;
					end
					`CP0_REG_EPC:	begin
						epc_o <= data_i;
					end
					`CP0_REG_CAUSE:	begin
						cause_o[9:8] <= data_i[9:8];
						cause_o[23] <= data_i[23];
						cause_o[22] <= data_i[22];
					end					
				endcase  //case addr_i
			end

			case (excepttype_i)
				32'h00000001:		begin
					if(is_in_delayslot_i == `InDelaySlot ) begin
						epc_o <= current_inst_addr_i - 4 ;
						cause_o[31] <= 1'b1;
					end else begin
					  epc_o <= current_inst_addr_i;
					  cause_o[31] <= 1'b0;
					end
					status_o[1] <= 1'b1;
					cause_o[6:2] <= 5'b00000;
					
				end
				32'h00000008:		begin
					if(status_o[1] == 1'b0) begin
						if(is_in_delayslot_i == `InDelaySlot ) begin
							epc_o <= current_inst_addr_i - 4 ;
							cause_o[31] <= 1'b1;
						end else begin
					  	epc_o <= current_inst_addr_i;
					  	cause_o[31] <= 1'b0;
						end
					end
					status_o[1] <= 1'b1;
					cause_o[6:2] <= 5'b01000;			
				end
				32'h0000000a:		begin
					if(status_o[1] == 1'b0) begin
						if(is_in_delayslot_i == `InDelaySlot ) begin
							epc_o <= current_inst_addr_i - 4 ;
							cause_o[31] <= 1'b1;
						end else begin
					  	epc_o <= current_inst_addr_i;
					  	cause_o[31] <= 1'b0;
						end
					end
					status_o[1] <= 1'b1;
					cause_o[6:2] <= 5'b01010;					
				end
				32'h0000000d:		begin
					if(status_o[1] == 1'b0) begin
						if(is_in_delayslot_i == `InDelaySlot ) begin
							epc_o <= current_inst_addr_i - 4 ;
							cause_o[31] <= 1'b1;
						end else begin
					  	epc_o <= current_inst_addr_i;
					  	cause_o[31] <= 1'b0;
						end
					end
					status_o[1] <= 1'b1;
					cause_o[6:2] <= 5'b01101;					
				end
				32'h0000000c:		begin
					if(status_o[1] == 1'b0) begin
						if(is_in_delayslot_i == `InDelaySlot ) begin
							epc_o <= current_inst_addr_i - 4 ;
							cause_o[31] <= 1'b1;
						end else begin
					  	epc_o <= current_inst_addr_i;
					  	cause_o[31] <= 1'b0;
						end
					end
					status_o[1] <= 1'b1;
					cause_o[6:2] <= 5'b01100;					
				end				
				32'h0000000e:   begin
					status_o[1] <= 1'b0;
				end
				default:				begin
				end
			endcase			
			
		end    //if
	end      //always
			
	always @ (*) begin
		if(rst == `RstEnable) begin
			data_o <= `ZeroWord;
		end else begin
				case (raddr_i) 
					`CP0_REG_COUNT:		begin
						data_o <= count_o ;
					end
					`CP0_REG_COMPARE:	begin
						data_o <= compare_o ;
					end
					`CP0_REG_STATUS:	begin
						data_o <= status_o ;
					end
					`CP0_REG_CAUSE:	begin
						data_o <= cause_o ;
					end
					`CP0_REG_EPC:	begin
						data_o <= epc_o ;
					end
					`CP0_REG_PRId:	begin
						data_o <= prid_o ;
					end
					`CP0_REG_CONFIG:	begin
						data_o <= config_o ;
					end	
					default: 	begin
					end			
				endcase  //case addr_i			
		end    //if
	end      //always

endmodule