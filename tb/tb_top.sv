// =============================================================================
// tb_top.sv
// Top-level testbench module: clock/reset, DUT, interface, UVM run_test.
// =============================================================================

`timescale 1ns/1ps

module tb_top;

    import uvm_pkg::*;
    import pcs_tx_pkg::*;
    `include "uvm_macros.svh"

    // 125 MHz GTX_CLK (8 ns period) for 1000BASE-T
    logic gtx_clk = 1'b0;
    always #4ns gtx_clk = ~gtx_clk;

    logic rst_n = 1'b0;
    initial begin
        repeat (5) @(posedge gtx_clk);
        rst_n <= 1'b1;
    end

    // Interface instance
    pcs_tx_if pif (.gtx_clk(gtx_clk), .rst_n(rst_n));

    // ----- DUT --------------------------------------------------------------
    pcs_tx_dut_stub dut (
        .gtx_clk        (gtx_clk),
        .rst_n          (rst_n),
        .txd            (pif.txd),
        .tx_en          (pif.tx_en),
        .tx_er          (pif.tx_er),
        .config_master  (pif.config_master),
        .loc_rcvr_status(pif.loc_rcvr_status),
        .tx_an          (pif.tx_an),
        .tx_bn          (pif.tx_bn),
        .tx_cn          (pif.tx_cn),
        .tx_dn          (pif.tx_dn),
        .tx_sym_valid   (pif.tx_sym_valid),
        .dbg_scr_n      (pif.dbg_scr_n),
        .dbg_cs_n       (pif.dbg_cs_n),
        .dbg_srev_n     (pif.dbg_srev_n),
        .dbg_sd_n       (pif.dbg_sd_n),
        .force_cs_en    (pif.force_cs_en),
        .force_cs_val   (pif.force_cs_val),
        .force_scr_en   (pif.force_scr_en),
        .force_scr_val  (pif.force_scr_val),
        .force_srev_en  (pif.force_srev_en),
        .force_srev_val (pif.force_srev_val)
    );

    // ----- Hand the interface to UVM ----------------------------------------
    initial begin
        uvm_config_db#(virtual pcs_tx_if)::set(null, "*", "vif", pif);
        run_test();
    end

    // ----- Waves ------------------------------------------------------------
    initial begin
        if ($test$plusargs("waves")) begin
            $dumpfile("pcs_tx_tb.vcd");
            $dumpvars(0, tb_top);
        end
    end

    // ----- Watchdog ---------------------------------------------------------
    initial begin
        #500us;
        `uvm_fatal("WATCHDOG", "Simulation watchdog expired (500us)")
    end

endmodule : tb_top
