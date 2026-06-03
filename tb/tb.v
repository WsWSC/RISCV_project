////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`timescale 1ns/1ps
`include "defines.v"

module tb;

    reg clk;
    reg rst_n;
    reg external_irq;

    always #10 clk = ~clk;

    initial begin
        clk   <= 1'b1;
        rst_n <= 1'b0;
        external_irq <= 1'b0;

        #30
        rst_n <= 1'b1;
    end

    // rom default val
    initial begin
        // python auto test used
        $readmemh("../sim/test_bin/inst_data.txt", tb.soc_inst.inst_rom_inst.rom_mem );
    end

    // ============================================================
    // Debug / observability controls
    // ============================================================
    integer cycle_count;
    integer instret_count;
    integer stall_count;
    integer flush_count;
    integer jump_count;
    integer load_count;
    integer store_count;
    integer reg_write_count;
    integer timeout_cycles;
    integer trace_en;
    integer dump_en;
    integer external_irq_cycle;
    integer external_irq_cycle_en;

    initial begin
        cycle_count   = 0;
        instret_count = 0;
        stall_count   = 0;
        flush_count   = 0;
        jump_count    = 0;
        load_count    = 0;
        store_count   = 0;
        reg_write_count = 0;

        timeout_cycles = 100000;
        trace_en = $test$plusargs("trace");
        dump_en  = $test$plusargs("dump");
        external_irq_cycle_en = $value$plusargs("external_irq_cycle=%d", external_irq_cycle);

        if (!$value$plusargs("timeout_cycles=%d", timeout_cycles))
            timeout_cycles = 100000;

        if (dump_en) begin
            $dumpfile("tb.vcd");
            $dumpvars(0, tb);
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            external_irq <= 1'b0;
        end else if (external_irq_cycle_en && (cycle_count == external_irq_cycle)) begin
            external_irq <= 1'b1;
        end else begin
            external_irq <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            cycle_count     <= 0;
            instret_count   <= 0;
            stall_count     <= 0;
            flush_count     <= 0;
            jump_count      <= 0;
            load_count      <= 0;
            store_count     <= 0;
            reg_write_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;

            if (tb.soc_inst.core_inst.if_id_inst_o != `INST_NOP &&
                !tb.soc_inst.core_inst.ctrl_stall_flag_o &&
                !tb.soc_inst.core_inst.ctrl_flush_flag_o) begin
                instret_count <= instret_count + 1;
            end

            if (tb.soc_inst.core_inst.ctrl_stall_flag_o)
                stall_count <= stall_count + 1;

            if (tb.soc_inst.core_inst.ctrl_flush_flag_o)
                flush_count <= flush_count + 1;

            if (tb.soc_inst.core_inst.ctrl_jump_en_o)
                jump_count <= jump_count + 1;

            if (tb.soc_inst.core_inst.data_ram_r_en_o)
                load_count <= load_count + 1;

            if (tb.soc_inst.core_inst.data_ram_w_en_o)
                store_count <= store_count + 1;

            if (tb.soc_inst.core_inst.ex_rd_w_en_o)
                reg_write_count <= reg_write_count + 1;

            if (trace_en) begin
                $display("TRACE cycle=%0d pc=%h if_id_inst=%h id_ex_inst=%h stall=%b flush=%b jump=%b jump_addr=%h wb_en=%b wb_rd=x%0d wb_data=%h load=%b load_addr=%h store=%b store_sel=%b store_addr=%h store_data=%h",
                    cycle_count,
                    tb.soc_inst.core_inst.pc_reg_pc_addr_o,
                    tb.soc_inst.core_inst.if_id_inst_o,
                    tb.soc_inst.core_inst.id_ex_inst_o,
                    tb.soc_inst.core_inst.ctrl_stall_flag_o,
                    tb.soc_inst.core_inst.ctrl_flush_flag_o,
                    tb.soc_inst.core_inst.ctrl_jump_en_o,
                    tb.soc_inst.core_inst.ctrl_jump_addr_o,
                    tb.soc_inst.core_inst.ex_rd_w_en_o,
                    tb.soc_inst.core_inst.ex_rd_addr_o,
                    tb.soc_inst.core_inst.ex_rd_data_o,
                    tb.soc_inst.core_inst.data_ram_r_en_o,
                    tb.soc_inst.core_inst.data_ram_r_addr_o,
                    tb.soc_inst.core_inst.data_ram_w_en_o,
                    tb.soc_inst.core_inst.data_ram_w_sel_o,
                    tb.soc_inst.core_inst.data_ram_w_addr_o,
                    tb.soc_inst.core_inst.data_ram_w_data_o
                );
            end
        end
    end

    wire [31:0] x3  = tb.soc_inst.core_inst.regs_inst.regs[3]  ;
    wire [31:0] x26 = tb.soc_inst.core_inst.regs_inst.regs[26] ;
    wire [31:0] x27 = tb.soc_inst.core_inst.regs_inst.regs[27] ;

    integer i;

    task print_summary;
        begin
            $display("========== simulation summary ==========");
            $display("cycles           = %0d", cycle_count);
            $display("retired_estimate = %0d", instret_count);
            $display("stall_cycles     = %0d", stall_count);
            $display("flush_cycles     = %0d", flush_count);
            $display("jumps_taken      = %0d", jump_count);
            $display("loads            = %0d", load_count);
            $display("stores           = %0d", store_count);
            $display("reg_writes       = %0d", reg_write_count);
            $display("last_pc          = %h", tb.soc_inst.core_inst.pc_reg_pc_addr_o);
            $display("last_if_id_inst  = %h", tb.soc_inst.core_inst.if_id_inst_o);
            $display("last_id_ex_inst  = %h", tb.soc_inst.core_inst.id_ex_inst_o);
            $display("========================================");
        end
    endtask

    task print_regs;
        begin
            $display("x 0 reg val is %h (%0d)", 32'h0, 32'h0);
            $display("x 1 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[1], tb.soc_inst.core_inst.regs_inst.regs[1]);
            $display("x 2 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[2], tb.soc_inst.core_inst.regs_inst.regs[2]);
            $display("x 3 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[3], tb.soc_inst.core_inst.regs_inst.regs[3]);
            $display("x 4 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[4], tb.soc_inst.core_inst.regs_inst.regs[4]);
            $display("x 5 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[5], tb.soc_inst.core_inst.regs_inst.regs[5]);
            $display("x 6 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[6], tb.soc_inst.core_inst.regs_inst.regs[6]);
            $display("x 7 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[7], tb.soc_inst.core_inst.regs_inst.regs[7]);
            $display("x 8 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[8], tb.soc_inst.core_inst.regs_inst.regs[8]);
            $display("x 9 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[9], tb.soc_inst.core_inst.regs_inst.regs[9]);
            $display("x10 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[10], tb.soc_inst.core_inst.regs_inst.regs[10]);
            $display("x11 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[11], tb.soc_inst.core_inst.regs_inst.regs[11]);
            $display("x12 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[12], tb.soc_inst.core_inst.regs_inst.regs[12]);
            $display("x13 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[13], tb.soc_inst.core_inst.regs_inst.regs[13]);
            $display("x14 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[14], tb.soc_inst.core_inst.regs_inst.regs[14]);
            $display("x15 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[15], tb.soc_inst.core_inst.regs_inst.regs[15]);
            $display("x16 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[16], tb.soc_inst.core_inst.regs_inst.regs[16]);
            $display("x17 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[17], tb.soc_inst.core_inst.regs_inst.regs[17]);
            $display("x18 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[18], tb.soc_inst.core_inst.regs_inst.regs[18]);
            $display("x19 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[19], tb.soc_inst.core_inst.regs_inst.regs[19]);
            $display("x20 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[20], tb.soc_inst.core_inst.regs_inst.regs[20]);
            $display("x21 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[21], tb.soc_inst.core_inst.regs_inst.regs[21]);
            $display("x22 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[22], tb.soc_inst.core_inst.regs_inst.regs[22]);
            $display("x23 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[23], tb.soc_inst.core_inst.regs_inst.regs[23]);
            $display("x24 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[24], tb.soc_inst.core_inst.regs_inst.regs[24]);
            $display("x25 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[25], tb.soc_inst.core_inst.regs_inst.regs[25]);
            $display("x26 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[26], tb.soc_inst.core_inst.regs_inst.regs[26]);
            $display("x27 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[27], tb.soc_inst.core_inst.regs_inst.regs[27]);
            $display("x28 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[28], tb.soc_inst.core_inst.regs_inst.regs[28]);
            $display("x29 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[29], tb.soc_inst.core_inst.regs_inst.regs[29]);
            $display("x30 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[30], tb.soc_inst.core_inst.regs_inst.regs[30]);
            $display("x31 reg val is %h (%0d)", tb.soc_inst.core_inst.regs_inst.regs[31], tb.soc_inst.core_inst.regs_inst.regs[31]);
        end
    endtask

    initial begin
        #1;
        fork
            begin
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
                    print_regs();
                end

                print_summary();
                $finish();
            end

            begin
                repeat(timeout_cycles) @(posedge clk);
                $display("##################################\n");
                $display("##########    timeout    #########\n");
                $display("##################################\n");
                print_summary();
                print_regs();
                $finish();
            end
        join

	end

    soc soc_inst(
        .clk        (clk),
        .rst_n      (rst_n),
        .external_irq_i(external_irq)
    );

endmodule
