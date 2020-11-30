/* 
McMaster University
3DQ5 Project 2020
Milestone 1

Jack Wawrychuk - 400145293
Minhaj Shah - 400119266
*/

`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

module Milestone_1 (

	input logic Clock_50,
	input logic resetn,
	input logic [15:0] SRAM_read_data,
	input logic Milestone_1_start,
	
	output logic [15:0] SRAM_write_data,
	output logic SRAM_we_n,
	output logic [17:0] SRAM_address_O,
	output logic Milestone_1_finished
);

//Registers to store current address's for YUV segments
logic [17:0] RGB_address;
logic [17:0] Y_address;
logic [17:0] U_address;
logic [17:0] V_address;

//Registers to hold RGB values
logic [31:0] R_data; 
logic [31:0] G_data;
logic [31:0] B_data;
logic [31:0] B_buff;
 
logic [15:0] Y_data;

//Registers to hold odd pixel data
logic [23:0] U_prime;
logic [23:0] V_prime;

//Flags to check if values are stored
logic stored_U;
logic stored_V;

//Flag to check if we are on first iteration of common case for each row
logic first_case;

//Register to track what pixel we're on
logic [16:0]pixel_count;

//Registers to hold data used for U prime
logic [7:0] U_neg5;
logic [7:0] U_neg3; 
logic [7:0] U_neg1; 
logic [7:0] U_pos1; 
logic [7:0] U_pos3; 
logic [7:0] U_pos5;  

//Stores U data for even pixels
logic [7:0] U_even;

//Register to hold stored U data, when SRAM is not being read
logic [7:0] U_buff;

//Register to hold accumulated data from MAC unit
logic [31:0] U_accum;

//Same logic here for V, instead of U
logic [7:0] V_neg5;
logic [7:0] V_neg3; 
logic [7:0] V_neg1; 
logic [7:0] V_pos1; 
logic [7:0] V_pos3; 
logic [7:0] V_pos5; 

logic [7:0] V_even;
logic [7:0] V_buff;

logic [31:0] V_accum;


//States
enum logic [4:0] {
	S_IDLE,
	S_LEAD_I_1,
	S_LEAD_I_2,
	S_LEAD_I_3,
	S_LEAD_I_4,
	S_LEAD_I_5,
	S_LEAD_I_6,
	S_LEAD_I_7,
	S_COMMONCASE_1,
	S_COMMONCASE_2,
	S_COMMONCASE_3,
	S_COMMONCASE_4,
	S_COMMONCASE_5,
	S_COMMONCASE_6,
	S_LEAD_O_1,
	S_LEAD_O_2,
	S_DELAY
} state;

//Multiplier 1
logic[31:0]Mult_1_op1,Mult_1_op2,Mult_1_result;
logic[63:0]Mult_1_result_long;

assign Mult_1_result_long = Mult_1_op1*Mult_1_op2;
assign Mult_1_result = Mult_1_result_long[31:0];


//Muliplier 2
logic[31:0]Mult_2_op1,Mult_2_op2,Mult_2_result;
logic[63:0]Mult_2_result_long;

assign Mult_2_result_long = Mult_2_op1*Mult_2_op2;
assign Mult_2_result = Mult_2_result_long[31:0];


//Multiplier 3
logic[31:0]Mult_3_op1,Mult_3_op2,Mult_3_result;
logic[63:0]Mult_3_result_long;

assign Mult_3_result_long = Mult_3_op1*Mult_3_op2;
assign Mult_3_result = Mult_3_result_long[31:0];


//Multiplier 4
logic[31:0]Mult_4_op1,Mult_4_op2,Mult_4_result;
logic[63:0]Mult_4_result_long;

assign Mult_4_result_long = Mult_4_op1*Mult_4_op2;
assign Mult_4_result = Mult_4_result_long[31:0];


always_ff @(posedge Clock_50 or negedge resetn) begin
	if(~resetn) begin
	
		state <= S_IDLE;
		
		RGB_address <= 18'b0;
		Y_address <= 18'b0;
		U_address <= 18'b0;
		V_address <= 18'b0;

		R_data <= 32'b0; 
		G_data <= 32'b0;
		B_data <= 32'b0;
		B_buff <= 32'b0;

		Y_data <= 16'b0;
		U_prime <= 24'b0;
		V_prime <= 24'b0;
		
		stored_U <= 1'b0;
		stored_V <= 1'b0;
		first_case <= 1'b0;
		pixel_count <= 17'b0;
		
		Mult_1_op1 <= 32'b0;
		Mult_1_op2 <= 32'b0;
		Mult_2_op1 <= 32'b0;
		Mult_2_op2 <= 32'b0;
		Mult_3_op1 <= 32'b0;
		Mult_3_op2 <= 32'b0;
		Mult_4_op1 <= 32'b0;
		Mult_4_op2 <= 32'b0;
		
		
		U_neg5 <= 8'b0;
		U_neg3 <= 8'b0; 
		U_neg1 <= 8'b0; 
		U_pos1 <= 8'b0; 
		U_pos3 <= 8'b0; 
		U_pos5 <= 8'b0;  
		U_even <= 8'b0;
		U_buff <= 8'b0;
		
		//Initialized to 128, due to constant term in equation
		U_accum <= 32'd128;
		
		V_neg5 <= 8'b0;
		V_neg3 <= 8'b0; 
		V_neg1 <= 8'b0; 
		V_pos1 <= 8'b0; 
		V_pos3 <= 8'b0; 
		V_pos5 <= 8'b0; 
		V_even <= 8'b0;
		V_buff <= 8'b0;
		
		//Initialized to 128, due to constant term in equation
		V_accum <= 32'd128;
				
		SRAM_write_data <= 16'b0;
		SRAM_we_n <= 1'b1;
		SRAM_address_O <= 18'b0;
		Milestone_1_finished <= 1'b0;
	
	end else begin
	
	case(state)
	S_IDLE: begin
	
		//Starting addresses corresponding to SRAM Memory Map Segments
		RGB_address <= 18'd146944;
		Y_address <= 18'b0;
		U_address <= 18'd38400;
		V_address <= 18'd57600;
		
		SRAM_we_n <= 1'b1;
		
		//Flag recieved from top level FSM to determine when UART is completed
		if(Milestone_1_start == 1'b1)
			state <= S_LEAD_I_1;
		
	end
	S_LEAD_I_1:begin
		pixel_count <= 17'd0;
		SRAM_we_n <= 1'b1;
		//Read in first U address
		SRAM_address_O <= U_address;
		U_address <= U_address + 18'b1;
		
		
		//Constant 128 term
		U_accum <= 32'd128; 
		V_accum <= 32'd128;
		
		state <= S_LEAD_I_2;
		
	end
	S_LEAD_I_2: begin
		
		SRAM_address_O <= U_address;
		U_address <= U_address + 18'b1;
		
		state <= S_LEAD_I_3;
		
	end
	S_LEAD_I_3: begin
	
		SRAM_address_O <= V_address;
		V_address <= V_address + 18'b1;
		
		state <= S_LEAD_I_4;
	
	end
	S_LEAD_I_4: begin
	
		SRAM_address_O <= V_address;
		V_address <= V_address + 18'b1;
		
		//Repeated U values to replace data from prevous rows
		U_neg5 <= SRAM_read_data[15:8];
		U_neg3 <= SRAM_read_data[15:8];
		U_neg1 <= SRAM_read_data[15:8];
		U_pos1 <= SRAM_read_data[7:0];
		
		U_even <= SRAM_read_data[15:8];
		
		state <= S_LEAD_I_5;
	
	end
	S_LEAD_I_5: begin
		
		U_pos3 <= SRAM_read_data[15:8];
		U_pos5 <= SRAM_read_data[7:0];
		
		state <= S_LEAD_I_6;
		
	end
	S_LEAD_I_6: begin
		
		SRAM_address_O <= Y_address;
		Y_address <= Y_address + 18'b1;
		
		//Repeated U values to replace data from prevous rows
		V_neg5 <= SRAM_read_data[15:8];
		V_neg3 <= SRAM_read_data[15:8];
		V_neg1 <= SRAM_read_data[15:8];
		V_pos1 <= SRAM_read_data[7:0];
		
		V_even <= SRAM_read_data[15:8];
		
		state <= S_LEAD_I_7;
		
	end
	S_LEAD_I_7: begin
	
		V_pos3 <= SRAM_read_data[15:8];
		V_pos5 <= SRAM_read_data[7:0];
		
		first_case <= 1'b1;
		
		state <= S_COMMONCASE_1;
		
	end
	S_COMMONCASE_1: begin
		
		//Multipliers initialized with corresponding equation terms
		Mult_1_op1 <= 32'd21;
		Mult_1_op2 <= U_neg5;
		
		Mult_2_op1 <= 32'd52;
		Mult_2_op2 <= U_neg3;
		
		Mult_3_op1 <= 32'd159;
		Mult_3_op2 <= U_neg1;
		
		Mult_4_op1 <= 32'd159;
		Mult_4_op2 <= U_pos1;
		
		//First iteration of Common Case, values do not exist to write to SRAM
		if(first_case == 1'b0) begin
			//Not in First iteration, of common case
			
			SRAM_address_O <= RGB_address;
			RGB_address <= RGB_address + 1'b1;
			
			//Computing G data based on multiplier results from Common Case 6
			G_data <= G_data - Mult_1_result - Mult_2_result;
			
			SRAM_we_n <= 1'b0;
			
			
			//Edge Case Checks
			//If RGB pixel data is less than 0, Set to 0
			//If RGB pixel data is greater than 255, set to 255
			
			//Checking if value is positive
			if(B_buff[31] == 1'b0 ) begin
				
				//Checking if value is positive
				if(R_data[31] == 1'b0) begin
				
					//Checking if value exceeds 255
					if(|(B_buff[30:24])) begin
					
						//Checking if value exceeds 255
						if(|(R_data[30:24]))
							//Write 255
							SRAM_write_data <= {8'hff,8'hff};
						else
							//Otherwise write data
							SRAM_write_data <= {8'hff,R_data[23:16]};
							
					end else	if(|(R_data[30:24]))	
						SRAM_write_data <= {B_buff[23:16],8'hff};
					else
						SRAM_write_data <= {B_buff[23:16],R_data[23:16]};
					
				
				end else
					//If value negative, write 0
					SRAM_write_data <= {B_buff[23:16],8'b0};
				
			//Blue data negative. Checking if R data is positive		
			end else if(R_data[31] == 1'b0) begin
				//Write the R data
				SRAM_write_data <= {8'b0,R_data[23:16]};
				
			end else begin
				//Write 0 if negative
				SRAM_write_data <= {8'b0,8'b0};
				
			end
		
			//Shift V data to compute in next V' 
			V_neg5 <= V_neg3;
			V_neg3 <= V_neg1;
			V_neg1 <= V_pos1;
			V_pos1 <= V_pos3;
			V_pos3 <= V_pos5;
		
			//If close to end of row, then we repeat values so no overflow to next row values
			//If data already buffered, from previous case, then use this data
			
			//No buffered data, and not close to end of row, so we read data from SRAM
			if(pixel_count < 17'd313 && stored_V == 1'b1)
				V_pos5 <= SRAM_read_data[15:8];
				
			//Buffered data, and not close to end of row, so we use buffered data from register
			else if(stored_V == 1'b0 && pixel_count < 17'd313) begin
				V_pos5 <= V_buff;
			
			//Close to end of the row, so we repeat data to avoid using data for next row
			end else if(pixel_count > 17'd313)
				V_pos5 <= V_pos5;
			
			//Shift in the data for register j/2 for the even case
			V_even <= V_pos1;
			
			//Buffers data, only read from every second common case because
			//So we read in 8 MSB's, and save 8 LSB's for next common case
			V_buff <= SRAM_read_data[7:0];
			
			//Reset to 128
			V_accum <= 31'd128;
		end
		
		state <= S_COMMONCASE_2;
		
	end
	S_COMMONCASE_2: begin
		
		Y_data <= SRAM_read_data;
		
		
		
		//First iteration of Common Case, values do not exist to write to SRAM
		if(first_case == 1'b0) begin
			
			SRAM_address_O <= RGB_address;
			RGB_address <= RGB_address + 1'b1;
			
			SRAM_we_n <= 1'b0;
			
			
			//Edge Case Checks
			//If RGB pixel data is less than 0, Set to 0
			//If RGB pixel data is greater than 255, set to 255
			if(G_data[31] == 1'b0 ) begin
		
				if(B_data[31] == 1'b0) begin 
				
					if(|(G_data[30:24])) begin
					
						if(|(B_data[30:24])) 
							SRAM_write_data <= {8'hff,8'hff};
						else
							SRAM_write_data <= {8'hff,B_data[23:16]};
							
					end else	if(|(B_data[30:24]))	
						SRAM_write_data <= {G_data[23:16],8'hff};
					else
						SRAM_write_data <= {G_data[23:16],B_data[23:16]};
					
				
				end else
					SRAM_write_data <= {G_data[23:16],8'b0};
					
			end else if(B_data[31] == 1'b0) begin
			
				SRAM_write_data <= {8'b0,B_data[23:16]};
				
			end else begin
			
				SRAM_write_data <= {8'b0,8'b0};
				
			end
			
		end
		
		//Multipliers initialized with corresponding equation terms
		Mult_1_op1 <= 32'd52;
		Mult_1_op2 <= U_pos3;
		
		Mult_2_op1 <= 32'd21;
		Mult_2_op2 <= U_pos5;
		
		Mult_3_op1 <= 32'd21;
		Mult_3_op2 <= V_neg5;
		
		Mult_4_op1 <= 32'd52;
		Mult_4_op2 <= V_neg3;
		
		//Accumulate partial products
		U_accum <= U_accum + Mult_1_result - Mult_2_result + Mult_3_result + Mult_4_result;
		
		state <= S_COMMONCASE_3;
		
	end
	S_COMMONCASE_3:begin
	
		SRAM_we_n <= 1'b1;
		
		//If close to end of row, then we repeat values so no overflow to next row values
		//Don't need to read new addresses, because recycled data being utilized since we're at end of row
		if(pixel_count < 17'd313 && stored_U == 1'b0) begin
			SRAM_address_O <= U_address;
			U_address <= U_address + 18'b1;
			
			stored_U <= 1'b1;
		end else if(stored_U == 1'b1)
			stored_U <= 1'b0;
			
		//Multipliers initialized with corresponding equation terms
		Mult_1_op1 <= 32'd159;
		Mult_1_op2 <= V_neg1;
		
		Mult_2_op1 <= 32'd159;
		Mult_2_op2 <= V_pos1;
		
		Mult_3_op1 <= 32'd52;
		Mult_3_op2 <= V_pos3;
		
		Mult_4_op1 <= 32'd21;
		Mult_4_op2 <= V_pos5;
		
		//Accumulate partial products
		U_accum <= U_accum - Mult_1_result + Mult_2_result;
		V_accum <= V_accum + Mult_3_result - Mult_4_result;
		
		state <= S_COMMONCASE_4;
		
	end
	S_COMMONCASE_4: begin
		
		//If close to end of row, then we repeat values so no overflow to next row values
		//Don't need to read new addresses, because recycled data being utilized since we're at end of row
		if(pixel_count < 17'd313 && stored_V == 1'b0) begin
			SRAM_address_O <= V_address;
			V_address <= V_address + 18'b1;
			stored_V <= 1'b1;
		end else if(stored_V == 1'b1)
			stored_V <= 1'b0;
		
		//Multipliers initialized with corresponding equation terms
		Mult_1_op1 <= 32'd76284;
		Mult_1_op2 <= Y_data[15:8] - 8'd16;
		
		Mult_2_op1 <= 32'd104595;
		Mult_2_op2 <= V_even - 8'd128;
		
		Mult_3_op1 <= 32'd25624;
		Mult_3_op2 <=  U_even - 8'd128;
		
		Mult_4_op1 <= 32'd53281;
		Mult_4_op2 <=  V_even - 8'd128;
		
		U_prime <= U_accum[31:8];
		
		//Accumulate partial products
		V_accum <= V_accum + Mult_1_result + Mult_2_result - Mult_3_result + Mult_4_result;
		
		state <= S_COMMONCASE_5;
		
	end
	S_COMMONCASE_5: begin 
		pixel_count <= pixel_count + 17'd2;
		SRAM_address_O <= Y_address;
		Y_address <= Y_address + 18'b1;
		
		//Multipliers initialized with corresponding equation terms
		Mult_1_op1 <= 32'd132251;
		Mult_1_op2 <=  U_even - 8'd128;
		
		Mult_2_op1 <= 32'd76284;
		Mult_2_op2 <=  Y_data[7:0] - 8'd16;
		
		Mult_3_op1 <= 32'd104595;
		Mult_3_op2 <=  V_accum[31:8] - 8'd128;
		
		Mult_4_op1 <= 32'd132251;
		Mult_4_op2 <=  U_prime - 8'd128;
		
		//Accumulate partial products for RGB Data
		R_data <= Mult_1_result + Mult_2_result;
		G_data <= Mult_1_result - Mult_3_result - Mult_4_result;
		B_data <= Mult_1_result;
		
		V_prime <= V_accum[31:8];
		
		
		state <= S_COMMONCASE_6;
		
	end
	S_COMMONCASE_6: begin
		
		
		//End of Common Case, so we reset this flag
		if(first_case == 1'b1)
			first_case <= 1'b0;
			
		SRAM_address_O <= RGB_address;
		RGB_address <= RGB_address + 18'b1;
		
		//Activate Write enable
		SRAM_we_n <= 1'b0;
			
		//Edge Case Checks
		//If RGB pixel data is less than 0, Set to 0
		//If RGB pixel data is greater than 255, set to 255
		if(R_data[31] == 1'b0 ) begin
		
			if(G_data[31] == 1'b0) begin 
				
				if(|(R_data[30:24])) begin
				
					if(|(G_data[30:24])) 
						SRAM_write_data <= {8'hff,8'hff};
					else
						SRAM_write_data <= {8'hff,G_data[23:16]};
						
				end else	if(|(G_data[30:24]))	
					SRAM_write_data <= {R_data[23:16],8'hff};
				else
					SRAM_write_data <= {R_data[23:16],G_data[23:16]};
				
			
			end else
				SRAM_write_data <= {R_data[23:16],8'b0};
				
		end else if(G_data[31] == 1'b0) begin
		
			SRAM_write_data <= {8'b0,G_data[23:16]};
			
		end else begin
		
			SRAM_write_data <= {8'b0,8'b0};
			
		end
			

		//Multipliers initialized with corresponding equation terms
		Mult_1_op1 <= 32'd25624;
		Mult_1_op2 <=  U_prime - 8'd128;
		
		Mult_2_op1 <= 32'd53281;
		Mult_2_op2 <=  V_prime - 8'd128;
		
		//Accumulate partial products for RGB Data
		R_data <= Mult_2_result + Mult_3_result;
		G_data <= Mult_2_result;
		B_data <= Mult_2_result + Mult_4_result;
		//Buffers B data so not overwritten, before written to SRAM memory
		B_buff <= B_data + Mult_1_result;
		
		//Shift U data to compute in next U' 
		U_neg5 <= U_neg3;
		U_neg3 <= U_neg1;
		U_neg1 <= U_pos1;
		U_pos1 <= U_pos3;
		U_pos3 <= U_pos5;
		
		//If close to end of row, then we repeat values so no overflow to next row values
		//Don't need to read new addresses, because recycled data being utilized since we're at end of row
		
		//No buffered data, and not close to end of row, so we read data from SRAM
		if(pixel_count < 17'd313 && stored_U == 1'b1) 
			U_pos5 <= SRAM_read_data[15:8];
			
		//Buffered data, and not close to end of row, so we use buffered data from register
		else if(stored_U == 1'b0 && pixel_count < 17'd313) begin
			U_pos5 <= U_buff;
			
		//Close to end of the row, so we repeat data to avoid using data for next row
		end else if(pixel_count > 17'd313)
			U_pos5 <= U_pos5;
		
		//Shift in the data for register j/2 for the even case
		U_even <= U_pos1;
		
		//Buffers data, only read from every second common case because
		//So we read in 8 MSB's, and save 8 LSB's for next common case
		U_buff <= SRAM_read_data[7:0];
		U_accum <= 31'd128;
		
		//If we are at end of row, we are at Lead Out State, otherwise, back to common case
		if(pixel_count > 17'd318)
			state <= S_LEAD_O_1;
		else
			state <= S_COMMONCASE_1;
		
	end
	
	S_LEAD_O_1: begin
	
		SRAM_address_O <= RGB_address;
		RGB_address <= RGB_address + 1'b1;
			
		SRAM_we_n <= 1'b0;		
			
		//Edge Case Checks
		//If RGB pixel data is less than 0, Set to 0
		//If RGB pixel data is greater than 255, set to 255
		if(B_buff[31] == 1'b0 ) begin
		
			if(R_data[31] == 1'b0) begin
			
				if(|(B_buff[30:24])) begin
				
					if(|(R_data[30:24]))
						SRAM_write_data <= {8'hff,8'hff};
					else
						SRAM_write_data <= {8'hff,R_data[23:16]};
						
				end else	if(|(R_data[30:24]))	
					SRAM_write_data <= {B_buff[23:16],8'hff};
				else
					SRAM_write_data <= {B_buff[23:16],R_data[23:16]};
				
			
			end else
				SRAM_write_data <= {B_buff[23:16],8'b0};
			
				
		end else if(R_data[31] == 1'b0) begin
		
			SRAM_write_data <= {8'b0,R_data[23:16]};
			
		end else begin
		
			SRAM_write_data <= {8'b0,8'b0};
			
		end
		
		G_data <= G_data - Mult_1_result - Mult_2_result;	
		
		state <= S_LEAD_O_2;
		
	end
	S_LEAD_O_2: begin
		
		SRAM_address_O <= RGB_address;
		RGB_address <= RGB_address + 1'b1;
		
		//Corrections for addresses to ensure right values for next row
		Y_address <= Y_address - 18'd1;
		U_address <= U_address - 18'd1;
		V_address <= V_address - 18'd1;
		SRAM_we_n <= 1'b0;		
			
		//Edge Case Checks
		//If RGB pixel data is less than 0, Set to 0
		//If RGB pixel data is greater than 255, set to 255
		if(G_data[31] == 1'b0 ) begin
		
			if(B_data[31] == 1'b0) begin 
			
				if(|(G_data[30:24])) begin
				
					if(|(B_data[30:24])) 
						SRAM_write_data <= {8'hff,8'hff};
					else
						SRAM_write_data <= {8'hff,B_data[23:16]};
						
				end else	if(|(B_data[30:24]))	
					SRAM_write_data <= {G_data[23:16],8'hff};
				else
					SRAM_write_data <= {G_data[23:16],B_data[23:16]};
				
			
			end else
				SRAM_write_data <= {G_data[23:16],8'b0};
				
		end else if(B_data[31] == 1'b0) begin
		
			SRAM_write_data <= {8'b0,B_data[23:16]};
			
		end else begin
		
			SRAM_write_data <= {8'b0,8'b0};
			
		end

	
		//If we are not at end of SRAM we go back to Lead In State, otherwise we are finished milestone and we go back to IDLE state
		if(RGB_address < 18'd262143)
			state <= S_LEAD_I_1;
		else begin
			state <= S_DELAY;
			Milestone_1_finished <= 1'b1;
		end
			
	end
	S_DELAY: begin
		state <= S_IDLE;
	end
	
	default: state <= S_IDLE;

	endcase
	end
end
                                                 
endmodule 