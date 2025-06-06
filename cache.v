// 4-Way Set Associative Cache Module
// Cache Size: 32KB | Block Size: 64B | 128 Sets | LRU | Write-back with Write-allocate

module cache(
    input clk,
    input rst,

    input [31:0] address,
    input [511:0] write_data,
    input read,
    input write,

    input        ram_ready,       // signal: RAM says "your data is ready"
    input [511:0] ram_in,          // 64-bit data from RAM

    output reg [511:0] read_data,
    output reg hit,
    output reg miss,
    output reg dirty_evicted,
    output reg [31:0] evicted_address // this data is sent to the controller
);

  localparam BLOCK_SIZE = 64; // in bytes
  localparam SETS = 128;      // number of sets
  localparam WAYS = 4;        // 4-way SA
  localparam TAG_SIZE = 19;   // 19 tag, 7 index, 6 offset

  // break down the address for easier access
  wire [5:0] offset = address[5:0];         // block offset
  wire [6:0] index  = address[12:6];        // set index (determines which set)
  wire [18:0] tag   = address[31:13];       // tag

  
  reg [18:0] tags     [0:3][0:127]; // tag
  reg [511:0] data [0:1][0:127]; // the actual data in the cache (a block)
  reg valid            [0:3][0:127]; // valid bit
  reg dirty            [0:3][0:127]; // dirty bit
  reg [1:0] lru        [0:3][0:127]; // counter that holds the 'age' of each block in the cache

  integer i, w;

  initial begin
  for (w = 0; w < WAYS; w = w + 1)
    for (i = 0; i < SETS; i = i + 1) begin
      tags[w][i]  = 0;
      data[w][i]  = 0;
      valid[w][i] = 0;
      dirty[w][i] = 0;
      lru[w][i]   = w; // make sure all the blocks in every set have different ages
    end // make sure everything is 0'd out before starting
  end


  reg [1:0] hit_way;
  reg hit_found;
  reg waiting_for_ram;
  reg [1:0] lru_way;

  reg hit_nxt, miss_nxt, dirty_evicted_nxt, waiting_for_ram_nxt;

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      hit <= 0;
      miss <= 0;
      hit_nxt <= 0;
      miss_nxt <= 0;
      dirty_evicted_nxt <= 0;
      waiting_for_ram_nxt <= 0;
    end else begin
      hit <= hit_nxt;
      miss <= miss_nxt;
      dirty_evicted <= dirty_evicted_nxt;
      waiting_for_ram <= waiting_for_ram_nxt;
    end
  end



  // cache lookup logic
  always @(*) begin
    hit_found = 0;
    hit_nxt = 0;
    miss_nxt = 0;
    dirty_evicted_nxt = 0;

    if (waiting_for_ram) read_data = 0; // avoiding undefined behavior

    if((read || write) && ~waiting_for_ram) begin // if theres a request and we aren't waiting for ram, just process the request

      for (w = 0; w < WAYS; w = w + 1) begin // find the right way (if there is one)
          if (valid[w][index] && tags[w][index] == tag) begin
          hit_found = 1;
          hit_way = w;
        end
      end

      if (hit_found) begin // -------- HIT ---------
      hit_nxt = 1;
      read_data = data[hit_way][index];

      for (w = 0; w < WAYS; w = w + 1) begin
          if (lru[w][index] < lru[hit_way][index])
          lru[w][index] = lru[w][index] + 1;
      end // update all lru's in the current set (they are still all different)
      lru[hit_way][index] = 0;
      if (write) begin
          data[hit_way][index] = write_data;
          dirty[hit_way][index] = 1; // mark dirty
      end

      end else begin // -------- MISS ---------
      miss_nxt = 1;

      // find way to replace data with
      
      for (w = 0; w < WAYS; w = w + 1) begin
          if (lru[w][index] == WAYS-1) begin
          lru_way = w;
          end // the oldest block in the set will always have age=3
      end

      
      if (dirty[lru_way][index]) begin
          dirty_evicted_nxt = 1;
          evicted_address = {tags[lru_way][index], index, 6'b0};
      end // if the block is dirty, set dirty_evicted so the controller knows to replace it in ram

      // request new data from RAM
      tags[lru_way][index] = tag;
      valid[lru_way][index] = 1;
      dirty[lru_way][index] = write;
      waiting_for_ram_nxt = 1;


      for (w = 0; w < WAYS; w = w + 1) begin
          if (lru[w][index] < lru[lru_way][index])
              lru[w][index] = lru[w][index] + 1;
      end // update all lru's in the current set
      lru[lru_way][index] = 0; // this block was just accesed so age=0
      end

    end
    if (waiting_for_ram && ram_ready) begin // if the ram request is ready
      data[lru_way][index]         <= ram_in;         // store data from RAM
      tags[lru_way][index]         <= tag;            // update tag
      valid[lru_way][index]        <= 1;              // mark as valid
      dirty[lru_way][index]        <= 0;              // it's clean (just loaded)
      read_data = data[lru_way][index];
      waiting_for_ram_nxt =  0;
    end
end




endmodule
