/* 
McMaster University
3DQ5 Project 2020
Milestone 2

Jack Wawrychuk - 400145293
Minhaj Shah - 400119266
*/

`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

module Milestone_2 (

	input logic Clock_50,
	input logic resetn,
	input logic [15:0] SRAM_read_data,
	input logic Milestone_2_start,

	output logic [15:0] SRAM_write_data,
	output logic SRAM_we_n,
	output logic [17:0] SRAM_address_O,
	output logic Milestone_2_finished
);

//Offsets Specified from Memory Map Layout
parameter 
    Y_offset = 18'd0,
    U_offset = 18'd38400,
    V_offset = 18'd57600,
    Pre_IDCT_Y_offset = 18'd76800,
    Pre_IDCT_U_offset = 18'd153600,
    Pre_IDCT_V_offset = 18'd192000;


//Buffers for key values
logic [15:0] S_prime_buffer;
logic [31:0] matrix_mult_buffer;
logic [7:0] clipped_buffer;

//Segement Trackers
logic read_Y_blocks;
logic read_UV_blocks;

logic YUV_write_en;

integer i; //Used in loops

//Used to keep track of block operations
logic block_read_complete;
logic block_write_complete;

//Used to alternate next block SRAM writes to RAM
logic write_next_block;

//Used for memory addressing with row and column offsets of SRAM
logic [3:0] SRAM_read_col_offset;
logic [11:0] SRAM_read_row_offset;
logic [3:0] SRAM_write_col_offset;
logic [11:0] SRAM_write_row_offset;

//Used for memory addressing with row and column offsets of Block Computations
logic [8:0] SRAM_read_block_hor_offset;
logic [17:0] SRAM_read_block_ver_offset;
logic [8:0] SRAM_write_block_hor_offset;
logic [17:0] SRAM_write_block_ver_offset;

//Used for memory addressing with RAM
logic [6:0] S_prime_write_address;
logic [6:0] S_prime_read_address;
logic [6:0] SC_write_address; 
logic [6:0] SC_read_address;
logic [6:0] C_read_address;
logic [6:0] Ct_read_address;

//Used to offset read addressing for coefficient matrix based on which column's partial products are being computed in matrix multiplication
logic [6:0] matrix_mult_col_offset;



//Operands for Multipliers
logic [31:0] mult_1_op_1, mult_1_op_2;
logic [31:0] mult_2_op_1, mult_2_op_2;
logic [31:0] mult_3_op_1, mult_3_op_2;
logic [31:0] mult_4_op_1, mult_4_op_2;

//Output from Multipliers
logic [31:0] mult_1_result;
logic [31:0] mult_2_result;
logic [31:0] mult_3_result;
logic [31:0] mult_4_result;

//Multiply-accumulate unit
logic [31:0] MAC;

//Used to determine multiplier operands based on matrix multiplication stage
logic stage1_matrix_mult;
logic stage2_matrix_mult;

//Holds scaled value from shift from MAC
logic [31:0] MAC_shifted;

//Holds clipped value to be stored as half of one 16 bit location in segment
logic [7:0] MAC_clipped;

logic S_prime_alternate_block;

logic Ct_row_transition;

//States
enum logic [4:0] {
	S_IDLE,
	S_SRAM_READS_0,
	S_SRAM_READS_1,
	S_SRAM_READS_2,
	S_T_MULT_0,
	S_T_MULT_1,
	S_T_MULT_2,
	S_T_MULT_3,
	S_T_MULT_4,
	S_S_MULT_0,
	S_S_MULT_1,
	S_S_MULT_2,
	S_S_MULT_3,
	S_RESET
} state;

//Instantiating 4 Multipliers from module
multiplier_module mult_1 (
    .mult_op_1(mult_1_op_1),
    .mult_op_2(mult_1_op_2),
    .mult_result(mult_1_result)
);

multiplier_module mult_2 (
    .mult_op_1(mult_2_op_1),
    .mult_op_2(mult_2_op_2),
    .mult_result(mult_2_result)
);

multiplier_module mult_3 (
    .mult_op_1(mult_3_op_1),
    .mult_op_2(mult_3_op_2),
    .mult_result(mult_3_result)
);

multiplier_module mult_4 (
    .mult_op_1(mult_4_op_1),
    .mult_op_2(mult_4_op_2),
    .mult_result(mult_4_result)
);

//Instantiating a clipping unit from module
clipping_module unit1 (
    .clip_in(MAC_shifted),
    .clip_out(MAC_clipped)
);


//3 DUAL PORT RAM SETUPS
//RAM_A
logic RAM_A_write_en_0, RAM_A_write_en_1;
logic [6:0] RAM_A_address_0, RAM_A_address_1;
logic [31:0] RAM_A_read_0, RAM_A_read_1;
logic [31:0] RAM_A_write_0, RAM_A_write_1;

//RAM_B
logic RAM_B_write_en_0, RAM_B_write_en_1;
logic [6:0] RAM_B_address_0, RAM_B_address_1;
logic [31:0] RAM_B_read_0, RAM_B_read_1;
logic [31:0] RAM_B_write_0, RAM_B_write_1;

//RAM_C
logic RAM_C_write_en_0, RAM_C_write_en_1;
logic [6:0] RAM_C_address_0, RAM_C_address_1;
logic [31:0] RAM_C_read_0, RAM_C_read_1;
logic [31:0] RAM_C_write_0, RAM_C_write_1;

logic [6:0] S_prime_alternating_read_offset;
logic [6:0] S_prime_alternating_write_offset;

//Testing
logic flag;

//Instantiation of RAM_A
dual_port_RAM_A RAM_A_unit (
	.address_a (RAM_A_address_0),
	.address_b (RAM_A_address_1),
	.clock (Clock_50),
	.data_a (RAM_A_write_0),
	.data_b (RAM_A_write_1),
	.wren_a (RAM_A_write_en_0),
	.wren_b (RAM_A_write_en_1),
	.q_a (RAM_A_read_0),
	.q_b (RAM_A_read_1)
);

//Instantiation of RAM_B
dual_port_RAM_B RAM_B_unit (
	.address_a (RAM_B_address_0),
	.address_b (RAM_B_address_1),
	.clock (Clock_50),
	.data_a (RAM_B_write_0),
	.data_b (RAM_B_write_1),
	.wren_a (RAM_B_write_en_0),
	.wren_b (RAM_B_write_en_1),
	.q_a (RAM_B_read_0),
	.q_b (RAM_B_read_1)
);

//Instantiation of RAM_C
dual_port_RAM_C RAM_C_unit (
	.address_a (RAM_C_address_0),
	.address_b (RAM_C_address_1),
	.clock (Clock_50),
	.data_a (RAM_C_write_0),
	.data_b (RAM_C_write_1),
	.wren_a (RAM_C_write_en_0),
	.wren_b (RAM_C_write_en_1),
	.q_a (RAM_C_read_0),
	.q_b (RAM_C_read_1)
);

//MAC assigned summation of previous partial product and current
assign MAC = matrix_mult_buffer + mult_1_result + mult_2_result + mult_3_result + mult_4_result,
       MAC_shifted = stage1_matrix_mult ? $signed(MAC) >>> 8 : (stage2_matrix_mult ? $signed(MAC) >>> 16 : $signed(MAC));

assign S_prime_alternating_read_offset = S_prime_alternate_block ? 7'd32 : 7'd0;

assign S_prime_alternating_write_offset = S_prime_alternate_block ? 7'd0 : 7'd32;

//Multiplier Operand Assignment based on matrix multiplication stage
always_comb begin
	//Default values
    mult_1_op_1 = 32'd0;
	mult_1_op_2 = 32'd0;
    mult_2_op_1 = 32'd0;
    mult_2_op_2 = 32'd0;
	mult_3_op_1 = 32'd0;
    mult_3_op_2 = 32'd0;
	mult_4_op_1 = 32'd0;
    mult_4_op_2 = 32'd0;

    if (stage1_matrix_mult) begin
        mult_1_op_1 = {{16{RAM_C_read_0[15]}}, RAM_C_read_0[15:0]}; //C lower (C0)
        mult_1_op_2 = {{16{RAM_A_read_0[15]}}, RAM_A_read_0[15:0]}; //S' lower (S'0)

        mult_2_op_1 = {{16{RAM_C_read_0[31]}}, RAM_C_read_0[31:16]}; //C upper (C1)
        mult_2_op_2 = {{16{RAM_A_read_0[31]}}, RAM_A_read_0[31:16]}; //S' upper (S'1)

		mult_3_op_1 = {{16{RAM_C_read_1[15]}}, RAM_C_read_1[15:0]}; //C lower (C2)
		mult_3_op_2 = {{16{RAM_B_read_0[15]}}, RAM_B_read_0[15:0]}; //S' lower (S'2)

		mult_4_op_1 = {{16{RAM_C_read_1[31]}}, RAM_C_read_1[31:16]}; //C upper (C3)
		mult_4_op_2 = {{16{RAM_B_read_0[31]}}, RAM_B_read_0[31:16]}; //S' lower (S'3)

    end else if (stage2_matrix_mult) begin
        mult_1_op_1 = {{16{RAM_C_read_0[15]}}, RAM_C_read_0[15:0]}; //Ct lower (Ct0)
        mult_1_op_2 = RAM_A_read_0; //S'C lower (S'0*C0)

        mult_2_op_1 = {{16{RAM_C_read_0[31]}}, RAM_C_read_0[31:16]}; //Ct upper (Ct1)
        mult_2_op_2 = RAM_A_read_1; //S'C upper (S'1*C1)
		
		mult_3_op_1 = {{16{RAM_C_read_1[15]}}, RAM_C_read_1[15:0]}; //Ct lower (Ct2)
		mult_3_op_2 = RAM_B_read_0; //S'C lower (S'2*C2)

		mult_4_op_1 = {{16{RAM_C_read_1[31]}}, RAM_C_read_1[31:16]}; //Ct upper (Ct3)
		mult_4_op_2 = RAM_B_read_1; //S'C upper (S'3*C3)
    end
	
end



always_ff @(posedge Clock_50 or negedge resetn) begin
	if(resetn == 1'b0) begin
		Milestone_2_finished <= 1'b0;
		state <= S_IDLE;

		SRAM_we_n <= 1'b1;
		SRAM_address_O <= 18'd0;
		SRAM_write_data <= 16'd0;

		//RAM_A
		{RAM_A_write_en_0, RAM_A_write_en_1} <= {2{1'd0}};
		{RAM_A_address_0, RAM_A_address_1} <= {2{7'd0}};
		{RAM_A_write_0, RAM_A_write_1} <= {2{32'd0}};

		//RAM_B
		{RAM_B_write_en_0, RAM_B_write_en_1} <= {2{1'd0}};
		{RAM_B_address_0, RAM_B_address_1} <= {2{7'd0}};
		{RAM_B_write_0, RAM_B_write_1} <= {2{32'd0}};

		//RAM_C
		{RAM_C_write_en_0, RAM_C_write_en_1} <= {2{1'd0}};
		{RAM_C_address_0, RAM_C_address_1} <= {2{7'd0}};
		{RAM_C_write_0, RAM_C_write_1} <= {2{32'd0}};

		//Offsets for Address Reads and Writes
		SRAM_read_col_offset <= 4'd0;
		SRAM_read_row_offset <= 12'd0;
		SRAM_write_col_offset <= 4'd0;
		SRAM_write_row_offset <= 12'd0;

		SRAM_read_block_hor_offset <= 9'd0;
		SRAM_read_block_ver_offset <= 18'd0;
		SRAM_write_block_hor_offset <= 9'd0;
		SRAM_write_block_ver_offset <= 18'd0;

		//Tracking for S, SC, C, and Ct Read & Writes
		{S_prime_write_address, S_prime_read_address} <= {2{7'd0}};
		{SC_write_address, SC_read_address} <= {2{7'd64}};
		{C_read_address, Ct_read_address} <= {2{7'd0}};
		
		//Offset to track column between partial products
		matrix_mult_col_offset <= 7'd0;

		//Buffers
		S_prime_buffer <= 16'd0;
		matrix_mult_buffer <= 32'd0;
		clipped_buffer <= 8'd0;

		//Matrix Multiplication Stage Trackers
		stage1_matrix_mult <= 1'b0;
		stage2_matrix_mult <= 1'b0;

		//Control singnals and flags
		{block_read_complete, block_write_complete, write_next_block} <= {2{1'b0}};

		//Initially read Y first, so set flag high
		read_Y_blocks <= 1'b1;
		read_UV_blocks <= 1'b0;
		YUV_write_en <= 1'b0;

	S_prime_alternate_block <= 1'b0;

	flag <= 1'b0;

	Ct_row_transition <= 1'b0;

	
	end else begin
	
	case(state)

//IDLE State
	S_IDLE: begin
		//If start flag not high, stay in Idle State
		state <= Milestone_2_start ? S_SRAM_READS_0 : S_IDLE;
	end
	
//Lead In SRAM Reads
	S_SRAM_READS_0:begin
		//Enable Read
		SRAM_we_n <= 1'b1;
		SRAM_address_O <= (read_Y_blocks ? Pre_IDCT_Y_offset : Pre_IDCT_U_offset) + SRAM_read_col_offset;

		SRAM_read_col_offset <= SRAM_read_col_offset + 1'd1;

		state <= SRAM_read_col_offset == 4'd2 ? S_SRAM_READS_1 : S_SRAM_READS_0;
	end

//Common Case SRAM read State 1
	S_SRAM_READS_1: begin
		SRAM_address_O <= (read_Y_blocks ? Pre_IDCT_Y_offset : Pre_IDCT_U_offset) + SRAM_read_col_offset + SRAM_read_row_offset;
		//Buffer current SRAM data to be stored in RAM together at next state
		S_prime_buffer <= SRAM_read_data;

		//If Block Read Not complete
		if(~block_read_complete) begin
			//Final Read for first block 
			if ((read_Y_blocks && SRAM_read_col_offset + SRAM_read_row_offset == 12'd2247) || 
			(read_UV_blocks && SRAM_read_col_offset + SRAM_read_row_offset == 12'd1127)) begin
				//Reset all Offsets for next block
				SRAM_read_col_offset <= 4'd0;
                SRAM_read_row_offset <= 12'd0;
				//Offset for second block
				SRAM_read_block_hor_offset <= 9'd8; 

			end else if (SRAM_read_col_offset == 4'd7) begin 
				//Reached end of row for block
				//Must Reset column offset and incrementing row offset for reading of next row in current block
				SRAM_read_col_offset <= 4'd0;
				//Offset for row dependent on what segment being read
				SRAM_read_row_offset <= SRAM_read_row_offset + (read_Y_blocks ? 12'd320 : 12'd160);

			end else begin 
				SRAM_read_col_offset <= SRAM_read_col_offset + 1'd1;
			end
		end

		//Deassert for S_SRAM_READS_2
		{RAM_A_write_en_0, RAM_B_write_en_0} <= {2{1'b0}};

		state <= S_SRAM_READS_2;
	end

//Common Case SRAM read State 2
	S_SRAM_READS_2: begin
		SRAM_address_O <= (read_Y_blocks ? Pre_IDCT_Y_offset : Pre_IDCT_U_offset) + SRAM_read_col_offset + SRAM_read_row_offset;
		
		//Enable Writes for Rams
		{RAM_A_write_en_0, RAM_B_write_en_0} <= {2{1'b1}};
		//Adjusting address for SRAM writes to RAM
		{RAM_A_address_0, RAM_B_address_0} <= {2{S_prime_write_address}};
		//Concatanate the 2 values at one location
		{RAM_A_write_0, RAM_B_write_0} <= {2{SRAM_read_data, S_prime_buffer}};
		//Increment address and offset
        S_prime_write_address <= S_prime_write_address + 1'd1;
		SRAM_read_col_offset <= SRAM_read_col_offset + 1'd1;

		//Block read complete if block offset reaches 8 
		block_read_complete <= SRAM_read_block_hor_offset == 9'd8;

		state <= block_read_complete ? S_T_MULT_0 : S_SRAM_READS_1;
	end
	
//Lead in T computation State 0
	S_T_MULT_0: begin

		{RAM_A_write_en_0, RAM_B_write_en_0} <= {2{1'b0}};
		SRAM_we_n <= 1'b1;
        SRAM_address_O <= SRAM_read_block_hor_offset + SRAM_read_block_ver_offset + (read_Y_blocks ? Pre_IDCT_Y_offset : Pre_IDCT_U_offset);
		SRAM_read_col_offset <= 4'd1;
		SRAM_read_row_offset <= 12'd0;

		//First Matrix Multiplication Setup
		block_read_complete <= 1'b0;
		SC_write_address <= 7'd64;
		state <= S_T_MULT_1;
	end

//Lead in T computation State 1
	S_T_MULT_1: begin

		//Setting up to read S values from RAM A and B
		{RAM_A_write_en_0, RAM_B_write_en_0} <= {2{1'b0}};
		RAM_A_address_0 <= S_prime_alternate_block ? 7'd32 : 7'd0;
		RAM_B_address_0 <= S_prime_alternate_block ? 7'd33 : 7'd1;
		S_prime_read_address <= 7'd2 + S_prime_alternating_read_offset;

		//Setting up to read C values from Port C
		{RAM_C_write_en_0, RAM_C_write_en_1} <= {2{1'b0}};
		RAM_C_address_0 <= 7'd0;
		RAM_C_address_1 <= 7'd1;

		C_read_address <= 7'd2;
		matrix_mult_col_offset <= 7'd0;	
		S_prime_write_address <=  S_prime_alternating_write_offset;
		state <= S_T_MULT_2;
	end

//Lead in T computation State 2
	S_T_MULT_2: begin

		SRAM_address_O <= SRAM_read_block_hor_offset + SRAM_read_block_ver_offset + SRAM_read_col_offset + SRAM_read_row_offset + (read_Y_blocks ? Pre_IDCT_Y_offset : Pre_IDCT_U_offset);
		//Setting up to read S values from RAM A and B
		RAM_A_address_0 <= S_prime_read_address;
		RAM_B_address_0 <= S_prime_read_address + 1'd1;
		S_prime_read_address <= S_prime_read_address + 2'd2;

		//Setting up to read C values from Port C
		RAM_C_address_0 <= C_read_address;
		RAM_C_address_1 <= C_read_address + 1'd1;
		C_read_address <= 7'd0;

		stage1_matrix_mult <= 1'b1;

		SRAM_read_col_offset <= SRAM_read_col_offset + 1'd1;

		state <= S_T_MULT_3;
	end

//First State of General Case for T Computation
	S_T_MULT_3: begin
		
		//S and C Value addressing for RAM's
		RAM_A_address_0 <= S_prime_read_address;
		RAM_B_address_0 <= S_prime_read_address + 1'd1;

		RAM_C_address_0 <= matrix_mult_col_offset;
		RAM_C_address_1 <= matrix_mult_col_offset + 1'd1;
		C_read_address <= matrix_mult_col_offset + 2'd2;
		S_prime_read_address <= S_prime_read_address + 7'd2;

		if (~block_read_complete || ((S_prime_write_address == 7'd63 & ~S_prime_alternate_block) | (S_prime_write_address == 7'd31 & S_prime_alternate_block))) begin
			if(write_next_block) begin
				//Write SRAM to RAM
				{RAM_A_write_en_1, RAM_B_write_en_1} <= {2{1'b1}};
				//Adjusting address for SRAM writes to RAM
				{RAM_A_address_1, RAM_B_address_1} <= {2{S_prime_write_address}};
				//Concatanate the 2 values at one location
				{RAM_A_write_1, RAM_B_write_1} <= {2{SRAM_read_data, S_prime_buffer}};

				S_prime_write_address <= S_prime_write_address + (SC_write_address == 7'd64 ? 7'd0 : 7'd1);
				
				write_next_block <= ~write_next_block;
			end else begin
				write_next_block <= ~write_next_block;
				{RAM_A_write_en_0, RAM_B_write_en_0} <= {2{1'b0}};
				S_prime_buffer <= SRAM_read_data;
			end

			if (SRAM_read_col_offset == 4'd0 && SRAM_read_row_offset == 12'd0) begin
				block_read_complete <= 1'b1;
			end
			
		end
	
		//Buffer first 4 partial products of matrix multiplication
		matrix_mult_buffer <= mult_1_result + mult_2_result + mult_3_result + mult_4_result;
		state <= S_T_MULT_4;
		
	end

//Second State of General Case for T Computation
	S_T_MULT_4: begin

		//If true, end of S_prime Values, so we reset back to 0. Otherwise increment. 
		if ((S_prime_read_address == 7'd30 & ~S_prime_alternate_block) | (S_prime_read_address == 7'd62 & S_prime_alternate_block)) begin
			flag <= 1'b1;
			S_prime_read_address <= S_prime_alternating_read_offset;
			matrix_mult_col_offset <= matrix_mult_col_offset + 7'd4;
		end else begin
			S_prime_read_address <= S_prime_read_address + 7'd2;
		end
		//Enable RAM Reads
		{RAM_A_write_en_0, RAM_B_write_en_0} <= {2{1'b0}};

		//S and C Value addressing for RAM's
		RAM_A_address_0 <= S_prime_read_address;
		RAM_B_address_0 <= S_prime_read_address + 1'd1;
		
		RAM_C_address_0 <= C_read_address;
		RAM_C_address_1 <= C_read_address + 1'd1;
		C_read_address <= matrix_mult_col_offset + 2'd2;

		if (~block_read_complete) begin
			//Enabling read for next S' values for next block
			SRAM_we_n <= 1'b1;
			SRAM_address_O <= SRAM_read_block_hor_offset + SRAM_read_block_ver_offset + SRAM_read_col_offset + SRAM_read_row_offset + (read_Y_blocks ? Pre_IDCT_Y_offset : Pre_IDCT_U_offset);
					
			//Checks for Final Read in Current Block
			if ((read_Y_blocks && SRAM_read_col_offset + SRAM_read_row_offset == 12'd2247) || (read_UV_blocks && SRAM_read_col_offset + SRAM_read_row_offset == 12'd1127)) begin          
				//Reset Offsets for Next Block
				SRAM_read_col_offset <= 4'd0;
				SRAM_read_row_offset <= 12'd0;

				if ((read_Y_blocks && SRAM_read_block_hor_offset == 9'd312) || (read_UV_blocks && SRAM_read_block_hor_offset == 9'd152)) begin
					SRAM_read_block_hor_offset <= 9'd0;
					SRAM_read_block_ver_offset <= SRAM_read_block_ver_offset +  (read_Y_blocks ? 18'd2560 : 18'd1280);  
				end else begin
					SRAM_read_block_hor_offset <= SRAM_read_block_hor_offset + 9'd8;
				end

			//Checks if we're at end of row in current block
			end else if (SRAM_read_col_offset == 4'd7) begin
				//If true, reset column offset, and increment row by segment offset
				SRAM_read_col_offset <= 4'd0;
				SRAM_read_row_offset <= SRAM_read_row_offset + (read_Y_blocks ? 12'd320 : 12'd160);

			end else begin 
				SRAM_read_col_offset <= SRAM_read_col_offset + 1'd1;
			end
		end

		//Buffer last 4 partial products of matrix multiplication and add to previous
		matrix_mult_buffer <= matrix_mult_buffer + mult_1_result + mult_2_result + mult_3_result + mult_4_result;

		//Writes in RAM for S'C product
		{RAM_A_write_en_1, RAM_B_write_en_1} <= {2{1'b1}};
		{RAM_A_address_1, RAM_B_address_1} <= {2{SC_write_address}};
		{RAM_A_write_1, RAM_B_write_1} <= {2{MAC_shifted}};
		SC_write_address <= SC_write_address + 1'd1;

		state <= SC_write_address == 7'd127 ? S_S_MULT_0 : S_T_MULT_3;

	end

//Lead in S computation State 1
	S_S_MULT_0: begin
		stage1_matrix_mult <= 1'b0;
		stage2_matrix_mult <= 1'b1;

		YUV_write_en <= 1'b0;

		//Read enables for T values
		{RAM_A_write_en_0, RAM_A_write_en_1} = {2{1'b0}};
		{RAM_B_write_en_0, RAM_B_write_en_1} = {2{1'b0}};
		//Read addresses for T values
		RAM_A_address_0 <= 7'd64;
		RAM_A_address_1 <= 7'd65;
		RAM_B_address_0 <= 7'd66;
		RAM_B_address_1 <= 7'd67;

		//Read enables for Ct values
		{RAM_C_write_en_0, RAM_C_write_en_1} = {2{1'b0}};
		//Read addresses for Ct values
		RAM_C_address_0 <= 7'd32;
		RAM_C_address_1 <= 7'd33;

		SC_read_address <= 7'd68;
		Ct_read_address <= 7'd34;

		state <= S_S_MULT_1;
	end

//Lead in S computation State 1
	S_S_MULT_1: begin
		//Read addresses for T values
		RAM_A_address_0 <= SC_read_address;
		RAM_A_address_1 <= SC_read_address + 1'd1;
		RAM_B_address_0 <= SC_read_address + 2'd2;
		RAM_B_address_1 <= SC_read_address + 2'd3;

		//Read addresses for Ct values
		RAM_C_address_0 <= Ct_read_address;
		RAM_C_address_1 <= Ct_read_address + 1'd1;

		//Increment read addresses
		SC_read_address <= SC_read_address + 3'd4;
		Ct_read_address <= Ct_read_address + 1'd1;

		state <= S_S_MULT_2;
	end

//S Computation General Case State 1
	S_S_MULT_2:begin
		SRAM_we_n <= 1'b1;

		if (Ct_row_transition) begin
			matrix_mult_col_offset <= matrix_mult_col_offset + 6'd4;
			Ct_read_address <= Ct_read_address + 2'd3;
			RAM_C_address_0 <= Ct_read_address + 1'd1;
			RAM_C_address_1 <= Ct_read_address + 2'd2;
			SC_read_address <= SC_read_address + 3'd4;
		end else begin
			flag <= 1'b0;
			SC_read_address <= SC_read_address + 3'd4;
			Ct_read_address <= matrix_mult_col_offset + 2'd2;
			RAM_C_address_0 <= matrix_mult_col_offset;
			RAM_C_address_1 <= matrix_mult_col_offset + 1'd1;
		end

		RAM_A_address_0 <= SC_read_address;
		RAM_A_address_1 <= SC_read_address + 1'd1;
		RAM_B_address_0 <= SC_read_address + 2'd2;
		RAM_B_address_1 <= SC_read_address + 2'd3;

		if (Ct_row_transition) begin
			SC_read_address <= SC_read_address + 3'd4;
		end

		//Buffering result of current multiplications
        matrix_mult_buffer <= mult_1_result + mult_2_result + mult_3_result + mult_4_result; 

		if (YUV_write_en && ((read_Y_blocks && SRAM_write_col_offset + SRAM_write_row_offset == 12'd1123) || (read_UV_blocks && SRAM_write_col_offset + SRAM_write_row_offset == 12'd563))) begin
			block_write_complete <= 1'b1;
		end

		state <= S_S_MULT_3;
	end

//S Computation General Case State 2
	S_S_MULT_3: begin

		YUV_write_en <= ~YUV_write_en;

		if (YUV_write_en) begin
			SRAM_we_n <= 1'b0;
			SRAM_address_O <= SRAM_write_block_hor_offset + SRAM_write_block_ver_offset + SRAM_write_col_offset + SRAM_write_row_offset + (read_Y_blocks ? 1'd0 : U_offset);
			SRAM_write_data <= {clipped_buffer, MAC_clipped};

			//If true, final write for block initiated in this clock cycle 
			if ((read_Y_blocks && SRAM_write_col_offset + SRAM_write_row_offset == 12'd1123) || (read_UV_blocks && SRAM_write_col_offset + SRAM_write_row_offset == 12'd563)) begin          
				
				//Resetting column and row offsets in preparation for next block write
				SRAM_write_col_offset <= 4'd0;
				SRAM_write_row_offset <= 12'd0;

				if ((read_Y_blocks && SRAM_write_block_hor_offset == 9'd156) || (read_UV_blocks && SRAM_write_block_hor_offset == 9'd76)) begin
					SRAM_write_block_hor_offset <= 9'd0;
					SRAM_write_block_ver_offset <= SRAM_write_block_ver_offset +  (read_Y_blocks ? 18'd1280 : 18'd640);  
				end else begin
					SRAM_write_block_hor_offset <= SRAM_write_block_hor_offset + 9'd4;
				end

			//If true, end of row for current block
			end else if ((read_Y_blocks && SRAM_write_col_offset == 4'd3) || (read_UV_blocks && SRAM_write_col_offset == 4'd3)) begin
				//Resetting column offset and incrementing row offset for writing of next column in current block
				SRAM_write_col_offset <= 4'd0;
				SRAM_write_row_offset <= SRAM_write_row_offset + (read_Y_blocks ? 12'd160 : 12'd80);

			end else begin 
				SRAM_write_col_offset <= SRAM_write_col_offset + 1'd1;
			end

		end	else begin
			clipped_buffer <= MAC_clipped;
		end

		if(SC_read_address == 7'd124) begin
			flag <= 1'b1;
			Ct_row_transition <= 1'b1;
		end else begin
			Ct_row_transition <= 1'b0;

		end

		//Read addresses for T values
		RAM_A_address_0 <= SC_read_address;
		RAM_A_address_1 <= SC_read_address + 1'd1;
		RAM_B_address_0 <= SC_read_address + 2'd2;
		RAM_B_address_1 <= SC_read_address + 2'd3;
		//Increment read addresses
		SC_read_address <= SC_read_address == 7'd124 ? 7'd64 : SC_read_address + 7'd4;

		//Read addresses for Ct values
		RAM_C_address_0 <= Ct_read_address;
		RAM_C_address_1 <= Ct_read_address + 1'd1;
		Ct_read_address <= Ct_read_address + 1'd1;

		state <= block_write_complete ? S_RESET : S_S_MULT_2;
	end

//Reset variables in preperation for next block write
	S_RESET: begin
		SRAM_we_n <= 1'b1;
		stage2_matrix_mult <= 1'b0;
		YUV_write_en <= 1'b0;
		block_read_complete <= 1'b0;
		block_write_complete <= 1'b0;

		S_prime_alternate_block <= ~S_prime_alternate_block;
		
		//Milestone complete flag
		if (SRAM_address_O == 18'd76799) begin 
			Milestone_2_finished <= 1'b1;
			state <= S_IDLE;
		
		//Y segment complete, must repeat for UV
		end else if (SRAM_write_block_ver_offset == 18'd38400) begin 
			read_Y_blocks <= 1'b0;
			read_UV_blocks <= 1'b1;
			
			SRAM_we_n <= 1'b1;
			SRAM_address_O <= 18'd0;
			SRAM_write_data <= 16'd0;

			//RAM_A
			{RAM_A_write_en_0, RAM_A_write_en_1} <= {2{1'd0}};
			{RAM_A_address_0, RAM_A_address_1} <= {2{7'd0}};
			{RAM_A_write_0, RAM_A_write_1} <= {2{32'd0}};

			//RAM_B
			{RAM_B_write_en_0, RAM_B_write_en_1} <= {2{1'd0}};
			{RAM_B_address_0, RAM_B_address_1} <= {2{7'd0}};
			{RAM_B_write_0, RAM_B_write_1} <= {2{32'd0}};

			//RAM_C
			{RAM_C_write_en_0, RAM_C_write_en_1} <= {2{1'd0}};
			{RAM_C_address_0, RAM_C_address_1} <= {2{7'd0}};
			{RAM_C_write_0, RAM_C_write_1} <= {2{32'd0}};

			//Offsets for Address Reads and Writes
			SRAM_read_col_offset <= 4'd0;
			SRAM_read_row_offset <= 12'd0;
			SRAM_write_col_offset <= 4'd0;
			SRAM_write_row_offset <= 12'd0;

			SRAM_read_block_hor_offset <= 9'd0;
			SRAM_read_block_ver_offset <= 18'd0;
			SRAM_write_block_hor_offset <= 9'd0;
			SRAM_write_block_ver_offset <= 18'd0;

			//Tracking for S, SC, C, and Ct Read & Writes
			{S_prime_write_address, S_prime_read_address} <= {2{7'd0}};
			{SC_write_address, SC_read_address} <= {2{7'd64}};
			{C_read_address, Ct_read_address} <= {2{7'd0}};
			
			//Offset to track column between partial products
			matrix_mult_col_offset <= 7'd0;

			//Buffers
			S_prime_buffer <= 16'd0;
			matrix_mult_buffer <= 32'd0;
			clipped_buffer <= 8'd0;

			//Matrix Multiplication Stage Trackers
			stage1_matrix_mult <= 1'b0;
			stage2_matrix_mult <= 1'b0;

			//Control singnals and flags
			{block_read_complete, block_write_complete, write_next_block} <= {2{1'b0}};

			S_prime_alternate_block <= 1'b0;
			Ct_row_transition <= 1'b0;

						
			state <= S_SRAM_READS_0;
			
		end else begin
			state <= S_T_MULT_0;
		end

	end
	
	default: state <= S_IDLE;

	endcase
	end
end
                                                 
endmodule 