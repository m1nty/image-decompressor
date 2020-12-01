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
    IDCT_Y_offset = 18'd76800,
    IDCT_U_offset = 18'd153600,
    IDCT_V_offset = 18'd192000;


//Buffers for key values
logic [15:0] S_prime_buffer;
logic [31:0] mmult_buffer;
logic [7:0] clipped_buffer;

//Segement Trackers
logic Y_segment_reads;
logic UV_segment_reads;

//S value write flag
logic S_writes;

//Used to keep track of block r/w operations
logic block_r_finished;
logic block_w_finished;

//Used to alternate next block SRAM writes to RAM
logic alternate_next_block_writes;

//SRAM column r/w offset tracking for memory addressing 
logic [3:0] SRAM_r_column_offset;
logic [3:0] SRAM_w_column_offset;

//SRAM row r/w offset tracking for memory addressing 
logic [11:0] SRAM_r_row_offset;
logic [11:0] SRAM_w_row_offset;

//SRAM horizontal block offset tracking for memory addressing of block computations
logic [8:0] SRAM_r_horizontal_block_offset;
logic [8:0] SRAM_w_horizontal_block_offset;

//SRAM vertical block offset tracking for memory addressing of block computations
logic [17:0] SRAM_r_vertical_block_offset;
logic [17:0] SRAM_w_vertical_block_offset;

//S_prime r/w addressing trackers
logic [6:0] S_prime_w_address;
logic [6:0] S_prime_r_address;

//T r/w addressing trackers
logic [6:0] T_w_address; 
logic [6:0] T_r_address;

//C/Ct read addressing trackers
logic [6:0] C_r_address;
logic [6:0] Ct_r_address;

//Used to offset read addressing for coefficient matrix based on which column's partial products are being computed in matrix multiplication
logic [6:0] mmult_column_offset;

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

//Used to determine multiplier operands based on matrix multiplication stage due to different computations
logic stage1_matrix_mult;
logic stage2_matrix_mult;

//Holds scaled value from shift from MAC
logic [31:0] MAC_shifted;

//Holds clipped value to be stored as half of one 16 bit location in segment
logic [7:0] MAC_clipped;

//Used to alternate S_prime writes every other iteration of general case 
logic S_prime_alternate_block;

//Used to track C Transpose matrix row transitions to ensure offsets are set properly for computations
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
	S_RESET,
	S_DELAY
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

//Instantiating clipping unit from module
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
//MAC_shifted expereinces bit shift which has a magnitude depending on what stage of computation currently in
assign MAC = mmult_buffer + mult_1_result + mult_2_result + mult_3_result + mult_4_result,
       MAC_shifted = stage1_matrix_mult ? $signed(MAC) >>> 8 : (stage2_matrix_mult ? $signed(MAC) >>> 16 : $signed(MAC));

