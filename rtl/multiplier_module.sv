/* 
McMaster University
3DQ5 Project 2020
Multiplier Module

Jack Wawrychuk - 400145293
Minhaj Shah - 400119266
*/

`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

module multiplier_module (
	input logic [31:0] mult_op_1, mult_op_2,
	output logic [31:0] mult_result
);

logic [63:0] mult_result_long;

assign mult_result_long = mult_op_1 * mult_op_2,
       mult_result = mult_result_long[31:0];
	
endmodule