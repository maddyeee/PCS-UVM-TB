// =============================================================================
// PCS Transmit Encoder - DUT Stub
// =============================================================================

module pcs_tx_encoder (
  input  logic        clk,            // 125 MHz transmit clock
  input  logic        reset_n,        // Active-low asynchronous reset
  
  // GMII Interface (from MAC)
  input  logic [7:0]  txd,            // Transmit data (TXD[7:0])
  input  logic        tx_en,          // Transmit enable
  input  logic        tx_er,          // Transmit error
  
  // Configuration
  input  logic        link_status,    // Link up/down indicator
  input  logic        col_test,       // Collision test mode
  
  // PCS Encoded Output (to PMA)
  output logic [9:0]  tx_code_group,  // 10-bit encoded code group
  output logic        tx_code_valid,  // Code group valid
  
  // Status outputs
  output logic [2:0]  tx_state,       // Current transmitter state
  output logic        transmitting,   // Actively transmitting
  output logic        tx_error_out,   // Error condition detected
  output logic        carrier_extend  // Carrier extension active
);

  // =========================================================================
  // State encoding matching the box diagram
  // =========================================================================
  typedef enum logic [2:0] {
    ST_IDLE         = 3'b000,   // Agent A: Send Idle (Link Down/Idle)
    ST_SSD          = 3'b001,   // Agent A: SSD1 & SSD2 (Start Transmit)
    ST_DATA         = 3'b010,   // Agent B: Transmit Data (Active Data)
    ST_TX_ERROR     = 3'b011,   // Agent B: Error Check / Transmit Error
    ST_CARRIER_EXT  = 3'b100,   // Agent C: Carrier Extension (Extending)
    ST_ESD          = 3'b101    // Agent C: ESD & CSReset (Ending Stream)
  } pcs_state_e;

  pcs_state_e current_state, next_state;

  // =========================================================================
  // Special code groups (IEEE 802.3z Table 36-1)
  // =========================================================================
  localparam logic [9:0] CG_IDLE   = 10'b1010101010;  // /I/ Idle
  localparam logic [9:0] CG_SSD1   = 10'b1100010001;  // /S1/ Start of Stream D1
  localparam logic [9:0] CG_SSD2   = 10'b1100010010;  // /S2/ Start of Stream D2
  localparam logic [9:0] CG_ESD1   = 10'b1100011101;  // /T/ End of Stream
  localparam logic [9:0] CG_ESD2   = 10'b1100011110;  // /R/ Carrier Extension
  localparam logic [9:0] CG_CEXT   = 10'b1111100000;  // /R/ Carrier Extension
  localparam logic [9:0] CG_ERROR  = 10'b0011111010;  // /V/ Error propagation

  // =========================================================================
  // State register
  // =========================================================================
  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n)
      current_state <= ST_IDLE;
    else
      current_state <= next_state;
  end

  // =========================================================================
  // Next state logic (per box diagram flow)
  // =========================================================================
  always_comb begin
    next_state = current_state;
    
    case (current_state)
      ST_IDLE: begin
        // Agent A: Idle → Start on tx_en assertion
        if (tx_en && link_status)
          next_state = ST_SSD;
      end

      ST_SSD: begin
        // Agent A: SSD → Data (after sending SSD1 & SSD2)
        next_state = ST_DATA;
      end

      ST_DATA: begin
        // Agent B: Active Data transmission
        if (tx_er)
          next_state = ST_TX_ERROR;   // TX_ER path
        else if (!tx_en)
          next_state = ST_CARRIER_EXT; // End Data path
      end

      ST_TX_ERROR: begin
        // Agent B: Error state
        if (!tx_en)
          next_state = ST_CARRIER_EXT;
        else if (!tx_er)
          next_state = ST_DATA;
      end

      ST_CARRIER_EXT: begin
        // Agent C: Carrier Extension
        if (!tx_en && !tx_er)
          next_state = ST_ESD;
        else if (tx_en)
          next_state = ST_DATA;       // Back to data on re-assertion
      end

      ST_ESD: begin
        // Agent C: End of Stream → Finish → back to Idle
        next_state = ST_IDLE;
      end

      default: next_state = ST_IDLE;
    endcase
  end

  // =========================================================================
  // Output logic
  // =========================================================================
  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      tx_code_group  <= CG_IDLE;
      tx_code_valid  <= 1'b0;
      transmitting   <= 1'b0;
      tx_error_out   <= 1'b0;
      carrier_extend <= 1'b0;
    end else begin
      tx_code_valid  <= 1'b1;
      transmitting   <= 1'b0;
      tx_error_out   <= 1'b0;
      carrier_extend <= 1'b0;

      case (next_state)
        ST_IDLE: begin
          tx_code_group <= CG_IDLE;
        end
        ST_SSD: begin
          tx_code_group <= CG_SSD1;  // Simplified: SSD1 then SSD2
          transmitting  <= 1'b1;
        end
        ST_DATA: begin
          tx_code_group <= {2'b01, txd};  // 8b/10b encode placeholder
          transmitting  <= 1'b1;
        end
        ST_TX_ERROR: begin
          tx_code_group <= CG_ERROR;
          transmitting  <= 1'b1;
          tx_error_out  <= 1'b1;
        end
        ST_CARRIER_EXT: begin
          tx_code_group  <= CG_CEXT;
          carrier_extend <= 1'b1;
        end
        ST_ESD: begin
          tx_code_group <= CG_ESD1;
        end
        default: begin
          tx_code_group <= CG_IDLE;
        end
      endcase
    end
  end

  // Expose state for monitoring
  assign tx_state = current_state;

endmodule
