// =============================================================================
// gmii_tx_item.sv
// GMII transmit transaction. One item == one GTX_CLK cycle of stimulus.
// =============================================================================

class gmii_tx_item extends uvm_sequence_item;
    `uvm_object_utils(gmii_tx_item)

    rand bit [7:0] txd;
    rand bit       tx_en;
    rand bit       tx_er;

    // Per-item delay (in GTX_CLK cycles) before driving this item.
    rand int unsigned pre_delay;

    // -- Constraints ---------------------------------------------------------
    // Default: no pre-delay between back-to-back items. Sequences relax it.
    constraint c_pre_delay { soft pre_delay == 0; }

    // GMII does not allow tx_er=1 with tx_en=0 except in carrier-extend
    // and false-carrier patterns. Sequences explicitly enable this mode
    // for protocol-violation tests.
    constraint c_legal_combo { soft (!(tx_er && !tx_en)); }

    function new(string name = "gmii_tx_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("TXD=0x%02h TX_EN=%0b TX_ER=%0b pre_delay=%0d",
                         txd, tx_en, tx_er, pre_delay);
    endfunction

endclass : gmii_tx_item
