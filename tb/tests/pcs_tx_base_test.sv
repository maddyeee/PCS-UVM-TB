// =============================================================================
// pcs_tx_base_test.sv
// =============================================================================

class pcs_tx_base_test extends uvm_test;
    `uvm_component_utils(pcs_tx_base_test)

    pcs_tx_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = pcs_tx_env::type_id::create("env", this);
        // Default verbosity
        uvm_top.set_report_verbosity_level_hier(UVM_LOW);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction

    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        // Subclasses extend this. The default base test just lets the
        // simulator run for a small window so reset settles.
        phase.raise_objection(this);
        #200ns;
        phase.drop_objection(this);
    endtask

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        uvm_report_server srv = uvm_report_server::get_server();
        if (srv.get_severity_count(UVM_FATAL) > 0 ||
            srv.get_severity_count(UVM_ERROR) > 0)
            `uvm_info("RESULT", "TEST FAILED", UVM_NONE)
        else
            `uvm_info("RESULT", "TEST PASSED", UVM_NONE)
    endfunction

endclass : pcs_tx_base_test
