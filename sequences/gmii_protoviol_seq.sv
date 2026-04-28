// =============================================================================
// gmii_protoviol_seq.sv
// Drives illegal GMII patterns to test the encoder's response to protocol
// violations:
//   - TX_ER = 1 with TX_EN = 0 (false carrier)
//   - TX_EN glitches in the middle of preamble
//   - TX_ER pulse on a single cycle of valid data
// =============================================================================

class gmii_protoviol_seq extends uvm_sequence #(gmii_tx_item);
    `uvm_object_utils(gmii_protoviol_seq)

    typedef enum {PV_FALSE_CARRIER, PV_PREAMBLE_GLITCH, PV_TXER_PULSE} pv_e;
    rand pv_e flavor;

    function new(string name = "gmii_protoviol_seq");
        super.new(name);
    endfunction

    task body();
        gmii_tx_item it;
        case (flavor)
            PV_FALSE_CARRIER: begin
                // tx_er=1 with tx_en=0 for a few cycles. The legal-combo
                // constraint blocks this, so disable it manually before
                // randomizing.
                repeat (4) begin
                    it = gmii_tx_item::type_id::create("it");
                    it.c_legal_combo.constraint_mode(0);
                    start_item(it);
                    if (!it.randomize() with { tx_en == 0; tx_er == 1; })
                        `uvm_fatal("PV_SEQ", "false-carrier randomize failed")
                    finish_item(it);
                end
            end
            PV_PREAMBLE_GLITCH: begin
                // Drop tx_en in the middle of preamble
                repeat (3)
                    `uvm_do_with(req, { req.txd == 8'h55; req.tx_en == 1; req.tx_er == 0; })
                `uvm_do_with(req, { req.tx_en == 0; req.tx_er == 0; })
                repeat (4)
                    `uvm_do_with(req, { req.txd == 8'h55; req.tx_en == 1; req.tx_er == 0; })
                `uvm_do_with(req, { req.txd == 8'hD5; req.tx_en == 1; req.tx_er == 0; })
            end
            PV_TXER_PULSE: begin
                repeat (8)
                    `uvm_do_with(req, { req.tx_en == 1; req.tx_er == 0; })
                `uvm_do_with(req, { req.tx_en == 1; req.tx_er == 1; })   // single-cycle tx_er
                repeat (8)
                    `uvm_do_with(req, { req.tx_en == 1; req.tx_er == 0; })
            end
        endcase
    endtask

endclass : gmii_protoviol_seq
