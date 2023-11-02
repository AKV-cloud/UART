// Code your testbench here
// or browse Examples
module tb_uart;


  parameter BAUD_RATE = 9600;
  parameter CLOCK_PERIOD = 20;

  reg clk = 1'b0;
  reg reset;
  reg [7:0] data_in;
  reg rx;
  reg cts;

  // Outputs
  wire tx;
  wire txd;
  wire rts;

  
  uart_transmitter_receiver uut (
    .clk(clk),
    .reset(reset),
    .data_in(data_in),
    .rx(rx),
    .tx(tx),
    .txd(txd),
    .rts(rts),
    .cts(cts)
  );


  always #5 clk = ~clk;

  // Test data
  reg [7:0] test_data [0:1] = '{8'h45, 8'h6C}; 
  
  initial 
    begin
      $dumpfile("dump.vcd");
      $dumpvars(0);
    end

  // Testbench behavior
  initial begin
    // Reset
    reset = 1;
    cts = 1;
    data_in = 8'b0;
    #10;
    reset = 0;

    // Test transmission
    #20;
    data_in = test_data[0];
    #200; 
    // Test reception
    rx = 0;
    #220; // Start bit
    rx = 1;
    #60; // Bit 0 - "E"
    rx = 0;
    #60;
    rx = 1;
    #60; // Bit 1
    

    // Test flow control (XOFF)
    rx = 0;
    #220; // Start bit
    rx = 1;
    #60; // Bit 0 - XOFF character
    rx = 0;
    #60;
    rx = 1;
    #60; // Bit 1
 

    // Test flow control (XON)
    rx = 0;
    #220; // Start bit
    rx = 1;
    #60; // Bit 0 - XON character
    rx = 0;
    #60;
    rx = 1;
    #60; // Bit 1
    

    #100;
    $finish;
  end

endmodule
