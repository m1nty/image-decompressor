/* 
McMaster University
3DQ5 Project 2020
Clipping Module

Jack Wawrychuk - 400145293
Minhaj Shah - 400119266
*/

`timescale 1ns/100ps

`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

module clipping_module (
	input logic [31:0] clip_in,
	output logic [7:0] clip_out
);

assign clip_out = clip_in[31] == 1'b1 ? 8'd0 : |clip_in[31:8] == 1'b1 ? 8'd255 : clip_in[7:0];
	
endmodule