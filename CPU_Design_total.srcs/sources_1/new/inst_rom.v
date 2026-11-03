`include "defines.v"

module inst_rom( 
 input wire ce, 
 input wire[`InstAddrBus] addr, 
 output reg[`InstBus] inst 
 
); 
 // 定义一个数组，大小是 InstMemNum，元素宽度是 InstBus 
    reg[`InstBus] inst_mem[0:`InstMemNum-1]; 
 // 使用文件 inst_rom.data 初始化指令存储器
    initial $readmemh ( "D:/HDLfiles/CPU_Design_total/CPU_Design_total.sim/sim_1/behav/xsim/inst_rom.data", inst_mem ); 
 // 当复位信号无效时，依据输入的地址，给出指令存储器 ROM 中对应的元素
    always @ (*) begin 
        if (ce == `ChipDisable) begin 
            inst <= `ZeroWord; 
        end else begin 
            inst <= inst_mem[addr[`InstMemNumLog2+1:2]]; 
        end 
    end 
endmodule
