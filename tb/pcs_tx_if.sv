// =============================================================================
// pcs_tx_if.sv
// 1000BASE-T PCS Transmit Encoder Verification Interface
//
// Carries the GMII input side, the 4D-PAM5 output side, and a debug bundle
// of internal state probes (cs_n, Scr_n, Srev_n) used by the verification
// environment for white-box checking and error injection.
// -----------------------------------------------------------------------------
// Spec reference: IEEE Std 802.3-2012 Clause 40 (1000BASE-T PCS)
// =============================================================================

interface pcs_tx_if (input logic gtx_clk, input logic rst_n);

    // ----- GMII transmit (input) side ---------------------------------------
    logic [7:0] txd;
    logic       tx_en;
    logic       tx_er;

    // PHY config
    logic       config_master;     // 1 = master polynomial, 0 = slave
    logic       loc_rcvr_status;   // From PHY, drives convolutional encoder

    // ----- 4D-PAM5 transmit (output) side -----------------------------------
    // Quinary symbols: legal values are -2, -1, 0, +1, +2
    // Sized as signed [2:0] for safe two's-complement carry of -2..+2.
    logic signed [2:0] tx_an;
    logic signed [2:0] tx_bn;
    logic signed [2:0] tx_cn;
    logic signed [2:0] tx_dn;
    logic              tx_sym_valid;  // qualifies one quartet per 8 ns

    // ----- Internal state probes (white-box) --------------------------------
    // These are probed via the bind/hierarchical reference style. The DUT
    // designer must expose them. They also serve as drive points for error
    // injection sequences.
    logic [32:0] dbg_scr_n;     // Scrambler shift register
    logic  [2:0] dbg_cs_n;      // Convolutional encoder state
    logic        dbg_srev_n;    // Sign-reversal toggle (Srev_n)
    logic  [8:0] dbg_sd_n;      // 9-bit scrambled word into bit-to-symbol mapper

    // Force-enable signals - asserted by error_inject driver to override
    // internal state for fault campaigns.
    logic        force_cs_en;
    logic  [2:0] force_cs_val;
    logic        force_scr_en;
    logic [32:0] force_scr_val;
    logic        force_srev_en;
    logic        force_srev_val;

    // ------------------------------------------------------------------------
    // Clocking blocks
    // ------------------------------------------------------------------------
    clocking gmii_drv_cb @(posedge gtx_clk);
        default input #1ns output #1ns;
        output txd, tx_en, tx_er, config_master, loc_rcvr_status;
    endclocking

    clocking gmii_mon_cb @(posedge gtx_clk);
        default input #1ns;
        input txd, tx_en, tx_er, config_master, loc_rcvr_status;
    endclocking

    clocking pam5_mon_cb @(posedge gtx_clk);
        default input #1ns;
        input tx_an, tx_bn, tx_cn, tx_dn, tx_sym_valid;
        input dbg_scr_n, dbg_cs_n, dbg_srev_n, dbg_sd_n;
    endclocking

    clocking err_inj_cb @(posedge gtx_clk);
        default output #1ns;
        output force_cs_en, force_cs_val;
        output force_scr_en, force_scr_val;
        output force_srev_en, force_srev_val;
    endclocking

    // ------------------------------------------------------------------------
    // Modports
    // ------------------------------------------------------------------------
    modport gmii_drv (clocking gmii_drv_cb, input gtx_clk, rst_n);
    modport gmii_mon (clocking gmii_mon_cb, input gtx_clk, rst_n);
    modport pam5_mon (clocking pam5_mon_cb, input gtx_clk, rst_n);
    modport err_inj  (clocking err_inj_cb,  input gtx_clk, rst_n);

    // ------------------------------------------------------------------------
    // Asserts (sanity) - quinary symbol must be in {-2,-1,0,1,2}
    // ------------------------------------------------------------------------
    // synthesis translate_off
    property p_legal_symbol(sig);
        @(posedge gtx_clk) disable iff (!rst_n)
            tx_sym_valid |-> (sig inside {-2,-1,0,1,2});
    endproperty
    a_an_legal: assert property (p_legal_symbol(tx_an))
        else $error("[PCS_TX_IF] Illegal An symbol: %0d", tx_an);
    a_bn_legal: assert property (p_legal_symbol(tx_bn))
        else $error("[PCS_TX_IF] Illegal Bn symbol: %0d", tx_bn);
    a_cn_legal: assert property (p_legal_symbol(tx_cn))
        else $error("[PCS_TX_IF] Illegal Cn symbol: %0d", tx_cn);
    a_dn_legal: assert property (p_legal_symbol(tx_dn))
        else $error("[PCS_TX_IF] Illegal Dn symbol: %0d", tx_dn);
    // synthesis translate_on

endinterface : pcs_tx_if
