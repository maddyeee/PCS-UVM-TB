// =============================================================================
// gmii_idle_seq.sv
// Drives N cycles of GMII IDLE (TXD = 0x00, TX_EN = 0, TX_ER = 0).
// =============================================================================

class gmii_idle_seq extends uvm_sequence #(gmii_tx_item);
    `uvm_object_utils(gmii_idle_seq)

    rand int unsigned num_cycles;
    constraint c_n { soft num_cycles inside {[8:64]}; }

    function new(string name = "gmii_idle_seq");
        super.new(name);
    endfunction

    task body();
        repeat (num_cycles) begin
            `uvm_do_with(req, { req.txd == 8'h00; req.tx_en == 0; req.tx_er == 0; })
        end
    endtask

endclass : gmii_idle_seq
