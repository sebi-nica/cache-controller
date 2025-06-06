# simulate.tcl - TCL script to compile and simulate cache system

# Set the working library
vlib work
vmap work work

# Compile all source files
vlog ram.v
vlog cache.v
vlog controller.v
vlog top_level.v
vlog top_level_tb.v

# Run simulation
vsim work.top_level_tb

# Add only top-level testbench signals to waveform
add wave sim:/top_level_tb/dut/ctrl/state
add wave sim:/top_level_tb/dut/fake_ram/delay_counter
add wave sim:/top_level_tb/dut/fake_ram/req
add wave sim:/top_level_tb/dut/cache_inst/waiting_for_ram
add wave sim:/top_level_tb/dut/cache_inst/ram_ready
add wave *

radix hex

run -all
