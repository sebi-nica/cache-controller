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

  // State encoding
  localparam IDLE            = 3'b000; // 0
  localparam CHECK_CACHE     = 3'b001; // 1
  localparam HANDLE_HIT      = 3'b010; // 2
  localparam HANDLE_MISS     = 3'b011; // 3
  localparam WRITE_BACK      = 3'b100; // 4
  localparam WAITING_FOR_RAM = 3'b101; // 5
  localparam FINISH          = 3'b110; // 6

  // Current and next state registers
  reg [2:0] state, next_state;


  // FSM state transitions
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // FSM next state logic and control signals
  always @(*) begin
  // Default all outputs (clean slate)
  cache_address     = 0;
  cache_write_data  = 0;
  cache_read        = 0;
  cache_write       = 0;
  ram_address       = 0;
  ram_req           = 0;
  cpu_read_data     = 0;
  done              = 0;

  next_state = state; // default: hold current state

  case (state)
    IDLE: begin
      if (read_req || write_req) begin
        cache_address    = cpu_address;
        cache_write_data = cpu_write_data;
        cache_read       = read_req;
        cache_write      = write_req;
        next_state       = CHECK_CACHE;
      end
    end

    CHECK_CACHE: begin // wait for cache to finish
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
      cpu_read_data = cache_read_data;
      next_state = FINISH;
    end

    HANDLE_MISS: begin
      cache_address    = cpu_address;
      cache_write_data = cpu_write_data;
      cache_read       = read_req;
      cache_write      = write_req;

      if (dirty_evicted)
        next_state = WRITE_BACK;
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

      if (ram_ready)
        next_state = WAITING_FOR_RAM;
    end

    WAITING_FOR_RAM: begin
      cache_address    = cpu_address;
      cache_write_data = cpu_write_data;
      cache_read       = read_req;
      cache_write      = write_req;

      ram_address = cpu_address;
      ram_req     = 1;

      if (ram_ready) begin
        cpu_read_data = cache_read_data;
        ram_req     = 0;
        next_state = FINISH;
      end
    end

    FINISH: begin
      done       = 1;
      ram_req = 0;
      next_state = IDLE;
    end
  endcase
end


endmodule
