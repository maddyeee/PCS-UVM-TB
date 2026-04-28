// =============================================================================
// pam5_item.sv
// One sample of the 4D-PAM5 transmit output, plus the white-box state probes
// captured on the same cycle.
// =============================================================================

class pam5_item extends uvm_sequence_item;
    `uvm_object_utils(pam5_item)

    int   an, bn, cn, dn;        // Quinary symbols, signed -2..+2
    bit   valid;

    bit [32:0] scr_n;
    bit  [2:0] cs_n;
    bit        srev_n;
    bit  [8:0] sd_n;

    function new(string name = "pam5_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("PAM5 [A=%0d B=%0d C=%0d D=%0d] valid=%0b cs=%0d srev=%0b sd=0x%03h",
                         an, bn, cn, dn, valid, cs_n, srev_n, sd_n);
    endfunction

endclass : pam5_item
