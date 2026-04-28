// =============================================================================
// pcs_tx_smoke_test.sv
// One packet of GMII traffic + IDLE. Quickest sanity check.
// =============================================================================

class pcs_tx_smoke_test extends pcs_tx_base_test;
    `uvm_component_utils(pcs_tx_smoke_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        gmii_idle_seq   ids;
        gmii_packet_seq pkt;

        phase.raise_objection(this);

        // Pre-IDLE so scrambler has time to whiten
        ids = gmii_idle_seq::type_id::create("ids");
        ids.randomize() with { num_cycles == 32; };
        ids.start(env.gmii_agt.sqr);

        pkt = gmii_packet_seq::type_id::create("pkt");
        pkt.randomize() with { payload_bytes == 64; ipg_cycles == 16; };
        pkt.start(env.gmii_agt.sqr);

        // Trail with IDLE so the pipeline drains
        ids = gmii_idle_seq::type_id::create("ids2");
        ids.randomize() with { num_cycles == 32; };
        ids.start(env.gmii_agt.sqr);

        phase.drop_objection(this);
    endtask

endclass : pcs_tx_smoke_test
