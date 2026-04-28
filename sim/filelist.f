// Compile order for the 1000BASE-T PCS TX UVM environment.
// Adjust simulator-specific flags in Makefile, not here.

+incdir+../tb
+incdir+../tb/components
+incdir+../tb/env
+incdir+../tb/sequences
+incdir+../tb/tests

// RTL (replace stub with the real DUT)
../rtl/pcs_tx_dut_stub.sv

// Interface (must compile before tb_top binds it)
../tb/pcs_tx_if.sv

// UVM package - includes every class
../tb/pcs_tx_pkg.sv

// Top-level
../tb/tb_top.sv
