// =============================================================================
// pcs_tx_dut_stub.sv
// Placeholder for the 1000BASE-T PCS transmit encoder Device Under Test.
//
// REPLACE THIS FILE with your real RTL. The port list below matches what
// pcs_tx_if.sv expects. Internal debug probes (dbg_*) are exposed so that
// the verification environment can perform white-box checking and error
// injection without resorting to hierarchical force/release.
// =============================================================================

module pcs_tx_dut_stub (
    input  logic         gtx_clk,
    input  logic         rst_n,

    // GMII inputs
    input  logic [7:0]   txd,
    input  logic         tx_en,
    input  logic         tx_er,

    // Config
    input  logic         config_master,
    input  logic         loc_rcvr_status,

    // PAM5 outputs
    output logic signed [2:0] tx_an,
    output logic signed [2:0] tx_bn,
    output logic signed [2:0] tx_cn,
    output logic signed [2:0] tx_dn,
    output logic              tx_sym_valid,

    // White-box debug observation
    output logic [32:0]  dbg_scr_n,
    output logic  [2:0]  dbg_cs_n,
    output logic         dbg_srev_n,
    output logic  [8:0]  dbg_sd_n,

    // Error injection inputs (gated overrides)
    input  logic         force_cs_en,
    input  logic  [2:0]  force_cs_val,
    input  logic         force_scr_en,
    input  logic [32:0]  force_scr_val,
    input  logic         force_srev_en,
    input  logic         force_srev_val
);

    // The real implementation must instantiate scrambler, convolutional
    // encoder, bit-to-symbol mapper, and sign randomizer per Clause 40.3.
    // Below is a no-op stub that lets the testbench elaborate.
    initial begin
        $display("[%0t] [DUT_STUB] pcs_tx_dut_stub elaborated.", $time);
        $display("              Replace with real 1000BASE-T TX PCS RTL.");
    end

    assign tx_an        = '0;
    assign tx_bn        = '0;
    assign tx_cn        = '0;
    assign tx_dn        = '0;
    assign tx_sym_valid = 1'b0;
    assign dbg_scr_n    = '0;
    assign dbg_cs_n     = '0;
    assign dbg_srev_n   = 1'b0;
    assign dbg_sd_n     = '0;

endmodule : pcs_tx_dut_stub
