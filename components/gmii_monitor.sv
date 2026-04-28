// =============================================================================
// gmii_monitor.sv
// Samples GMII inputs every GTX_CLK and broadcasts a transaction to the
// scoreboard / golden model.
// =============================================================================

class gmii_monitor extends uvm_monitor;
    `uvm_component_utils(gmii_monitor)

    virtual pcs_tx_if vif;
    uvm_analysis_port #(gmii_tx_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual pcs_tx_if)::get(this, "", "vif", vif))
            `uvm_fatal("GMII_MON", "Could not get virtual interface 'vif'")
    endfunction

    task run_phase(uvm_phase phase);
        @(posedge vif.rst_n);
        forever begin
            gmii_tx_item tr;
            @(vif.gmii_mon_cb);
            tr = gmii_tx_item::type_id::create("tr");
            tr.txd       = vif.gmii_mon_cb.txd;
            tr.tx_en     = vif.gmii_mon_cb.tx_en;
            tr.tx_er     = vif.gmii_mon_cb.tx_er;
            tr.pre_delay = 0;
            ap.write(tr);
        end
    endtask

endclass : gmii_monitor
