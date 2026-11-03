//module ALU_test(
//    alu_control,
//    alu_operatorA,
//    alu_operatorB,
//    alu_result
//);

//    parameter Data_w=32;
//    parameter Control_w=12;
//    parameter Shift_w=5;

//    input[Data_w-1:0]alu_operatorA,alu_operatorB;
//    input[Control_w-1:0]alu_control;
//    output[Data_w-1:0]alu_result;
    
//    wire op_add;
//    wire op_sub;
//    wire op_slt;        //有符号数比较
//    wire op_sltu;       //无符号数比较
//    wire op_and;
//    wire op_nor;
//    wire op_or;
//    wire op_xor;
//    wire op_sll;        //逻辑右移        
//    wire op_srl;        //逻辑左移
//    wire op_sra;        //算术右移
//    wire op_lui;        //高位加载
    
//    assign op_add =alu_control[0];
//    assign op_sub =alu_control[1];
//    assign op_slt =alu_control[2];
//    assign op_sltu=alu_control[3];
//    assign op_and =alu_control[4];
//    assign op_nor =alu_control[5];
//    assign op_or  =alu_control[6];
//    assign op_xor =alu_control[7];
//    assign op_sll =alu_control[8];
//    assign op_srl =alu_control[9];
//    assign op_sra =alu_control[10];
//    assign op_lui =alu_control[11];
    
//    wire[Data_w-1:0]add_sub_result;
//    wire[Data_w-1:0]slt_result;
//    wire[Data_w-1:0]sltu_result;
//    wire[Data_w-1:0]and_result;
//    wire[Data_w-1:0]nor_result;
//    wire[Data_w-1:0]or_result;
//    wire[Data_w-1:0]xor_result;
//    wire[Data_w-1:0]sll_result;
//    wire[Data_w-1:0]srl_result;
//    wire[Data_w-1:0]sra_result;
//    wire[Data_w-1:0]lui_result;
    
//    assign and_result=alu_operatorA & alu_operatorB;
//    assign or_result=alu_operatorA & alu_operatorB;
//    assign nor_result=alu_operatorA & alu_operatorB;
//    assign xor_result=alu_operatorA & alu_operatorB;
//    assign lui_result={alu_operatorB[Data_w/2 -1:0],16'b0};
    
//    wire[Data_w-1:0]adder_a;
//    wire[Data_w-1:0]adder_b;
//    wire adder_cin;
//    wire[Data_w-1:0]adder_result;
//    wire adder_cout;
    
//    assign adder_a=alu_operatorA;
//    assign adder_b=(op_sub || op_slt || op_sltu)?~alu_operatorB:alu_operatorB;
//    assign adder_cin=(op_sub || op_slt || op_sltu);
//    assign {adder_cout,adder_result}=adder_a+adder_b+adder_cin;
    
//    assign add_sub_result=adder_cout;
    
//    assign slt_result[Data_w-1:1]=0;
    
//    assign slt_result[0]=(alu_operatorA[Data_w-1] && ~alu_operatorB[Data_w-1]) || ((alu_operatorA[Data_w-1]^~alu_operatorB[Data_w-1]) && adder_result[Data_w-1]);
    
//    assign sll_result=alu_operatorB << alu_operatorA[Shift_w-1:0];
    
//    assign srl_result=alu_operatorB >> alu_operatorA[Shift_w-1:0];
    
//    assign sra_result=($signed(alu_operatorB)) >>> alu_operatorA[Shift_w-1:0];
    
//    assign alu_result=({32{op_add | op_sub}} & add_sub_result)|
//                      ({32{op_slt}} & slt_result)|
//                      ({32{op_sltu}} & sltu_result)|
//                      ({32{op_and}} & and_result)|
//                      ({32{op_nor}} & nor_result)|
//                      ({32{op_or}} & or_result)|
//                      ({32{op_xor}} & xor_result)|
//                      ({32{op_sll}} & sll_result)|
//                      ({32{op_srl}} & srl_result)|
//                      ({32{op_sra}} & sra_result)|
//                      ({32{op_lui}} & lui_result);

//endmodule
