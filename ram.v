module ram (
    input clk,
    input rst,
    input req, // 
    input [31:0] address,
    output reg [511:0] data_out, // 64 bytes = 512 bits
    output reg ready
);

    localparam DELAY_CYCLES = 100;

    reg [7:0] delay_counter;
    reg busy;

    // Simple PRNG for simulation (LFSR-like)
    function [511:0] generate_random_data(input [31:0] seed);
        integer k;
        begin
            for (k = 0; k < 512; k = k + 1) begin
                generate_random_data[k] = seed[(k % 32)] ^ (k & 1);
            end
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ready <= 0;
            delay_counter <= DELAY_CYCLES;
            busy <= 0;
        end else begin
            if (req && !busy) begin
                busy <= 1;
                delay_counter <= DELAY_CYCLES;
                ready <= 0;
            end else if (busy) begin
                if (delay_counter > 0) begin
                    delay_counter <= delay_counter - 1;
                end else begin
                    data_out <= generate_random_data(address); // use the address as seed because why not
                    ready <= 1;
                    busy <= 0;
                end
            end else begin
                ready <= 0;
            end
        end
    end

endmodule
