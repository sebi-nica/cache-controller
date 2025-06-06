`timescale 1ns / 1ps

module top_level_tb;

  reg clk, rst;
  reg cpu_read, cpu_write;
  reg [31:0] cpu_address;
  reg [63:0] cpu_write_data;
  wire [63:0] cpu_read_data;
  wire cache_hit, cache_miss;

  // Instantiate top_level
  top_level dut (
    .clk(clk),
    .rst(rst),
    .cpu_read(cpu_read),
    .cpu_write(cpu_write),
    .cpu_address(cpu_address),
    .cpu_write_data(cpu_write_data),
    .cpu_read_data(cpu_read_data),
    .cache_hit(cache_hit),
    .cache_miss(cache_miss)
  );

  // Clock generation
  always #5 clk = ~clk;

  // Tasks for operations
  task read_from_cache(input [31:0] addr);
    begin
      cpu_read = 1;
      cpu_write = 0;
      cpu_address = addr;
      @(posedge clk);
      cpu_read = 0;
    end
  endtask

  task write_to_cache(input [31:0] addr, input [63:0] data);
    begin
      cpu_write = 1;
      cpu_read = 0;
      cpu_address = addr;
      cpu_write_data = data;
      @(posedge clk);
      cpu_write = 0;
    end
  endtask

  // Simulation flow
  initial begin
    $dumpfile("cache.vcd");
    $dumpvars(0, top_level_tb);

    clk = 0;
    rst = 1;
    cpu_read = 0;
    cpu_write = 0;
    cpu_address = 0;
    cpu_write_data = 0;

    // Reset
    @(posedge clk);
    rst = 0;

    // Write Miss (should trigger write allocate)
    $display("Write Miss");
    write_to_cache(32'h0000_1000, 64'hAAAA_BBBB_CCCC_DDDD);
    repeat(20) @(posedge clk); // allow time for fake RAM

    // Read Hit (should get data we just wrote)
    $display("Read Hit");
    read_from_cache(32'h0000_1000);
    repeat(5) @(posedge clk);

    // Read Miss (different address)
    $display("Read Miss");
    read_from_cache(32'h0000_2000);
    repeat(20) @(posedge clk);

    // Write Hit (update cached data)
    $display("Write Hit");
    write_to_cache(32'h0000_1000, 64'h1111_2222_3333_4444);
    repeat(5) @(posedge clk);

    // Read Hit (see updated data)
    $display("Read Updated Value");
    read_from_cache(32'h0000_1000);
    repeat(5) @(posedge clk);

    $stop;
  end

endmodule
