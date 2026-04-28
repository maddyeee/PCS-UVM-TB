// =============================================================================
// pam5_agent.sv
// Passive agent: only monitors the PAM5 outputs.
// =============================================================================

class pam5_agent extends uvm_agent;
    `uvm_component_utils(pam5_agent)

    pam5_monitor mon;
    uvm_analysis_port #(pam5_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        // Hard-wire passive BEFORE calling super so get_is_active() agrees.
        is_active = UVM_PASSIVE;
        super.build_phase(phase);
        mon = pam5_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        mon.ap.connect(ap);
    endfunction

endclass : pam5_agent
