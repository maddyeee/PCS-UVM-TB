// =============================================================================
// error_inject_seq.sv
//
// Family of sequences that drive the state_agent to corrupt internal
// encoder state (cs_n, scr_n, srev_n). The scoreboard opens a grace
// window in response, so these tests verify two things:
//
//   1. The DUT recovers/handles the corruption without locking up.
//   2. Coverage of error_kind bins is closed.
//
// To verify that the scoreboard ITSELF can catch errors, use the
// EI_BITFLIP variant: that sequence does not open a grace window, so any
// resulting symbol mismatch should fire an `uvm_error`. Tests that want
// to confirm scoreboard liveness should expect_error and pass when at
// least one mismatch is reported.
// =============================================================================

class error_inject_seq extends uvm_sequence #(state_item);
    `uvm_object_utils(error_inject_seq)

    rand ei_kind_e    kind;
    rand int unsigned num_injections;
    constraint c_d { soft num_injections inside {[1:5]}; }

    function new(string name = "error_inject_seq");
        super.new(name);
    endfunction

    task body();
        repeat (num_injections) begin
            `uvm_do_with(req, { req.kind        == local::kind;
                                req.hold_cycles inside {[1:6]};
                                req.pre_delay   inside {[10:60]}; })
        end
    endtask

endclass : error_inject_seq

// ----- Convenience wrappers per kind ----------------------------------------
class error_inject_cs_seq extends error_inject_seq;
    `uvm_object_utils(error_inject_cs_seq)
    function new(string name = "error_inject_cs_seq");
        super.new(name);
        kind = EI_FORCE_CS;
    endfunction
endclass

class error_inject_scr_seq extends error_inject_seq;
    `uvm_object_utils(error_inject_scr_seq)
    function new(string name = "error_inject_scr_seq");
        super.new(name);
        kind = EI_FORCE_SCR;
    endfunction
endclass

class error_inject_srev_seq extends error_inject_seq;
    `uvm_object_utils(error_inject_srev_seq)
    function new(string name = "error_inject_srev_seq");
        super.new(name);
        kind = EI_FORCE_SREV;
    endfunction
endclass

class error_inject_bitflip_seq extends error_inject_seq;
    `uvm_object_utils(error_inject_bitflip_seq)
    function new(string name = "error_inject_bitflip_seq");
        super.new(name);
        kind = EI_BITFLIP;
    endfunction
endclass
