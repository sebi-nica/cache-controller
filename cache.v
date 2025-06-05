// 4-Way Set Associative Cache Module
// Cache Size: 32KB | Block Size: 64B | 128 Sets | LRU | Write-back with Write-allocate

module cache(
    input clk,
    input rst,

    input read,
    input write,
    input [31:0] address,
    input [63:0] write_data,

    input        ram_ready,       // signal: RAM says "your data is ready"
    input [63:0] ram_in,          // 64-bit data from RAM
    output reg   ram_req,         // cache asks RAM for data
    output reg [31:0] ram_address // address to fetch from RAM


    output reg [63:0] read_data,
    output reg hit,
    output reg miss,
    output reg dirty_evicted,
    output reg [31:0] evicted_address
);

  localparam BLOCK_SIZE = 64; // in bytes
  localparam SETS = 128;      // number of sets
  localparam WAYS = 4;        // 4-way set associative
  localparam TAG_SIZE = 19;   // from 32-bit address: 19 tag, 7 index, 6 offset

  // Address breakdown - this is the address to be searched for
  wire [5:0] offset = address[5:0];         // block offset
  wire [6:0] index  = address[12:6];        // set index
  wire [18:0] tag   = address[31:13];       // tag

  // Per-way arrays for tags, data, valid and dirty bits, and LRU
  reg [18:0] tags     [0:WAYS-1][0:SETS-1]; // TAG for each BLOCK
  reg [BLOCK_SIZE*8-1:0] data [0:WAYS-1][0:SETS-1]; // DATA of each block 
  reg valid            [0:WAYS-1][0:SETS-1]; // valid bit
  reg dirty            [0:WAYS-1][0:SETS-1]; // dirty bit
  reg [1:0] lru        [0:WAYS-1][0:SETS-1]; // counter that holds the 'age' of each block in the cache

  integer i, w;

  // On reset, clear cache metadata
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      for (w = 0; w < WAYS; w = w + 1) begin
        for (i = 0; i < SETS; i = i + 1) begin
          valid[w][i] <= 0;
          dirty[w][i] <= 0;
          lru[w][i]   <= w;
          data[w][i] <= 0;
        end
      end
    end
  end

  reg [1:0] hit_way;
  reg hit_found;
  reg waiting_for_ram;


  // Cache lookup logic
  always @(*) begin
    hit_found = 0;
    hit = 0;
    miss = 0;
    dirty_evicted = 0;
    read_data = 64'b0;

    for (w = 0; w < WAYS; w = w + 1) begin // find the right way (if there is one)
        if (valid[w][index] && tags[w][index] == tag) begin
        hit_found = 1;
        hit_way = w;
      end
    end

    if (hit_found) begin // we got a hit
    hit = 1;
    read_data = data[hit_way][index][63:0];

    for (w = 0; w < WAYS; w = w + 1) begin
        if (lru[w][index] < lru[hit_way][index])
        lru[w][index] = lru[w][index] + 1;
    end // update all lru's in the current set
    lru[hit_way][index] = 0;
    if (write) begin
        data[hit_way][index][63:0] = write_data;
        dirty[hit_way][index] = 1; // mark dirty
    end

    end else begin // we got a miss
    miss = 1;

    // find way to replace data with
    reg [1:0] lru_way;
    for (w = 0; w < WAYS; w = w + 1) begin
        if (lru[w][index] == WAYS-1) begin
        lru_way = w;
        end
    end

    // If the block is dirty, set dirty_evicted so the 
    if (dirty[lru_way][index]) begin
        dirty_evicted = 1;
        evicted_address = {tags[lru_way][index], index, 6'b0};
    end

    // Simulate new data loaded from memory (not actually done here)
    tags[lru_way][index] = tag;
    valid[lru_way][index] = 1;
    dirty[lru_way][index] = write;
    ram_req = 1;
    ram_address = address;
    waiting_for_ram = 1;


    for (w = 0; w < WAYS; w = w + 1) begin
        if (lru[w][index] < lru[lru_way][index])
            lru[w][index] = lru[w][index] + 1;
    end // update all lru's in the current set
    lru[lru_way][index] = 0;

    if (read)
        read_data = data[lru_way][index][63:0];
    end
end

always @(posedge clk) begin // waiting for RAM. when ready, 
    if (waiting_for_ram && ram_ready) begin
        data[lru_way][index][63:0]   <= ram_in;         // store data from RAM
        tags[lru_way][index]         <= tag;            // update tag
        valid[lru_way][index]        <= 1;              // mark as valid
        dirty[lru_way][index]        <= 0;              // it's clean (just loaded)
        waiting_for_ram              <= 0;              // done waiting
        ram_req                      <= 0;              // drop RAM request
    end
end


endmodule
