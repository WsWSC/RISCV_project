////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module tb;

    reg clk;
    reg rst_n;

    always #10 clk = ~clk;

    initial begin
        clk   <= 1'b1;
        rst_n <= 1'b0;

        #30
        rst_n <= 1'b1;
    end

    // rom default val
    initial begin
        // modelsim used
        //$readmemh("../sim/generated/rv32ui-p-auipc.txt", tb.soc_inst.rom_inst.rom_mem);
        // python auto test used
        $readmemh("../sim/generated/inst_data.txt", tb.soc_inst.rom_inst.rom_mem);
    end

    // gtkwave used
    /*
    initial begin
        $dumpfile("tb.vcd");
        $dumpvars;
    end
    */

    wire [31:0] x3  = tb.soc_inst.core_inst.regs_inst.regs[3]  ;
    wire [31:0] x26 = tb.soc_inst.core_inst.regs_inst.regs[26] ;
    wire [31:0] x27 = tb.soc_inst.core_inst.regs_inst.regs[27] ;

    integer i;

    initial begin
        wait(x26 == 32'b1);
        repeat(2) @(posedge clk);

        if(x27 == 32'b1) begin
            $display("##################################\n");
            $display("##########     pass     ##########\n");
            $display("##################################\n");
        end else begin
            $display("##################################\n");
            $display("##########     fail     ##########\n");
            $display("##################################\n");

            $display("fail at test case %2d\n", x3);
            for (i = 0; i < 32; i = i + 1) begin
                $display("x%2d reg val is %d\n", i, tb.soc_inst.core_inst.regs_inst.regs[i]);
            end
        end


        $finish();
        //$stop;


	end

    soc soc_inst(
        .clk        (clk),
        .rst_n      (rst_n)
    );

endmodule