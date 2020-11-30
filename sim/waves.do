# activate waveform simulation

view wave

# format signal names in waveform

configure wave -signalnamewidth 1
configure wave -timeline 0
configure wave -timelineunits us

# add signals to waveform

add wave -divider -height 20 {Top-level signals}
add wave -bin UUT/CLOCK_50_I
add wave -bin UUT/resetn
add wave UUT/top_state
add wave -uns UUT/UART_timer

add wave -divider -height 10 {SRAM signals}
add wave -uns UUT/SRAM_address
add wave -hex UUT/SRAM_write_data
add wave -bin UUT/SRAM_we_n
add wave -hex UUT/SRAM_read_data

add wave -divider -height 10 {VGA signals}
# add wave -bin UUT/VGA_unit/VGA_HSYNC_O
# add wave -bin UUT/VGA_unit/VGA_VSYNC_O
# add wave -uns UUT/VGA_unit/pixel_X_pos
# add wave -uns UUT/VGA_unit/pixel_Y_pos
# add wave -hex UUT/VGA_unit/VGA_red
# add wave -hex UUT/VGA_unit/VGA_green
# add wave -hex UUT/VGA_unit/VGA_blue

add wave -hex UUT/Milestone_2_unit/state
add wave -hex UUT/Milestone_2_unit/read_UV_blocks

add wave -divider -height 10 {Write Signals}
add wave -dec UUT/Milestone_2_unit/RAM_A_write_0
add wave -dec UUT/Milestone_2_unit/RAM_A_write_1
add wave -dec UUT/Milestone_2_unit/RAM_B_write_0
add wave -dec UUT/Milestone_2_unit/RAM_B_write_1

add wave -divider -height 10 {Read Signals}
add wave -dec UUT/Milestone_2_unit/RAM_A_read_0
add wave -dec UUT/Milestone_2_unit/RAM_A_read_1
add wave -dec UUT/Milestone_2_unit/RAM_B_read_0
add wave -dec UUT/Milestone_2_unit/RAM_B_read_1
add wave -dec UUT/Milestone_2_unit/RAM_C_read_0
add wave -dec UUT/Milestone_2_unit/RAM_C_read_1

add wave -divider -height 10 {RAM Addressing}
add wave -uns UUT/Milestone_2_unit/RAM_A_address_0
add wave -uns UUT/Milestone_2_unit/RAM_A_address_1
add wave -uns UUT/Milestone_2_unit/RAM_B_address_0
add wave -uns UUT/Milestone_2_unit/RAM_B_address_1
add wave -uns UUT/Milestone_2_unit/RAM_C_address_0
add wave -uns UUT/Milestone_2_unit/RAM_C_address_1
add wave -uns UUT/Milestone_2_unit/Ct_read_address
add wave -uns UUT/Milestone_2_unit/Ct_row_transition
add wave -uns UUT/Milestone_2_unit/SC_read_address
add wave -uns UUT/Milestone_2_unit/flag

add wave -uns UUT/Milestone_2_unit/S_prime_write_address
add wave -uns UUT/Milestone_2_unit/S_prime_read_address
add wave -uns UUT/Milestone_2_unit/SC_write_address

add wave -uns UUT/Milestone_2_unit/matrix_mult_col_offset
add wave -uns UUT/Milestone_2_unit/C_read_address
add wave -hex UUT/Milestone_2_unit/S_prime_buffer
add wave -hex UUT/Milestone_2_unit/matrix_mult_buffer
add wave -divider -height 10 {VGA signals}
add wave -uns UUT/Milestone_2_unit/SRAM_read_col_offset
add wave -uns UUT/Milestone_2_unit/SRAM_read_row_offset
add wave -uns UUT/Milestone_2_unit/SRAM_read_block_ver_offset
add wave -uns UUT/Milestone_2_unit/SRAM_read_block_hor_offset

add wave -divider -height 10 {MAC}
add wave -dec UUT/Milestone_2_unit/mult_1_op_1
add wave -dec UUT/Milestone_2_unit/mult_1_op_2
add wave -dec UUT/Milestone_2_unit/mult_2_op_1
add wave -dec UUT/Milestone_2_unit/mult_2_op_2
add wave -dec UUT/Milestone_2_unit/mult_3_op_1
add wave -dec UUT/Milestone_2_unit/mult_3_op_2
add wave -dec UUT/Milestone_2_unit/mult_4_op_1
add wave -dec UUT/Milestone_2_unit/mult_4_op_2
add wave -divider -height 10 {MAC results}
add wave -dec UUT/Milestone_2_unit/matrix_mult_buffer
add wave -dec UUT/Milestone_2_unit/mult_1_result
add wave -dec UUT/Milestone_2_unit/mult_2_result
add wave -dec UUT/Milestone_2_unit/mult_3_result
add wave -dec UUT/Milestone_2_unit/mult_4_result
add wave -dec UUT/Milestone_2_unit/stage1_matrix_mult
add wave -dec UUT/Milestone_2_unit/stage2_matrix_mult

add wave -divider -height 10 {Buffers for MAC}
add wave -uns UUT/Milestone_2_unit/clipped_buffer
add wave -uns UUT/Milestone_2_unit/MAC_clipped
add wave -dec UUT/Milestone_2_unit/MAC
add wave -dec UUT/Milestone_2_unit/MAC_shifted

add wave -divider -height 10 {VGA signals}
add wave -hex UUT/Milestone_2_unit/stage1_matrix_mult
add wave -hex UUT/Milestone_2_unit/stage2_matrix_mult
add wave -hex UUT/Milestone_2_unit/block_read_complete
add wave -hex UUT/Milestone_2_unit/block_write_complete
