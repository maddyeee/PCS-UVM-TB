// =============================================================================
// state_item.sv
// Error injection transaction. Tells the state_driver which white-box
// signal to override, and for how long.
// =============================================================================

typedef enum bit [2:0] {
    EI_NONE       = 3'd0,
    EI_FORCE_CS   = 3'd1,    // Override convolutional state
    EI_FORCE_SCR  = 3'd2,    // Override scrambler register
    EI_FORCE_SREV = 3'd3,    // Override sign reversal
    EI_BITFLIP    = 3'd4     // Flip a bit in the OUTPUT symbol path (passive
                             // overlay applied by scoreboard, not here)
} ei_kind_e;

class state_item extends uvm_sequence_item;
    `uvm_object_utils(state_item)

    rand ei_kind_e    kind;
    rand bit  [32:0]  scr_val;
    rand bit  [2:0]   cs_val;
    rand bit          srev_val;
    rand int unsigned hold_cycles;
    rand int unsigned pre_delay;

    constraint c_default {
        soft hold_cycles inside {[1:8]};
        soft pre_delay   inside {[0:32]};
    }

    function new(string name = "state_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("EI kind=%s pre=%0d hold=%0d cs=%0d scr=0x%09h srev=%0b",
                         kind.name(), pre_delay, hold_cycles, cs_val, scr_val, srev_val);
    endfunction

endclass : state_item
