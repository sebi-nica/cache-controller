`timescale 1ns / 1ps

module top_level_tb;

  reg clk, rst;
  reg cpu_read, cpu_write;
  reg [31:0] cpu_address;
  reg [511:0] cpu_write_data;

  wire [511:0] cpu_read_data;
  wire cache_hit, cache_miss;
  wire done_signal;

  reg [31:0] miss_count, hit_count;
  

  top_level dut (
    .clk(clk),
    .rst(rst),
    .cpu_read(cpu_read),
    .cpu_write(cpu_write),
    .cpu_address(cpu_address),
    .cpu_write_data(cpu_write_data),
    .cpu_read_data(cpu_read_data),
    .cache_hit(cache_hit),
    .cache_miss(cache_miss),
    .done_signal(done_signal)
  );

  always #5 clk = ~clk;

  task automatic do_single_access; // request something from the cache on a random address
  input [31:0] addr;
  input is_write; // done like this to make it easier to randomly decide whether an access is a write or a read
    integer i;
  begin
    cpu_address = addr;


    for (i = 0; i < 16; i = i + 1) begin
      cpu_write_data[i*32 +: 32] = $random;
    end
    cpu_read = 0;
    cpu_write = 0;
    @(posedge clk);

    if (is_write)
      cpu_write = 1;
    else
      cpu_read = 1;

    wait(cache_hit || cache_miss);
    if (cache_miss) miss_count = miss_count + 1;
    else hit_count = hit_count + 1;

    wait (done_signal);

    @(posedge clk);
    cpu_read = 0;
    cpu_write = 0;
  end
endtask

task automatic run_random_accesses; // as using the entire 32-bit address would be like having a 4GiB RAM (massive compared to the size of the cache)
  input integer num_accesses;       // this task rarely hits
  input integer write_percentage;   // I simulated 4.000.000 requests and got 245 hits. that's a MR of 99.993875 %
  integer i;
  begin
    miss_count = 0;
    hit_count = 0;


    for (i = 0; i < num_accesses; i = i + 1) begin
      do_single_access($random, ($random % 100) < write_percentage);
    end

    $display("hits: %d", num_accesses - miss_count);
  end
endtask

task automatic run_locality_access; // this task simulates a smaller RAM by restricting the range of the address 
  input integer num_accesses;
  input integer region_size; // this restricts the number of bytes of fake "capacity" that the fake "RAM" has
  input integer write_percentage; // variable amount of reads/writes
  integer base_addr;
  integer i;
  begin
    miss_count = 0;
    hit_count = 0;
    base_addr = 32'h10000000;

    

    for (i = 0; i < num_accesses; i = i + 1) begin
      do_single_access(base_addr + ($random % region_size), ($random % 100) < write_percentage);
    end

    hit_count = num_accesses - miss_count;

    $display("-------- Cache Simulation Stats --------");
    $display("Total Accesses  : %0d", num_accesses);
    $display("Region Size     : %0d bytes", region_size);
    $display("Misses          : %0d", miss_count);
    $display("Hits            : %0d", hit_count);
    $display("Miss Rate       : %0f%%", 100.0 * miss_count / num_accesses);
    $display("----------------------------------------");
  end
endtask



  // Initial block
  initial begin
    clk = 0;
    rst = 1;
    cpu_read = 0;
    cpu_write = 0;
    cpu_address = 0;
    cpu_write_data = 0;

    repeat (5) @(posedge clk);
    rst = 0;

    #10;
    run_locality_access(100000, 64000, 30);
    #20;

    $stop;
  end

endmodule
