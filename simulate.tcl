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
add wave *

# Run for a long enough time
run -all
