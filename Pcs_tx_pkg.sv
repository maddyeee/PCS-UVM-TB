// =============================================================================
// PCS TX Encoder - UVM Package
// =============================================================================

package pcs_tx_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // =========================================================================
  // State encoding (matches DUT & box diagram)
  // =========================================================================
  typedef enum logic [2:0] {
    ST_IDLE        = 3'b000,
    ST_SSD         = 3'b001,
    ST_DATA        = 3'b010,
    ST_TX_ERROR    = 3'b011,
    ST_CARRIER_EXT = 3'b100,
    ST_ESD         = 3'b101
  } pcs_state_e;

  // =========================================================================
  // Transaction Item
  // =========================================================================
  class pcs_tx_item extends uvm_sequence_item;
    `uvm_object_utils(pcs_tx_item)

    // GMII stimulus fields
    rand logic [7:0] txd;
    rand logic       tx_en;
    rand logic       tx_er;
    rand logic       link_status;

    // Observed response fields
    logic [9:0] tx_code_group;
    logic       tx_code_valid;
    logic [2:0] tx_state;
    logic       transmitting;
    logic       tx_error_out;
    logic       carrier_extend;

    // Constraints
    constraint c_link_up   { link_status == 1'b1; }
    constraint c_no_error  { soft tx_er == 1'b0;  }
    constraint c_valid_data { txd inside {[8'h00:8'hFF]}; }

    function new(string name = "pcs_tx_item");
      super.new(name);
    endfunction

    function string convert2string();
      return $sformatf("txd=0x%02h tx_en=%0b tx_er=%0b link=%0b | code=0x%03h state=%0d tx=%0b err=%0b ext=%0b",
                       txd, tx_en, tx_er, link_status,
                       tx_code_group, tx_state, transmitting, tx_error_out, carrier_extend);
    endfunction
  endclass

  // =========================================================================
  // Sequences
  // =========================================================================

  // Base sequence
  class pcs_base_seq extends uvm_sequence #(pcs_tx_item);
    `uvm_object_utils(pcs_base_seq)
    function new(string name = "pcs_base_seq");
      super.new(name);
    endfunction
  endclass

  // Reset sequence - drives idle with link down
  class pcs_reset_seq extends pcs_base_seq;
    `uvm_object_utils(pcs_reset_seq)
    int unsigned num_idle_cycles = 10;

    function new(string name = "pcs_reset_seq");
      super.new(name);
    endfunction

    task body();
      pcs_tx_item item;
      `uvm_info(get_type_name(), "Running reset/idle sequence", UVM_MEDIUM)
      repeat (num_idle_cycles) begin
        item = pcs_tx_item::type_id::create("item");
        start_item(item);
        item.randomize() with { tx_en == 0; tx_er == 0; link_status == 0; };
        finish_item(item);
      end
    endtask
  endclass

  // Normal frame transmit sequence (Idle → SSD → Data → ESD → Idle)
  class pcs_frame_seq extends pcs_base_seq;
    `uvm_object_utils(pcs_frame_seq)
    rand int unsigned frame_len;
    constraint c_len { frame_len inside {[4:20]}; }

    function new(string name = "pcs_frame_seq");
      super.new(name);
    endfunction

    task body();
      pcs_tx_item item;
      `uvm_info(get_type_name(), $sformatf("Transmitting frame of %0d bytes", frame_len), UVM_MEDIUM)

      // Pre-frame idle
      repeat (3) begin
        item = pcs_tx_item::type_id::create("item");
        start_item(item);
        item.randomize() with { tx_en == 0; tx_er == 0; link_status == 1; };
        finish_item(item);
      end

      // Frame data (tx_en=1 triggers SSD then DATA)
      repeat (frame_len) begin
        item = pcs_tx_item::type_id::create("item");
        start_item(item);
        item.randomize() with { tx_en == 1; tx_er == 0; link_status == 1; };
        finish_item(item);
      end

      // De-assert tx_en → triggers Carrier Ext then ESD
      repeat (3) begin
        item = pcs_tx_item::type_id::create("item");
        start_item(item);
        item.randomize() with { tx_en == 0; tx_er == 0; link_status == 1; };
        finish_item(item);
      end
    endtask
  endclass

  // Error injection sequence (TX_ER during data)
  class pcs_error_seq extends pcs_base_seq;
    `uvm_object_utils(pcs_error_seq)

    function new(string name = "pcs_error_seq");
      super.new(name);
    endfunction

    task body();
      pcs_tx_item item;
      `uvm_info(get_type_name(), "Running TX error injection sequence", UVM_MEDIUM)

      // Idle
      repeat (3) begin
        item = pcs_tx_item::type_id::create("item");
        start_item(item);
        item.randomize() with { tx_en == 0; tx_er == 0; link_status == 1; };
        finish_item(item);
      end

      // Start frame
      repeat (5) begin
        item = pcs_tx_item::type_id::create("item");
        start_item(item);
        item.randomize() with { tx_en == 1; tx_er == 0; link_status == 1; };
        finish_item(item);
      end

      // Inject TX_ER (Agent B: Error Check path)
      repeat (2) begin
        item = pcs_tx_item::type_id::create("item");
        start_item(item);
        item.randomize() with { tx_en == 1; tx_er == 1; link_status == 1; };
        finish_item(item);
      end

      // End frame
      repeat (4) begin
        item = pcs_tx_item::type_id::create("item");
        start_item(item);
        item.randomize() with { tx_en == 0; tx_er == 0; link_status == 1; };
        finish_item(item);
      end
    endtask
  endclass

  // Carrier extension sequence
  class pcs_carrier_ext_seq extends pcs_base_seq;
    `uvm_object_utils(pcs_carrier_ext_seq)

    function new(string name = "pcs_carrier_ext_seq");
      super.new(name);
    endfunction

    task body();
      pcs_tx_item item;
      `uvm_info(get_type_name(), "Running carrier extension sequence", UVM_MEDIUM)

      // Idle
      repeat (2) begin
        item = pcs_tx_item::type_id::create("item");
        start_item(item);
        item.randomize() with { tx_en == 0; tx_er == 0; link_status == 1; };
        finish_item(item);
      end

      // Short frame
      repeat (4) begin
        item = pcs_tx_item::type_id::create("item");
        start_item(item);
        item.randomize() with { tx_en == 1; tx_er == 0; link_status == 1; };
        finish_item(item);
      end

      // Carrier extension (tx_er=1 while tx_en=0)
      repeat (4) begin
        item = pcs_tx_item::type_id::create("item");
        start_item(item);
        item.randomize() with { tx_en == 0; tx_er == 1; link_status == 1; };
        finish_item(item);
      end

      // Final end
      repeat (3) begin
        item = pcs_tx_item::type_id::create("item");
        start_item(item);
        item.randomize() with { tx_en == 0; tx_er == 0; link_status == 1; };
        finish_item(item);
      end
    endtask
  endclass

  // =========================================================================
  // Driver
  // =========================================================================
  class pcs_tx_driver extends uvm_driver #(pcs_tx_item);
    `uvm_component_utils(pcs_tx_driver)

    virtual pcs_tx_if vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual pcs_tx_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "Virtual interface not found")
    endfunction

    task run_phase(uvm_phase phase);
      pcs_tx_item item;
      forever begin
        seq_item_port.get_next_item(item);
        drive_item(item);
        seq_item_port.item_done();
      end
    endtask

    task drive_item(pcs_tx_item item);
      @(posedge vif.clk);
      vif.txd         <= item.txd;
      vif.tx_en       <= item.tx_en;
      vif.tx_er       <= item.tx_er;
      vif.link_status <= item.link_status;
    endtask
  endclass

  // =========================================================================
  // Monitor
  // =========================================================================
  class pcs_tx_monitor extends uvm_monitor;
    `uvm_component_utils(pcs_tx_monitor)

    virtual pcs_tx_if vif;
    uvm_analysis_port #(pcs_tx_item) ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      ap = new("ap", this);
      if (!uvm_config_db#(virtual pcs_tx_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "Virtual interface not found")
    endfunction

    task run_phase(uvm_phase phase);
      pcs_tx_item item;
      forever begin
        @(posedge vif.clk);
        item = pcs_tx_item::type_id::create("mon_item");
        // Capture inputs
        item.txd         = vif.txd;
        item.tx_en       = vif.tx_en;
        item.tx_er       = vif.tx_er;
        item.link_status = vif.link_status;
        // Capture outputs
        item.tx_code_group = vif.tx_code_group;
        item.tx_code_valid = vif.tx_code_valid;
        item.tx_state      = vif.tx_state;
        item.transmitting  = vif.transmitting;
        item.tx_error_out  = vif.tx_error_out;
        item.carrier_extend = vif.carrier_extend;
        ap.write(item);
      end
    endtask
  endclass

  // =========================================================================
  // Scoreboard
  // =========================================================================
  class pcs_tx_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(pcs_tx_scoreboard)

    uvm_analysis_imp #(pcs_tx_item, pcs_tx_scoreboard) imp;

    // Reference model state
    pcs_state_e expected_state;
    int pass_count, fail_count;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      imp = new("imp", this);
      expected_state = ST_IDLE;
      pass_count = 0;
      fail_count = 0;
    endfunction

    function void write(pcs_tx_item item);
      pcs_state_e actual_state = pcs_state_e'(item.tx_state);

      // Reference model: compute expected next state
      case (expected_state)
        ST_IDLE:
          if (item.tx_en && item.link_status) expected_state = ST_SSD;
        ST_SSD:
          expected_state = ST_DATA;
        ST_DATA: begin
          if (item.tx_er)       expected_state = ST_TX_ERROR;
          else if (!item.tx_en) expected_state = ST_CARRIER_EXT;
        end
        ST_TX_ERROR: begin
          if (!item.tx_en)      expected_state = ST_CARRIER_EXT;
          else if (!item.tx_er) expected_state = ST_DATA;
        end
        ST_CARRIER_EXT: begin
          if (!item.tx_en && !item.tx_er) expected_state = ST_ESD;
          else if (item.tx_en)            expected_state = ST_DATA;
        end
        ST_ESD:
          expected_state = ST_IDLE;
        default:
          expected_state = ST_IDLE;
      endcase

      // Check state transition
      if (actual_state == expected_state) begin
        pass_count++;
        `uvm_info("SCBD", $sformatf("PASS: %s | %s", item.convert2string(), expected_state.name()), UVM_HIGH)
      end else begin
        fail_count++;
        `uvm_error("SCBD", $sformatf("FAIL: expected=%s actual=%s | %s",
                   expected_state.name(), actual_state.name(), item.convert2string()))
      end

      // Check error flag consistency
      if (actual_state == ST_TX_ERROR && !item.tx_error_out)
        `uvm_error("SCBD", "tx_error_out should be asserted in TX_ERROR state")

      if (actual_state == ST_CARRIER_EXT && !item.carrier_extend)
        `uvm_error("SCBD", "carrier_extend should be asserted in CARRIER_EXT state")
    endfunction

    function void report_phase(uvm_phase phase);
      `uvm_info("SCBD", $sformatf("=== SCOREBOARD SUMMARY: %0d PASS, %0d FAIL ===", pass_count, fail_count), UVM_LOW)
    endfunction
  endclass

  // =========================================================================
  // Coverage Collector
  // =========================================================================
  class pcs_tx_coverage extends uvm_subscriber #(pcs_tx_item);
    `uvm_component_utils(pcs_tx_coverage)

    pcs_tx_item item;

    covergroup cg_pcs_states;
      cp_state: coverpoint item.tx_state {
        bins idle       = {ST_IDLE};
        bins ssd        = {ST_SSD};
        bins data       = {ST_DATA};
        bins tx_error   = {ST_TX_ERROR};
        bins carrier_ext = {ST_CARRIER_EXT};
        bins esd        = {ST_ESD};
      }
      cp_tx_en: coverpoint item.tx_en;
      cp_tx_er: coverpoint item.tx_er;
      cx_state_x_en: cross cp_state, cp_tx_en;
      cx_state_x_er: cross cp_state, cp_tx_er;
    endgroup

    covergroup cg_transitions;
      cp_state: coverpoint item.tx_state {
        bins idle_to_ssd     = (ST_IDLE => ST_SSD);
        bins ssd_to_data     = (ST_SSD  => ST_DATA);
        bins data_to_error   = (ST_DATA => ST_TX_ERROR);
        bins data_to_ext     = (ST_DATA => ST_CARRIER_EXT);
        bins error_to_ext    = (ST_TX_ERROR => ST_CARRIER_EXT);
        bins error_to_data   = (ST_TX_ERROR => ST_DATA);
        bins ext_to_esd      = (ST_CARRIER_EXT => ST_ESD);
        bins esd_to_idle     = (ST_ESD  => ST_IDLE);
      }
    endgroup

    function new(string name, uvm_component parent);
      super.new(name, parent);
      cg_pcs_states = new();
      cg_transitions = new();
    endfunction

    function void write(pcs_tx_item t);
      item = t;
      cg_pcs_states.sample();
      cg_transitions.sample();
    endfunction

    function void report_phase(uvm_phase phase);
      `uvm_info("COV", $sformatf("State coverage: %.1f%%, Transition coverage: %.1f%%",
                cg_pcs_states.get_coverage(), cg_transitions.get_coverage()), UVM_LOW)
    endfunction
  endclass

  // =========================================================================
  // Agent
  // =========================================================================
  class pcs_tx_agent extends uvm_agent;
    `uvm_component_utils(pcs_tx_agent)

    pcs_tx_driver    drv;
    pcs_tx_monitor   mon;
    uvm_sequencer #(pcs_tx_item) seqr;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      mon = pcs_tx_monitor::type_id::create("mon", this);
      if (get_is_active() == UVM_ACTIVE) begin
        drv  = pcs_tx_driver::type_id::create("drv", this);
        seqr = uvm_sequencer#(pcs_tx_item)::type_id::create("seqr", this);
      end
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      if (get_is_active() == UVM_ACTIVE)
        drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
  endclass

  // =========================================================================
  // Environment
  // =========================================================================
  class pcs_tx_env extends uvm_env;
    `uvm_component_utils(pcs_tx_env)

    pcs_tx_agent      agent;
    pcs_tx_scoreboard scbd;
    pcs_tx_coverage   cov;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agent = pcs_tx_agent::type_id::create("agent", this);
      scbd  = pcs_tx_scoreboard::type_id::create("scbd", this);
      cov   = pcs_tx_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      agent.mon.ap.connect(scbd.imp);
      agent.mon.ap.connect(cov.analysis_export);
    endfunction
  endclass

  // =========================================================================
  // Tests
  // =========================================================================

  // Base test with reset
  class pcs_base_test extends uvm_test;
    `uvm_component_utils(pcs_base_test)

    pcs_tx_env env;
    virtual pcs_tx_if vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = pcs_tx_env::type_id::create("env", this);
      if (!uvm_config_db#(virtual pcs_tx_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "No virtual interface")
    endfunction

    // Hardware reset task - callable from any test
    task apply_reset();
      `uvm_info("TEST", "Applying hardware reset...", UVM_MEDIUM)
      vif.reset_n     <= 1'b0;
      vif.txd         <= 8'h00;
      vif.tx_en       <= 1'b0;
      vif.tx_er       <= 1'b0;
      vif.link_status <= 1'b0;
      vif.col_test    <= 1'b0;
      repeat (5) @(posedge vif.clk);
      vif.reset_n <= 1'b1;
      repeat (2) @(posedge vif.clk);
      `uvm_info("TEST", "Reset de-asserted", UVM_MEDIUM)
    endtask

    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      apply_reset();
      phase.drop_objection(this);
    endtask
  endclass

  // Test: Normal frame transmission
  class pcs_frame_test extends pcs_base_test;
    `uvm_component_utils(pcs_frame_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      pcs_frame_seq frame_seq;
      pcs_reset_seq rst_seq;
      phase.raise_objection(this);

      // Apply HW reset
      apply_reset();

      // Run idle/reset sequence
      rst_seq = pcs_reset_seq::type_id::create("rst_seq");
      rst_seq.start(env.agent.seqr);

      // Run multiple frames
      repeat (5) begin
        frame_seq = pcs_frame_seq::type_id::create("frame_seq");
        frame_seq.randomize();
        frame_seq.start(env.agent.seqr);
      end

      // Post-frame idle
      rst_seq = pcs_reset_seq::type_id::create("post_idle");
      rst_seq.start(env.agent.seqr);

      phase.drop_objection(this);
    endtask
  endclass

  // Test: Error injection
  class pcs_error_test extends pcs_base_test;
    `uvm_component_utils(pcs_error_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      pcs_error_seq err_seq;
      phase.raise_objection(this);
      apply_reset();

      repeat (3) begin
        err_seq = pcs_error_seq::type_id::create("err_seq");
        err_seq.start(env.agent.seqr);
      end

      phase.drop_objection(this);
    endtask
  endclass

  // Test: Carrier extension
  class pcs_carrier_ext_test extends pcs_base_test;
    `uvm_component_utils(pcs_carrier_ext_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      pcs_carrier_ext_seq ext_seq;
      phase.raise_objection(this);
      apply_reset();

      repeat (3) begin
        ext_seq = pcs_carrier_ext_seq::type_id::create("ext_seq");
        ext_seq.start(env.agent.seqr);
      end

      phase.drop_objection(this);
    endtask
  endclass

  // Test: Full regression (all sequences)
  class pcs_full_test extends pcs_base_test;
    `uvm_component_utils(pcs_full_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      pcs_reset_seq       rst_seq;
      pcs_frame_seq       frame_seq;
      pcs_error_seq       err_seq;
      pcs_carrier_ext_seq ext_seq;

      phase.raise_objection(this);

      // === Phase 1: Reset ===
      `uvm_info("TEST", "=== Phase 1: Hardware Reset ===", UVM_LOW)
      apply_reset();

      // === Phase 2: Idle verification ===
      `uvm_info("TEST", "=== Phase 2: Idle Verification ===", UVM_LOW)
      rst_seq = pcs_reset_seq::type_id::create("rst_seq");
      rst_seq.num_idle_cycles = 20;
      rst_seq.start(env.agent.seqr);

      // === Phase 3: Normal frames ===
      `uvm_info("TEST", "=== Phase 3: Normal Frame Tx ===", UVM_LOW)
      repeat (10) begin
        frame_seq = pcs_frame_seq::type_id::create("frame_seq");
        frame_seq.randomize();
        frame_seq.start(env.agent.seqr);
      end

      // === Phase 4: Error injection ===
      `uvm_info("TEST", "=== Phase 4: Error Injection ===", UVM_LOW)
      repeat (5) begin
        err_seq = pcs_error_seq::type_id::create("err_seq");
        err_seq.start(env.agent.seqr);
      end

      // === Phase 5: Carrier extension ===
      `uvm_info("TEST", "=== Phase 5: Carrier Extension ===", UVM_LOW)
      repeat (5) begin
        ext_seq = pcs_carrier_ext_seq::type_id::create("ext_seq");
        ext_seq.start(env.agent.seqr);
      end

      // === Phase 6: Mid-stream reset ===
      `uvm_info("TEST", "=== Phase 6: Mid-Stream Reset ===", UVM_LOW)
      frame_seq = pcs_frame_seq::type_id::create("frame_mid");
      frame_seq.randomize() with { frame_len == 10; };
      fork
        frame_seq.start(env.agent.seqr);
        begin
          repeat (8) @(posedge vif.clk);
          apply_reset(); // Reset during active transmission
        end
      join

      // Final idle
      rst_seq = pcs_reset_seq::type_id::create("final_idle");
      rst_seq.start(env.agent.seqr);

      phase.drop_objection(this);
    endtask
  endclass

endpackage
