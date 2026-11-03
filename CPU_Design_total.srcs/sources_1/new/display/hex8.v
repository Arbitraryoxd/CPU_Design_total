module hex8(
    clk,
    rst,
    Data,
    Sel,
    Cout
);
    parameter Data_w=32;
    parameter Sel_w=8;
    parameter Cout_w=8;
    parameter Time=50000;
    
    input clk,rst;
    input[Data_w-1:0]Data;
    output reg [Sel_w-1:0]Sel;
    output reg [Cout_w-1:0]Cout;
    
    reg[2:0]num_cnt;
    reg[31:0]div_cnt;
    reg[3:0]disp_tmp;
    reg clk_en;
    
    always @(posedge clk or negedge rst)
    if(!rst)
        div_cnt<=0;
    else if(div_cnt==Time-1)
        div_cnt<=0;
    else
        div_cnt<=div_cnt+1;
    
    always @(posedge clk or negedge rst)
    if(!rst)
        clk_en<=0;
    else if(div_cnt==Time-1)
        clk_en<=1;
    else
        clk_en<=0;
    
    always @(posedge clk or negedge rst)
    if(!rst)
        num_cnt<=0;
    else if(clk_en)
        num_cnt<=num_cnt+1;
    
    always @(*)
    case(num_cnt)
        0:Sel<=8'b00000001;
        1:Sel<=8'b00000010;
        2:Sel<=8'b00000100;
        3:Sel<=8'b00001000;
        4:Sel<=8'b00010000;
        5:Sel<=8'b00100000;
        6:Sel<=8'b01000000;
        7:Sel<=8'b10000000;
        default:;
    endcase
    
    always @(*)
    case(num_cnt)
        0:disp_tmp<=Data[3:0];
        1:disp_tmp<=Data[7:4];
        2:disp_tmp<=Data[11:8];
        3:disp_tmp<=Data[15:12];
        4:disp_tmp<=Data[19:16];
        5:disp_tmp<=Data[23:20];
        6:disp_tmp<=Data[27:24];
        7:disp_tmp<=Data[31:28];
    endcase
    
    always @(*)
    case(disp_tmp)
        0:Cout<=8'hc0;
        1:Cout<=8'hf9;
        2:Cout<=8'ha4;
        3:Cout<=8'hb0;
        4:Cout<=8'h99;
        5:Cout<=8'h92;
        6:Cout<=8'h82;
        7:Cout<=8'hf8;
        8:Cout<=8'h80;
        9:Cout<=8'h90;
        4'ha:Cout<=8'h88;
        4'hb:Cout<=8'h83;
        4'hc:Cout<=8'hc6;
        4'hd:Cout<=8'ha1;
        4'he:Cout<=8'h86;
        4'hf:Cout<=8'h8e;
        default:Cout<=8'hff;
    endcase
    
endmodule
