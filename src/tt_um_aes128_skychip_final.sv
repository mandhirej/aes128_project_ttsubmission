// =============================================================================
// aes128_alt1.sv  –  Primary AES-128 Accelerator Core
//
// Design choices (primary / baseline design):
//   Criterion 1 – Iterative 1-Round-Per-Cycle Design
//                 A single set of AES round logic (SubBytes, ShiftRows, 
//                 MixColumns, AddRoundKey) is reused across 10 cycles. 
//                 This minimizes chip area for the Tiny Tapeout backend.
//
//   Criterion 2 – 16-bit Serial Loading Wrapper Interface
//                 To maximize throughput over the limited Tiny Tapeout I/O,
//                 the 128-bit Key and Plaintext are shifted in 16 bits at a time 
//                 over 8 clock cycles each. The resulting 128-bit Ciphertext 
//                 is similarly shifted out 16 bits at a time over 8 cycles.
//
//   Criterion 3 – Case-statement S-box (sbox)
//                 The S-box is implemented via a 256-entry SystemVerilog 
//                 unique case statement, allowing the synthesis tool 
//                 to optimize for the targeted FPGA or ASIC standard cells.
//
// Operation Sequence (per 128-bit block):
//   Cycles 0-7:   ST_LOAD_KEY state. 128-bit CipherKey is loaded 16 bits/cycle.
//   Cycles 8-15:  ST_LOAD_PT state. 128-bit Plaintext is loaded 16 bits/cycle.
//                 On Cycle 15, the Initial AddRoundKey (Round 0) is applied.
//   Cycles 16-24: ST_MAIN_ROUND state. 1 standard AES round is computed per cycle
//                 (Rounds 1 through 9).
//   Cycle 25:     ST_FINAL_ROUND state. Round 10 is computed (MixColumns bypassed).
//   Cycles 26-33: ST_UNLOAD state. 128-bit Ciphertext is shifted out 16 bits/cycle.
//                 (Cycle 33 completes unloading and loops back to ST_LOAD_PT).
//
// Interface:
//   clk, rst_n    – Standard synchronous clock / active-low reset
//   ui_in[7:0]    – Dedicated input pins (Data In LSB)
//   uio_in[7:0]   – Bidirectional pins configured as inputs (Data In MSB)
//   uo_out[7:0]   – Dedicated output pins (Data Out LSB)
//   uio_out[7:0]  – Bidirectional pins configured as outputs (Data Out MSB)
//   uio_oe[7:0]   – Output enable for bidirectional pins (1=output, 0=input)
//   ena           – Power enable (ignored in this design)
// =============================================================================

/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_aes128_skychip_final (
    input  wire [7:0] ui_in,    // Dedicated inputs (Data In LSB)
    output wire [7:0] uo_out,   // Dedicated outputs (Data Out LSB)
    input  wire [7:0] uio_in,   // IOs: Input path (Data In MSB)
    output wire [7:0] uio_out,  // IOs: Output path (Data Out MSB)
    output wire [7:0] uio_oe,   // IOs: Enable path (1=output, 0=input)
    input  wire       ena,      // Power enable (ignored)
    input  wire       clk,      // Clock
    input  wire       rst_n     // Reset (Active Low)
);

    // -------------------------------------------------------------------------
    // FSM States
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] {
        ST_LOAD_KEY,   // 8 cycles: Load 128-bit key
        ST_LOAD_PT,    // 8 cycles: Load 128-bit plaintext
        ST_MAIN_ROUND, // 9 cycles: AES rounds 1-9
        ST_FINAL_ROUND,// 1 cycle : AES round 10
        ST_UNLOAD      // 8 cycles: Shift out 128-bit ciphertext
    } state_t;

    state_t state;
    logic [3:0] count;       // Counter for shifts and rounds
    logic [127:0] state_reg; // Holds PT, then internal state, then CT
    logic [127:0] key_reg;   // Holds initial key, then expanded round keys

    // -------------------------------------------------------------------------
    // AES Datapath Logic
    // -------------------------------------------------------------------------
    logic [127:0] sb_sr_out, mix_out, next_key_out;

    subbytes_shiftrows sb_sr_inst (.data_in(state_reg), .data_out(sb_sr_out));
    mixcolumns         mix_inst    (.data_in(sb_sr_out), .data_out(mix_out));
    
    // Note: round for key_expansion needs to be the round we are MOVING TO.
    // In Load_PT (final cycle), we prep Round 0. In Main Rounds, we prep next.
    key_expansion key_exp (
        .prev_key(key_reg), 
        .round(count), 
        .next_key(next_key_out)
    );

    // -------------------------------------------------------------------------
    // Control & Shift Logic
    // -------------------------------------------------------------------------
    wire [15:0] bus_in = {uio_in, ui_in};
	 wire _unused = &{ena, 1'b0};

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= ST_LOAD_KEY;
            count       <= 4'd0;
            state_reg   <= 128'h0;
            key_reg     <= 128'h0;
        end else begin
            case (state)
                // 1. Load 128-bit Key (16 bits x 8 cycles)
                ST_LOAD_KEY: begin
                    key_reg <= {key_reg[111:0], bus_in}; // 16 new bits + 112 old bits = 128 bits
                    if (count == 4'd7) begin
                        count <= 4'd0;
                        state <= ST_LOAD_PT;
                    end else begin
                        count <= count + 4'd1;
                    end
                end

                // 2. Load 128-bit Plaintext (16 bits x 8 cycles)
                ST_LOAD_PT: begin
                    state_reg <= {state_reg[111:0], bus_in};
                    if (count == 4'd7) begin
                        count <= 4'd1; // Setup for Round 1
                        state <= ST_MAIN_ROUND;
                        // Initial Round XOR (Round 0) happens during transition
                        state_reg <= {state_reg[111:0], bus_in} ^ key_reg;
                    end else begin
                        count <= count + 4'd1;
                    end
                end

                // 3. Perform Main Rounds (1-9)
                ST_MAIN_ROUND: begin
                    key_reg   <= next_key_out;
                    state_reg <= mix_out ^ next_key_out;
                    if (count == 4'd9) begin
                        count <= 4'd10;
                        state <= ST_FINAL_ROUND;
                    end else begin
                        count <= count + 4'd1;
                    end
                end

                // 4. Final Round (Round 10 - No MixColumns)
                ST_FINAL_ROUND: begin
                    key_reg   <= next_key_out;
                    state_reg <= sb_sr_out ^ next_key_out;
                    state     <= ST_UNLOAD;
                    count     <= 4'd0;
                end

                // 5. Unload Ciphertext (16 bits x 8 cycles)
                ST_UNLOAD: begin
                    state_reg <= {state_reg[111:0], 16'h0};
                    if (count == 4'd7) begin
                        count <= 4'd0;
                        state <= ST_LOAD_PT; // Back to PT for streaming blocks
                    end else begin
                        count <= count + 4'd1;
                    end
                end
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Pin Assignments
    // -------------------------------------------------------------------------
    // uio pins are outputs only during the UNLOAD state
    assign uio_oe  = (state == ST_UNLOAD) ? 8'hFF : 8'h00;

    // Use MSB of state_reg for the 16-bit output bus
    assign uio_out = state_reg[127:120]; 
    assign uo_out  = state_reg[119:112];

endmodule 
