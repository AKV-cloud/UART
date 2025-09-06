module uart_transmitter_receiver (
    input clk,                  // Clock input
    input reset,                // Reset input
    input [7:0] data_in,        // Data to be transmitted from the sender side
    input rx,                   // Receiver input (RX)
    output reg tx,              // Transmitter output (TX)
    output reg txd,             // Transmitter data output (TXD)
    output reg rts,             // Request to Send (RTS) output
    input cts                   // Clear to Send (CTS) input
);

    // Parameters
    parameter BAUD_RATE = 9600;
    parameter CLOCK_FREQ = 50000000; // e.g., 50MHz

    // States for transmitter and receiver state machines
    parameter [3:0] IDLE       = 4'b0000;
    parameter [3:0] START_BIT  = 4'b0001;
    parameter [3:0] DATA_BITS  = 4'b0010;
    parameter [3:0] PARITY_BIT = 4'b0011;
    parameter [3:0] STOP_BIT   = 4'b0100;

    // Transmitter variables
    reg [3:0] tx_state;
    reg [3:0] tx_bit_counter;
    reg [7:0] tx_data;
    reg [10:0] tx_baud_timer;
    reg tx_transmitting;
    reg [2:0] tx_parity;
    reg [2:0] tx_parity_counter;
    reg tx_rts;
    reg tx_xoff_sent;

    // Receiver variables
    reg [3:0] rx_state;
    reg [3:0] rx_bit_counter;
    reg [7:0] rx_data;
    reg [10:0] rx_baud_timer;
    reg rx_receiving;
    reg [2:0] rx_parity;
    reg [2:0] rx_parity_counter;
    reg rx_xoff_received;
    reg rx_rts;

    // Baud rate generator
    always @(posedge clk) begin
        if (rx_state == IDLE || tx_state == IDLE) begin
            rx_baud_timer <= 0;
            tx_baud_timer <= 0;
        end else begin
            if (rx_baud_timer == (CLOCK_FREQ / BAUD_RATE) - 1)
                rx_baud_timer <= 0;
            else
                rx_baud_timer <= rx_baud_timer + 1;

            if (tx_baud_timer == (CLOCK_FREQ / BAUD_RATE) - 1)
                tx_baud_timer <= 0;
            else
                tx_baud_timer <= tx_baud_timer + 1;
        end
    end

    // Transmitter state machine
    always @(posedge clk) begin
        if (reset) begin
            tx_state <= IDLE;
            tx_bit_counter <= 0;
            tx_data <= 8'b0;
            tx_transmitting <= 0;
            tx_parity <= 0;
            tx_parity_counter <= 0;
            tx_rts <= 0;
            tx_xoff_sent <= 0;
        end else begin
            if (tx_state == IDLE && tx_transmitting) begin
                tx_state <= START_BIT;
                tx_bit_counter <= 0;
                tx_data <= data_in;
                tx_parity <= 0;
                tx_parity_counter <= 0;
                tx_rts <= cts;
                tx_xoff_sent <= 0;
            end else begin
                case (tx_state)
                    IDLE: begin
                        tx_state <= tx_transmitting ? START_BIT : IDLE;
                    end
                    START_BIT: begin
                        tx_state <= DATA_BITS;
                        tx_bit_counter <= 0;
                        tx_parity_counter <= 0;
                    end
                    DATA_BITS: begin
                        if (tx_bit_counter == 7)
                            tx_state <= PARITY_BIT;
                        else
                            tx_bit_counter <= tx_bit_counter + 1;
                    end
                    PARITY_BIT: begin
                        if (tx_parity_counter == 2)
                            tx_state <= STOP_BIT;
                        else
                            tx_parity_counter <= tx_parity_counter + 1;
                    end
                    STOP_BIT: begin
                        tx_state <= IDLE;
                    end
                    default: tx_state <= IDLE;
                endcase
            end
        end
    end

    // Transmitter data output
    always @(posedge clk) begin
        if (reset)
            txd <= 1;
        else begin
            case (tx_state)
                DATA_BITS:  txd <= tx_data[tx_bit_counter];
                PARITY_BIT: txd <= tx_parity;
                STOP_BIT:   txd <= 1;
                default:    txd <= 1;
            endcase
        end
    end

    // Transmitter line control
    always @(posedge clk) begin
        if (reset)
            tx <= 1;
        else begin
            if (tx_state == START_BIT || tx_state == DATA_BITS ||
                tx_state == PARITY_BIT || tx_state == STOP_BIT)
                tx <= 0;
            else
                tx <= 1;
        end
    end

    // Start transmission on data input
    always @(posedge clk) begin
        if (reset)
            tx_transmitting <= 0;
        else begin
            if (!tx_transmitting && data_in != 8'b0)
                tx_transmitting <= 1;
        end
    end

    // Transmitter parity calculation
    always @(posedge clk) begin
        if (reset)
            tx_parity <= 0;
        else begin
            if (tx_state == DATA_BITS)
                tx_parity <= tx_data[0] ^ tx_data[1] ^ tx_data[2] ^
                             tx_data[3] ^ tx_data[4] ^ tx_data[5] ^
                             tx_data[6] ^ tx_data[7];
            else
                tx_parity <= 0;
        end
    end

    // Receiver state machine
    always @(posedge clk) begin
        if (reset) begin
            rx_state <= IDLE;
            rx_bit_counter <= 0;
            rx_data <= 8'b0;
            rx_receiving <= 0;
            rx_parity <= 0;
            rx_parity_counter <= 0;
            rx_xoff_received <= 0;
            rx_rts <= 0;
        end else begin
            if (rx_state == IDLE && rx_receiving) begin
                rx_state <= START_BIT;
                rx_bit_counter <= 0;
                rx_parity <= 0;
                rx_parity_counter <= 0;
            end else begin
                case (rx_state)
                    IDLE: begin
                        rx_state <= rx_receiving ? START_BIT : IDLE;
                    end
                    START_BIT: begin
                        rx_state <= DATA_BITS;
                        rx_bit_counter <= 0;
                        rx_parity_counter <= 0;
                    end
                    DATA_BITS: begin
                        if (rx_bit_counter == 7)
                            rx_state <= PARITY_BIT;
                        else
                            rx_bit_counter <= rx_bit_counter + 1;
                    end
                    PARITY_BIT: begin
                        if (rx_parity_counter == 2)
                            rx_state <= STOP_BIT;
                        else
                            rx_parity_counter <= rx_parity_counter + 1;
                    end
                    STOP_BIT: begin
                        rx_state <= IDLE;
                    end
                    default: rx_state <= IDLE;
                endcase
            end
        end
    end

    // Receiver data input
    always @(posedge clk) begin
        if (reset)
            rx_data <= 8'b0;
        else if (rx_state == DATA_BITS)
            rx_data[rx_bit_counter] <= rx;
    end

    // Receiver RTS output logic
    always @(posedge clk) begin
        if (reset)
            rts <= 0;
        else
            rts <= (rx_state == PARITY_BIT) ? 1 : 0;
    end

    // Start reception on start bit
    always @(posedge clk) begin
        if (reset)
            rx_receiving <= 0;
        else if (!rx_receiving && rx == 0) begin
            rx_receiving <= 1;
            rx_xoff_received <= 0;
        end
    end

    // Receiver parity calculation
    always @(posedge clk) begin
        if (reset)
            rx_parity <= 0;
        else if (rx_state == DATA_BITS)
            rx_parity <= rx_data[0] ^ rx_data[1] ^ rx_data[2] ^
                         rx_data[3] ^ rx_data[4] ^ rx_data[5] ^
                         rx_data[6] ^ rx_data[7] ^ rx;
        else
            rx_parity <= 0;
    end

    // XON/XOFF flow control - transmitter side
    always @(posedge clk) begin
        if (reset)
            tx_xoff_sent <= 0;
        else begin
            if (rx_xoff_received && !tx_xoff_sent) begin
                // Handle XOFF
                tx_transmitting <= 0;
            end else begin
                // Handle XON
                if (!tx_transmitting && data_in != 8'b0)
                    tx_transmitting <= 1;
                end
            end
        end
    end

    // X
     // XOFF reception detection
    always @(posedge clk) begin
       if (reset) begin
           rx_xoff_received <= 0;
       end else begin
           if (rx_state == DATA_BITS && rx_data == 8'h13) begin
               rx_xoff_received <= 1;
           end else begin
               rx_xoff_received <= 0;
           end
       end
   end
 endmodule
