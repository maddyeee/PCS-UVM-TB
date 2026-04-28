// =============================================================================
// gmii_agent.sv
// =============================================================================

class gmii_agent extends uvm_agent;
    `uvm_component_utils(gmii_agent)

    gmii_sequencer  sqr;
    gmii_driver     drv;
    gmii_monitor    mon;

    uvm_analysis_port #(gmii_tx_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = gmii_monitor::type_id::create("mon", this);
        if (get_is_active() == UVM_ACTIVE) begin
            sqr = gmii_sequencer::type_id::create("sqr", this);
            drv = gmii_driver  ::type_id::create("drv", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        mon.ap.connect(ap);
        if (get_is_active() == UVM_ACTIVE)
            drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction

endclass : gmii_agent
