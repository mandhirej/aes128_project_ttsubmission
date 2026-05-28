// =============================================================================
// tt_um_aes128_skychip_final.sv  –  Primary AES-128 Accelerator Core
//
// Design choices (primary / baseline design):
//   Criterion 1 – Partially Unrolled 2-round design
//                 Two full AES rounds are computed per clock cycle by
//                 duplicating the SubBytes/ShiftRows/MixColumns/AddRoundKey
//                 datapath. 10 rounds → 5 active cycles instead of 10.
//
//   Criterion 2 – 16-bit Serial Loading Wrapper Interface
//                 To fit within the limited I/O pins of Tiny Tapeout, the
//                 128-bit Key and Plaintext are shifted in 16 bits at a time 
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
//   Cycles 16-20: ST_PROCESS state. 2 AES rounds are computed per cycle.
//                 Cycle 20 processes Rounds 9 and 10 (MixColumns bypassed in R10).
//   Cycles 21-28: ST_UNLOAD state. 128-bit Ciphertext is shifted out 16 bits/cycle.
//                 (Cycle 28 completes unloading and loops back to ST_LOAD_PT).
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
    typedef enum logic [1:0] {
        ST_LOAD_KEY = 2'd0,  // 8 cycles: Load 128-bit key
        ST_LOAD_PT  = 2'd1,  // 8 cycles: Load 128-bit plaintext
        ST_PROCESS  = 2'd2,  // 5 cycles: 2 AES rounds per cycle (10 rounds total)
        ST_UNLOAD   = 2'd3   // 8 cycles: Shift out 128-bit ciphertext
    } state_t;

    state_t state;
    logic [3:0] count;       // Counter for shifts and rounds
    logic [127:0] state_reg; // Holds PT, then internal state, then CT
    logic [127:0] key_reg;   // Holds initial key, then expanded round keys

    // -------------------------------------------------------------------------
    // Partially Unrolled AES Datapath Logic (2 Rounds)
    // -------------------------------------------------------------------------
    
    // --- STAGE 1: Odd Rounds (1, 3, 5, 7, 9) ---
    logic [127:0] sb_sr_1_out, mix_1_out, key_1_out, rk_1_out;
    
    subbytes_shiftrows sb_sr_1 (.data_in(state_reg),   .data_out(sb_sr_1_out));
    mixcolumns              mix_1   (.data_in(sb_sr_1_out), .data_out(mix_1_out));
    key_expansion      ke_1    (.prev_key(key_reg),    .round(count), .next_key(key_1_out));
    
    assign rk_1_out = mix_1_out ^ key_1_out; // End of Stage 1

    // --- STAGE 2: Even Rounds (2, 4, 6, 8, 10) ---
    logic [127:0] sb_sr_2_out, mix_2_out, key_2_out, rk_2_out;
    
    subbytes_shiftrows sb_sr_2 (.data_in(rk_1_out),    .data_out(sb_sr_2_out));
    mixcolumns              mix_2   (.data_in(sb_sr_2_out), .data_out(mix_2_out));
    key_expansion      ke_2    (.prev_key(key_1_out),  .round(count + 4'd1), .next_key(key_2_out));
    
    // Round 10 Bypass Logic: MixColumns is skipped in the very last round of AES.
    // When count == 9, Stage 2 is processing Round 10.
    wire is_round_10 = (count == 4'd9);
    assign rk_2_out = (is_round_10 ? sb_sr_2_out : mix_2_out) ^ key_2_out;

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
                    key_reg <= {key_reg[111:0], bus_in}; 
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
                        count <= 4'd1; // Setup to start Round 1
                        state <= ST_PROCESS;
                        // Initial Round XOR (Round 0) happens during transition
                        state_reg <= {state_reg[111:0], bus_in} ^ key_reg;
                    end else begin
                        count <= count + 4'd1;
                    end
                end

                // 3. Process 2 Rounds per Cycle (5 cycles total)
                ST_PROCESS: begin
                    // Commit the result of the 2-round combinational path
                    state_reg <= rk_2_out;
                    key_reg   <= key_2_out;
                    
                    if (count == 4'd9) begin
                        // Reached Round 10, encryption is complete
                        count <= 4'd0;
                        state <= ST_UNLOAD;
                    end else begin
                        // Advance round counter by 2 (e.g., 1 -> 3 -> 5 -> 7 -> 9)
                        count <= count + 4'd2;
                    end
                end

                // 4. Unload Ciphertext (16 bits x 8 cycles)
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