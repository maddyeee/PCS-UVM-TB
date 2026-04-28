// =============================================================================
// pcs_tx_coverage.sv
//
// Functional coverage collector for the 1000BASE-T TX PCS encoder.
// Subscribes to the same analysis ports as the scoreboard and samples
// covergroups for input traffic, output symbol distribution, internal
// trellis states, and injected error categories.
// =============================================================================

`uvm_analysis_imp_decl(_cov_gmii)
`uvm_analysis_imp_decl(_cov_pam5)
`uvm_analysis_imp_decl(_cov_state)

class pcs_tx_coverage extends uvm_subscriber #(pam5_item);
    `uvm_component_utils(pcs_tx_coverage)

    uvm_analysis_imp_cov_gmii  #(gmii_tx_item, pcs_tx_coverage) gmii_export;
    uvm_analysis_imp_cov_state #(state_item,   pcs_tx_coverage) state_export;

    // ------------------------------------------------------------------------
    // Sampling registers (covergroups can only sample class members)
    // ------------------------------------------------------------------------
    bit [7:0] cov_txd;
    bit       cov_tx_en;
    bit       cov_tx_er;

    int       cov_an, cov_bn, cov_cn, cov_dn;
    bit [2:0] cov_cs_n;
    bit       cov_srev;

    ei_kind_e cov_ei_kind;

    // ------------------------------------------------------------------------
    // Covergroups
    // ------------------------------------------------------------------------
    covergroup cg_gmii;
        option.per_instance = 1;
        cp_txd      : coverpoint cov_txd {
            bins low   = {[8'h00:8'h3F]};
            bins mid   = {[8'h40:8'hBF]};
            bins high  = {[8'hC0:8'hFF]};
        }
        cp_ctrl     : coverpoint {cov_tx_en, cov_tx_er} {
            bins idle    = {2'b00};
            bins data    = {2'b10};
            bins ext     = {2'b01};
            bins err     = {2'b11};
        }
        cross_txd_ctrl : cross cp_txd, cp_ctrl;
    endgroup

    covergroup cg_pam5;
        option.per_instance = 1;
        cp_a : coverpoint cov_an { bins v[] = {-2,-1,0,1,2}; }
        cp_b : coverpoint cov_bn { bins v[] = {-2,-1,0,1,2}; }
        cp_c : coverpoint cov_cn { bins v[] = {-2,-1,0,1,2}; }
        cp_d : coverpoint cov_dn { bins v[] = {-2,-1,0,1,2}; }
        cp_cs    : coverpoint cov_cs_n;
        cp_srev  : coverpoint cov_srev;
        cross_a_b : cross cp_a, cp_b;
        cross_c_d : cross cp_c, cp_d;
        cross_cs_srev : cross cp_cs, cp_srev;
    endgroup

    covergroup cg_errinj;
        option.per_instance = 1;
        cp_kind : coverpoint cov_ei_kind {
            bins force_cs   = {EI_FORCE_CS};
            bins force_scr  = {EI_FORCE_SCR};
            bins force_srev = {EI_FORCE_SREV};
            bins bitflip    = {EI_BITFLIP};
        }
    endgroup

    // ------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
        gmii_export  = new("gmii_export",  this);
        state_export = new("state_export", this);
        cg_gmii   = new();
        cg_pam5   = new();
        cg_errinj = new();
    endfunction

    // PAM5 sampling lives in `write` (uvm_subscriber).
    virtual function void write(pam5_item t);
        if (!t.valid) return;
        cov_an   = t.an;
        cov_bn   = t.bn;
        cov_cn   = t.cn;
        cov_dn   = t.dn;
        cov_cs_n = t.cs_n;
        cov_srev = t.srev_n;
        cg_pam5.sample();
    endfunction

    function void write_cov_gmii(gmii_tx_item t);
        cov_txd   = t.txd;
        cov_tx_en = t.tx_en;
        cov_tx_er = t.tx_er;
        cg_gmii.sample();
    endfunction

    function void write_cov_state(state_item t);
        cov_ei_kind = t.kind;
        cg_errinj.sample();
    endfunction

endclass : pcs_tx_coverage
