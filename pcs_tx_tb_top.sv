// =============================================================================
// PCS TX Encoder - Top-Level Testbench
// =============================================================================
`include "uvm_macros.svh"

module pcs_tx_tb_top;

  import uvm_pkg::*;
  import pcs_tx_pkg::*;

  // =========================================================================
  // Clock generation - 125 MHz (8ns period) for Gigabit Ethernet
  // =========================================================================
  logic clk;
  initial begin
    clk = 0;
    forever #4 clk = ~clk; // 125 MHz
  end

  // =========================================================================
  // Interface instantiation
  // =========================================================================
  pcs_tx_if pcs_if (.clk(clk));

  // =========================================================================
  // DUT instantiation
  // =========================================================================
  pcs_tx_encoder dut (
    .clk            (clk),
    .reset_n        (pcs_if.reset_n),
    .txd            (pcs_if.txd),
    .tx_en          (pcs_if.tx_en),
    .tx_er          (pcs_if.tx_er),
    .link_status    (pcs_if.link_status),
    .col_test       (pcs_if.col_test),
    .tx_code_group  (pcs_if.tx_code_group),
    .tx_code_valid  (pcs_if.tx_code_valid),
    .tx_state       (pcs_if.tx_state),
    .transmitting   (pcs_if.transmitting),
    .tx_error_out   (pcs_if.tx_error_out),
    .carrier_extend (pcs_if.carrier_extend)
  );

  // =========================================================================
  // Reset initialization
  // =========================================================================
  initial begin
    pcs_if.reset_n     = 1'b0;
    pcs_if.txd         = 8'h00;
    pcs_if.tx_en       = 1'b0;
    pcs_if.tx_er       = 1'b0;
    pcs_if.link_status = 1'b0;
    pcs_if.col_test    = 1'b0;
  end

  // =========================================================================
  // UVM configuration and test launch
  // =========================================================================
  initial begin
    // Register virtual interface with config_db
    uvm_config_db#(virtual pcs_tx_if)::set(null, "*", "vif", pcs_if);

    // Dump waveforms
    $dumpfile("pcs_tx_waves.vcd");
    $dumpvars(0, pcs_tx_tb_top);

    // Run UVM test
    run_test();
  end

  // =========================================================================
  // Timeout watchdog
  // =========================================================================
  initial begin
    #100_000;
    `uvm_fatal("TIMEOUT", "Simulation timed out at 100us")
  end

  // =========================================================================
  // Assertions - Reset behavior checks
  // =========================================================================

  // After reset, DUT must be in IDLE state
  property p_reset_to_idle;
    @(posedge clk) !pcs_if.reset_n |-> ##[1:3] (pcs_if.tx_state == 3'b000);
  endproperty
  assert property (p_reset_to_idle)
    else `uvm_error("ASSERT", "DUT did not return to IDLE after reset");

  // After reset, tx_code_valid should eventually assert
  property p_reset_code_valid;
    @(posedge clk) $rose(pcs_if.reset_n) |-> ##[1:5] pcs_if.tx_code_valid;
  endproperty
  assert property (p_reset_code_valid)
    else `uvm_error("ASSERT", "tx_code_valid not asserted after reset release");

  // No transmission during reset
  property p_no_tx_during_reset;
    @(posedge clk) !pcs_if.reset_n |-> !pcs_if.transmitting;
  endproperty
  assert property (p_no_tx_during_reset)
    else `uvm_error("ASSERT", "Transmitting asserted during reset");

  // TX error must only appear in error state
  property p_error_in_error_state;
    @(posedge clk) pcs_if.tx_error_out |-> (pcs_if.tx_state == 3'b011);
  endproperty
  assert property (p_error_in_error_state)
    else `uvm_error("ASSERT", "tx_error_out asserted outside TX_ERROR state");

endmodule
