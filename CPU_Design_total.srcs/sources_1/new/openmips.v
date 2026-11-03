`include "defines.v"

module openmips(
    clk,
    rst,
    int_i,
    iwishbone_data_i,
    iwishbone_ack_i,
    iwishbone_addr_o,
    iwishbone_data_o,
    iwishbone_we_o,
    iwishbone_sel_o,
    iwishbone_stb_o,
    iwishbone_cyc_o,
    dwishbone_data_i,
    dwishbone_ack_i,
    dwishbone_addr_o,
    dwishbone_data_o,
    dwishbone_we_o,
    dwishbone_sel_o,
    dwishbone_stb_o,
    dwishbone_cyc_o,
    timer_int_o
);

    input wire                  clk;
    input wire                  rst;
    input wire[5:0]             int_i;

    input wire[`RegBus]         iwishbone_data_i;
    input wire                  iwishbone_ack_i;
    output wire[`RegBus]        iwishbone_addr_o;
    output wire[`RegBus]        iwishbone_data_o;
    output wire                 iwishbone_we_o;
    output wire[3:0]            iwishbone_sel_o;
    output wire                 iwishbone_stb_o;
    output wire                 iwishbone_cyc_o;

    input wire[`RegBus]         dwishbone_data_i;
    input wire                  dwishbone_ack_i;
    output wire[`RegBus]        dwishbone_addr_o;
    output wire[`RegBus]        dwishbone_data_o;
    output wire                 dwishbone_we_o;
    output wire[3:0]            dwishbone_sel_o;
    output wire                 dwishbone_stb_o;
    output wire                 dwishbone_cyc_o;
    output wire                 timer_int_o;

    // Fetch queue and front-end control.
    wire[`InstAddrBus]          pc;
    wire                        rom_ce;
    wire[`InstBus]              fetch_inst;
    wire[`InstAddrBus]          fetch_addr;
    wire                        fetch_valid;

    wire[1:0]                   queue_count;
    wire[1:0]                   consume_count;
    wire[`InstAddrBus]          queue_pc0;
    wire[`InstBus]              queue_inst0;
    wire[`InstAddrBus]          queue_pc1;
    wire[`InstBus]              queue_inst1;

    wire                        issue_valid;
    wire                        pair_issue;
    wire                        wait_for_pair;
    wire                        branch_issue;
    wire                        fetch_enable;
    wire                        fetch_ce;

    wire[5:0]                   stall;
    wire                        pipe_stall;
    wire                        flush;
    wire[`RegBus]               new_pc;
    wire[`RegBus]               id0_branch_target;

    // Pipeline 0: full instruction capability.
    wire[`AluOpBus]             id0_aluop;
    wire[`AluSelBus]            id0_alusel;
    wire[`RegBus]               id0_reg1;
    wire[`RegBus]               id0_reg2;
    wire                        id0_wreg;
    wire[`RegAddrBus]           id0_wd;
    wire                        id0_is_in_delayslot;
    wire[`RegBus]               id0_link_address;
    wire[`RegBus]               id0_inst;
    wire[31:0]                  id0_excepttype;
    wire[`RegBus]               id0_current_inst_address;
    wire                        id0_next_inst_in_delayslot;
    wire                        id0_branch_flag;
    wire                        id0_stallreq;

    wire[`AluOpBus]             id_ex0_aluop;
    wire[`AluSelBus]            id_ex0_alusel;
    wire[`RegBus]               id_ex0_reg1;
    wire[`RegBus]               id_ex0_reg2;
    wire                        id_ex0_wreg;
    wire[`RegAddrBus]           id_ex0_wd;
    wire                        id_ex0_is_in_delayslot;
    wire[`RegBus]               id_ex0_link_address;
    wire[`RegBus]               id_ex0_inst;
    wire[31:0]                  id_ex0_excepttype;
    wire[`RegBus]               id_ex0_current_inst_address;
    wire                        id_ex0_next_inst_in_delayslot;

    wire[`RegAddrBus]           ex0_wd;
    wire                        ex0_wreg;
    wire[`RegBus]               ex0_wdata;
    wire[`RegBus]               ex0_hi;
    wire[`RegBus]               ex0_lo;
    wire                        ex0_whilo;
    wire[`AluOpBus]             ex0_aluop;
    wire[`RegBus]               ex0_mem_addr;
    wire[`RegBus]               ex0_reg2;
    wire                        ex0_cp0_reg_we;
    wire[4:0]                   ex0_cp0_reg_write_addr;
    wire[`RegBus]               ex0_cp0_reg_data;
    wire[31:0]                  ex0_excepttype;
    wire                        ex0_is_in_delayslot;
    wire[`RegBus]               ex0_current_inst_address;
    wire[`DoubleRegBus]         ex0_hilo_temp;
    wire[1:0]                   ex0_cnt;
    wire[`RegBus]               ex0_div_opdata1;
    wire[`RegBus]               ex0_div_opdata2;
    wire                        ex0_div_start;
    wire                        ex0_signed_div;
    wire                        ex0_stallreq;

    wire[`RegAddrBus]           mem0_wd;
    wire                        mem0_wreg;
    wire[`RegBus]               mem0_wdata;
    wire[`RegBus]               mem0_hi;
    wire[`RegBus]               mem0_lo;
    wire                        mem0_whilo;
    wire[`AluOpBus]             mem0_aluop;
    wire[`RegBus]               mem0_mem_addr;
    wire[`RegBus]               mem0_reg2;
    wire                        mem0_cp0_reg_we;
    wire[4:0]                   mem0_cp0_reg_write_addr;
    wire[`RegBus]               mem0_cp0_reg_data;
    wire[31:0]                  mem0_excepttype_in;
    wire                        mem0_is_in_delayslot;
    wire[`RegBus]               mem0_current_inst_address;

    wire[`RegAddrBus]           mem0_wd_out;
    wire                        mem0_wreg_out;
    wire[`RegBus]               mem0_wdata_out;
    wire[`RegBus]               mem0_hi_out;
    wire[`RegBus]               mem0_lo_out;
    wire                        mem0_whilo_out;
    wire                        mem0_LLbit_we;
    wire                        mem0_LLbit_value;
    wire                        mem0_cp0_reg_we_out;
    wire[4:0]                   mem0_cp0_reg_write_addr_out;
    wire[`RegBus]               mem0_cp0_reg_data_out;
    wire[31:0]                  mem0_excepttype;
    wire[`RegBus]               mem0_cp0_epc;
    wire                        mem0_is_in_delayslot_out;
    wire[`RegBus]               mem0_current_inst_address_out;

    wire[`RegAddrBus]           wb0_wd;
    wire                        wb0_wreg;
    wire[`RegBus]               wb0_wdata;
    wire[`RegBus]               wb0_hi;
    wire[`RegBus]               wb0_lo;
    wire                        wb0_whilo;
    wire                        wb0_LLbit_we;
    wire                        wb0_LLbit_value;
    wire                        wb0_cp0_reg_we;
    wire[4:0]                   wb0_cp0_reg_write_addr;
    wire[`RegBus]               wb0_cp0_reg_data;

    // Pipeline 1: independent ALU instructions only.
    wire[`AluOpBus]             id1_aluop;
    wire[`AluSelBus]            id1_alusel;
    wire[`RegBus]               id1_reg1;
    wire[`RegBus]               id1_reg2;
    wire                        id1_wreg;
    wire[`RegAddrBus]           id1_wd;
    wire                        id1_is_in_delayslot;
    wire[`RegBus]               id1_link_address;
    wire[`RegBus]               id1_inst;
    wire[31:0]                  id1_excepttype;
    wire[`RegBus]               id1_current_inst_address;
    wire                        id1_next_inst_in_delayslot;
    wire                        id1_branch_flag;
    wire                        id1_stallreq;

    wire[`AluOpBus]             id_ex1_aluop;
    wire[`AluSelBus]            id_ex1_alusel;
    wire[`RegBus]               id_ex1_reg1;
    wire[`RegBus]               id_ex1_reg2;
    wire                        id_ex1_wreg;
    wire[`RegAddrBus]           id_ex1_wd;
    wire                        id_ex1_is_in_delayslot;
    wire[`RegBus]               id_ex1_link_address;
    wire[`RegBus]               id_ex1_inst;
    wire[31:0]                  id_ex1_excepttype;
    wire[`RegBus]               id_ex1_current_inst_address;
    wire                        id_ex1_next_inst_in_delayslot;

    wire[`RegAddrBus]           ex1_wd;
    wire                        ex1_wreg;
    wire[`RegBus]               ex1_wdata;
    wire[`RegBus]               ex1_hi;
    wire[`RegBus]               ex1_lo;
    wire                        ex1_whilo;
    wire[`AluOpBus]             ex1_aluop;
    wire[`RegBus]               ex1_mem_addr;
    wire[`RegBus]               ex1_reg2;
    wire                        ex1_cp0_reg_we;
    wire[4:0]                   ex1_cp0_reg_write_addr;
    wire[`RegBus]               ex1_cp0_reg_data;
    wire[31:0]                  ex1_excepttype;
    wire                        ex1_is_in_delayslot;
    wire[`RegBus]               ex1_current_inst_address;
    wire[`DoubleRegBus]         ex1_hilo_temp;
    wire[1:0]                   ex1_cnt;
    wire[`RegBus]               ex1_div_opdata1;
    wire[`RegBus]               ex1_div_opdata2;
    wire                        ex1_div_start;
    wire                        ex1_signed_div;
    wire                        ex1_stallreq;

    wire[`RegAddrBus]           mem1_wd;
    wire                        mem1_wreg;
    wire[`RegBus]               mem1_wdata;
    wire[`RegBus]               mem1_hi;
    wire[`RegBus]               mem1_lo;
    wire                        mem1_whilo;
    wire[`AluOpBus]             mem1_aluop;
    wire[`RegBus]               mem1_mem_addr;
    wire[`RegBus]               mem1_reg2;
    wire                        mem1_cp0_reg_we;
    wire[4:0]                   mem1_cp0_reg_write_addr;
    wire[`RegBus]               mem1_cp0_reg_data;
    wire[31:0]                  mem1_excepttype_in;
    wire                        mem1_is_in_delayslot;
    wire[`RegBus]               mem1_current_inst_address;

    wire[`RegAddrBus]           mem1_wd_out;
    wire                        mem1_wreg_out;
    wire[`RegBus]               mem1_wdata_out;
    wire[`RegBus]               mem1_hi_out;
    wire[`RegBus]               mem1_lo_out;
    wire                        mem1_whilo_out;
    wire                        mem1_LLbit_we;
    wire                        mem1_LLbit_value;
    wire                        mem1_cp0_reg_we_out;
    wire[4:0]                   mem1_cp0_reg_write_addr_out;
    wire[`RegBus]               mem1_cp0_reg_data_out;
    wire[31:0]                  mem1_excepttype;
    wire[`RegBus]               mem1_cp0_epc;
    wire                        mem1_is_in_delayslot_out;
    wire[`RegBus]               mem1_current_inst_address_out;

    wire[`RegAddrBus]           wb1_wd;
    wire                        wb1_wreg;
    wire[`RegBus]               wb1_wdata;
    wire[`RegBus]               wb1_hi;
    wire[`RegBus]               wb1_lo;
    wire                        wb1_whilo;
    wire                        wb1_LLbit_we;
    wire                        wb1_LLbit_value;
    wire                        wb1_cp0_reg_we;
    wire[4:0]                   wb1_cp0_reg_write_addr;
    wire[`RegBus]               wb1_cp0_reg_data;

    wire[5:0]                   stall_ch0;
    wire[5:0]                   stall_ch1;
    wire                        stall_ch0_id;
    wire                        stall_ch1_id;

    // Register file ports.
    wire                        reg0_re1;
    wire                        reg0_re2;
    wire[`RegAddrBus]           reg0_raddr1;
    wire[`RegAddrBus]           reg0_raddr2;
    wire[`RegBus]               reg0_rdata1;
    wire[`RegBus]               reg0_rdata2;
    wire                        reg1_re1;
    wire                        reg1_re2;
    wire[`RegAddrBus]           reg1_raddr1;
    wire[`RegAddrBus]           reg1_raddr2;
    wire[`RegBus]               reg1_rdata1;
    wire[`RegBus]               reg1_rdata2;

    wire[`RegBus]               hi;
    wire[`RegBus]               lo;
    wire[`DoubleRegBus]         hilo_temp_i;
    wire[1:0]                   cnt_i;

    wire[`DoubleRegBus]         div_result;
    wire                        div_ready;
    wire[`RegBus]               div_opdata1;
    wire[`RegBus]               div_opdata2;
    wire                        div_start;
    wire                        signed_div;

    wire[`RegBus]               cp0_data;
    wire[4:0]                   cp0_raddr;
    wire[`RegBus]               cp0_count;
    wire[`RegBus]               cp0_compare;
    wire[`RegBus]               cp0_status;
    wire[`RegBus]               cp0_cause;
    wire[`RegBus]               cp0_epc;
    wire[`RegBus]               cp0_config;
    wire[`RegBus]               cp0_prid;
    wire                        LLbit;

    wire                        stallreq_from_if;
    wire                        stallreq_from_ex;
    wire                        stallreq_from_mem;
    wire                        ibus_stallreq;
    wire                        dbus_stallreq;

    wire[`RegBus]               ram_addr_o;
    wire                        ram_we_o;
    wire[3:0]                   ram_sel_o;
    wire[`RegBus]               ram_data_o;
    wire                        ram_ce_o;
    wire[`RegBus]               ram_data_i;

    assign pipe_stall = |stall[5:1];
    // A request may only be launched when the queue has a physical free slot.
    // This prevents a long-latency bus response from arriving at a full queue.
    assign fetch_enable = (queue_count < 2'b10);
    assign fetch_ce = rom_ce && fetch_enable && (~flush) && (~branch_issue);
    assign branch_issue = issue_valid && (id0_branch_flag == `Branch);
    assign stallreq_from_if = (branch_issue == 1'b1) ? `NoStop :
                              (ibus_stallreq | (~fetch_enable));
    assign stallreq_from_ex = ex0_stallreq | ex1_stallreq;
    assign stallreq_from_mem = dbus_stallreq;

    // Keep one channel free to insert a bubble while the other channel
    // continues with an instruction already in flight.
    assign stall_ch0_id = ((stall[2] == `Stop) || (issue_valid == 1'b0)) ?
                          `Stop : `NoStop;
    assign stall_ch1_id = ((stall[2] == `Stop) || (pair_issue == 1'b0)) ?
                          `Stop : `NoStop;
    assign stall_ch0 = {stall[5:3], stall_ch0_id, stall[1:0]};
    assign stall_ch1 = {stall[5:3], stall_ch1_id, stall[1:0]};

    pc_reg pc_reg0(
        .clk(clk),
        .rst(rst),
        .stall(stall),
        .flush(flush),
        .new_pc(new_pc),
        .branch_flag_i(branch_issue),
        .branch_target_address_i(id0_branch_target),
        .pc(pc),
        .ce(rom_ce)
    );

    instruction_queue instruction_queue0(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .push_en(fetch_valid &&
                 (~branch_issue) &&
                 ((queue_count < 2'b10) || (consume_count != 2'b00))),
        .push_pc(fetch_addr),
        .push_inst(fetch_inst),
        .consume_count(consume_count),
        .q_count(queue_count),
        .pc0(queue_pc0),
        .inst0(queue_inst0),
        .pc1(queue_pc1),
        .inst1(queue_inst1)
    );

    id id0(
        .rst(rst),
        .pc_i(queue_pc0),
        .inst_i(queue_inst0),
        .reg1_data_i(reg0_rdata1),
        .reg2_data_i(reg0_rdata2),
        .ex_aluop_i(ex0_aluop),
        .ex_wreg_i(ex0_wreg),
        .ex_wdata_i(ex0_wdata),
        .ex_wd_i(ex0_wd),
        .ex1_aluop_i(ex1_aluop),
        .ex1_wreg_i(ex1_wreg),
        .ex1_wdata_i(ex1_wdata),
        .ex1_wd_i(ex1_wd),
        .mem_wreg_i(mem0_wreg_out),
        .mem_wdata_i(mem0_wdata_out),
        .mem_wd_i(mem0_wd_out),
        .mem1_wreg_i(mem1_wreg_out),
        .mem1_wdata_i(mem1_wdata_out),
        .mem1_wd_i(mem1_wd_out),
        .is_in_delayslot_i(id_ex0_next_inst_in_delayslot),
        .next_inst_in_delayslot_o(id0_next_inst_in_delayslot),
        .branch_flag_o(id0_branch_flag),
        .branch_target_address_o(id0_branch_target),
        .link_addr_o(id0_link_address),
        .is_in_delayslot_o(id0_is_in_delayslot),
        .reg1_read_o(reg0_re1),
        .reg2_read_o(reg0_re2),
        .reg1_addr_o(reg0_raddr1),
        .reg2_addr_o(reg0_raddr2),
        .aluop_o(id0_aluop),
        .alusel_o(id0_alusel),
        .reg1_o(id0_reg1),
        .reg2_o(id0_reg2),
        .wd_o(id0_wd),
        .wreg_o(id0_wreg),
        .stallreq(id0_stallreq),
        .inst_o(id0_inst),
        .excepttype_o(id0_excepttype),
        .current_inst_address_o(id0_current_inst_address)
    );

    id id1(
        .rst(rst),
        .pc_i(queue_pc1),
        .inst_i(queue_inst1),
        .reg1_data_i(reg1_rdata1),
        .reg2_data_i(reg1_rdata2),
        .ex_aluop_i(ex0_aluop),
        .ex_wreg_i(ex0_wreg),
        .ex_wdata_i(ex0_wdata),
        .ex_wd_i(ex0_wd),
        .ex1_aluop_i(ex1_aluop),
        .ex1_wreg_i(ex1_wreg),
        .ex1_wdata_i(ex1_wdata),
        .ex1_wd_i(ex1_wd),
        .mem_wreg_i(mem0_wreg_out),
        .mem_wdata_i(mem0_wdata_out),
        .mem_wd_i(mem0_wd_out),
        .mem1_wreg_i(mem1_wreg_out),
        .mem1_wdata_i(mem1_wdata_out),
        .mem1_wd_i(mem1_wd_out),
        .is_in_delayslot_i(id_ex0_next_inst_in_delayslot),
        .next_inst_in_delayslot_o(id1_next_inst_in_delayslot),
        .branch_flag_o(id1_branch_flag),
        .branch_target_address_o(),
        .link_addr_o(id1_link_address),
        .is_in_delayslot_o(id1_is_in_delayslot),
        .reg1_read_o(reg1_re1),
        .reg2_read_o(reg1_re2),
        .reg1_addr_o(reg1_raddr1),
        .reg2_addr_o(reg1_raddr2),
        .aluop_o(id1_aluop),
        .alusel_o(id1_alusel),
        .reg1_o(id1_reg1),
        .reg2_o(id1_reg2),
        .wd_o(id1_wd),
        .wreg_o(id1_wreg),
        .stallreq(id1_stallreq),
        .inst_o(id1_inst),
        .excepttype_o(id1_excepttype),
        .current_inst_address_o(id1_current_inst_address)
    );

    dual_issue_ctrl dual_issue_ctrl0(
        .rst(rst),
        .q_count(queue_count),
        .is_in_delayslot_i(id_ex0_next_inst_in_delayslot),
        .pipe_stall(pipe_stall),
        .flush(flush),
        .id0_wreg(id0_wreg),
        .id0_wd(id0_wd),
        .id0_aluop(id0_aluop),
        .id0_alusel(id0_alusel),
        .id0_branch_flag(id0_branch_flag),
        .id0_excepttype(id0_excepttype),
        .id0_stallreq(id0_stallreq),
        .id0_reg1_read(reg0_re1),
        .id0_reg1_addr(reg0_raddr1),
        .id0_reg2_read(reg0_re2),
        .id0_reg2_addr(reg0_raddr2),
        .id1_wreg(id1_wreg),
        .id1_wd(id1_wd),
        .id1_aluop(id1_aluop),
        .id1_alusel(id1_alusel),
        .id1_branch_flag(id1_branch_flag),
        .id1_excepttype(id1_excepttype),
        .id1_stallreq(id1_stallreq),
        .id1_reg1_read(reg1_re1),
        .id1_reg1_addr(reg1_raddr1),
        .id1_reg2_read(reg1_re2),
        .id1_reg2_addr(reg1_raddr2),
        .issue_valid(issue_valid),
        .pair_issue(pair_issue),
        .consume_count(consume_count),
        .wait_for_pair(wait_for_pair)
    );

    Regfile_1 regfile1(
        .clk(clk),
        .rst(rst),
        .we(wb0_wreg),
        .waddr(wb0_wd),
        .wdata(wb0_wdata),
        .we2(wb1_wreg),
        .waddr2(wb1_wd),
        .wdata2(wb1_wdata),
        .re1(reg0_re1),
        .raddr1(reg0_raddr1),
        .rdata1(reg0_rdata1),
        .re2(reg0_re2),
        .raddr2(reg0_raddr2),
        .rdata2(reg0_rdata2),
        .re3(reg1_re1),
        .raddr3(reg1_raddr1),
        .rdata3(reg1_rdata1),
        .re4(reg1_re2),
        .raddr4(reg1_raddr2),
        .rdata4(reg1_rdata2)
    );

    id_ex id_ex0(
        .rst(rst),
        .clk(clk),
        .stall(stall_ch0),
        .flush(flush),
        .id_aluop(id0_aluop),
        .id_alusel(id0_alusel),
        .id_reg1(id0_reg1),
        .id_reg2(id0_reg2),
        .id_wd(id0_wd),
        .id_wreg(id0_wreg),
        .id_link_address(id0_link_address),
        .id_is_in_delayslot(id0_is_in_delayslot),
        .next_inst_in_delayslot_i(id0_next_inst_in_delayslot),
        .id_inst(id0_inst),
        .id_excepttype(id0_excepttype),
        .id_current_inst_address(id0_current_inst_address),
        .ex_aluop(id_ex0_aluop),
        .ex_alusel(id_ex0_alusel),
        .ex_reg1(id_ex0_reg1),
        .ex_reg2(id_ex0_reg2),
        .ex_wd(id_ex0_wd),
        .ex_wreg(id_ex0_wreg),
        .ex_link_address(id_ex0_link_address),
        .ex_is_in_delayslot(id_ex0_is_in_delayslot),
        .is_in_delayslot_o(id_ex0_next_inst_in_delayslot),
        .ex_inst(id_ex0_inst),
        .ex_excepttype(id_ex0_excepttype),
        .ex_current_inst_address(id_ex0_current_inst_address)
    );

    id_ex id_ex1(
        .rst(rst),
        .clk(clk),
        .stall(stall_ch1),
        .flush(flush),
        .id_aluop(id1_aluop),
        .id_alusel(id1_alusel),
        .id_reg1(id1_reg1),
        .id_reg2(id1_reg2),
        .id_wd(id1_wd),
        .id_wreg(id1_wreg),
        .id_link_address(id1_link_address),
        .id_is_in_delayslot(id1_is_in_delayslot),
        .next_inst_in_delayslot_i(id1_next_inst_in_delayslot),
        .id_inst(id1_inst),
        .id_excepttype(id1_excepttype),
        .id_current_inst_address(id1_current_inst_address),
        .ex_aluop(id_ex1_aluop),
        .ex_alusel(id_ex1_alusel),
        .ex_reg1(id_ex1_reg1),
        .ex_reg2(id_ex1_reg2),
        .ex_wd(id_ex1_wd),
        .ex_wreg(id_ex1_wreg),
        .ex_link_address(id_ex1_link_address),
        .ex_is_in_delayslot(id_ex1_is_in_delayslot),
        .is_in_delayslot_o(id_ex1_next_inst_in_delayslot),
        .ex_inst(id_ex1_inst),
        .ex_excepttype(id_ex1_excepttype),
        .ex_current_inst_address(id_ex1_current_inst_address)
    );

    ex ex0(
        .rst(rst),
        .alusel_i(id_ex0_alusel),
        .aluop_i(id_ex0_aluop),
        .reg1_i(id_ex0_reg1),
        .reg2_i(id_ex0_reg2),
        .wd_i(id_ex0_wd),
        .wreg_i(id_ex0_wreg),
        .hi_i(hi),
        .lo_i(lo),
        .wb_hi_i(wb0_hi),
        .wb_lo_i(wb0_lo),
        .wb_whilo_i(wb0_whilo),
        .mem_hi_i(mem0_hi),
        .mem_lo_i(mem0_lo),
        .mem_whilo_i(mem0_whilo),
        .hilo_temp_i(hilo_temp_i),
        .cnt_i(cnt_i),
        .div_result_i(div_result),
        .div_ready_i(div_ready),
        .link_address_i(id_ex0_link_address),
        .is_in_delayslot_i(id_ex0_is_in_delayslot),
        .inst_i(id_ex0_inst),
        .excepttype_i(id_ex0_excepttype),
        .current_inst_address_i(id_ex0_current_inst_address),
        .mem_cp0_reg_we(mem0_cp0_reg_we),
        .mem_cp0_reg_write_addr(mem0_cp0_reg_write_addr),
        .mem_cp0_reg_data(mem0_cp0_reg_data),
        .wb_cp0_reg_we(wb0_cp0_reg_we),
        .wb_cp0_reg_write_addr(wb0_cp0_reg_write_addr),
        .wb_cp0_reg_data(wb0_cp0_reg_data),
        .cp0_reg_data_i(cp0_data),
        .cp0_reg_read_addr_o(cp0_raddr),
        .cp0_reg_we_o(ex0_cp0_reg_we),
        .cp0_reg_write_addr_o(ex0_cp0_reg_write_addr),
        .cp0_reg_data_o(ex0_cp0_reg_data),
        .excepttype_o(ex0_excepttype),
        .is_in_delayslot_o(ex0_is_in_delayslot),
        .current_inst_address_o(ex0_current_inst_address),
        .wd_o(ex0_wd),
        .wreg_o(ex0_wreg),
        .wdata_o(ex0_wdata),
        .hi_o(ex0_hi),
        .lo_o(ex0_lo),
        .whilo_o(ex0_whilo),
        .hilo_temp_o(ex0_hilo_temp),
        .cnt_o(ex0_cnt),
        .div_opdata1_o(ex0_div_opdata1),
        .div_opdata2_o(ex0_div_opdata2),
        .div_start_o(ex0_div_start),
        .signed_div_o(ex0_signed_div),
        .aluop_o(ex0_aluop),
        .mem_addr_o(ex0_mem_addr),
        .reg2_o(ex0_reg2),
        .stallreq(ex0_stallreq)
    );

    ex ex1(
        .rst(rst),
        .alusel_i(id_ex1_alusel),
        .aluop_i(id_ex1_aluop),
        .reg1_i(id_ex1_reg1),
        .reg2_i(id_ex1_reg2),
        .wd_i(id_ex1_wd),
        .wreg_i(id_ex1_wreg),
        .hi_i(hi),
        .lo_i(lo),
        .wb_hi_i(wb0_hi),
        .wb_lo_i(wb0_lo),
        .wb_whilo_i(wb0_whilo),
        .mem_hi_i(mem0_hi),
        .mem_lo_i(mem0_lo),
        .mem_whilo_i(mem0_whilo),
        .hilo_temp_i({`ZeroWord, `ZeroWord}),
        .cnt_i(2'b00),
        .div_result_i({`ZeroWord, `ZeroWord}),
        .div_ready_i(`DivResultNotReady),
        .link_address_i(id_ex1_link_address),
        .is_in_delayslot_i(id_ex1_is_in_delayslot),
        .inst_i(id_ex1_inst),
        .excepttype_i(id_ex1_excepttype),
        .current_inst_address_i(id_ex1_current_inst_address),
        .mem_cp0_reg_we(mem0_cp0_reg_we),
        .mem_cp0_reg_write_addr(mem0_cp0_reg_write_addr),
        .mem_cp0_reg_data(mem0_cp0_reg_data),
        .wb_cp0_reg_we(wb0_cp0_reg_we),
        .wb_cp0_reg_write_addr(wb0_cp0_reg_write_addr),
        .wb_cp0_reg_data(wb0_cp0_reg_data),
        .cp0_reg_data_i(cp0_data),
        .cp0_reg_read_addr_o(),
        .cp0_reg_we_o(ex1_cp0_reg_we),
        .cp0_reg_write_addr_o(ex1_cp0_reg_write_addr),
        .cp0_reg_data_o(ex1_cp0_reg_data),
        .excepttype_o(ex1_excepttype),
        .is_in_delayslot_o(ex1_is_in_delayslot),
        .current_inst_address_o(ex1_current_inst_address),
        .wd_o(ex1_wd),
        .wreg_o(ex1_wreg),
        .wdata_o(ex1_wdata),
        .hi_o(ex1_hi),
        .lo_o(ex1_lo),
        .whilo_o(ex1_whilo),
        .hilo_temp_o(ex1_hilo_temp),
        .cnt_o(ex1_cnt),
        .div_opdata1_o(ex1_div_opdata1),
        .div_opdata2_o(ex1_div_opdata2),
        .div_start_o(ex1_div_start),
        .signed_div_o(ex1_signed_div),
        .aluop_o(ex1_aluop),
        .mem_addr_o(ex1_mem_addr),
        .reg2_o(ex1_reg2),
        .stallreq(ex1_stallreq)
    );

    ex_mem ex_mem0(
        .clk(clk),
        .rst(rst),
        .stall(stall),
        .flush(flush),
        .ex_wd(ex0_wd),
        .ex_wreg(ex0_wreg),
        .ex_wdata(ex0_wdata),
        .ex_hi(ex0_hi),
        .ex_lo(ex0_lo),
        .ex_whilo(ex0_whilo),
        .ex_aluop(ex0_aluop),
        .ex_mem_addr(ex0_mem_addr),
        .ex_reg2(ex0_reg2),
        .ex_cp0_reg_we(ex0_cp0_reg_we),
        .ex_cp0_reg_write_addr(ex0_cp0_reg_write_addr),
        .ex_cp0_reg_data(ex0_cp0_reg_data),
        .ex_excepttype(ex0_excepttype),
        .ex_is_in_delayslot(ex0_is_in_delayslot),
        .ex_current_inst_address(ex0_current_inst_address),
        .hilo_i(ex0_hilo_temp),
        .cnt_i(ex0_cnt),
        .mem_wd(mem0_wd),
        .mem_wreg(mem0_wreg),
        .mem_wdata(mem0_wdata),
        .mem_hi(mem0_hi),
        .mem_lo(mem0_lo),
        .mem_whilo(mem0_whilo),
        .mem_cp0_reg_we(mem0_cp0_reg_we),
        .mem_cp0_reg_write_addr(mem0_cp0_reg_write_addr),
        .mem_cp0_reg_data(mem0_cp0_reg_data),
        .mem_aluop(mem0_aluop),
        .mem_mem_addr(mem0_mem_addr),
        .mem_reg2(mem0_reg2),
        .mem_excepttype(mem0_excepttype_in),
        .mem_is_in_delayslot(mem0_is_in_delayslot),
        .mem_current_inst_address(mem0_current_inst_address),
        .hilo_o(hilo_temp_i),
        .cnt_o(cnt_i)
    );

    ex_mem ex_mem1(
        .clk(clk),
        .rst(rst),
        .stall(stall),
        .flush(flush),
        .ex_wd(ex1_wd),
        .ex_wreg(ex1_wreg),
        .ex_wdata(ex1_wdata),
        .ex_hi(ex1_hi),
        .ex_lo(ex1_lo),
        .ex_whilo(ex1_whilo),
        .ex_aluop(ex1_aluop),
        .ex_mem_addr(ex1_mem_addr),
        .ex_reg2(ex1_reg2),
        .ex_cp0_reg_we(ex1_cp0_reg_we),
        .ex_cp0_reg_write_addr(ex1_cp0_reg_write_addr),
        .ex_cp0_reg_data(ex1_cp0_reg_data),
        .ex_excepttype(ex1_excepttype),
        .ex_is_in_delayslot(ex1_is_in_delayslot),
        .ex_current_inst_address(ex1_current_inst_address),
        .hilo_i(ex1_hilo_temp),
        .cnt_i(ex1_cnt),
        .mem_wd(mem1_wd),
        .mem_wreg(mem1_wreg),
        .mem_wdata(mem1_wdata),
        .mem_hi(mem1_hi),
        .mem_lo(mem1_lo),
        .mem_whilo(mem1_whilo),
        .mem_cp0_reg_we(mem1_cp0_reg_we),
        .mem_cp0_reg_write_addr(mem1_cp0_reg_write_addr),
        .mem_cp0_reg_data(mem1_cp0_reg_data),
        .mem_aluop(mem1_aluop),
        .mem_mem_addr(mem1_mem_addr),
        .mem_reg2(mem1_reg2),
        .mem_excepttype(mem1_excepttype_in),
        .mem_is_in_delayslot(mem1_is_in_delayslot),
        .mem_current_inst_address(mem1_current_inst_address),
        .hilo_o(),
        .cnt_o()
    );

    mem mem0(
        .rst(rst),
        .wd_i(mem0_wd),
        .wreg_i(mem0_wreg),
        .wdata_i(mem0_wdata),
        .hi_i(mem0_hi),
        .lo_i(mem0_lo),
        .whilo_i(mem0_whilo),
        .aluop_i(mem0_aluop),
        .mem_addr_i(mem0_mem_addr),
        .reg2_i(mem0_reg2),
        .mem_data_i(ram_data_i),
        .LLbit_i(LLbit),
        .wb_LLbit_we_i(wb0_LLbit_we),
        .wb_LLbit_value_i(wb0_LLbit_value),
        .cp0_reg_we_i(mem0_cp0_reg_we),
        .cp0_reg_write_addr_i(mem0_cp0_reg_write_addr),
        .cp0_reg_data_i(mem0_cp0_reg_data),
        .excepttype_i(mem0_excepttype_in),
        .is_in_delayslot_i(mem0_is_in_delayslot),
        .current_inst_address_i(mem0_current_inst_address),
        .cp0_status_i(cp0_status),
        .cp0_cause_i(cp0_cause),
        .cp0_epc_i(cp0_epc),
        .wb_cp0_reg_we(wb0_cp0_reg_we),
        .wb_cp0_reg_write_addr(wb0_cp0_reg_write_addr),
        .wb_cp0_reg_data(wb0_cp0_reg_data),
        .cp0_reg_we_o(mem0_cp0_reg_we_out),
        .cp0_reg_write_addr_o(mem0_cp0_reg_write_addr_out),
        .cp0_reg_data_o(mem0_cp0_reg_data_out),
        .wd_o(mem0_wd_out),
        .wreg_o(mem0_wreg_out),
        .wdata_o(mem0_wdata_out),
        .hi_o(mem0_hi_out),
        .lo_o(mem0_lo_out),
        .whilo_o(mem0_whilo_out),
        .mem_addr_o(ram_addr_o),
        .mem_sel_o(ram_sel_o),
        .mem_data_o(ram_data_o),
        .mem_ce_o(ram_ce_o),
        .mem_we_o(ram_we_o),
        .LLbit_we_o(mem0_LLbit_we),
        .LLbit_value_o(mem0_LLbit_value),
        .excepttype_o(mem0_excepttype),
        .cp0_epc_o(mem0_cp0_epc),
        .is_in_delayslot_o(mem0_is_in_delayslot_out),
        .current_inst_address_o(mem0_current_inst_address_out)
    );

    mem mem1(
        .rst(rst),
        .wd_i(mem1_wd),
        .wreg_i(mem1_wreg),
        .wdata_i(mem1_wdata),
        .hi_i(mem1_hi),
        .lo_i(mem1_lo),
        .whilo_i(mem1_whilo),
        .aluop_i(mem1_aluop),
        .mem_addr_i(mem1_mem_addr),
        .reg2_i(mem1_reg2),
        .mem_data_i(ram_data_i),
        .LLbit_i(LLbit),
        .wb_LLbit_we_i(wb0_LLbit_we),
        .wb_LLbit_value_i(wb0_LLbit_value),
        .cp0_reg_we_i(mem1_cp0_reg_we),
        .cp0_reg_write_addr_i(mem1_cp0_reg_write_addr),
        .cp0_reg_data_i(mem1_cp0_reg_data),
        .excepttype_i(mem1_excepttype_in),
        .is_in_delayslot_i(mem1_is_in_delayslot),
        .current_inst_address_i(mem1_current_inst_address),
        .cp0_status_i(cp0_status),
        .cp0_cause_i(cp0_cause),
        .cp0_epc_i(cp0_epc),
        .wb_cp0_reg_we(wb0_cp0_reg_we),
        .wb_cp0_reg_write_addr(wb0_cp0_reg_write_addr),
        .wb_cp0_reg_data(wb0_cp0_reg_data),
        .cp0_reg_we_o(mem1_cp0_reg_we_out),
        .cp0_reg_write_addr_o(mem1_cp0_reg_write_addr_out),
        .cp0_reg_data_o(mem1_cp0_reg_data_out),
        .wd_o(mem1_wd_out),
        .wreg_o(mem1_wreg_out),
        .wdata_o(mem1_wdata_out),
        .hi_o(mem1_hi_out),
        .lo_o(mem1_lo_out),
        .whilo_o(mem1_whilo_out),
        .mem_addr_o(),
        .mem_sel_o(),
        .mem_data_o(),
        .mem_ce_o(),
        .mem_we_o(),
        .LLbit_we_o(mem1_LLbit_we),
        .LLbit_value_o(mem1_LLbit_value),
        .excepttype_o(mem1_excepttype),
        .cp0_epc_o(mem1_cp0_epc),
        .is_in_delayslot_o(mem1_is_in_delayslot_out),
        .current_inst_address_o(mem1_current_inst_address_out)
    );

    mem_wb mem_wb0(
        .clk(clk),
        .rst(rst),
        .stall(stall),
        .flush(flush),
        .mem_wd(mem0_wd_out),
        .mem_wreg(mem0_wreg_out),
        .mem_wdata(mem0_wdata_out),
        .mem_hi(mem0_hi_out),
        .mem_lo(mem0_lo_out),
        .mem_whilo(mem0_whilo_out),
        .mem_LLbit_we(mem0_LLbit_we),
        .mem_LLbit_value(mem0_LLbit_value),
        .mem_cp0_reg_we(mem0_cp0_reg_we_out),
        .mem_cp0_reg_write_addr(mem0_cp0_reg_write_addr_out),
        .mem_cp0_reg_data(mem0_cp0_reg_data_out),
        .wb_wd(wb0_wd),
        .wb_wreg(wb0_wreg),
        .wb_wdata(wb0_wdata),
        .wb_hi(wb0_hi),
        .wb_lo(wb0_lo),
        .wb_whilo(wb0_whilo),
        .wb_LLbit_we(wb0_LLbit_we),
        .wb_LLbit_value(wb0_LLbit_value),
        .wb_cp0_reg_we(wb0_cp0_reg_we),
        .wb_cp0_reg_write_addr(wb0_cp0_reg_write_addr),
        .wb_cp0_reg_data(wb0_cp0_reg_data)
    );

    mem_wb mem_wb1(
        .clk(clk),
        .rst(rst),
        .stall(stall),
        .flush(flush),
        .mem_wd(mem1_wd_out),
        .mem_wreg(mem1_wreg_out),
        .mem_wdata(mem1_wdata_out),
        .mem_hi(mem1_hi_out),
        .mem_lo(mem1_lo_out),
        .mem_whilo(mem1_whilo_out),
        .mem_LLbit_we(mem1_LLbit_we),
        .mem_LLbit_value(mem1_LLbit_value),
        .mem_cp0_reg_we(mem1_cp0_reg_we_out),
        .mem_cp0_reg_write_addr(mem1_cp0_reg_write_addr_out),
        .mem_cp0_reg_data(mem1_cp0_reg_data_out),
        .wb_wd(wb1_wd),
        .wb_wreg(wb1_wreg),
        .wb_wdata(wb1_wdata),
        .wb_hi(wb1_hi),
        .wb_lo(wb1_lo),
        .wb_whilo(wb1_whilo),
        .wb_LLbit_we(wb1_LLbit_we),
        .wb_LLbit_value(wb1_LLbit_value),
        .wb_cp0_reg_we(wb1_cp0_reg_we),
        .wb_cp0_reg_write_addr(wb1_cp0_reg_write_addr),
        .wb_cp0_reg_data(wb1_cp0_reg_data)
    );

    hilo_reg hilo_reg0(
        .clk(clk),
        .rst(rst),
        .we(wb0_whilo),
        .hi_i(wb0_hi),
        .lo_i(wb0_lo),
        .hi_o(hi),
        .lo_o(lo)
    );

    ctrl ctrl0(
        .rst(rst),
        .stallreq_from_if(stallreq_from_if),
        .stallreq_from_id(id0_stallreq),
        .stallreq_from_ex(stallreq_from_ex),
        .stallreq_from_mem(stallreq_from_mem),
        .excepttype_i(mem0_excepttype),
        .cp0_epc_i(mem0_cp0_epc),
        .new_pc(new_pc),
        .flush(flush),
        .stall(stall)
    );

    div div0(
        .clk(clk),
        .rst(rst),
        .signed_div_i(ex0_signed_div),
        .opdata1_i(ex0_div_opdata1),
        .opdata2_i(ex0_div_opdata2),
        .start_i(ex0_div_start),
        .annul_i(flush),
        .result_o(div_result),
        .ready_o(div_ready)
    );

    LLbit_reg LLbit_reg0(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .LLbit_i(wb0_LLbit_value),
        .we(wb0_LLbit_we),
        .LLbit_o(LLbit)
    );

    cp0_reg cp0_reg0(
        .clk(clk),
        .rst(rst),
        .we_i(wb0_cp0_reg_we),
        .waddr_i(wb0_cp0_reg_write_addr),
        .raddr_i(cp0_raddr),
        .data_i(wb0_cp0_reg_data),
        .excepttype_i(mem0_excepttype),
        .int_i(int_i),
        .current_inst_addr_i(mem0_current_inst_address_out),
        .is_in_delayslot_i(mem0_is_in_delayslot_out),
        .data_o(cp0_data),
        .count_o(cp0_count),
        .compare_o(cp0_compare),
        .status_o(cp0_status),
        .cause_o(cp0_cause),
        .epc_o(cp0_epc),
        .config_o(cp0_config),
        .prid_o(cp0_prid),
        .timer_int_o(timer_int_o)
    );

    wishbone_bus_if dwishbone_bus_if(
        .clk(clk),
        .rst(rst),
        .stall_i(stall),
        .flush_i(flush),
        .cpu_ce_i(ram_ce_o),
        .cpu_data_i(ram_data_o),
        .cpu_addr_i(ram_addr_o),
        .cpu_we_i(ram_we_o),
        .cpu_sel_i(ram_sel_o),
        .cpu_data_o(ram_data_i),
        .cpu_data_addr_o(),
        .cpu_data_valid_o(),
        .wishbone_data_i(dwishbone_data_i),
        .wishbone_ack_i(dwishbone_ack_i),
        .wishbone_addr_o(dwishbone_addr_o),
        .wishbone_data_o(dwishbone_data_o),
        .wishbone_we_o(dwishbone_we_o),
        .wishbone_sel_o(dwishbone_sel_o),
        .wishbone_stb_o(dwishbone_stb_o),
        .wishbone_cyc_o(dwishbone_cyc_o),
        .stallreq(dbus_stallreq)
    );

    wishbone_bus_if iwishbone_bus_if(
        .clk(clk),
        .rst(rst),
        .stall_i(stall),
        .flush_i(flush | branch_issue),
        .cpu_ce_i(fetch_ce),
        .cpu_data_i(`ZeroWord),
        .cpu_addr_i(pc),
        .cpu_we_i(`WriteDisable),
        .cpu_sel_i(4'b1111),
        .cpu_data_o(fetch_inst),
        .cpu_data_addr_o(fetch_addr),
        .cpu_data_valid_o(fetch_valid),
        .wishbone_data_i(iwishbone_data_i),
        .wishbone_ack_i(iwishbone_ack_i),
        .wishbone_addr_o(iwishbone_addr_o),
        .wishbone_data_o(iwishbone_data_o),
        .wishbone_we_o(iwishbone_we_o),
        .wishbone_sel_o(iwishbone_sel_o),
        .wishbone_stb_o(iwishbone_stb_o),
        .wishbone_cyc_o(iwishbone_cyc_o),
        .stallreq(ibus_stallreq)
    );

endmodule
