// =============================================================================
// pcs_tx_scoreboard.sv
//
// Cycle-accurate predictor + checker for the 1000BASE-T TX PCS encoder.
//
//   GMII items  -->  golden model step()  -->  expected PAM5 quartet
//                                                     |
//   PAM5 items (DUT)  -------- compared against ------+
//
// Error-injection events from the state_agent are intercepted via
// state_export and used to re-sync the golden model to whatever
// override the driver applied. This keeps the scoreboard from raising
// false positives during a deliberately corrupted run, while still
// allowing it to flag real, unexpected mismatches.
//
// Statistics tracked:
//   - sym_compares       : total quartets checked
//   - sym_mismatches     : quartets that disagreed with the golden model
//   - injection_count    : number of injection events received
//   - last_mismatch_time : $time of the most recent mismatch
// =============================================================================

`uvm_analysis_imp_decl(_gmii)
`uvm_analysis_imp_decl(_pam5)
`uvm_analysis_imp_decl(_state)

class pcs_tx_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(pcs_tx_scoreboard)

    // Analysis exports
    uvm_analysis_imp_gmii  #(gmii_tx_item, pcs_tx_scoreboard) gmii_export;
    uvm_analysis_imp_pam5  #(pam5_item,    pcs_tx_scoreboard) pam5_export;
    uvm_analysis_imp_state #(state_item,   pcs_tx_scoreboard) state_export;

    // Reference model
    pcs_tx_golden_model golden;

    // Pipeline FIFO of expected outputs that have not yet been compared.
    // Depth >= modelled DUT pipeline depth.
    int unsigned  pipeline_depth = 4;
    int           expq_an[$], expq_bn[$], expq_cn[$], expq_dn[$];

    // Error-injection bookkeeping.
    bit  injection_active;
    int  injection_grace_cycles;   // ignore mismatches for this many quartets

    // Stats
    int unsigned sym_compares;
    int unsigned sym_mismatches;
    int unsigned injection_count;
    time         last_mismatch_time;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        gmii_export  = new("gmii_export",  this);
        pam5_export  = new("pam5_export",  this);
        state_export = new("state_export", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        golden = pcs_tx_golden_model::type_id::create("golden");
        void'(uvm_config_db#(int unsigned)::get(this, "", "pipeline_depth", pipeline_depth));
    endfunction

    // ------------------------------------------------------------------------
    // GMII input -> step the golden model and queue expected output
    // ------------------------------------------------------------------------
    virtual function void write_gmii(gmii_tx_item tr);
        int an, bn, cn, dn;
        bit valid;
        golden.step(tr.txd, tr.tx_en, tr.tx_er, an, bn, cn, dn, valid);
        expq_an.push_back(an);
        expq_bn.push_back(bn);
        expq_cn.push_back(cn);
        expq_dn.push_back(dn);
    endfunction

    // ------------------------------------------------------------------------
    // PAM5 output -> dequeue expected and compare
    // ------------------------------------------------------------------------
    virtual function void write_pam5(pam5_item tr);
        int eA, eB, eC, eD;
        if (!tr.valid) return;
        if (expq_an.size() == 0) begin
            `uvm_warning("SCB", $sformatf(
                "DUT produced PAM5 quartet with no pending expected: %s",
                tr.convert2string()))
            return;
        end
        eA = expq_an.pop_front();
        eB = expq_bn.pop_front();
        eC = expq_cn.pop_front();
        eD = expq_dn.pop_front();
        sym_compares++;

        // If we are inside an injection grace window, swallow mismatches
        // and re-align the golden model to the DUT's observed white-box
        // state on the way out.
        if (injection_grace_cycles > 0) begin
            injection_grace_cycles--;
            golden.load_state(tr.scr_n, tr.cs_n, tr.srev_n);
            return;
        end

        if ((eA != tr.an) || (eB != tr.bn) ||
            (eC != tr.cn) || (eD != tr.dn)) begin
            sym_mismatches++;
            last_mismatch_time = $time;
            `uvm_error("SCB", $sformatf(
                "PAM5 mismatch:\n  expected [A=%0d B=%0d C=%0d D=%0d]\n  got      [A=%0d B=%0d C=%0d D=%0d]\n  probes  cs=%0d srev=%0b sd=0x%03h scr=0x%09h",
                eA, eB, eC, eD,
                tr.an, tr.bn, tr.cn, tr.dn,
                tr.cs_n, tr.srev_n, tr.sd_n, tr.scr_n))
        end
    endfunction

    // ------------------------------------------------------------------------
    // Error-injection notifications. Open a grace window so the model can
    // resync to whatever the driver overrode.
    // ------------------------------------------------------------------------
    virtual function void write_state(state_item tr);
        injection_count++;
        case (tr.kind)
            EI_FORCE_CS, EI_FORCE_SCR, EI_FORCE_SREV: begin
                injection_grace_cycles = tr.hold_cycles + pipeline_depth + 2;
                `uvm_info("SCB", $sformatf(
                    "Injection: %s -> grace window = %0d quartets",
                    tr.kind.name(), injection_grace_cycles), UVM_MEDIUM)
            end
            EI_BITFLIP: begin
                // Bit-flip injection is observed at the DUT output. We do NOT
                // open a grace window: the scoreboard SHOULD flag it.
                `uvm_info("SCB",
                    "Injection: BITFLIP - expecting scoreboard to fire", UVM_MEDIUM)
            end
            default: ;
        endcase
    endfunction

    // ------------------------------------------------------------------------
    // End-of-test report
    // ------------------------------------------------------------------------
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SCB_REPORT", $sformatf(
            "\n  --- PCS TX scoreboard summary ---\n  compares    = %0d\n  mismatches  = %0d\n  injections  = %0d\n  last fail @ %0t",
            sym_compares, sym_mismatches, injection_count, last_mismatch_time),
            UVM_NONE)
    endfunction

endclass : pcs_tx_scoreboard
