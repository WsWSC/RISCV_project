////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

//`timescale 1ns/1ps

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
        $readmemb("../tb/test_data.txt", tb.soc_inst.rom_inst.rom_mem);
    end

    initial begin
        while (1) begin
            @(posedge clk)
            $display("=================\n");
            $display("x27 reg val is %d\n", tb.soc_inst.core_inst.regs_inst.regs[27]);
            $display("x28 reg val is %d\n", tb.soc_inst.core_inst.regs_inst.regs[28]);
            $display("x29 reg val is %d\n", tb.soc_inst.core_inst.regs_inst.regs[29]);
            #10;
        end
    end

    soc soc_inst(
        .clk        (clk),
        .rst_n      (rst_n)
    );

endmodule