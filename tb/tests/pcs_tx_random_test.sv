// =============================================================================
// pcs_tx_random_test.sv
// Mix of random packets + occasional protocol violations.
// =============================================================================

class pcs_tx_random_test extends pcs_tx_base_test;
    `uvm_component_utils(pcs_tx_random_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        gmii_random_seq rs;
        phase.raise_objection(this);

        rs = gmii_random_seq::type_id::create("rs");
        void'(rs.randomize() with {
            num_packets            == 12;
            protocol_violation_pct == 5;
        });
        rs.start(env.gmii_agt.sqr);

        // Drain
        #2us;
        phase.drop_objection(this);
    endtask

endclass : pcs_tx_random_test
