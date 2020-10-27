
vlog -sv -work my_work +define+DISABLE_DEFAULT_NET +define+SIMULATION $rtl/SRAM_controller.sv
vlog -sv -work my_work +define+DISABLE_DEFAULT_NET $rtl/PB_controller.sv
vlog -sv -work my_work +define+DISABLE_DEFAULT_NET $rtl/VGA_controller.sv
vlog -sv -work my_work +define+DISABLE_DEFAULT_NET $rtl/convert_hex_to_seven_segment.sv
vlog -sv -work my_work +define+DISABLE_DEFAULT_NET +define+SIMULATION $rtl/UART_receive_controller.sv
vlog -sv -work my_work +define+DISABLE_DEFAULT_NET $rtl/UART_SRAM_interface.sv
vlog -sv -work my_work +define+DISABLE_DEFAULT_NET $rtl/VGA_SRAM_interface.sv
vlog -sv -work my_work +define+DISABLE_DEFAULT_NET $rtl/experiment4.sv

vlog -sv -work my_work +define+DISABLE_DEFAULT_NET $tb/tb_SRAM_Emulator.sv
vlog -sv -work my_work +define+DISABLE_DEFAULT_NET $tb/testbench.sv
# vlog -sv -work my_work +define+DISABLE_DEFAULT_NET $tb/tb_project_v0.sv
# vlog -sv -work my_work +define+DISABLE_DEFAULT_NET $tb/tb_project_v1.sv

