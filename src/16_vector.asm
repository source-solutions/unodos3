;	// UnoDOS 3 - A disk operating system for the divMMC SD card interface.
;	// Copyright (c) 2017-2026 Source Solutions, Inc.

;	// UnoDOS 3 is free software: you can redistribute it and/or modify
;	// it under the terms of the GNU General Public License as published by
;	// the Free Software Foundation, either version 3 of the License, or
;	// (at your option) any later version.
;	// 
;	// UnoDOS 3 is distributed in the hope that it will be useful,
;	// but WITHOUT ANY WARRANTY; without even the implied warranty of
;	// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;	// GNU General Public License for more details.
;	// 
;	// You should have received a copy of the GNU General Public License
;	// along with UnoDOS 3. If not, see <http://www.gnu.org/licenses/>.

;	// vector table for 'dot' commands
	org $1FCA
v_errror_code_4:
	jp error_code_4;					// error code 4 - "Disk full"

v_error_code_2:
	org $1FCD
	jp error_code_2;					// error code 2 - "File not found"

	org $1FD0
v_pr_str:
	jp pr_str;							// print string routine

	org $1FD3
v_format_decimal_10k:
	jp format_decimal_10k;				// numeric display routine

	org $1FD6
v_format_file_size:
	jp format_file_size;				// file size display routine

	org $1FD9
v_open_screen_channel:
	jp open_screen_channel;				// screen channel open 

	org $1FDC
v_call_expression_eval:
	jp call_expression_eval;			// expression evaluation routine 

	org $1FDF
v_save_accumulator_flag:
	jp save_accumulator_flag;			// save accumulator flag routine

	org $1FE2
v_call_rom_routine_c1:
	jp call_rom_routine_c1;				// ROM routine C1

	org $1FE5
v_error_handler_setup:
	jp error_handler_setup;				// error handler setup routine

	org $1FE8
v_load_file_state_flag:
	jp load_file_state_flag;			// load file state flag routine

	org $1FEB
v_load_file_state_again:
	jp load_file_state_again;			// load file state again routine

	org $1FEE
v_pr_msg:
	jp pr_msg;							// message print routine

	org $1FF1
v_delay_routine:
	jp delay_routine;					// delay routine

	org $1ff4
interrupt_cleanup_exit:
	ex (sp), hl;						// exchange HL with top of stack
	jr unmap_and_return;				// jump to unmap routine
	ei;									// enable interrupts

;	// A jump to 1FF8 - 1FFF unmaps divMMC ROM/RAM when M1 goes high
direct_unmap_return:
	ret;								// return (causes divMMC unmap on M1)

	ei;									// enable interrupts

;	// Jump from RST $18 handler to return to a system ROM routine whose address has 
;	// been placed in the stack
;	// Also called from taps.io
unmap_and_return:
	ret;								// return to ROM routine (unmaps divMMC)

jump_unmap_hl:
	jp (hl);							// jump to address in HL (with divMMC unmapped)
	rst $38;							// mask interrupt (filler)
	rst $38;							// mask interrupt (filler)
	rst $38;							// mask interrupt (filler)
	rst $38;							// mask interrupt (filler)
