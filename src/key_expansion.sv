module key_expansion(
	input  logic [127:0] prev_key,
   input  logic [3:0]   round,
   output logic [127:0] next_key
);

	logic [31:0] w0, w1, w2, w3;
   logic [31:0] sub_word_out;
   logic [31:0] rcon;

	assign {w0, w1, w2, w3} = prev_key;
	
	always_comb begin
        case(round)
            4'd1: rcon = 32'h01000000; 4'd2: rcon = 32'h02000000;
            4'd3: rcon = 32'h04000000; 4'd4: rcon = 32'h08000000;
            4'd5: rcon = 32'h10000000; 4'd6: rcon = 32'h20000000;
            4'd7: rcon = 32'h40000000; 4'd8: rcon = 32'h80000000;
            4'd9: rcon = 32'h1b000000; 4'd10: rcon = 32'h36000000;
            default: rcon = 32'h00000000;
        endcase
    end
	
	sbox sb0 (.in_byte(w3[23:16]), .out_byte(sub_word_out[31:24]));
   sbox sb1 (.in_byte(w3[15:8]),  .out_byte(sub_word_out[23:16]));
   sbox sb2 (.in_byte(w3[7:0]),   .out_byte(sub_word_out[15:8]));
   sbox sb3 (.in_byte(w3[31:24]), .out_byte(sub_word_out[7:0]));
	
	logic [31:0] next_w0, next_w1, next_w2, next_w3;
   assign next_w0 = w0 ^ sub_word_out ^ rcon;
   assign next_w1 = w1 ^ next_w0;
   assign next_w2 = w2 ^ next_w1;
   assign next_w3 = w3 ^ next_w2;
	
	assign next_key = {next_w0, next_w1, next_w2, next_w3};

endmodule 