# =============================================================================
# Makefile for the 1000BASE-T PCS TX UVM testbench
#
# Targets:
#   make smoke      - run pcs_tx_smoke_test
#   make random     - run pcs_tx_random_test
#   make error      - run pcs_tx_error_test
#   make all        - run all three with random seeds
#   make clean      - remove build artifacts
#
# Simulator: pick one (default = vcs). Override on command line:
#   make SIM=questa smoke
#   make SIM=xcelium random
# =============================================================================

SIM      ?= vcs
TEST     ?= pcs_tx_smoke_test
SEED     ?= $(shell date +%s)
WAVES    ?= 0
VERBOSITY?= UVM_LOW

UVM_RUN_FLAGS = +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=$(VERBOSITY)
ifeq ($(WAVES),1)
  UVM_RUN_FLAGS += +waves
endif

# -----------------------------------------------------------------------------
# Synopsys VCS
# -----------------------------------------------------------------------------
ifeq ($(SIM),vcs)
COMP = vcs -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps \
           -CFLAGS -DVCS -debug_access+all -kdb \
           -f filelist.f -l comp.log
RUN  = ./simv -ntb_random_seed=$(SEED) $(UVM_RUN_FLAGS) -l run.log
endif

# -----------------------------------------------------------------------------
# Mentor Questa
# -----------------------------------------------------------------------------
ifeq ($(SIM),questa)
COMP = vlib work && vlog -sv -mfcu +incdir+../tb +incdir+../tb/components \
           +incdir+../tb/env +incdir+../tb/sequences +incdir+../tb/tests \
           -L $(QUESTA_HOME)/uvm-1.2 -timescale 1ns/1ps -f filelist.f -l comp.log
RUN  = vsim -c -do "run -all; quit" -sv_seed $(SEED) $(UVM_RUN_FLAGS) tb_top -l run.log
endif

# -----------------------------------------------------------------------------
# Cadence Xcelium
# -----------------------------------------------------------------------------
ifeq ($(SIM),xcelium)
COMP = xrun -uvmhome CDNS-1.2 -sv -access +rwc -timescale 1ns/1ps \
           -f filelist.f -l comp.log -elaborate
RUN  = xrun -R -svseed $(SEED) $(UVM_RUN_FLAGS) -l run.log
endif

.PHONY: compile run smoke random error all clean

compile:
	$(COMP)

run: compile
	$(RUN)

smoke:
	$(MAKE) run TEST=pcs_tx_smoke_test

random:
	$(MAKE) run TEST=pcs_tx_random_test

error:
	$(MAKE) run TEST=pcs_tx_error_test

all: smoke random error

clean:
	rm -rf simv simv.daidir csrc work transcript *.log *.vpd *.vcd \
	       xcelium.d xrun.history *.shm ucli.key vc_hdrs.h
