module controller(
    input clk,
    input rst,
    input read_req,
    input write_req,
    input [31:0] cpu_address,
    input [63:0] cpu_write_data,

    input cache_hit,
    input cache_miss,
    input dirty_evicted,
    input [63:0] cache_read_data,
    input [31:0] evicted_address,

    input ram_ready,
    input [63:0] ram_in,

    output reg [31:0] cache_address,
    output reg [63:0] cache_write_data,
    output reg cache_read,
    output reg cache_write,

    output reg [31:0] ram_address,
    output reg ram_req,
    output reg [63:0] cpu_read_data,
    output reg done
);

  typedef enum logic [2:0] {
    IDLE, CHECK_CACHE, HANDLE_HIT, HANDLE_MISS,
    WRITE_BACK, WAITING_FOR_RAM, FINISH
  } state_t;

  state_t state, next_state;

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
    // Defaults
    cache_read = 0;
    cache_write = 0;
    cache_address = 0;
    cache_write_data = 0;
    ram_address = 0;
    ram_req = 0;
    done = 0;
    cpu_read_data = 0;

    next_state = state;

    case (state)
      IDLE: begin
        if (read_req || write_req) begin
          cache_address = cpu_address;
          cache_write_data = cpu_write_data;
          cache_read = read_req;
          cache_write = write_req;
          next_state = CHECK_CACHE;
        end
      end

      CHECK_CACHE: begin
        if (cache_hit)
          next_state = HANDLE_HIT;
        else if (cache_miss)
          next_state = HANDLE_MISS;
      end

      HANDLE_HIT: begin
        if (read_req)
          cpu_read_data = cache_read_data;
        done = 1;
        next_state = IDLE;
      end

      HANDLE_MISS: begin
        if (dirty_evicted) begin
          ram_address = evicted_address;
          ram_req = 1;
          next_state = WRITE_BACK;
        end else begin
          ram_address = cpu_address;
          ram_req = 1;
          next_state = WAITING_FOR_RAM;
        end
      end

      WRITE_BACK: begin
        if (ram_ready) begin
          ram_address = cpu_address;
          ram_req = 1;
          next_state = WAITING_FOR_RAM;
        end
      end

      WAITING_FOR_RAM: begin
        if (ram_ready)
          next_state = FINISH;
      end

      FINISH: begin
        done = 1;
        next_state = IDLE;
      end
    endcase
  end

endmodule
