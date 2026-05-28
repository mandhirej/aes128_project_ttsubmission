module subbytes_shiftrows (
    input  logic [127:0] data_in,
    output logic [127:0] data_out
);
    logic [7:0] sb_out [15:0];

    // Instantiate 16 S-boxes for SubBytes
    genvar i;
    generate
        for (i = 0; i < 16; i++) 
		  begin : 
				sbox_gen
            sbox sb_inst (.in_byte(data_in[i*8 +: 8]), .out_byte(sb_out[i]));
        end
    endgenerate

    // Perform ShiftRows rearrangement
    assign data_out = {
        sb_out[15], sb_out[10], sb_out[5],  sb_out[0],  // Column 3 (shifted)
        sb_out[11], sb_out[6],  sb_out[1],  sb_out[12], // Column 2 (shifted)
        sb_out[7],  sb_out[2],  sb_out[13], sb_out[8],  // Column 1 (shifted)
        sb_out[3],  sb_out[14], sb_out[9],  sb_out[4]   // Column 0 (shifted)
    };
	 
endmodule 