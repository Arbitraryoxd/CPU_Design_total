module hex8_test(
    clk,
    rst,
    Data,
    SH_CP,
    ST_CP,
    DS    
);
    
    input clk,rst;
    input wire[31:0] Data;
    output SH_CP,ST_CP,DS;
    
    wire[7:0]Sel,Cout;
    wire[15:0]Cin_Data;
    assign Cin_Data={Cout,Sel};
    
    hex8 U2(
        clk,
        rst,
        Data,
        Sel,
        Cout
    );
    
    HC595_driver U3(
        clk,
        rst,
        Cin_Data,
        1,
        SH_CP,
        ST_CP,
        DS
    );
    
endmodule
