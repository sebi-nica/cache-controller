module top_level(
    input clk,
    input rst,
    input cpu_read,
    input cpu_write,
    input [31:0] cpu_address,
    input [511:0] cpu_write_data,
    output [511:0] cpu_read_data,
    output cache_hit,
    output cache_miss,
    output done_signal
); // just connecting everything together

  wire        cache_read, cache_write;
  wire [31:0] cache_address;
  wire [511:0] cache_write_data;
  wire [511:0] cache_read_data;
  wire        cache_ready;
  wire        cache_request;
  wire [31:0] cache_ram_address;
  wire [31:0] evicted_address;

  wire        ram_ready;
  wire [511:0] ram_data;
  wire        ram_req;
  wire [31:0] ram_address;

  controller ctrl (
    .clk(clk),
    .rst(rst),

    .read_req(cpu_read),
    .write_req(cpu_write),
    .cpu_address(cpu_address),
    .cpu_write_data(cpu_write_data), // these 4 are from CPU

    .cache_hit(cache_hit),
    .cache_miss(cache_miss),
    .dirty_evicted(dirty_evicted),
    .cache_read_data(cache_read_data),
    .evicted_address(evicted_address), // data from cache

    .ram_ready(ram_ready), // 

    .cache_address(cache_address),
    .cache_write_data(cache_write_data),
    .cache_read(cache_read),
    .cache_write(cache_write), // instructions to cache

    .ram_address(ram_address),
    .ram_req(ram_req), // instructions to RAM

    .cpu_read_data(cpu_read_data),
    .done(done_signal) // outputs
  );

  cache cache_inst (
    .clk(clk),
    .rst(rst),

    .address(cache_address),
    .write_data(cache_write_data),
    .read(cache_read),
    .write(cache_write), // instructions from controller

    .ram_ready(ram_ready),
    .ram_in(ram_data), // return from RAM

    .read_data(cache_read_data),
    .hit(cache_hit),
    .miss(cache_miss),
    .dirty_evicted(dirty_evicted),
    .evicted_address(evicted_address) // data to controller
  );

  ram fake_ram (
    .clk(clk),
    .rst(rst),
    .req(ram_req),
    .address(ram_address),
    .data_out(ram_data),
    .ready(ram_ready)
  );


endmodule
