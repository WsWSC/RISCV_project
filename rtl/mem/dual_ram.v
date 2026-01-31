module dual_ram #(
    parameter DW = 32,
    parameter AW = 12,
    parameter MEM_NUM = 4096
) (
    input  wire             clk         ,
    input  wire             rst_n       ,

    // write data
    input  wire             w_en        ,
    input  wire[AW-1:0]     w_addr_i    ,
    input  wire[DW-1:0]     w_data_i    ,

    // read data
    input  wire             r_en        ,
    input  wire[AW-1:0]     r_addr_i    ,

    output reg[DW-1:0]     r_data_o
);

    // memory
    reg  [DW-1:0] memory[0:MEM_NUM-1];

    // write data when w_en == 1
    always @(posedge clk) begin
        if (rst_n && w_en) begin
            memory[w_addr_i] <= w_data_i;
        end
    end

    // read data when r_en == 1
    always @(posedge clk) begin
        if (rst_n && r_en) begin
            r_data_o <= memory[r_addr_i];
        end
    end

endmodule