////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module uart (
    input  wire                 clk,
    input  wire                 rst_n,

    input  wire                 w_en_i,
    input  wire [3:0]           w_sel_i,
    input  wire [`MemAddrBus]   w_addr_i,
    input  wire [`MemDataBus]   w_data_i,

    input  wire [`MemAddrBus]   r_addr_i,

    output reg  [`MemDataBus]   r_data_o,
    output wire                 tx_pin_o,
    input  wire                 rx_pin_i
);

    // ============================================================
    //  Internal Signals
    // ============================================================
    localparam [7:0]   UART_REG_CTRL    = 8'h00;
    localparam [7:0]   UART_REG_STATUS  = 8'h04;
    localparam [7:0]   UART_REG_BAUD    = 8'h08;
    localparam [7:0]   UART_REG_TXDATA  = 8'h0c;
    localparam [7:0]   UART_REG_RXDATA  = 8'h10;

    localparam [31:0]  UART_BAUD_115200 = 32'h0000_01b8;

    localparam [3:0]   TX_STATE_IDLE    = 4'b0001;
    localparam [3:0]   TX_STATE_START   = 4'b0010;
    localparam [3:0]   TX_STATE_DATA    = 4'b0100;
    localparam [3:0]   TX_STATE_STOP    = 4'b1000;

    // addr: 0x00
    // rw. bit[0]: tx enable, 1 = enable, 0 = disable
    // rw. bit[1]: rx enable, 1 = enable, 0 = disable
    reg [`MemDataBus]  uart_ctrl         ;

    // addr: 0x04
    // ro. bit[0]: tx busy, 1 = busy, 0 = idle
    // rw. bit[1]: rx done, reserved for later RX support
    // must check this bit before writing tx data
    reg [`MemDataBus]  uart_status       ;

    // addr: 0x08
    // rw. baud divider
    reg [`MemDataBus]  uart_baud         ;

    // addr: 0x10, reserved for later RX support
    // reg [`MemDataBus]  uart_rx_data      ;

    reg                tx_start          ;
    reg                tx_done           ;
    reg [3:0]          tx_state          ;
    reg [15:0]         tx_baud_count     ;
    reg [3:0]          tx_bit_count      ;
    reg [7:0]          tx_data           ;
    reg                tx_pin_reg        ;

    // RX path is reserved for a later version.
    // reg                rx_pin_d0         ;
    // reg                rx_pin_d1         ;
    // wire               rx_start_edge     ;
    // reg                rx_start          ;
    // reg [3:0]          rx_sample_count   ;
    // reg                rx_sample_tick    ;
    // reg [15:0]         rx_cycle_count    ;
    // reg [15:0]         rx_baud_count     ;
    // reg [7:0]          rx_data           ;
    // reg                rx_done           ;

    wire               tx_enable         ;
    wire               tx_busy           ;
    // wire               rx_enable         ;
    // wire               rx_done_flag      ;

    assign tx_pin_o      = tx_pin_reg;
    assign tx_enable     = uart_ctrl[0];
    assign tx_busy       = uart_status[0];
    // assign rx_enable     = uart_ctrl[1];
    // assign rx_done_flag  = uart_status[1];
    // assign rx_start_edge = rx_pin_d1 && !rx_pin_d0;


    // ============================================================
    //  Write Mask
    // ============================================================
    function [`MemDataBus] apply_wstrb;
        input [`MemDataBus] old_data;
        input [`MemDataBus] new_data;
        input [3:0]         byte_sel;
        begin
            apply_wstrb = old_data;
            if (byte_sel[0]) begin
                apply_wstrb[ 7: 0] = new_data[ 7: 0];
            end
            if (byte_sel[1]) begin
                apply_wstrb[15: 8] = new_data[15: 8];
            end
            if (byte_sel[2]) begin
                apply_wstrb[23:16] = new_data[23:16];
            end
            if (byte_sel[3]) begin
                apply_wstrb[31:24] = new_data[31:24];
            end
        end
    endfunction


    // ============================================================
    //  Register Write
    // ============================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            uart_ctrl   <= `ZeroWord;
            uart_status <= `ZeroWord;
            uart_baud   <= UART_BAUD_115200;
            tx_data     <= 8'b0;
            tx_start    <= 1'b0;
        end else begin
            tx_start <= 1'b0;

            if (tx_done) begin
                uart_status[0] <= 1'b0;
            end

            if (w_en_i == `WriteEnable) begin
                case (w_addr_i[7:0])
                    UART_REG_CTRL: begin
                        uart_ctrl <= apply_wstrb(uart_ctrl, w_data_i, w_sel_i);
                    end

                    UART_REG_STATUS: begin
                        // RX status is reserved in this TX-only version.
                        uart_status[1] <= 1'b0;
                    end

                    UART_REG_BAUD: begin
                        uart_baud <= apply_wstrb(uart_baud, w_data_i, w_sel_i);
                    end

                    UART_REG_TXDATA: begin
                        if (tx_enable && !tx_busy) begin
                            tx_data        <= w_data_i[7:0];
                            uart_status[0] <= 1'b1;
                            tx_start       <= 1'b1;
                        end
                    end

                    default: begin
                    end
                endcase
            end
        end
    end


    // ============================================================
    //  TX FSM
    // ============================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            tx_state      <= TX_STATE_IDLE;
            tx_baud_count <= 16'b0;
            tx_bit_count  <= 4'b0;
            tx_pin_reg    <= 1'b1;
            tx_done       <= 1'b0;
        end else begin
            tx_done <= 1'b0;

            case (tx_state)
                TX_STATE_IDLE: begin
                    tx_pin_reg    <= 1'b1;
                    tx_baud_count <= 16'b0;
                    tx_bit_count  <= 4'b0;

                    if (tx_start) begin
                        tx_pin_reg <= 1'b0;
                        tx_state   <= TX_STATE_START;
                    end
                end

                TX_STATE_START: begin
                    if (tx_baud_count >= uart_baud[15:0]) begin
                        tx_baud_count <= 16'b0;
                        tx_pin_reg    <= tx_data[0];
                        tx_state      <= TX_STATE_DATA;
                    end else begin
                        tx_baud_count <= tx_baud_count + 1'b1;
                    end
                end

                TX_STATE_DATA: begin
                    if (tx_baud_count >= uart_baud[15:0]) begin
                        tx_baud_count <= 16'b0;

                        if (tx_bit_count == 4'd7) begin
                            tx_bit_count <= 4'b0;
                            tx_pin_reg   <= 1'b1;
                            tx_state     <= TX_STATE_STOP;
                        end else begin
                            tx_bit_count <= tx_bit_count + 1'b1;
                            tx_pin_reg   <= tx_data[tx_bit_count + 1'b1];
                        end
                    end else begin
                        tx_baud_count <= tx_baud_count + 1'b1;
                    end
                end

                TX_STATE_STOP: begin
                    if (tx_baud_count >= uart_baud[15:0]) begin
                        tx_baud_count <= 16'b0;
                        tx_pin_reg    <= 1'b1;
                        tx_done       <= 1'b1;
                        tx_state      <= TX_STATE_IDLE;
                    end else begin
                        tx_baud_count <= tx_baud_count + 1'b1;
                    end
                end

                default: begin
                    tx_state      <= TX_STATE_IDLE;
                    tx_baud_count <= 16'b0;
                    tx_bit_count  <= 4'b0;
                    tx_pin_reg    <= 1'b1;
                end
            endcase
        end
    end


    // ============================================================
    //  Register Read
    // ============================================================
    always @(*) begin
        if (!rst_n) begin
            r_data_o = `ZeroWord;
        end else begin
            case (r_addr_i[7:0])
                UART_REG_CTRL: begin
                    r_data_o = uart_ctrl;
                end

                UART_REG_STATUS: begin
                    r_data_o = uart_status;
                end

                UART_REG_BAUD: begin
                    r_data_o = uart_baud;
                end

                UART_REG_RXDATA: begin
                    r_data_o = `ZeroWord;
                end

                default: begin
                    r_data_o = `ZeroWord;
                end
            endcase
        end
    end

endmodule
