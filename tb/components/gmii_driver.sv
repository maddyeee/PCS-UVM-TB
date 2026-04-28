// =============================================================================
// gmii_driver.sv
// Drives one GMII item per GTX_CLK cycle into pcs_tx_if.gmii_drv.
// =============================================================================

class gmii_driver extends uvm_driver #(gmii_tx_item);
    `uvm_component_utils(gmii_driver)

    virtual pcs_tx_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual pcs_tx_if)::get(this, "", "vif", vif))
            `uvm_fatal("GMII_DRV", "Could not get virtual interface 'vif'")
    endfunction

    task run_phase(uvm_phase phase);
        // Idle defaults
        vif.gmii_drv_cb.txd             <= '0;
        vif.gmii_drv_cb.tx_en           <= 1'b0;
        vif.gmii_drv_cb.tx_er           <= 1'b0;
        vif.gmii_drv_cb.config_master   <= 1'b1;
        vif.gmii_drv_cb.loc_rcvr_status <= 1'b1;

        @(posedge vif.rst_n);
        forever begin
            gmii_tx_item tr;
            seq_item_port.get_next_item(tr);
            repeat (tr.pre_delay) @(vif.gmii_drv_cb);
            vif.gmii_drv_cb.txd   <= tr.txd;
            vif.gmii_drv_cb.tx_en <= tr.tx_en;
            vif.gmii_drv_cb.tx_er <= tr.tx_er;
            @(vif.gmii_drv_cb);
            seq_item_port.item_done();
            `uvm_info("GMII_DRV", tr.convert2string(), UVM_HIGH)
        end
    endtask

endclass : gmii_driver
