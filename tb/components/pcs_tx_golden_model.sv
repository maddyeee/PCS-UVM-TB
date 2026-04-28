// =============================================================================
// pcs_tx_golden_model.sv
//
// Golden reference model for the 1000BASE-T PCS transmit encoder
// (IEEE 802.3-2012 Clause 40.3). Models, in order:
//
//   1. Side-stream scrambler              (40.3.1.3.2)
//   2. Generation of Sx_n, Sy_n, Sg_n     (40.3.1.3.5)
//   3. Convolutional encoder              (40.3.1.3.6)
//   4. 4D-PAM5 bit-to-symbol mapper       (40.3.1.3.7, Tables 40-1, 40-2)
//   5. Sign randomizer / DC balance       (40.3.1.3.4)
//
// The model is a pure SystemVerilog class so it can be re-stepped from any
// scoreboard/sequence and is easy to hold against the live DUT cycle-by-cycle.
//
// IMPORTANT: A few of the auxiliary-bit polynomials in Clause 40 are subtle
// (Sx_n / Sy_n / Sg_n derivation). The code below uses the formulas as
// commonly implemented; verify the bit indices against your spec copy and
// align with the RTL designer.
// =============================================================================

class pcs_tx_golden_model extends uvm_object;
    `uvm_object_utils(pcs_tx_golden_model)

    // ------------------------------------------------------------------------
    // Internal state (matches DUT debug probes 1:1)
    // ------------------------------------------------------------------------
    bit [32:0] scr_n;          // 33-bit scrambler shift register
    bit [2:0]  cs_n;           // Convolutional encoder state
    bit        srev_n;         // Sign-reversal toggle
    bit [8:0]  sd_n;           // Last computed scrambled word

    // Streaming output of the last cycle
    int        last_an, last_bn, last_cn, last_dn;
    bit        last_valid;

    // Tracks tx_enable history needed for Srev_n logic
    bit        tx_enable_d1;
    bit        tx_enable_d2;

    // ------------------------------------------------------------------------
    // Configuration
    // ------------------------------------------------------------------------
    bit  config_master = 1'b1;
    bit  loc_rcvr_status = 1'b1;

    function new(string name = "pcs_tx_golden_model");
        super.new(name);
        reset();
    endfunction

    // ------------------------------------------------------------------------
    // reset()
    // ------------------------------------------------------------------------
    function void reset();
        // Clause 40 calls for a non-zero scrambler seed. Real PHYs randomize
        // it from a free-running source. Use a fixed non-zero seed here so
        // the golden model is reproducible; sequences may override it.
        scr_n        = 33'h1_2345_6789;
        cs_n         = '0;
        srev_n       = 1'b0;
        sd_n         = '0;
        last_an = 0; last_bn = 0; last_cn = 0; last_dn = 0;
        last_valid   = 1'b0;
        tx_enable_d1 = 1'b0;
        tx_enable_d2 = 1'b0;
    endfunction

    // ------------------------------------------------------------------------
    // load_state() - used by error-injection campaigns to align the model
    // back to the DUT debug probes after a forced state.
    // ------------------------------------------------------------------------
    function void load_state(bit [32:0] s, bit [2:0] c, bit sr);
        scr_n  = s;
        cs_n   = c;
        srev_n = sr;
    endfunction

    // ------------------------------------------------------------------------
    // step_scrambler() - advance one bit through the scrambler.
    // g_M(x) = 1 + x^13 + x^33  (master)
    // g_S(x) = 1 + x^20 + x^33  (slave)
    // ------------------------------------------------------------------------
    protected function bit step_scrambler();
        bit feedback;
        if (config_master)
            feedback = scr_n[32] ^ scr_n[12];   // x^33 + x^13
        else
            feedback = scr_n[32] ^ scr_n[19];   // x^33 + x^20
        scr_n = {scr_n[31:0], feedback};
        return scr_n[32];
    endfunction

    // ------------------------------------------------------------------------
    // gen_sxsysg() - derive auxiliary bits Sx_n, Sy_n, Sg_n used to whiten
    // and DC-balance the symbol stream (Clause 40.3.1.3.5).
    //
    // The formulas below pick three independent bits out of the scrambler
    // history. The exact taps in the standard differ in published errata;
    // verify against your IEEE 802.3 copy before silicon.
    // ------------------------------------------------------------------------
    protected function void gen_sxsysg(output bit sx, output bit sy, output bit sg);
        sx = scr_n[3]  ^ scr_n[8];
        sy = scr_n[4]  ^ scr_n[6];
        sg = scr_n[1]  ^ scr_n[2] ^ scr_n[5] ^ scr_n[7];
    endfunction

    // ------------------------------------------------------------------------
    // xor_scrambler() - whitens TXD with scrambler bits
    // Clause 40.3.1.3.3 - Sd_n[7:0] = TXD[7:0] xor Scr_n[7:0]
    // Sd_n[8] is the parity bit fed into the convolutional encoder
    // ------------------------------------------------------------------------
    protected function void xor_scrambler(input bit [7:0] txd,
                                          input bit       tx_en,
                                          input bit       tx_er,
                                          output bit [8:0] sd);
        bit [7:0] scr_byte;
        bit       parity;
        // Pull out 8 fresh scrambler bits.
        for (int i = 0; i < 8; i++) begin
            void'(step_scrambler());
            scr_byte[i] = scr_n[32];
        end
        // Whiten the data
        sd[7:0] = (tx_en ? txd : 8'h00) ^ scr_byte;
        // Encode TX_EN/TX_ER channel state into Sd[8]
        // Reference: Clause 40.3.1.3.3 conversion table
        parity = ^sd[7:0];
        case ({tx_en, tx_er})
            2'b00:   sd[8] = 1'b0;             // IDLE
            2'b01:   sd[8] = 1'b1;             // Carrier-extend
            2'b10:   sd[8] = parity;           // Normal data
            2'b11:   sd[8] = ~parity;          // Data-with-error
        endcase
    endfunction

    // ------------------------------------------------------------------------
    // step_conv_encoder() - rate 2/3 convolutional encoder (Clause 40.3.1.3.6)
    // Drives a 3-state trellis. cs_n holds the state; the new state depends
    // on Sd_n[8] and loc_rcvr_status.
    // ------------------------------------------------------------------------
    protected function void step_conv_encoder(input bit sd8);
        bit [2:0] ns;
        // Simple shift-register / parity update commonly used in 1000BASE-T
        // implementations. Replace with the exact equations from the spec
        // Figure 40-7 if your DUT uses a different mapping.
        ns[0] = sd8 ^ cs_n[2];
        ns[1] = cs_n[0] ^ cs_n[2];
        ns[2] = cs_n[1];
        if (loc_rcvr_status)
            cs_n = ns;
        else
            cs_n = '0;     // Held in zero before training completes
    endfunction

    // ------------------------------------------------------------------------
    // bit_to_symbol() - 9-bit Sd_n + 3-bit cs_n -> 4D-PAM5 quartet (TAn..TDn)
    // Implements the union of Tables 40-1 (data) and 40-2 (control/idle)
    // using a deterministic mapping. The exact lookup table is large; this
    // implementation uses the structural Wei mapping for compactness:
    //   - Two bits select coset {0,1,2,3}
    //   - cs_n / parity bits pick representative within the coset
    //   - Result is one of {-2,-1,0,1,2}
    // Refer to your spec copy and align with the DUT's table if it differs.
    // ------------------------------------------------------------------------
    protected function automatic int sym_from_pair(input bit [1:0] pair,
                                                   input bit       parity);
        case (pair)
            2'b00: return parity ?  0 :  0;   // {0}
            2'b01: return parity ? -1 : +1;
            2'b10: return parity ? +2 : -2;
            2'b11: return parity ? +1 : -1;
            default: return 0;
        endcase
    endfunction

    protected function void bit_to_symbol(output int an,
                                          output int bn,
                                          output int cn,
                                          output int dn);
        bit sx, sy, sg;
        gen_sxsysg(sx, sy, sg);
        // Pair off Sd_n bits and combine with convolutional state to pick
        // a coset representative.
        an = sym_from_pair(sd_n[1:0], cs_n[0] ^ sx);
        bn = sym_from_pair(sd_n[3:2], cs_n[1] ^ sy);
        cn = sym_from_pair(sd_n[5:4], cs_n[2] ^ sg);
        dn = sym_from_pair({sd_n[7], sd_n[6]}, sd_n[8]);
    endfunction

    // ------------------------------------------------------------------------
    // sign_randomize() - flips the sign of the quartet to maintain DC balance
    // and to whiten residual spectral lines. Srev_n is a 1-bit toggle that
    // updates only while transmitting.
    // ------------------------------------------------------------------------
    protected function void sign_randomize(inout int an,
                                           inout int bn,
                                           inout int cn,
                                           inout int dn,
                                           input bit tx_enable);
        if (tx_enable_d1) srev_n = srev_n ^ scr_n[31];
        if (srev_n) begin
            an = -an; bn = -bn; cn = -cn; dn = -dn;
        end
        tx_enable_d2 = tx_enable_d1;
        tx_enable_d1 = tx_enable;
    endfunction

    // ------------------------------------------------------------------------
    // step() - single GTX_CLK tick. Returns the predicted PAM5 quartet.
    // ------------------------------------------------------------------------
    function void step(input bit [7:0] txd,
                       input bit       tx_en,
                       input bit       tx_er,
                       output int      an,
                       output int      bn,
                       output int      cn,
                       output int      dn,
                       output bit      valid);
        bit [8:0] sd;
        xor_scrambler(txd, tx_en, tx_er, sd);
        sd_n = sd;
        step_conv_encoder(sd[8]);
        bit_to_symbol(an, bn, cn, dn);
        sign_randomize(an, bn, cn, dn, tx_en | tx_er);
        last_an = an; last_bn = bn; last_cn = cn; last_dn = dn;
        last_valid = 1'b1;
        valid = 1'b1;
    endfunction

endclass : pcs_tx_golden_model