//Assign statement used to hold offsets for alternating S_prime R/W
//Stored at alternating segments in memory to prevent being overwritten
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
        mult_1_op_1 = {{16{RAM_C_read_0[15]}}, RAM_C_read_0[15:0]}; //C0
        mult_1_op_2 = {{16{RAM_A_read_0[15]}}, RAM_A_read_0[15:0]}; //S'0

        mult_2_op_1 = {{16{RAM_C_read_0[31]}}, RAM_C_read_0[31:16]}; //C1
        mult_2_op_2 = {{16{RAM_A_read_0[31]}}, RAM_A_read_0[31:16]}; //S'1

		mult_3_op_1 = {{16{RAM_C_read_1[15]}}, RAM_C_read_1[15:0]}; //C2
		mult_3_op_2 = {{16{RAM_B_read_0[15]}}, RAM_B_read_0[15:0]}; //S'2

		mult_4_op_1 = {{16{RAM_C_read_1[31]}}, RAM_C_read_1[31:16]}; //C3
		mult_4_op_2 = {{16{RAM_B_read_0[31]}}, RAM_B_read_0[31:16]}; //S'3

    end else if (stage2_matrix_mult) begin
        mult_1_op_1 = {{16{RAM_C_read_0[15]}}, RAM_C_read_0[15:0]}; //Ct0
        mult_1_op_2 = RAM_A_read_0; //S'0*C0

        mult_2_op_1 = {{16{RAM_C_read_0[31]}}, RAM_C_read_0[31:16]}; //Ct1
        mult_2_op_2 = RAM_A_read_1; //S'1*C1
		
		mult_3_op_1 = {{16{RAM_C_read_1[15]}}, RAM_C_read_1[15:0]}; //Ct2
		mult_3_op_2 = RAM_B_read_0; //S'2*C2

		mult_4_op_1 = {{16{RAM_C_read_1[31]}}, RAM_C_read_1[31:16]}; //Ct3
		mult_4_op_2 = RAM_B_read_1; //S'3*C3
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

		//Offsets for Address Reads and Writes for SRAM
		SRAM_r_column_offset <= 4'd0;
		SRAM_r_row_offset <= 12'd0;
		SRAM_w_column_offset <= 4'd0;
		SRAM_w_row_offset <= 12'd0;

		SRAM_r_horizontal_block_offset <= 9'd0;
		SRAM_r_vertical_block_offset <= 18'd0;
		SRAM_w_horizontal_block_offset <= 9'd0;
		SRAM_w_vertical_block_offset <= 18'd0;

		//Tracking for S, SC, C, and Ct Read & Writes
		{S_prime_w_address, S_prime_r_address} <= {2{7'd0}};
		{T_w_address, T_r_address} <= {2{7'd64}};
		{C_r_address, Ct_r_address} <= {2{7'd0}};
		
		//Offset to track column between partial products
		mmult_column_offset <= 7'd0;

		//Buffers
		S_prime_buffer <= 16'd0;
		mmult_buffer <= 32'd0;
		clipped_buffer <= 8'd0;

		//Matrix Multiplication Stage Trackers
		stage1_matrix_mult <= 1'b0;
		stage2_matrix_mult <= 1'b0;

		//Completion and alternating flags
		{block_r_finished, block_w_finished, alternate_next_block_writes, S_prime_alternate_block, Ct_row_transition, S_writes} <= {6{1'b0}};

		//Initially read Y first, so flag high
		Y_segment_reads <= 1'b1;
		UV_segment_reads <= 1'b0;
	
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
		//Set address depending on what segment
		SRAM_address_O <= (Y_segment_reads ? IDCT_Y_offset : IDCT_U_offset) + SRAM_r_column_offset;
		//Increment column offset for reading SRAM
		SRAM_r_column_offset <= SRAM_r_column_offset + 1'd1;
		//Iterates 3 times to ensure first SRAM read available in next state iteration
		state <= SRAM_r_column_offset == 4'd2 ? S_SRAM_READS_1 : S_SRAM_READS_0;
	end

//Common Case SRAM read State 1
	S_SRAM_READS_1: begin
		SRAM_address_O <= (Y_segment_reads ? IDCT_Y_offset : IDCT_U_offset) + SRAM_r_column_offset + SRAM_r_row_offset;
		//Buffer current SRAM data to be stored in RAM together at next state
		S_prime_buffer <= SRAM_read_data;

		//If Block Read Not complete
		if(~block_r_finished) begin
			//Final Read for first block 
			if ((Y_segment_reads && SRAM_r_column_offset + SRAM_r_row_offset == 12'd2247) || 
			(UV_segment_reads && SRAM_r_column_offset + SRAM_r_row_offset == 12'd1127)) begin
				//Reset all Offsets for next block
				SRAM_r_column_offset <= 4'd0;
                SRAM_r_row_offset <= 12'd0;
				//Offset for second block
				SRAM_r_horizontal_block_offset <= 9'd8; 

			end else if (SRAM_r_column_offset == 4'd7) begin 
				//Reached end of row for block
				//Must Reset column offset and incrementing row offset for reading of next row in current block
				SRAM_r_column_offset <= 4'd0;
				//Offset for row dependent on what segment being read
				SRAM_r_row_offset <= SRAM_r_row_offset + (Y_segment_reads ? 12'd320 : 12'd160);

			end else begin 
				//Incrememnt column offset
				SRAM_r_column_offset <= SRAM_r_column_offset + 1'd1;
			end
		end

		//Deassert for S_SRAM_READS_2
		{RAM_A_write_en_0, RAM_B_write_en_0} <= {2{1'b0}};

		state <= S_SRAM_READS_2;
	end

//Common Case SRAM read State 2
	S_SRAM_READS_2: begin
		SRAM_address_O <= (Y_segment_reads ? IDCT_Y_offset : IDCT_U_offset) + SRAM_r_column_offset + SRAM_r_row_offset;
		
		//Enable Writes for Rams
		{RAM_A_write_en_0, RAM_B_write_en_0} <= {2{1'b1}};
		//Adjusting address for SRAM writes to RAM
		{RAM_A_address_0, RAM_B_address_0} <= {2{S_prime_w_address}};
		//Concatanate the 2 values at one location
		{RAM_A_write_0, RAM_B_write_0} <= {2{SRAM_read_data, S_prime_buffer}};
		//Increment address and offset
        S_prime_w_address <= S_prime_w_address + 1'd1;
		SRAM_r_column_offset <= SRAM_r_column_offset + 1'd1;

		//Block read complete if block offset reaches 8 
		block_r_finished <= SRAM_r_horizontal_block_offset == 9'd8;

		//If reads are finished for first block, proceed to first matrix multiplication state
		state <= block_r_finished ? S_T_MULT_0 : S_SRAM_READS_1;
	end
	
//Lead in T computation State 0
	S_T_MULT_0: begin

		//Set SRAM address to correspond to segment for future block writes
		{RAM_A_write_en_0, RAM_B_write_en_0} <= {2{1'b0}};
		SRAM_we_n <= 1'b1;
        SRAM_address_O <= SRAM_r_horizontal_block_offset + SRAM_r_vertical_block_offset + (Y_segment_reads ? IDCT_Y_offset : IDCT_U_offset);
		SRAM_r_column_offset <= 4'd1;
		SRAM_r_row_offset <= 12'd0;

		//First Matrix Multiplication Setup
		block_r_finished <= 1'b0;
		T_w_address <= 7'd64;
		state <= S_T_MULT_1;
	end

//Lead in T computation State 1
	S_T_MULT_1: begin

		//Setting up to read S values from RAM A and B
		{RAM_A_write_en_0, RAM_B_write_en_0} <= {2{1'b0}};
		RAM_A_address_0 <= S_prime_alternate_block ? 7'd32 : 7'd0;
		RAM_B_address_0 <= S_prime_alternate_block ? 7'd33 : 7'd1;
		S_prime_r_address <= 7'd2 + S_prime_alternating_read_offset;

		//Setting up to read C values from Port C
		{RAM_C_write_en_0, RAM_C_write_en_1} <= {2{1'b0}};
		RAM_C_address_0 <= 7'd0;
		RAM_C_address_1 <= 7'd1;

		C_r_address <= 7'd2;
		mmult_column_offset <= 7'd0;	
		//Alternating offset used to set the s_prime write address
		S_prime_w_address <=  S_prime_alternating_write_offset;
		state <= S_T_MULT_2;
	end

//Lead in T computation State 2
	S_T_MULT_2: begin

		SRAM_address_O <= SRAM_r_horizontal_block_offset + SRAM_r_vertical_block_offset + SRAM_r_column_offset + SRAM_r_row_offset + (Y_segment_reads ? IDCT_Y_offset : IDCT_U_offset);
		//Setting up to read S values from RAM A and B
		RAM_A_address_0 <= S_prime_r_address;
		RAM_B_address_0 <= S_prime_r_address + 1'd1;
		S_prime_r_address <= S_prime_r_address + 2'd2;

		//Setting up to read C values from Port C
		RAM_C_address_0 <= C_r_address;
		RAM_C_address_1 <= C_r_address + 1'd1;
		C_r_address <= 7'd0;

		stage1_matrix_mult <= 1'b1;

		SRAM_r_column_offset <= SRAM_r_column_offset + 1'd1;

		state <= S_T_MULT_3;
	end

//First State of General Case for T Computation
	S_T_MULT_3: begin
		
		//S' and C Value addressing and increments for RAM's
		RAM_A_address_0 <= S_prime_r_address;
		RAM_B_address_0 <= S_prime_r_address + 1'd1;

		RAM_C_address_0 <= mmult_column_offset;
		RAM_C_address_1 <= mmult_column_offset + 1'd1;
		C_r_address <= mmult_column_offset + 2'd2;
		S_prime_r_address <= S_prime_r_address + 7'd2;

		if (~block_r_finished || ((S_prime_w_address == 7'd63 & ~S_prime_alternate_block) | (S_prime_w_address == 7'd31 & S_prime_alternate_block))) begin
			if(alternate_next_block_writes) begin
				//Write SRAM to RAM
				{RAM_A_write_en_1, RAM_B_write_en_1} <= {2{1'b1}};
				//Adjusting address for SRAM writes to RAM
				{RAM_A_address_1, RAM_B_address_1} <= {2{S_prime_w_address}};
				//Concatanate the 2 values at one location
				{RAM_A_write_1, RAM_B_write_1} <= {2{SRAM_read_data, S_prime_buffer}};
				//If at final write address, do not incrememnt
				S_prime_w_address <= S_prime_w_address + (T_w_address == 7'd64 ? 7'd0 : 7'd1);
				//Ensure flag is negated to alternate the above computation
				alternate_next_block_writes <= ~alternate_next_block_writes;
			end else begin
				//Ensure flag is negated to alternate the above computation
				alternate_next_block_writes <= ~alternate_next_block_writes;
				{RAM_A_write_en_0, RAM_B_write_en_0} <= {2{1'b0}};
				//Buffer data in preperation for next iteration to be written
				S_prime_buffer <= SRAM_read_data;
			end

			if (SRAM_r_column_offset == 4'd0 && SRAM_r_row_offset == 12'd0) begin
				//Offsets reset in S_T_MULT_4
				block_r_finished <= 1'b1;
			end
			
		end
	
		//Buffer first 4 partial products of matrix multiplication
		mmult_buffer <= mult_1_result + mult_2_result + mult_3_result + mult_4_result;
		state <= S_T_MULT_4;
		
	end

//Second State of General Case for T Computation
	S_T_MULT_4: begin

		//If true, end of S_prime Values, so we reset back to 0. Otherwise increment. 
		if ((S_prime_r_address == 7'd30 & ~S_prime_alternate_block) | (S_prime_r_address == 7'd62 & S_prime_alternate_block)) begin
			S_prime_r_address <= S_prime_alternating_read_offset;
			mmult_column_offset <= mmult_column_offset + 7'd4;
		end else begin
			S_prime_r_address <= S_prime_r_address + 7'd2;
		end
		//Enable RAM Reads
		{RAM_A_write_en_0, RAM_B_write_en_0} <= {2{1'b0}};

		//S and C Value addressing for RAM's
		RAM_A_address_0 <= S_prime_r_address;
		RAM_B_address_0 <= S_prime_r_address + 1'd1;
		
		RAM_C_address_0 <= C_r_address;
		RAM_C_address_1 <= C_r_address + 1'd1;
		C_r_address <= mmult_column_offset + 2'd2;

		if (~block_r_finished) begin
			//Enabling read for next S' values for next block
			SRAM_we_n <= 1'b1;
			SRAM_address_O <= SRAM_r_horizontal_block_offset + SRAM_r_vertical_block_offset + SRAM_r_column_offset + SRAM_r_row_offset + (Y_segment_reads ? IDCT_Y_offset : IDCT_U_offset);
					
			//Checks for Final Read in Current Block
			if ((Y_segment_reads && SRAM_r_column_offset + SRAM_r_row_offset == 12'd2247) || (UV_segment_reads && SRAM_r_column_offset + SRAM_r_row_offset == 12'd1127)) begin          
				//Reset Offsets for Next Block
				SRAM_r_column_offset <= 4'd0;
				SRAM_r_row_offset <= 12'd0;

				//Check to see if offsets have reached max values depending on segments (final read offsets)
				if ((Y_segment_reads && SRAM_r_horizontal_block_offset == 9'd312) || (UV_segment_reads && SRAM_r_horizontal_block_offset == 9'd152)) begin
					SRAM_r_horizontal_block_offset <= 9'd0;
					SRAM_r_vertical_block_offset <= SRAM_r_vertical_block_offset +  (Y_segment_reads ? 18'd2560 : 18'd1280);  
				end else begin
					SRAM_r_horizontal_block_offset <= SRAM_r_horizontal_block_offset + 9'd8;
				end

			//Checks if we're at end of row in current block
			end else if (SRAM_r_column_offset == 4'd7) begin
				//If true, reset column offset, and increment row by segment offset
				SRAM_r_column_offset <= 4'd0;
				SRAM_r_row_offset <= SRAM_r_row_offset + (Y_segment_reads ? 12'd320 : 12'd160);

			end else begin 
				SRAM_r_column_offset <= SRAM_r_column_offset + 1'd1;
			end
		end

		//Buffer last 4 partial products of matrix multiplication and add to previous
		mmult_buffer <= mmult_buffer + mult_1_result + mult_2_result + mult_3_result + mult_4_result;

		//Writes in RAM for S'C product
		{RAM_A_write_en_1, RAM_B_write_en_1} <= {2{1'b1}};
		{RAM_A_address_1, RAM_B_address_1} <= {2{T_w_address}};
		{RAM_A_write_1, RAM_B_write_1} <= {2{MAC_shifted}};
		T_w_address <= T_w_address + 1'd1;

		state <= T_w_address == 7'd127 ? S_S_MULT_0 : S_T_MULT_3;

	end

//Lead in S computation State 1
	S_S_MULT_0: begin
		stage1_matrix_mult <= 1'b0;
		stage2_matrix_mult <= 1'b1;

		S_writes <= 1'b0;

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

		T_r_address <= 7'd68;
		Ct_r_address <= 7'd34;

		state <= S_S_MULT_1;
	end

//Lead in S computation State 1
	S_S_MULT_1: begin
		//Read addresses for T values
		RAM_A_address_0 <= T_r_address;
		RAM_A_address_1 <= T_r_address + 1'd1;
		RAM_B_address_0 <= T_r_address + 2'd2;
		RAM_B_address_1 <= T_r_address + 2'd3;

		//Read addresses for Ct values
		RAM_C_address_0 <= Ct_r_address;
		RAM_C_address_1 <= Ct_r_address + 1'd1;

		//Increment read addresses
		T_r_address <= T_r_address + 3'd4;
		Ct_r_address <= Ct_r_address + 1'd1;

		state <= S_S_MULT_2;
	end

//S Computation General Case State 1
	S_S_MULT_2:begin
		SRAM_we_n <= 1'b1;

		if (Ct_row_transition) begin
			//If CT row transition is high it means we are in a new row of this matrix and must correct addressing
			mmult_column_offset <= mmult_column_offset + 6'd4;
			Ct_r_address <= Ct_r_address + 2'd3;
			RAM_C_address_0 <= Ct_r_address + 1'd1;
			RAM_C_address_1 <= Ct_r_address + 2'd2;
			T_r_address <= T_r_address + 3'd4;
		end else begin
			//Increment addressing normally for same row computation
			T_r_address <= T_r_address + 3'd4;
			Ct_r_address <= mmult_column_offset + 2'd2;
			RAM_C_address_0 <= mmult_column_offset;
			RAM_C_address_1 <= mmult_column_offset + 1'd1;
		end

		//Addressing Increment for T values
		RAM_A_address_0 <= T_r_address;
		RAM_A_address_1 <= T_r_address + 1'd1;
		RAM_B_address_0 <= T_r_address + 2'd2;
		RAM_B_address_1 <= T_r_address + 2'd3;

		if (Ct_row_transition) begin
			T_r_address <= T_r_address + 3'd4;
		end

		//Buffering result of current multiplications
        mmult_buffer <= mult_1_result + mult_2_result + mult_3_result + mult_4_result; 

		if (S_writes && ((Y_segment_reads && SRAM_w_column_offset + SRAM_w_row_offset == 12'd1123) || (UV_segment_reads && SRAM_w_column_offset + SRAM_w_row_offset == 12'd563))) begin
			block_w_finished <= 1'b1;
		end

		state <= S_S_MULT_3;
	end

//S Computation General Case State 2
	S_S_MULT_3: begin

		//Negate flag to alternate S value writes
		S_writes <= ~S_writes;

		if (S_writes) begin
			SRAM_we_n <= 1'b0;
			SRAM_address_O <= SRAM_w_horizontal_block_offset + SRAM_w_vertical_block_offset + SRAM_w_column_offset + SRAM_w_row_offset + (Y_segment_reads ? 1'd0 : U_offset);
			SRAM_write_data <= {clipped_buffer, MAC_clipped};

			//If true, final write for block initiated in this clock cycle 
			if ((Y_segment_reads && SRAM_w_column_offset + SRAM_w_row_offset == 12'd1123) || (UV_segment_reads && SRAM_w_column_offset + SRAM_w_row_offset == 12'd563)) begin          
				
				//Resetting column and row offsets in preparation for next block write
				SRAM_w_column_offset <= 4'd0;
				SRAM_w_row_offset <= 12'd0;

				if ((Y_segment_reads && SRAM_w_horizontal_block_offset == 9'd156) || (UV_segment_reads && SRAM_w_horizontal_block_offset == 9'd76)) begin
					SRAM_w_horizontal_block_offset <= 9'd0;
					SRAM_w_vertical_block_offset <= SRAM_w_vertical_block_offset +  (Y_segment_reads ? 18'd1280 : 18'd640);  
				end else begin
					SRAM_w_horizontal_block_offset <= SRAM_w_horizontal_block_offset + 9'd4;
				end

			//If true, end of row for current block
			end else if ((Y_segment_reads && SRAM_w_column_offset == 4'd3) || (UV_segment_reads && SRAM_w_column_offset == 4'd3)) begin
				//Resetting column offset and incrementing row offset for writing of next column in current block
				SRAM_w_column_offset <= 4'd0;
				SRAM_w_row_offset <= SRAM_w_row_offset + (Y_segment_reads ? 12'd160 : 12'd80);

			end else begin 
				SRAM_w_column_offset <= SRAM_w_column_offset + 1'd1;
			end

		end	else begin
			//Store clipped value in buffer until needed for writing on next iteration
			clipped_buffer <= MAC_clipped;
		end

		//Ct row transition determination
		if(T_r_address == 7'd124) begin
			Ct_row_transition <= 1'b1;
		end else begin
			Ct_row_transition <= 1'b0;

		end

		//Read addresses for T values
		RAM_A_address_0 <= T_r_address;
		RAM_A_address_1 <= T_r_address + 1'd1;
		RAM_B_address_0 <= T_r_address + 2'd2;
		RAM_B_address_1 <= T_r_address + 2'd3;
		//Increment read addresses
		T_r_address <= T_r_address == 7'd124 ? 7'd64 : T_r_address + 7'd4;

		//Read addresses for Ct values
		RAM_C_address_0 <= Ct_r_address;
		RAM_C_address_1 <= Ct_r_address + 1'd1;
		Ct_r_address <= Ct_r_address + 1'd1;

		state <= block_w_finished ? S_RESET : S_S_MULT_2;
	end

//Reset variables in preperation for next block writes and segments. 
	S_RESET: begin
		SRAM_we_n <= 1'b1;
		stage2_matrix_mult <= 1'b0;
		S_writes <= 1'b0;
		block_r_finished <= 1'b0;
		block_w_finished <= 1'b0;

		S_prime_alternate_block <= ~S_prime_alternate_block;
		
		//Milestone complete flag
		if (SRAM_address_O == 18'd76799) begin 
			Milestone_2_finished <= 1'b1;
			state <= S_DELAY;
		
		//Y segment complete, must repeat for UV
		end else if (SRAM_w_vertical_block_offset == 18'd38400) begin 
			Y_segment_reads <= 1'b0;
			UV_segment_reads <= 1'b1;
			
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
			SRAM_r_column_offset <= 4'd0;
			SRAM_r_row_offset <= 12'd0;
			SRAM_w_column_offset <= 4'd0;
			SRAM_w_row_offset <= 12'd0;

			SRAM_r_horizontal_block_offset <= 9'd0;
			SRAM_r_vertical_block_offset <= 18'd0;
			SRAM_w_horizontal_block_offset <= 9'd0;
			SRAM_w_vertical_block_offset <= 18'd0;

			//Tracking for S, SC, C, and Ct Read & Writes
			{S_prime_w_address, S_prime_r_address} <= {2{7'd0}};
			{T_w_address, T_r_address} <= {2{7'd64}};
			{C_r_address, Ct_r_address} <= {2{7'd0}};
			
			//Offset to track column between partial products
			mmult_column_offset <= 7'd0;

			//Buffers
			S_prime_buffer <= 16'd0;
			mmult_buffer <= 32'd0;
			clipped_buffer <= 8'd0;

			//Matrix Multiplication Stage Trackers
			stage1_matrix_mult <= 1'b0;
			stage2_matrix_mult <= 1'b0;

			//Control singnals and flags
			{block_r_finished, block_w_finished, alternate_next_block_writes} <= {2{1'b0}};

			S_prime_alternate_block <= 1'b0;
			Ct_row_transition <= 1'b0;

						
			state <= S_SRAM_READS_0;
			
		end else begin
			state <= S_T_MULT_0;
		end

	end
	
	S_DELAY: begin
		UV_segment_reads <= 1'b0; //reset UV segment read flag
		Y_segment_reads <= 1'b1; //resets Y segment read flag
		state <= S_IDLE;
	end
	
	default: state <= S_IDLE;

	endcase
	end
end
                                                 
endmodule 