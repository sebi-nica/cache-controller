module top_level(
    input clk,
    input rst,
    input cpu_read,
    input cpu_write,
    input [31:0] cpu_address,
    input [63:0] cpu_write_data,
    output [63:0] cpu_read_data,
    output cache_hit,
    output cache_miss
);

  // Signals between Controller and Cache
  wire        cache_read, cache_write;
  wire [31:0] cache_address;
  wire [63:0] cache_write_data;
  wire [63:0] cache_read_data;
  wire        cache_ready;
  wire        cache_request;
  wire [31:0] cache_ram_address;

  // Signals between Cache and RAM
  wire        ram_ready;
  wire [63:0] ram_data_out;
  wire        ram_req;
  wire [31:0] ram_address;

  // Controller
  controller ctrl (
    .clk(clk),
    .rst(rst),
    .cpu_read(cpu_read),
    .cpu_write(cpu_write),
    .cpu_address(cpu_address),
    .cpu_write_data(cpu_write_data),
    .cache_read(cache_read),
    .cache_write(cache_write),
    .cache_address(cache_address),
    .cache_write_data(cache_write_data),
    .cache_read_data(cache_read_data),
    .cache_hit(cache_hit),
    .cache_miss(cache_miss)
  );

  // Cache
  cache cache_inst (
    .clk(clk),
    .rst(rst),
    .read(cache_read),
    .write(cache_write),
    .address(cache_address),
    .write_data(cache_write_data),
    .read_data(cache_read_data),
    .hit(cache_hit),
    .miss(cache_miss),
    .ram_ready(ram_ready),
    .ram_in(ram_data_out),
    .ram_req(ram_req),
    .ram_address(ram_address)
  );

  // RAM
  ram fake_ram (
    .clk(clk),
    .rst(rst),
    .req(ram_req),
    .address(ram_address),
    .data_out(ram_data_out),
    .ready(ram_ready)
  );

  // CPU read data output
  assign cpu_read_data = cache_read_data;

endmodule
