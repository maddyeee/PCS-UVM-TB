// =============================================================================
// state_driver.sv
// Drives the force_* override signals on pcs_tx_if to corrupt internal
// encoder state. Used by error-injection sequences.
//
// Each state_item asserts the corresponding force_*_en signal for
// hold_cycles GTX_CLK ticks, then deasserts it. This lets the verification
// engineer model both transient glitches and stuck-faults.
//
// Whenever an injection is performed, the driver also broadcasts the item
// on its analysis port so the scoreboard can re-sync its golden model
// against the new internal state instead of flagging false mismatches.
// =============================================================================

class state_driver extends uvm_driver #(state_item);
    `uvm_component_utils(state_driver)

    virtual pcs_tx_if vif;

    uvm_analysis_port #(state_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual pcs_tx_if)::get(this, "", "vif", vif))
            `uvm_fatal("STATE_DRV", "Could not get virtual interface 'vif'")
    endfunction

    task run_phase(uvm_phase phase);
        // Park the force signals
        vif.err_inj_cb.force_cs_en    <= 1'b0;
        vif.err_inj_cb.force_cs_val   <= '0;
        vif.err_inj_cb.force_scr_en   <= 1'b0;
        vif.err_inj_cb.force_scr_val  <= '0;
        vif.err_inj_cb.force_srev_en  <= 1'b0;
        vif.err_inj_cb.force_srev_val <= 1'b0;

        @(posedge vif.rst_n);
        forever begin
            state_item tr;
            seq_item_port.get_next_item(tr);
            repeat (tr.pre_delay) @(vif.err_inj_cb);

            case (tr.kind)
                EI_FORCE_CS: begin
                    vif.err_inj_cb.force_cs_en  <= 1'b1;
                    vif.err_inj_cb.force_cs_val <= tr.cs_val;
                    repeat (tr.hold_cycles) @(vif.err_inj_cb);
                    vif.err_inj_cb.force_cs_en  <= 1'b0;
                end
                EI_FORCE_SCR: begin
                    vif.err_inj_cb.force_scr_en  <= 1'b1;
                    vif.err_inj_cb.force_scr_val <= tr.scr_val;
                    repeat (tr.hold_cycles) @(vif.err_inj_cb);
                    vif.err_inj_cb.force_scr_en  <= 1'b0;
                end
                EI_FORCE_SREV: begin
                    vif.err_inj_cb.force_srev_en  <= 1'b1;
                    vif.err_inj_cb.force_srev_val <= tr.srev_val;
                    repeat (tr.hold_cycles) @(vif.err_inj_cb);
                    vif.err_inj_cb.force_srev_en  <= 1'b0;
                end
                EI_BITFLIP, EI_NONE: begin
                    // Pure scoreboard-side overlay: nothing to drive here.
                    // Just consume the pre_delay and announce.
                end
                default: ;
            endcase

            ap.write(tr);
            seq_item_port.item_done();
            `uvm_info("STATE_DRV", tr.convert2string(), UVM_MEDIUM)
        end
    endtask

endclass : state_driver
