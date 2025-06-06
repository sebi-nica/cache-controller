module controller(
    input clk,
    input rst,
    input read_req,
    input write_req,
    input [31:0] cpu_address,
    input [511:0] cpu_write_data, // instr. from CPU

    input cache_hit,
    input cache_miss,
    input dirty_evicted,
    input [511:0] cache_read_data,
    input [31:0] evicted_address, // used for write-back

    input ram_ready,

    output reg [31:0] cache_address,
    output reg [511:0] cache_write_data,
    output reg cache_read,
    output reg cache_write,

    output reg [31:0] ram_address,
    output reg ram_req,
    output reg [511:0] cpu_read_data,
    output reg done
);

  localparam IDLE            = 3'b000; // 0
  localparam CHECK_CACHE     = 3'b001; // 1
  localparam HANDLE_HIT      = 3'b010; // 2
  localparam HANDLE_MISS     = 3'b011; // 3
  localparam WRITE_BACK      = 3'b100; // 4
  localparam WAITING_FOR_RAM = 3'b101; // 5
  localparam FINISH          = 3'b110; // 6

  reg [2:0] state, next_state;


  always @(posedge clk or posedge rst) begin
    if (rst) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  always @(*) begin
  cache_address     = 0;
  cache_write_data  = 0;
  cache_read        = 0; // default all just in case
  cache_write       = 0;
  ram_address       = 0;
  ram_req           = 0;
  cpu_read_data     = 0;
  done              = 0;
  next_state = state;

  case (state)
    IDLE: begin // wait for instructions from CPU and, when receiving said instructions, pass them to the cache
      if (read_req || write_req) begin
        cache_address    = cpu_address;
        cache_write_data = cpu_write_data;
        cache_read       = read_req;
        cache_write      = write_req;
        next_state       = CHECK_CACHE;
      end
    end

    CHECK_CACHE: begin // hit or miss
      cache_address    = cpu_address;
      cache_write_data = cpu_write_data;
      cache_read       = read_req;
      cache_write      = write_req;

      if (cache_hit)
        next_state = HANDLE_HIT;
      else if (cache_miss)
        next_state = HANDLE_MISS;
    end

    HANDLE_HIT: begin
      next_state = FINISH;
    end

    HANDLE_MISS: begin 
      cache_address    = cpu_address;
      cache_write_data = cpu_write_data;
      cache_read       = read_req;
      cache_write      = write_req;

      if (dirty_evicted)
        next_state = WRITE_BACK; // in case something dirty got evicted, the "RAM" should simulate another costly memory access to write-back
      else
        next_state = WAITING_FOR_RAM;
    end

    WRITE_BACK: begin
      cache_address    = cpu_address;
      cache_write_data = cpu_write_data;
      cache_read       = read_req;
      cache_write      = write_req;

      ram_address = evicted_address;
      ram_req     = 1;

      if (ram_ready) // wait for ram, then go wait again
        next_state = WAITING_FOR_RAM;
    end

    WAITING_FOR_RAM: begin
      cache_address    = cpu_address;
      cache_write_data = cpu_write_data;
      cache_read       = read_req;
      cache_write      = write_req;

      ram_address = cpu_address;
      ram_req     = 1;

      if (ram_ready) begin // waiting for the RAM to send new data to cache
        ram_req     = 0;
        next_state = FINISH;
      end
    end

    FINISH: begin
      done       = 1;
      ram_req = 0;
      next_state = IDLE; // send data to CPU and everything is done
      cpu_read_data = cache_read_data;
    end
  endcase
end


endmodule
