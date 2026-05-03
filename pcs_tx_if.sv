// =============================================================================
// PCS TX Encoder - Interface Definition
// =============================================================================

interface pcs_tx_if (input logic clk);

  // GMII inputs (driven by driver)
  logic        reset_n;
  logic [7:0]  txd;
  logic        tx_en;
  logic        tx_er;
  logic        link_status;
  logic        col_test;

  // PCS outputs (sampled by monitor)
  logic [9:0]  tx_code_group;
  logic        tx_code_valid;
  logic [2:0]  tx_state;
  logic        transmitting;
  logic        tx_error_out;
  logic        carrier_extend;

  // Clocking blocks for testbench synchronization
  clocking drv_cb @(posedge clk);
    default input #1 output #1;
    output txd, tx_en, tx_er, link_status, col_test, reset_n;
    input  tx_code_group, tx_code_valid, tx_state, transmitting, tx_error_out, carrier_extend;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1;
    input txd, tx_en, tx_er, link_status;
    input tx_code_group, tx_code_valid, tx_state, transmitting, tx_error_out, carrier_extend;
  endclocking

  // Modports
  modport DUT (
    input  clk, reset_n, txd, tx_en, tx_er, link_status, col_test,
    output tx_code_group, tx_code_valid, tx_state, transmitting, tx_error_out, carrier_extend
  );

  modport TB (
    clocking drv_cb, mon_cb,
    output reset_n
  );

endinterface
