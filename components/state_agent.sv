// =============================================================================
// state_agent.sv
// Active agent that injects faults into the encoder via the force_* hooks.
// =============================================================================

class state_agent extends uvm_agent;
    `uvm_component_utils(state_agent)

    state_sequencer sqr;
    state_driver    drv;

    uvm_analysis_port #(state_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (get_is_active() == UVM_ACTIVE) begin
            sqr = state_sequencer::type_id::create("sqr", this);
            drv = state_driver   ::type_id::create("drv", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE) begin
            drv.seq_item_port.connect(sqr.seq_item_export);
            drv.ap.connect(ap);
        end
    endfunction

endclass : state_agent
