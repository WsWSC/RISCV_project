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
    input  wire [`MemAddrBus]   m0_if_addr_i,
    output reg  [`MemDataBus]   m0_if_data_o,
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
    // 4'h2: reserved timer
    // 4'h3: reserved UART
    // 4'h4: reserved GPIO
    // 4'h5: reserved SPI
    // others: read zero, ignore write
    localparam [31:0]  RAM_SIZE        = (`MemNum << 2);

    localparam [1:0]   GRANT_IF        = 2'b00;
    localparam [1:0]   GRANT_MEM       = 2'b01;

    localparam [3:0]   SLAVE_RAM       = 4'h0;
    localparam [3:0]   SLAVE_TIMER     = 4'h2;
    localparam [3:0]   SLAVE_UART      = 4'h3;
    localparam [3:0]   SLAVE_GPIO      = 4'h4;
    localparam [3:0]   SLAVE_SPI       = 4'h5;
    localparam [3:0]   SLAVE_NONE      = 4'hf;

    wire [1:0]         req              ;
    wire               m0_if_req        ;
    wire               m1_mem_req       ;
    wire               m1_mem_grant     ;
    wire [1:0]         grant            ;

    reg  [3:0]         m1_mem_r_slave   ;
    reg  [3:0]         m1_mem_w_slave   ;

    assign m0_if_req = 1'b1;

    assign m1_mem_req = (m1_mem_r_en_i == `ReadEnable) ||
                        (m1_mem_w_en_i == `WriteEnable);

    assign req   = {m1_mem_req, m0_if_req};
    assign grant = req[1] ? GRANT_MEM : GRANT_IF;
    assign m1_mem_grant = (grant == GRANT_MEM);

    // ============================================================
    //  Address Decode
    // ============================================================
    always @(*) begin
        m1_mem_r_slave = SLAVE_NONE;

        if (m1_mem_r_en_i == `ReadEnable) begin
            case (m1_mem_r_addr_i[31:28])
                SLAVE_RAM,
                SLAVE_TIMER,
                SLAVE_UART,
                SLAVE_GPIO,
                SLAVE_SPI: begin
                    m1_mem_r_slave = m1_mem_r_addr_i[31:28];
                end

                default: begin
                    m1_mem_r_slave = SLAVE_NONE;
                end
            endcase
        end
    end

    always @(*) begin
        m1_mem_w_slave = SLAVE_NONE;

        if (m1_mem_w_en_i == `WriteEnable) begin
            case (m1_mem_w_addr_i[31:28])
                SLAVE_RAM,
                SLAVE_TIMER,
                SLAVE_UART,
                SLAVE_GPIO,
                SLAVE_SPI: begin
                    m1_mem_w_slave = m1_mem_w_addr_i[31:28];
                end

                default: begin
                    m1_mem_w_slave = SLAVE_NONE;
                end
            endcase
        end
    end

    // ============================================================
    //  Main logic
    // ============================================================
    always @(*) begin
        // priority: master 1 MEM > master 0 IF
        if (grant == GRANT_IF) begin
            m0_if_stall_o   = `StallDisable;
            s0_rom_r_addr_o = m0_if_addr_i;
            m0_if_data_o    = s0_rom_r_data_i;
        end else begin
            m0_if_stall_o   = `StallEnable;
            s0_rom_r_addr_o = `ZeroAddr;
            m0_if_data_o    = `INST_NOP;
        end

        s1_ram_w_en_o   = `WriteDisable;
        s1_ram_w_sel_o  = 4'b0;
        s1_ram_w_addr_o = `ZeroAddr;
        s1_ram_w_data_o = `ZeroWord;

        // in-range read: keep direct path for zero-wait load
        s1_ram_r_addr_o = (m1_mem_grant &&
                           (m1_mem_r_slave == SLAVE_RAM) &&
                           (m1_mem_r_addr_i < RAM_SIZE)) ? m1_mem_r_addr_i : `ZeroAddr;
        m1_mem_r_data_o = (m1_mem_grant &&
                           (m1_mem_r_slave == SLAVE_RAM) &&
                           (m1_mem_r_addr_i < RAM_SIZE)) ? s1_ram_r_data_i : `ZeroWord;

        if (m1_mem_grant) begin
            // in-range write: pass through to data_ram
            if (m1_mem_w_slave == SLAVE_RAM && m1_mem_w_addr_i < RAM_SIZE) begin
                s1_ram_w_en_o   = m1_mem_w_en_i;
                s1_ram_w_sel_o  = m1_mem_w_sel_i;
                s1_ram_w_addr_o = m1_mem_w_addr_i;
                s1_ram_w_data_o = m1_mem_w_data_i;
            end
        end
    end

endmodule
