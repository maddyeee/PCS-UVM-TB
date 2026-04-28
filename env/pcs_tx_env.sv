// =============================================================================
// pcs_tx_env.sv
//
// Top-level environment.  Wires the three agents (GMII input, PAM5 output,
// state-injection) into the scoreboard and coverage collector exactly as
// shown in the architecture diagram.
// =============================================================================

class pcs_tx_env extends uvm_env;
    `uvm_component_utils(pcs_tx_env)

    gmii_agent          gmii_agt;
    pam5_agent          pam5_agt;
    state_agent         state_agt;

    pcs_tx_scoreboard   sb;
    pcs_tx_coverage     cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        gmii_agt  = gmii_agent       ::type_id::create("gmii_agt",  this);
        pam5_agt  = pam5_agent       ::type_id::create("pam5_agt",  this);
        state_agt = state_agent      ::type_id::create("state_agt", this);
        sb        = pcs_tx_scoreboard::type_id::create("sb",        this);
        cov       = pcs_tx_coverage  ::type_id::create("cov",       this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // Scoreboard hookups
        gmii_agt .ap.connect(sb.gmii_export);
        pam5_agt .ap.connect(sb.pam5_export);
        state_agt.ap.connect(sb.state_export);

        // Coverage hookups
        gmii_agt .ap.connect(cov.gmii_export);
        pam5_agt .ap.connect(cov.analysis_export);  // uvm_subscriber
        state_agt.ap.connect(cov.state_export);
    endfunction

endclass : pcs_tx_env
