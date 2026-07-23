////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module rib(
    input  wire                 clk,
    input  wire                 rst_n,

    // master 0: instruction fetch
    input  wire [`MemAddrBus]   m0_if_r_addr_i,
    output reg  [`MemDataBus]   m0_if_r_data_o,
    output reg                  m0_if_stall_o,

    // master 1: load/store memory access
    input  wire                 m1_mem_r_en_i,
    input  wire [`MemAddrBus]   m1_mem_r_addr_i,
    output reg  [`MemDataBus]   m1_mem_r_data_o,

    input  wire                 m1_mem_w_en_i,
    input  wire [3:0]           m1_mem_w_sel_i,
    input  wire [`MemAddrBus]   m1_mem_w_addr_i,
    input  wire [`MemDataBus]   m1_mem_w_data_i,

    // slave 1: data_ram
    output reg                  s1_ram_w_en_o,
    output reg  [3:0]           s1_ram_w_sel_o,
    output reg  [`MemAddrBus]   s1_ram_w_addr_o,
    output reg  [`MemDataBus]   s1_ram_w_data_o,

    output reg  [`MemAddrBus]   s1_ram_r_addr_o,
    input  wire [`MemDataBus]   s1_ram_r_data_i,

    // slave 2: timer
    output reg                  s2_timer_w_en_o,
    output reg  [3:0]           s2_timer_w_sel_o,
    output reg  [`MemAddrBus]   s2_timer_w_addr_o,
    output reg  [`MemDataBus]   s2_timer_w_data_o,

    output reg  [`MemAddrBus]   s2_timer_r_addr_o,
    input  wire [`MemDataBus]   s2_timer_r_data_i,

    // slave 0: inst_rom
    output reg  [`MemAddrBus]   s0_rom_r_addr_o,
    input  wire [`MemDataBus]   s0_rom_r_data_i
);

    // ============================================================
    //  Internal Signals
    // ============================================================
    // Address map:
    // m1_mem addr[31:28] selects the slave.
    // 4'h0: data_ram
    // 4'h2: timer
    // Future reserved slaves (not implemented yet):
    // 4'h3: UART
    // 4'h4: GPIO
    // 4'h5: SPI
    // others: read zero, ignore write
    localparam [31:0]  RAM_ADDR_LIMIT  = (`MemNum << 2);

    localparam [1:0]   RIB_GRANT_IF    = 2'b00;
    localparam [1:0]   RIB_GRANT_MEM   = 2'b01;

    localparam [3:0]   RIB_SLAVE_RAM   = 4'h0;
    localparam [3:0]   RIB_SLAVE_TIMER = 4'h2;
    // localparam [3:0]   RIB_SLAVE_UART  = 4'h3;
    // localparam [3:0]   RIB_SLAVE_GPIO  = 4'h4;
    // localparam [3:0]   RIB_SLAVE_SPI   = 4'h5;
    localparam [3:0]   RIB_SLAVE_NONE  = 4'hf;

    wire [1:0]         master_req       ;
    wire               if_req           ;
    wire               mem_req          ;
    wire               mem_grant        ;
    wire [1:0]         master_grant     ;

    reg  [3:0]         mem_r_slave_sel  ;
    reg  [3:0]         mem_w_slave_sel  ;

    assign if_req = 1'b1;

    assign mem_req = (m1_mem_r_en_i == `ReadEnable) ||
                     (m1_mem_w_en_i == `WriteEnable);

    assign master_req   = {mem_req, if_req};
    assign master_grant = master_req[1] ? RIB_GRANT_MEM : RIB_GRANT_IF;
    assign mem_grant    = (master_grant == RIB_GRANT_MEM);

    // ============================================================
    //  Address Decode
    // ============================================================
    always @(*) begin
        mem_r_slave_sel = RIB_SLAVE_NONE;

        if (m1_mem_r_en_i == `ReadEnable) begin
            case (m1_mem_r_addr_i[31:28])
                RIB_SLAVE_RAM,
                RIB_SLAVE_TIMER: begin
                    mem_r_slave_sel = m1_mem_r_addr_i[31:28];
                end

                // Future slaves are reserved but not implemented yet.
                // RIB_SLAVE_UART,
                // RIB_SLAVE_GPIO,
                // RIB_SLAVE_SPI: begin
                //     mem_r_slave_sel = m1_mem_r_addr_i[31:28];
                // end

                default: begin
                    mem_r_slave_sel = RIB_SLAVE_NONE;
                end
            endcase
        end
    end

    always @(*) begin
        mem_w_slave_sel = RIB_SLAVE_NONE;

        if (m1_mem_w_en_i == `WriteEnable) begin
            case (m1_mem_w_addr_i[31:28])
                RIB_SLAVE_RAM,
                RIB_SLAVE_TIMER: begin
                    mem_w_slave_sel = m1_mem_w_addr_i[31:28];
                end

                // Future slaves are reserved but not implemented yet.
                // RIB_SLAVE_UART,
                // RIB_SLAVE_GPIO,
                // RIB_SLAVE_SPI: begin
                //     mem_w_slave_sel = m1_mem_w_addr_i[31:28];
                // end

                default: begin
                    mem_w_slave_sel = RIB_SLAVE_NONE;
                end
            endcase
        end
    end

    // ============================================================
    //  Main logic
    // ============================================================
    always @(*) begin
        // priority: master 1 MEM > master 0 IF
        if (master_grant == RIB_GRANT_IF) begin
            m0_if_stall_o   = `StallDisable;
            s0_rom_r_addr_o = m0_if_r_addr_i;
            m0_if_r_data_o  = s0_rom_r_data_i;
        end else begin
            m0_if_stall_o   = `StallEnable;
            s0_rom_r_addr_o = `ZeroAddr;
            m0_if_r_data_o  = `INST_NOP;
        end

        s1_ram_w_en_o   = `WriteDisable;
        s1_ram_w_sel_o  = 4'b0;
        s1_ram_w_addr_o = `ZeroAddr;
        s1_ram_w_data_o = `ZeroWord;

        s2_timer_w_en_o   = `WriteDisable;
        s2_timer_w_sel_o  = 4'b0;
        s2_timer_w_addr_o = `ZeroAddr;
        s2_timer_w_data_o = `ZeroWord;

        // in-range read: keep direct path for zero-wait load
        s1_ram_r_addr_o = (mem_grant &&
                           (mem_r_slave_sel == RIB_SLAVE_RAM) &&
                           (m1_mem_r_addr_i < RAM_ADDR_LIMIT)) ? m1_mem_r_addr_i : `ZeroAddr;
        s2_timer_r_addr_o = (mem_grant &&
                             (mem_r_slave_sel == RIB_SLAVE_TIMER)) ? m1_mem_r_addr_i : `ZeroAddr;
        m1_mem_r_data_o = (mem_grant &&
                           (mem_r_slave_sel == RIB_SLAVE_RAM) &&
                           (m1_mem_r_addr_i < RAM_ADDR_LIMIT)) ? s1_ram_r_data_i :
                          (mem_grant &&
                           (mem_r_slave_sel == RIB_SLAVE_TIMER)) ? s2_timer_r_data_i : `ZeroWord;

        if (mem_grant) begin
            // in-range write: pass through to data_ram
            if (mem_w_slave_sel == RIB_SLAVE_RAM && m1_mem_w_addr_i < RAM_ADDR_LIMIT) begin
                s1_ram_w_en_o   = m1_mem_w_en_i;
                s1_ram_w_sel_o  = m1_mem_w_sel_i;
                s1_ram_w_addr_o = m1_mem_w_addr_i;
                s1_ram_w_data_o = m1_mem_w_data_i;
            end

            if (mem_w_slave_sel == RIB_SLAVE_TIMER) begin
                s2_timer_w_en_o   = m1_mem_w_en_i;
                s2_timer_w_sel_o  = m1_mem_w_sel_i;
                s2_timer_w_addr_o = m1_mem_w_addr_i;
                s2_timer_w_data_o = m1_mem_w_data_i;
            end
        end
    end

endmodule
