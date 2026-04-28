// =============================================================================
// pcs_tx_pkg.sv
// Master package for the 1000BASE-T PCS TX verification environment.
// Compiles all UVM classes in dependency order.
// =============================================================================

package pcs_tx_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Reference model
    `include "components/pcs_tx_golden_model.sv"

    // Transactions / sequence items
    `include "components/gmii_tx_item.sv"
    `include "components/pam5_item.sv"
    `include "components/state_item.sv"

    // GMII agent
    `include "components/gmii_sequencer.sv"
    `include "components/gmii_driver.sv"
    `include "components/gmii_monitor.sv"
    `include "components/gmii_agent.sv"

    // PAM5 (passive) agent
    `include "components/pam5_monitor.sv"
    `include "components/pam5_agent.sv"

    // State / error-injection agent
    `include "components/state_sequencer.sv"
    `include "components/state_driver.sv"
    `include "components/state_agent.sv"

    // Scoreboard + coverage
    `include "components/pcs_tx_scoreboard.sv"
    `include "components/pcs_tx_coverage.sv"

    // Environment
    `include "env/pcs_tx_env.sv"

    // Sequences
    `include "sequences/gmii_idle_seq.sv"
    `include "sequences/gmii_packet_seq.sv"
    `include "sequences/gmii_protoviol_seq.sv"
    `include "sequences/gmii_random_seq.sv"
    `include "sequences/error_inject_seq.sv"

    // Tests
    `include "tests/pcs_tx_base_test.sv"
    `include "tests/pcs_tx_smoke_test.sv"
    `include "tests/pcs_tx_random_test.sv"
    `include "tests/pcs_tx_error_test.sv"

endpackage : pcs_tx_pkg
