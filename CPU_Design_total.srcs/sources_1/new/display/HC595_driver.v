module HC595_driver(
    clk,
    rst,
    Cin_Data,
    Send_GO,
    SH_CP,
    ST_CP,
    DS
);
    parameter Data_w=16;
    parameter DIV_MAX=2;
    
    input clk,rst,Send_GO;
    input[Data_w-1:0]Cin_Data;
    output reg SH_CP,ST_CP,DS;
    
    reg[7:0]div_cnt;
    reg[7:0]edge_cnt;
    reg[Data_w-1:0]Data;
    wire CLK_tmp;
    
    always @(posedge clk or negedge rst)
    if(!rst)
        Data<=0;
    else if(Send_GO)
        Data<=Cin_Data;
    
    always @(posedge clk or negedge rst)
    if(!rst)
        div_cnt<=0;
    else if(div_cnt==DIV_MAX-1)
        div_cnt<=0;
    else
        div_cnt<=div_cnt+1;
        
    assign CLK_tmp=(div_cnt==DIV_MAX-1);
    
    always @(posedge clk or negedge rst)
    if(!rst)
        edge_cnt<=0;
    else if(CLK_tmp)begin
        if(edge_cnt==8'd32)
            edge_cnt<=0;
        else
            edge_cnt<=edge_cnt+1;
    end
    
    always @(posedge clk or negedge rst)
    if(!rst)begin
        SH_CP<=0;
        ST_CP<=0;
        DS<=0;
    end
    else case(edge_cnt)
        0:begin SH_CP<=0;ST_CP<=0;DS<=Data[15];end
        1:SH_CP<=1;
        2:begin SH_CP<=0;DS<=Data[14];end
        3:SH_CP<=1;                      
        4:begin SH_CP<=0;DS<=Data[13];end
        5:SH_CP<=1;                      
        6:begin SH_CP<=0;DS<=Data[12];end
        7:SH_CP<=1;                      
        8:begin SH_CP<=0;DS<=Data[11];end
        9:SH_CP<=1;                      
        10:begin SH_CP<=0;DS<=Data[10];end
        11:SH_CP<=1;                      
        12:begin SH_CP<=0;DS<=Data[9];end
        13:SH_CP<=1;                      
        14:begin SH_CP<=0;DS<=Data[8];end
        15:SH_CP<=1;                      
        16:begin SH_CP<=0;DS<=Data[7];end
        17:SH_CP<=1;                      
        18:begin SH_CP<=0;DS<=Data[6];end
        19:SH_CP<=1;                      
        20:begin SH_CP<=0;DS<=Data[5];end
        21:SH_CP<=1;                      
        22:begin SH_CP<=0;DS<=Data[4];end
        23:SH_CP<=1;                      
        24:begin SH_CP<=0;DS<=Data[3];end
        25:SH_CP<=1;                      
        26:begin SH_CP<=0;DS<=Data[2];end
        27:SH_CP<=1;                      
        28:begin SH_CP<=0;DS<=Data[1];end
        29:SH_CP<=1;                      
        30:begin SH_CP<=0;DS<=Data[0];end
        31:SH_CP<=1;                      
        32:ST_CP<=1;
        default:begin
            SH_CP<=0;
            ST_CP<=0;
            DS<=0;   
        end
    endcase
    
endmodule
