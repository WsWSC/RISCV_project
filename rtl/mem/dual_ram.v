////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

module dual_ram #(
    parameter DW = 32,
    parameter AW = 12,
    parameter MEM_NUM = 4096
) (
    input  wire             clk,
    input  wire             rst_n,

    // write
    input  wire             w_en_i,
    input  wire [AW-1:0]    w_addr_i,
    input  wire [DW-1:0]    w_data_i,

    // read
    input  wire             r_en_i,
    input  wire [AW-1:0]    r_addr_i,

    output wire [DW-1:0]    r_data_o
);

    wire [DW-1:0] r_data_wire;
    reg           rw_equ_flag;
    reg  [DW-1:0] w_data_reg;

    // output mux: write-first on read/write same addr
    assign r_data_o = rw_equ_flag ? w_data_reg : r_data_wire;

    // delay write data by 1 cycle to align with sync read latency
    always @(posedge clk) begin
        if (!rst_n) 
            w_data_reg <= {DW{1'b0}};
        else        
            w_data_reg <= w_data_i;
    end

    // flag for same-address read/write in the cycle that will produce read data
    always @(posedge clk) begin
        if (!rst_n) 
            rw_equ_flag <= 1'b0;
        else if (w_en_i && r_en_i && (w_addr_i == r_addr_i))
            rw_equ_flag <= 1'b1;
        else if (r_en_i)
            rw_equ_flag <= 1'b0;
    end

    // memory primitive
    ram_array #(
        .DW      (DW),
        .AW      (AW),
        .MEM_NUM (MEM_NUM)
    ) ram_array_inst 
    (
        .clk      (clk),
        .rst_n    (rst_n),

        // write data
        .w_en_i   (w_en_i       ),
        .w_addr_i (w_addr_i     ),
        .w_data_i (w_data_i     ),

        // read data
        .r_en_i   (r_en_i       ),
        .r_addr_i (r_addr_i     ),
        .r_data_o (r_data_wire  )
    );

endmodule
