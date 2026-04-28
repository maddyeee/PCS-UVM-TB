// =============================================================================
// gmii_random_seq.sv
// Mix of IDLE, normal packets, and occasional GMII protocol violations.
// =============================================================================

class gmii_random_seq extends uvm_sequence #(gmii_tx_item);
    `uvm_object_utils(gmii_random_seq)

    rand int unsigned num_packets;
    rand int unsigned protocol_violation_pct;   // 0..100

    constraint c_d {
        soft num_packets            inside {[5:20]};
        soft protocol_violation_pct inside {[0:10]};
    }

    function new(string name = "gmii_random_seq");
        super.new(name);
    endfunction

    task body();
        gmii_idle_seq      ids;
        gmii_packet_seq    pkt;
        gmii_protoviol_seq pv;

        ids = gmii_idle_seq::type_id::create("ids");
        ids.randomize() with { num_cycles inside {[12:24]}; };
        ids.start(m_sequencer);

        for (int i = 0; i < num_packets; i++) begin
            int unsigned r;
            r = $urandom_range(0, 99);
            if (r < protocol_violation_pct) begin
                pv = gmii_protoviol_seq::type_id::create("pv");
                void'(pv.randomize());
                pv.start(m_sequencer);
            end else begin
                pkt = gmii_packet_seq::type_id::create("pkt");
                void'(pkt.randomize());
                pkt.start(m_sequencer);
            end
        end
    endtask

endclass : gmii_random_seq
