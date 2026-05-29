module mixcolumns (
    input  logic [127:0] data_in,
    output logic [127:0] data_out
);

    // Mix each of the four 32-bit columns 
    mixcolumns_one_column col0 (.col_in(data_in[127:96]), .col_out(data_out[127:96]));
    mixcolumns_one_column col1 (.col_in(data_in[95:64]),  .col_out(data_out[95:64]));
    mixcolumns_one_column col2 (.col_in(data_in[63:32]),  .col_out(data_out[63:32]));
    mixcolumns_one_column col3 (.col_in(data_in[31:0]),   .col_out(data_out[31:0]));
	 
endmodule

module mixcolumns_one_column (
    input  logic [31:0] col_in,
    output logic [31:0] col_out
);

    logic [7:0] s0, s1, s2, s3;
    logic [7:0] m0, m1, m2, m3;

    assign {s0, s1, s2, s3} = col_in; 

    // Finite field multiplication logic 
    assign m0 = xtime(s0) ^ (xtime(s1) ^ s1) ^ s2 ^ s3;
    assign m1 = s0 ^ xtime(s1) ^ (xtime(s2) ^ s2) ^ s3;
    assign m2 = s0 ^ s1 ^ xtime(s2) ^ (xtime(s3) ^ s3);
    assign m3 = (xtime(s0) ^ s0) ^ s1 ^ s2 ^ xtime(s3);

    assign col_out = {m0, m1, m2, m3};

	function automatic [7:0] xtime(input [7:0] b);
        begin
            xtime = (b[7]) ? ((b << 1) ^ 8'h1b) : (b << 1);
        end
    endfunction
	 
endmodule 
