module top(
    input  wire         clk,
    input  wire         rst_n,
    input  wire[31:0]   inst_i,

    output wire[31:0]   inst_addr_o
);

    // pc_reg to if
    wire[31:0]  pc_reg_pc_o;

    // if to if_id
    wire[31:0]  ifetch_inst_addr_o;
    wire[31:0]  ifetch_inst_o;

    // if_id to id
    wire[31:0]  if_id_inst_addr_o;
    wire[31:0]  if_id_inst_o;

    // id to regs
    wire[5:0]   id_rs1_addr_o;
    wire[5:0]   id_rs2_addr_o;

    // regs to id
    wire[31:0]  regs_reg1_rdata_o;
    wire[31:0]  regs_reg2_rdata_o;

    // id to id_ex
    wire[31:0] ;
    wire[31:0] ;


    pc_reg pc_reg_inst(
        // input
        .clk            (clk),
        .rst_n          (rst_n),

        // output
        .pc_o           (pc_reg_pc_o)
    );

    ifetch ifetch_inst(
        // from pc
        pc_addr_i       (pc_reg_pc_o),
        // from rom
        rom_inst_i      (inst_i), 
        
        // to rom 
        if2rom_addr_o   (inst_addr_o),
        // to if_id
        inst_addr_o     (ifetch_inst_addr_o),
        inst_o          (ifetch_inst_o)
    );

    if_id if_id_inst(
        .clk            (clk),
        .rst_n          (rst_n),
        .inst_addr_i    (ifetch_inst_addr_o),
        .inst_i         (ifetch_inst_o),

        .inst_addr_o    (if_id_inst_addr_o),
        .inst_o         (if_id_inst_o)
    );

    id id_inst(
        // from if_id
        .inst_addr_i    (if_id_inst_addr_o),
        .inst_i         (if_id_inst_o),
        
        // to regs
        .rs1_addr_o     (id_rs1_addr_o),
        .rs2_addr_o     (id_rs1_addr_o),

        // from regs
        .rs1_data_i     (regs_reg1_rdata_o),
        .rs2_data_i     (regs_reg2_rdata_o),

        // to id_ex
        .inst_addr_o    (),
        .inst_o         (),
        .op1_o          (),
        .op2_o          (),
        .rd_addr_o      (),
        .reg_wen        ()  
    );

    regs regs_inst(
        .clk            (clk),
        .rst_n          (rst_n),

        // from id
        .reg1_raddr_i   (id_rs1_addr_o),
        .reg2_raddr_i   (id_rs2_addr_o),

        // to id
        .reg1_rdata_o   (regs_reg1_rdata_o),
        .reg2_rdata_o   (regs_reg2_rdata_o),

        // from ex
        .reg_waddr_i    (),
        .reg_wdata_i    (),
        .reg_wen        ()
    );

    id_ex id_ex_inst(
        .clk            (clk),
        .rst_n          (rst_n),

        // from id
        .inst_addr_i    (),
        .inst_i         (),
        .op1_i          (),
        .op2_i          (),
        .rd_addr_i      (),
        .reg_wen_i      (),

        // to ex
        .inst_addr_o    (),
        .inst_o         (),
        .op1_o          (),
        .op2_o          (),
        .rd_addr_o      (),
        .reg_wen_o      ()
    );


    ex ex_inst(
        // from id_ex
        .inst_addr_i    (),
        .inst_i         (),
        .op1_i          (),
        .op2_i          (),
        .rd_addr_i      (),
        .reg_wen_i      (),

        // to regs
        .rd_addr_o      (),
        .rd_data_o      (),
        .rd_wen_o       ()
    );

endmodule()