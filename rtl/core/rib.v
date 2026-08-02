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
    output reg                  m0_if_stall_o,
    output reg  [`MemDataBus]   m0_if_r_data_o,

    // master 1: load/store memory access
    input  wire                 m1_mem_r_en_i,
    input  wire [`MemAddrBus]   m1_mem_r_addr_i,
    output reg  [`MemDataBus]   m1_mem_r_data_o,

    input  wire                 m1_mem_w_en_i,
    input  wire [3:0]           m1_mem_w_sel_i,
    input  wire [`MemAddrBus]   m1_mem_w_addr_i,
    input  wire [`MemDataBus]   m1_mem_w_data_i,

    // slave 0: inst_rom
    input  wire [`MemDataBus]   s0_rom_r_data_i,
    output reg  [`MemAddrBus]   s0_rom_r_addr_o,

    // slave 1: data_ram
    input  wire [`MemDataBus]   s1_ram_r_data_i,
    output reg  [`MemAddrBus]   s1_ram_r_addr_o,

    output reg                  s1_ram_w_en_o,
    output reg  [3:0]           s1_ram_w_sel_o,
    output reg  [`MemAddrBus]   s1_ram_w_addr_o,
    output reg  [`MemDataBus]   s1_ram_w_data_o,

    // slave 2: timer
    input  wire [`MemDataBus]   s2_timer_r_data_i,
    output reg  [`MemAddrBus]   s2_timer_r_addr_o,

    output reg                  s2_timer_w_en_o,
    output reg  [3:0]           s2_timer_w_sel_o,
    output reg  [`MemAddrBus]   s2_timer_w_addr_o,
    output reg  [`MemDataBus]   s2_timer_w_data_o,

    // slave 3: uart
    input  wire [`MemDataBus]   s3_uart_r_data_i,
    output reg  [`MemAddrBus]   s3_uart_r_addr_o,

    output reg                  s3_uart_w_en_o,
    output reg  [3:0]           s3_uart_w_sel_o,
    output reg  [`MemAddrBus]   s3_uart_w_addr_o,
    output reg  [`MemDataBus]   s3_uart_w_data_o
);

    // ============================================================
    //  Internal Signals
    // ============================================================
    // Address map:
    // m1_mem addr[31:28] selects the slave.
    // 4'h0: inst_rom (read only)
    // 4'h1: data_ram
    // 4'h2: timer
    // 4'h3: UART
    // Future reserved slaves (not implemented yet):
    // 4'h4: GPIO
    // 4'h5: SPI
    // others: read zero, ignore write
`ifdef TEST_ZERO_BASED_RAM_MAP
    // Tracked regression binaries use the original low-address Data RAM map.
    localparam [31:0]  RAM_BASE        = 32'h0000_0000;
`else
    localparam [31:0]  RAM_BASE        = 32'h1000_0000;
`endif
    localparam [31:0]  ROM_SIZE        = (`MemNum << 2);
    localparam [31:0]  RAM_SIZE        = (`MemNum << 2);
    localparam [31:0]  RAM_END         = RAM_BASE + RAM_SIZE;

    localparam [1:0]   RIB_GRANT_IF    = 2'b00;
    localparam [1:0]   RIB_GRANT_MEM   = 2'b01;

    localparam [3:0]   RIB_SLAVE_ROM   = 4'h0;
`ifdef TEST_ZERO_BASED_RAM_MAP
    localparam [3:0]   RIB_SLAVE_RAM   = 4'h0;
`else
    localparam [3:0]   RIB_SLAVE_RAM   = 4'h1;
`endif
    localparam [3:0]   RIB_SLAVE_TIMER = 4'h2;
    localparam [3:0]   RIB_SLAVE_UART  = 4'h3;
    // localparam [3:0]   RIB_SLAVE_GPIO  = 4'h4;
    // localparam [3:0]   RIB_SLAVE_SPI   = 4'h5;
    localparam [3:0]   RIB_SLAVE_NONE  = 4'hf;

    wire               if_req           ;
    wire               mem_req          ;
    wire               mem_grant        ;
    reg  [1:0]         master_grant     ;

    reg  [3:0]         mem_r_slave_sel  ;
    reg  [3:0]         mem_w_slave_sel  ;

    wire               mem_rom_read_sel;
    wire               mem_ram_read_sel;
    wire [`MemAddrBus] mem_ram_r_addr  ;
    wire [`MemAddrBus] mem_ram_w_addr  ;

    assign if_req = 1'b1;

    assign mem_req = (m1_mem_r_en_i == `ReadEnable) ||
                     (m1_mem_w_en_i == `WriteEnable);
    assign mem_grant = (master_grant == RIB_GRANT_MEM);

`ifdef TEST_ZERO_BASED_RAM_MAP
    assign mem_rom_read_sel = 1'b0;
`else
    assign mem_rom_read_sel = mem_grant &&
                              (mem_r_slave_sel == RIB_SLAVE_ROM) &&
                              (m1_mem_r_addr_i < ROM_SIZE);
`endif
    assign mem_ram_read_sel = mem_grant &&
                              (mem_r_slave_sel == RIB_SLAVE_RAM) &&
                              (m1_mem_r_addr_i >= RAM_BASE) &&
                              (m1_mem_r_addr_i < RAM_END);
    assign mem_ram_r_addr = m1_mem_r_addr_i - RAM_BASE;
    assign mem_ram_w_addr = m1_mem_w_addr_i - RAM_BASE;

    // ============================================================
    //  Master Grant
    // ============================================================
    always @(*) begin
        // priority: master 1 MEM > master 0 IF
        if (mem_req) begin
            master_grant = RIB_GRANT_MEM;
        end else if (if_req) begin
            master_grant = RIB_GRANT_IF;
        end else begin
            master_grant = RIB_GRANT_IF;
        end
    end

    // ============================================================
    //  Address Decode
    // ============================================================
    always @(*) begin
        mem_r_slave_sel = RIB_SLAVE_NONE;

        if (m1_mem_r_en_i == `ReadEnable) begin
            case (m1_mem_r_addr_i[31:28])
`ifndef TEST_ZERO_BASED_RAM_MAP
                RIB_SLAVE_ROM,
`endif
                RIB_SLAVE_RAM,
                RIB_SLAVE_TIMER,
                RIB_SLAVE_UART: begin
                    mem_r_slave_sel = m1_mem_r_addr_i[31:28];
                end

                // Future slaves are reserved but not implemented yet.
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
                RIB_SLAVE_TIMER,
                RIB_SLAVE_UART: begin
                    mem_w_slave_sel = m1_mem_w_addr_i[31:28];
                end

                // Future slaves are reserved but not implemented yet.
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
        m0_if_stall_o    = `StallEnable;
        m0_if_r_data_o   = `INST_NOP;

        s0_rom_r_addr_o  = mem_rom_read_sel ? m1_mem_r_addr_i : `ZeroAddr;

        s1_ram_w_en_o    = `WriteDisable;
        s1_ram_w_sel_o   = 4'b0;
        s1_ram_w_addr_o  = `ZeroAddr;
        s1_ram_w_data_o  = `ZeroWord;

        s2_timer_w_en_o   = `WriteDisable;
        s2_timer_w_sel_o  = 4'b0;
        s2_timer_w_addr_o = `ZeroAddr;
        s2_timer_w_data_o = `ZeroWord;

        s3_uart_w_en_o    = `WriteDisable;
        s3_uart_w_sel_o   = 4'b0;
        s3_uart_w_addr_o  = `ZeroAddr;
        s3_uart_w_data_o  = `ZeroWord;

        // keep direct read path for zero-wait load timing
        s1_ram_r_addr_o = mem_ram_read_sel ? mem_ram_r_addr : `ZeroAddr;
        s2_timer_r_addr_o = (mem_grant &&
                             (mem_r_slave_sel == RIB_SLAVE_TIMER)) ? m1_mem_r_addr_i : `ZeroAddr;
        s3_uart_r_addr_o = (mem_grant &&
                            (mem_r_slave_sel == RIB_SLAVE_UART)) ? m1_mem_r_addr_i : `ZeroAddr;
        m1_mem_r_data_o = mem_rom_read_sel ? s0_rom_r_data_i :
                          mem_ram_read_sel ? s1_ram_r_data_i :
                          (mem_grant &&
                           (mem_r_slave_sel == RIB_SLAVE_TIMER)) ? s2_timer_r_data_i :
                          (mem_grant &&
                           (mem_r_slave_sel == RIB_SLAVE_UART)) ? s3_uart_r_data_i : `ZeroWord;

        case (master_grant)
            RIB_GRANT_IF: begin
                m0_if_stall_o   = `StallDisable;
                s0_rom_r_addr_o = m0_if_r_addr_i;
                m0_if_r_data_o  = s0_rom_r_data_i;
            end

            RIB_GRANT_MEM: begin
                case (mem_w_slave_sel)
                    RIB_SLAVE_RAM: begin
                        if ((m1_mem_w_addr_i >= RAM_BASE) &&
                            (m1_mem_w_addr_i < RAM_END)) begin
                            s1_ram_w_en_o   = m1_mem_w_en_i;
                            s1_ram_w_sel_o  = m1_mem_w_sel_i;
                            s1_ram_w_addr_o = mem_ram_w_addr;
                            s1_ram_w_data_o = m1_mem_w_data_i;
                        end
                    end

                    RIB_SLAVE_TIMER: begin
                        s2_timer_w_en_o   = m1_mem_w_en_i;
                        s2_timer_w_sel_o  = m1_mem_w_sel_i;
                        s2_timer_w_addr_o = m1_mem_w_addr_i;
                        s2_timer_w_data_o = m1_mem_w_data_i;
                    end

                    RIB_SLAVE_UART: begin
                        s3_uart_w_en_o   = m1_mem_w_en_i;
                        s3_uart_w_sel_o  = m1_mem_w_sel_i;
                        s3_uart_w_addr_o = m1_mem_w_addr_i;
                        s3_uart_w_data_o = m1_mem_w_data_i;
                    end

                    default: begin
                    end
                endcase
            end

            default: begin
            end
        endcase
    end

endmodule
