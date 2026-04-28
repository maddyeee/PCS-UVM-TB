// =============================================================================
// pam5_monitor.sv
// Samples the 4D-PAM5 outputs + debug probes every GTX_CLK and writes a
// pam5_item to the analysis port.
// =============================================================================

class pam5_monitor extends uvm_monitor;
    `uvm_component_utils(pam5_monitor)

    virtual pcs_tx_if vif;
    uvm_analysis_port #(pam5_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual pcs_tx_if)::get(this, "", "vif", vif))
            `uvm_fatal("PAM5_MON", "Could not get virtual interface 'vif'")
    endfunction

    task run_phase(uvm_phase phase);
        @(posedge vif.rst_n);
        forever begin
            pam5_item tr;
            @(vif.pam5_mon_cb);
            tr = pam5_item::type_id::create("tr");
            tr.an     = vif.pam5_mon_cb.tx_an;
            tr.bn     = vif.pam5_mon_cb.tx_bn;
            tr.cn     = vif.pam5_mon_cb.tx_cn;
            tr.dn     = vif.pam5_mon_cb.tx_dn;
            tr.valid  = vif.pam5_mon_cb.tx_sym_valid;
            tr.scr_n  = vif.pam5_mon_cb.dbg_scr_n;
            tr.cs_n   = vif.pam5_mon_cb.dbg_cs_n;
            tr.srev_n = vif.pam5_mon_cb.dbg_srev_n;
            tr.sd_n   = vif.pam5_mon_cb.dbg_sd_n;
            ap.write(tr);
        end
    endtask

endclass : pam5_monitor
