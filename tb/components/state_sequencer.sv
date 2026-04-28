// =============================================================================
// state_sequencer.sv
// =============================================================================

class state_sequencer extends uvm_sequencer #(state_item);
    `uvm_component_utils(state_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass : state_sequencer
