// =============================================================================
// gmii_packet_seq.sv
// Drives a single Ethernet-like packet: preamble + SFD + payload + IDLE.
// Used as a building block by random and directed tests.
// =============================================================================

class gmii_packet_seq extends uvm_sequence #(gmii_tx_item);
    `uvm_object_utils(gmii_packet_seq)

    rand int unsigned payload_bytes;
    rand int unsigned ipg_cycles;
    rand bit          inject_tx_er;     // assert tx_er somewhere in payload

    constraint c_size {
        soft payload_bytes inside {[64:256]};
        soft ipg_cycles    inside {[12:32]};   // 12 = minimum IPG
        soft inject_tx_er  == 0;
    }

    function new(string name = "gmii_packet_seq");
        super.new(name);
    endfunction

    task body();
        // Preamble (7 bytes of 0x55) + SFD (0xD5)
        repeat (7)
            `uvm_do_with(req, { req.txd == 8'h55; req.tx_en == 1; req.tx_er == 0; })
        `uvm_do_with(req, { req.txd == 8'hD5; req.tx_en == 1; req.tx_er == 0; })

        // Payload
        for (int i = 0; i < payload_bytes; i++) begin
            bit force_er;
            force_er = inject_tx_er && (i == payload_bytes/2);
            `uvm_do_with(req, { req.tx_en == 1; req.tx_er == local::force_er; })
        end

        // Inter-packet gap = IDLE
        repeat (ipg_cycles)
            `uvm_do_with(req, { req.txd == 8'h00; req.tx_en == 0; req.tx_er == 0; })
    endtask

endclass : gmii_packet_seq
