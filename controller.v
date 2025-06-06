module controller(
    input clk,
    input rst,
    input read_req,
    input write_req,
    input [31:0] cpu_address,
    input [63:0] cpu_write_data,

    input cache_hit,
    input cache_miss,
    input dirty_evicted, // on when there is need for write-back
    input [63:0] cache_read_data,
    input [31:0] evicted_address, // address for write-back

    input ram_ready,

    output reg [31:0] cache_address,
    output reg [63:0] cache_write_data,
    output reg cache_read,
    output reg cache_write,

    output reg [31:0] ram_address,
    output reg ram_req,
    output reg [63:0] cpu_read_data,
    output reg done
);

  // State encoding
  localparam IDLE            = 3'b000;
  localparam CHECK_CACHE     = 3'b001;
  localparam HANDLE_HIT      = 3'b010;
  localparam HANDLE_MISS     = 3'b011;
  localparam WRITE_BACK      = 3'b100;
  localparam WAITING_FOR_RAM = 3'b101;
  localparam FINISH          = 3'b110;

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
        if (dirty_evicted) begin // tell the ram to pretend to write the data 
          next_state = WRITE_BACK;
        end else begin // tell the ram to pretend to retreive the data
          next_state = WAITING_FOR_RAM;
        end
        ram_address = cpu_address;
        ram_req = 1;
      end

      WRITE_BACK: begin
        if (ram_ready) begin // in this case, the ram needs to do 2 operations, write-back AND the original data retrieval because of the MISS
          ram_address = evicted_address;
          next_state = WAITING_FOR_RAM;
        end
      end

      WAITING_FOR_RAM: begin
        if (ram_ready) begin
          next_state = FINISH;
          ram_req = 0; // only now the ram can stop
        end
      end

      FINISH: begin
        done = 1;
        next_state = IDLE;
      end
    endcase
  end

endmodule
