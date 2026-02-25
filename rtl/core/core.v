////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

module core(
    input  wire         clk                 ,
    input  wire         rst_n               ,

    // =========================    
    // inst_mem 
    // =========================    
    input  wire[31:0]   inst_i              ,
    output wire[31:0]   inst_addr_o         ,

    // =========================
    // data_mem
    // =========================

    // read (from id)
    output wire         data_mem_r_en_o     ,
    output wire [31:0]  data_mem_r_addr_o   ,  
    input  wire [31:0]  data_mem_r_data_i   ,

    // write (from ex)
    output wire         data_mem_w_en_o     ,
    output wire [3:0]   data_mem_w_sel_o    ,
    output wire [31:0]  data_mem_w_addr_o   ,
    output wire [31:0]  data_mem_w_data_o   

);

    // ============================================================
    //  Wire Declarations
    // ============================================================

    // pc_reg to inst_mem / if_id
    wire[31:0]  pc_reg_pc_addr_o            ;
    assign inst_addr_o = pc_reg_pc_addr_o   ;

    // if_id to id
    wire[31:0]  if_id_inst_addr_o           ;
    wire[31:0]  if_id_inst_o                ;
 
    // id to regs
    wire[4:0]   id_rs1_addr_o               ;
    wire[4:0]   id_rs2_addr_o               ;

    // regs to id
    wire[31:0]  regs_reg1_r_data_o          ;
    wire[31:0]  regs_reg2_r_data_o          ;

    // id to id_ex
    wire[31:0]  id_inst_addr_o              ;
    wire[31:0]  id_inst_o                   ;
    wire[31:0]  id_op1_o                    ;
    wire[31:0]  id_op2_o                    ;
    wire[4:0]   id_rd_addr_o                ;
    wire        id_reg_w_en_o               ;
    wire[31:0]  id_base_addr_o              ;
    wire[31:0]  id_addr_offset_o            ;

    // id_ex to ex
    wire[31:0]  id_ex_inst_addr_o           ;
    wire[31:0]  id_ex_inst_o                ;
    wire[31:0]  id_ex_op1_o                 ;
    wire[31:0]  id_ex_op2_o                 ;
    wire[4:0]   id_ex_rd_addr_o             ;
    wire        id_ex_reg_w_en_o            ;
    wire[31:0]  id_ex_base_addr_o           ;
    wire[31:0]  id_ex_addr_offset_o         ;

    // ex to regs
    wire[4:0]   ex_rd_addr_o                ;
    wire[31:0]  ex_rd_data_o                ;
    wire        ex_rd_w_en_o                ;

    // ex to ctrl
    wire[31:0]  ex_jump_addr_o              ;
    wire        ex_jump_en_o                ;
    wire        ex_flush_req_o              ;
    wire        ex_stall_req_o              ;

    // ex to mul
    wire        ex_mul_start_o              ;
    wire[2:0]   ex_mul_funct3_o             ;
    wire[31:0]  ex_mul_op1_o                ;
    wire[31:0]  ex_mul_op2_o                ;
    wire[4:0]   ex_mul_reg_waddr_o          ;

    // mul to ex
    wire        mul_mul_busy_o              ;
    wire        mul_mul_ready_o             ;
    wire[63:0]  mul_mul_result64_o          ;
    wire[4:0]   mul_mul_rd_waddr_o          ;
    wire[2:0]   mul_mul_funct3_o            ;
       
    // ctrl to pc_reg
    wire[31:0]  ctrl_jump_addr_o            ;
    wire        ctrl_jump_en_o              ;
    // ctrl to if_id & id_ex
    wire        ctrl_flush_flag_o           ;
    wire        ctrl_stall_flag_o           ;


    // ============================================================
    //  Module Instantiation & Interconnection
    // ============================================================

    pc_reg pc_reg_inst(
        // input
        .clk                (clk                    ),
        .rst_n              (rst_n                  ),

        // from ctrl    
        .stall_flag_i       (ctrl_stall_flag_o      ),
        .jump_addr_i        (ctrl_jump_addr_o       ),    
        .jump_en_i          (ctrl_jump_en_o         ),

        // output           
        .pc_addr_o          (pc_reg_pc_addr_o       )
    );

    if_id if_id_inst(
        .clk                (clk                    ),
        .rst_n              (rst_n                  ),

        //from ctrl 
        .flush_flag_i       (ctrl_flush_flag_o      ),
        .stall_flag_i       (ctrl_stall_flag_o      ),

        // from inst_mem    
        .inst_addr_i        (pc_reg_pc_addr_o       ),
        .inst_i             (inst_i                 ),

        // to id    
        .inst_addr_o        (if_id_inst_addr_o      ),
        .inst_o             (if_id_inst_o           )
    );

    id id_inst(
        // from if_id
        .inst_addr_i        (if_id_inst_addr_o      ),
        .inst_i             (if_id_inst_o           ),

        // to regs  
        .rs1_addr_o         (id_rs1_addr_o          ),
        .rs2_addr_o         (id_rs2_addr_o          ),

        // from regs    
        .rs1_data_i         (regs_reg1_r_data_o     ),
        .rs2_data_i         (regs_reg2_r_data_o     ),

        // to id_ex
        .inst_addr_o        (id_inst_addr_o         ),
        .inst_o             (id_inst_o              ),
        .op1_o              (id_op1_o               ),
        .op2_o              (id_op2_o               ),
        .rd_addr_o          (id_rd_addr_o           ),
        .reg_w_en_o         (id_reg_w_en_o          ), 
        .base_addr_o        (id_base_addr_o         ),
        .addr_offset_o      (id_addr_offset_o       ),

        // to data_ram
        .data_ram_r_en_o    (data_mem_r_en_o        ),
        .data_ram_r_addr_o  (data_mem_r_addr_o      )

    );

    regs regs_inst(
        .clk                (clk                    ),
        .rst_n              (rst_n                  ),

        // from id  
        .reg1_r_addr_i      (id_rs1_addr_o          ),
        .reg2_r_addr_i      (id_rs2_addr_o          ),

        // to id        
        .reg1_r_data_o      (regs_reg1_r_data_o     ),
        .reg2_r_data_o      (regs_reg2_r_data_o     ),

        // from ex      
        .reg_w_addr_i       (ex_rd_addr_o           ),
        .reg_w_data_i       (ex_rd_data_o           ),
        .reg_w_en_i         (ex_rd_w_en_o           )
    );  

    id_ex id_ex_inst(   
        .clk                (clk                    ),
        .rst_n              (rst_n                  ),

        // from ctrl        
        .flush_flag_i       (ctrl_flush_flag_o      ),
        .stall_flag_i       (ctrl_stall_flag_o      ),

        // from id      
        .inst_addr_i        (id_inst_addr_o         ),
        .inst_i             (id_inst_o              ),
        .op1_i              (id_op1_o               ),
        .op2_i              (id_op2_o               ),
        .rd_addr_i          (id_rd_addr_o           ),
        .reg_w_en_i         (id_reg_w_en_o          ), 
        .base_addr_i        (id_base_addr_o         ),
        .addr_offset_i      (id_addr_offset_o       ),

        // to ex        
        .inst_addr_o        (id_ex_inst_addr_o      ),
        .inst_o             (id_ex_inst_o           ),
        .op1_o              (id_ex_op1_o            ),
        .op2_o              (id_ex_op2_o            ),
        .rd_addr_o          (id_ex_rd_addr_o        ),
        .reg_w_en_o         (id_ex_reg_w_en_o       ),
        .base_addr_o   	    (id_ex_base_addr_o      ),
		.addr_offset_o 	    (id_ex_addr_offset_o    )
    );  

    ex ex_inst( 
        // from id_ex   
        .inst_addr_i        (id_ex_inst_addr_o      ),
        .inst_i             (id_ex_inst_o           ),
        .op1_i              (id_ex_op1_o            ),
        .op2_i              (id_ex_op2_o            ),
        .rd_addr_i          (id_ex_rd_addr_o        ),
        .reg_w_en_i         (id_ex_reg_w_en_o       ),
        .base_addr_i        (id_ex_base_addr_o      ),
        .addr_offset_i      (id_ex_addr_offset_o    ),

        // to regs  
        .rd_addr_o          (ex_rd_addr_o           ),
        .rd_data_o          (ex_rd_data_o           ),
        .rd_w_en_o          (ex_rd_w_en_o           ),

        // from mul
        .mul_busy_i         (mul_mul_busy_o         ),
        .mul_ready_i        (mul_mul_ready_o        ),
        .mul_result64_i     (mul_mul_result64_o     ),
        .mul_rd_waddr_i     (mul_mul_rd_waddr_o     ),
        .mul_funct3_i       (mul_mul_funct3_o       ),

        // to mul
        .mul_start_o        (ex_mul_start_o         ),
        .mul_funct3_o       (ex_mul_funct3_o        ),
        .mul_op1_o          (ex_mul_op1_o           ),
        .mul_op2_o          (ex_mul_op2_o           ),
        .mul_reg_waddr_o    (ex_mul_reg_waddr_o     ),

        // to ctrl  
        .jump_addr_o        (ex_jump_addr_o         ),
        .jump_en_o          (ex_jump_en_o           ),
        .flush_req_o        (ex_flush_req_o         ),
        .stall_req_o        (ex_stall_req_o         ),

        // from data_mem read   
        .data_mem_r_data_i  (data_mem_r_data_i      ),

        // to data_mem write            
        .data_mem_w_en_o    (data_mem_w_en_o        ),
	    .data_mem_w_sel_o   (data_mem_w_sel_o       ),
	    .data_mem_w_addr_o  (data_mem_w_addr_o      ),
	    .data_mem_w_data_o  (data_mem_w_data_o      )
    );  

    mul #(
        .LATENCY(32)
    ) mul_inst (
        .clk                (clk                    ),
        .rst_n              (rst_n                  ),

        // from ex
        .mul_start_i        (ex_mul_start_o         ),
        .mul_funct3_i       (ex_mul_funct3_o        ),
        .mul_op1_i          (ex_mul_op1_o           ),
        .mul_op2_i          (ex_mul_op2_o           ),
        .mul_reg_waddr_i    (ex_mul_reg_waddr_o     ),

        // to ex
        .mul_busy_o         (mul_mul_busy_o         ),
        .mul_ready_o        (mul_mul_ready_o        ),
        .mul_result64_o     (mul_mul_result64_o     ),
        .mul_rd_waddr_o     (mul_mul_rd_waddr_o     ),
        .mul_funct3_o       (mul_mul_funct3_o       )
    );

    ctrl ctrl_inst( 
        // from ex  
        .flush_req_i        (ex_flush_req_o         ),
        .stall_req_i        (ex_stall_req_o         ),
        .jump_addr_i        (ex_jump_addr_o         ),
        .jump_en_i          (ex_jump_en_o           ),

        // to pc_reg & if_id & id_ex        
        .flush_flag_o       (ctrl_flush_flag_o      ),
        .stall_flag_o       (ctrl_stall_flag_o      ),
        .jump_addr_o        (ctrl_jump_addr_o       ),
        .jump_en_o          (ctrl_jump_en_o         )
    );

endmodule