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

;	org $23a5
tk_overloads:
	defb 0, 0, 0, 0, 0; 				// TOKENs that invoke BFILE.SYS
	defb "bfile";						// command name for BFILE.SYS
	defb 0, 0, 0;						// TOKENs that invoke BDIR.SYS
	defb "bdir";						// command name for BDIR.SYS
	defb 0, 0;							// TOKENs that invoke TAPE.SYS
	defb "tape";						// command name for TAPE.SYS
	defb 0;								// end marker
	defb "errors";						// command name for error reporting
	defb 0;								// end marker

;	// Function: Load message pointer
alt_load_message_pointer:
	ld hl, $23b8;						// load message table address
	jr memory_address_compare;			// jump to address comparison

;	// Function: Process command with register preservation
process_command_preserve:
	push hl;							// save HL register
	push de;							// save DE register
	push bc;							// save BC register
	call alt_load_message_pointer;		// call message processing
	pop bc;								// restore BC register
	pop de;								// restore DE register
	pop hl;								// restore HL register
	ld a, ixl;							// load IX low byte
	ld ($3df8), a;						// store result code
	ld a, $1a;							// load error code $1A
	ret;								// return with error

;	// Function: Process file extension
advance_past_period:
	inc hl;								// advance past period character
	push hl;							// save extension pointer
	ld hl, cmd_folder;					// load folder command string
	ld de, $2dce;						// load destination buffer
	ld bc, 5;							// copy 5 bytes
	ldir;								// copy folder command
	pop hl;								// restore extension pointer
	ld c, $20;							// set space character limit

;	// Function: Parse extension characters
load_extension_char:
	ld a, (hl);							// load character from extension
	cp ' ';								// compare with space character
	jr z, check_space_char;				// jump if space found
	rst $18;							// call ROM routine
	defw pr_st_end;						// check for string end
	jr z, check_space_char;				// jump if end of string

	ldi;								// copy character and increment
	jp po, check_space_char;			// jump if byte count expired
	jr load_extension_char;				// continue parsing characters

check_space_char:
	cp ' ';								// $20
	jr nz, set_char_pointer_alt;		// jump if not space character
	inc hl;								// advance past space
	ld ($2e46), hl;						// save command position

load_command_char:
	ld a, (hl);							// load character from command
	rst $18;							// call ROM routine
	defw pr_st_end;						// check for string end
	jr z, set_character_pointer;		// jump if end of string

	inc hl;								// advance to next character
	jr load_command_char;				// continue scanning

set_character_pointer:
	ld (ch_add), hl;					// set character pointer
	ld hl, ($2e46);						// load saved pointer
	jr store_pointer_later;				// jump to completion

set_char_pointer_alt:
	ld (ch_add), hl;					// set character pointer
	ld hl, 0;							// clear HL register

store_pointer_later:
	ld ($2e46), hl;						// store pointer for later use

external_command_entry equ $241b

;	// Function: Process command and handle errors
	call call_rom_routine_c1;			// call command processor
	call clear_null_terminator;			// call error handler
	jp nc, memory_init_routine;			// jump if no error
	cp 5;								// check for specific error code
	jp nz, restart_20;					// restart system if not error 5
	ld a, $16;							// load error code $16
	rst $20;							// call error handler

;	// Function: Initialize string terminator and open file
clear_null_terminator:
	xor a;								// clear accumulator (null terminator)
	ld (de), a;							// store null terminator at DE

;	// Function: Process file path and open
call_path_processing:
	call set_max_length_15;				// call path processing function
	ld a, $24;							// load file handle $24
	ld hl, $2dce;						// load filename buffer address
	ld b, 1;							// set mode to read
	rst $08;							// call DOS function
	defb f_open;						// open file operation
	ret;								// return with open result

cmd_folder_setup:
	ld a, ($3df8);						// load current drive state
	ld ($3df0), a;						// save drive state for operation
	push hl;							// save HL register
	ld hl, cmd_folder;					// load folder command string
	ld de, $2dce;						// load destination buffer
	ld bc, 5;							// copy 5 bytes
	ldir;								// copy folder command
	pop hl;								// restore HL register

;	// Function: Copy filename characters until space
load_filename_char:
	ld a, (hl);							// load character from filename
	inc hl;								// advance source pointer
	cp ' ';								// compare with space character
	jr z, save_current_position;		// jump if space found
	ld (de), a;							// store character in buffer
	inc de;								// advance destination pointer
	jr load_filename_char;				// continue copying characters

;	// Function: Complete filename processing
save_current_position:
	ld ($2e46), hl;						// save current position
	call clear_null_terminator;			// call file processing function
	ret c;								// return if error
	push af;							// save accumulator
	ld a, 2;							// load mode value 2
	ld ($3df8), a;						// store mode value
	ld hl, ($2e46);						// load saved pointer
	ld de, $3d00;						// load buffer address
	push de;							// save buffer address
	rst $30;							// call ROM routine
	inc b;								// increment B register
	pop hl;								// restore buffer address to HL
	pop af;								// restore accumulator
	jp memory_cleanup_with_hl;			// jump to completion handler

;	// Function: Process path string with length check
set_max_length_15:
	ld b, $0f;							// set maximum length to 15
	ld hl, $2e22;						// load path buffer address

;	// Function: Scan path characters
load_path_char:
	ld a, (hl);							// load character from path
	and a;								// test for null terminator
	jr z, advance_next_char;			// jump if null found
	push hl;							// save path pointer
	push bc;							// save BC register
	rst $08;							// call DOS function
	defb f_close;						// close file operation
	pop bc;								// restore BC register
	pop hl;								// restore HL register

;	// Function: Increment path pointer and check bounds
advance_next_char:
	inc hl;								// advance to next character
	djnz load_path_char;				// continue loop if counter not zero
	ret;								// return from function

dirs_io_entry equ $248a

;	// called from dirs.io
;	// Function: Process directory command (called from dirs.io)
call_expression_eval:
	call call_rom_rst18;				// call expression evaluation
	ret z;								// return if zero result
	ld a, c;							// load C register value
	or b;								// test if BC is zero
	jp z, error_code_19;				// jump to error handler if zero
	ex de, hl;							// exchange DE and HL
	ld de, $2d4e;						// load destination buffer address
	ldir;								// copy string to buffer
	xor a;								// clear accumulator
	ld (de), a;							// add null terminator
	ret;								// return from function

;	// Function: Evaluate BASIC expression
call_rom_rst18:
	rst $18;							// call ROM routine
	defw expt_exp;						// expect expression
	rst $30;							// call calculator
	inc bc;								// increment BC
	ret z;								// return if zero
	push af;							// save accumulator
	rst $18;							// call ROM routine
	defw stk_fetch;						// fetch from calculator stack
	pop af;								// restore accumulator
	ret;								// return from function

;	// Function: Parameter processing (called from dirs.io)
save_accumulator_flag:
	push af;							// save accumulator
	rst $30;							// call calculator
	ld (bc), a;							// store result at BC
	cp $64;								// compare with 'd' character
	jp nz, error_code_11;				// jump if not 'd'
	rst $30;							// call calculator
	ld (bc), a;							// store result at BC
	jp z, error_code_11;				// jump if zero
	sub $30;							// convert ASCII to numeric (subtract '0')
	and 7;								// mask to 3 bits (0-7)
	ld c, a;							// store masked value in C
	pop af;								// restore accumulator
	sla a;								// shift left (multiply by 2)
	sla a;								// shift left (multiply by 4)
	sla a;								// shift left (multiply by 8)
	or c;								// combine with lower bits
	ret;								// return combined value

;	// Function: Get character and process commands (called from dirs.io)
call_rom_routine_c1:
	rst $18;							// call ROM routine
	defw get_char;						// get current character

;	// Function: Check for string end
call_rom_routine_c4:
	rst $18;							// call ROM routine
	defw pr_st_end;						// check for program/string end
	jp nz, error_code_3;				// jump if not at end
	rst $30;							// call calculator
	inc bc;								// increment BC
	ret nz;								// return if not zero

;	// Function: Set up error handling (called from dirs.io)
error_handler_setup:
	ld sp, (err_sp);					// restore error stack pointer
	ld (iy + 0), $ff;					// set system flag to $FF
	ld hl, $1bf4;						// load error handler address
	rst $30;							// call calculator
	inc bc;								// increment BC
	jp z, jump_unmap_hl;				// jump to system function if zero
	ld hl, $1b7d;						// load alternate handler address
	jp jump_unmap_hl;					// jump to system function
	ld a, 1;							// load error code 1
	rst $20;							// call error handler

;	// Function: File error handler (called from files.io)
error_code_2:
	ld a, 2;							// load error code 2
	rst $20;							// call error handler

;	// Function: Command processing error
error_code_3:
	ld a, 3;							// load error code 3
	rst $20;							// call error handler

;	// Function: Parameter error
error_code_11:
	ld a, $0B;							// load error code 11 ($0B)
	rst $20;							// call error handler

;	// Function: Invalid argument error
error_code_19:
	ld a, $13;							// load error code 19 ($13)
	rst $20;							// call error handler

;	// Function: File operation error (called from files.io)
error_code_4:
	ld a, 4;							// load error code 4
	rst $20;							// call error handler

;	// called from dirs.io
;	// Function: File close with state management (called from dirs.io)
load_file_state_flag:
	ld a, ($2e32);						// load file state flag
	push af;							// save state flag
	ld a, 0;							// clear accumulator
	ld ($2e32), a;						// clear file state flag
	pop af;								// restore original state
	rst $08;							// call DOS function
	defb f_close;						// close file operation
	ret;								// return from function

;	// called from dirs.io
;	// Function: Conditional file close (called from dirs.io)
load_file_state_again:
	ld a, ($2e32);						// load file state flag
	and a;								// test if flag is set
	ret z;								// return if no file open
	push bc;							// save BC register
	push de;							// save DE register
	call load_file_state_flag;			// call file close function
	pop de;								// restore DE register
	pop bc;								// restore BC register
	ret;								// return from function

;	// Function: Close file using BASIC system variable
load_basic_newppc:
	ld a, (iy + _newppc);				// load BASIC system variable
	rst $08;							// call DOS function
	defb f_close;						// close file operation
	ret;								// return from function

;	// Function: Graphics character validation and processing
save_char_in_ixh:
	ld ixh, a;							// save character in IXH
	and $E0;							// mask upper 3 bits
	cp $60;								// compare with graphics character range
	scf;								// set carry flag (error condition)
	ret nz;								// return with error if not graphics
	ld a, ixh;							// restore original character
	and $F8;							// mask to graphics subset
	push bc;							// save BC register
	push af;							// save processed character
	ld ($3dea), de;						// save pointer for later use
	push bc;							// save BC register
	ld de, $2d4e;						// load filename buffer address
	push de;							// save buffer address
	rst $30;							// call calculator
	dec b;								// decrement B register
	pop hl;								// restore buffer address to HL
	pop bc;								// restore BC register
	ld a, c;							// load C register value
	ld b, 3;							// set mode to read/write
	rst $08;							// call DOS function
	defb f_open;						// open file operation
	jr nc, save_file_handle;			// jump if successful
	pop bc;								// clean up stack
	pop bc;								// clean up stack
	ret;								// return with error

save_file_handle:
	ld ($2D4D), a;						// save file handle
	ld hl, $2df2;						// load file status buffer
	rst $08;							// call DOS function
	defb f_fstat;						// get file status
	pop af;								// restore accumulator
	call check_handle_limit;			// call system function
	ld hl, $1a95;						// load address value
	ld (iy + 2), l;						// store low byte in IY+2
	ld (iy + 3), h;						// store high byte in IY+3
	pop bc;								// restore BC register
	call load_page_address;				// call validation function
	jr nc, load_b_register_flags;		// jump if no error
	call load_screen0_address;			// call alternate validation
	jr nc, load_b_register_flags;		// jump if no error
	ld c, 3;							// load error code 3

;	// Function: Process file attributes and flags
load_b_register_flags:
	ld a, b;							// load B register (flags)
	and 7;								// mask lower 3 bits
	or c;								// combine with C register
	or b;								// combine with full B register
	ld (iy + 1), a;						// store combined flags in IY+1
	ld a, c;							// load C register value
	ld hl, $2df9;						// load data buffer address
	rst $30;							// call ROM routine
	ld bc, $f4cd;						// load immediate value
	dec h;								// adjust high byte
	ld l, a;							// set low byte from A
	dec l;								// adjust shift count
	rst $30;							// call ROM routine
	dec c;								// decrement counter
	jr z, save_iy_register;				// jump if zero
	ld h, 0;							// clear overflow counter

;	// Function: Multi-precision right shift with overflow tracking
shift_right_b:
	srl b;								// shift right B register
	rr c;								// rotate right C register
	rr d;								// rotate right D register
	rr e;								// rotate right E register
	rl h;								// rotate left H (collect overflow)
	dec l;								// decrement shift counter
	jr nz, shift_right_b;				// repeat until done
	ld a, h;							// load overflow bits
	and a;								// test for overflow
	call nz, inc_32bit;					// handle overflow if present

save_iy_register:
	push iy;							// save IY register
	pop hl;								// transfer IY to HL
	ld a, 4;							// load offset value
	add a, l;							// add offset to low byte
	ld l, a;							// store adjusted address
	rst $30;							// call ROM routine
	nop;								// padding/alignment
	ld a, ($2d4d);						// load file handle
	ld (iy + _newppc), a;				// store handle in system variable
	ld a, ixl;							// load drive number
	ld ($3df8), a;						// store current drive
	ld de, ($3dea);						// load saved pointer
	ld hl, final_virtual_disk_string;	// load routine address
	rst $30;							// call ROM routine
	inc b;								// increment B register
	ld a, (iy + 0);						// load flags from system area
	or a;								// test flags
	ret;								// return with status

;	// Function: Load and validate memory page
load_page_address:
	ld de, $0800;						// load page address
	call save_bc_register;				// call page loading function
	ret c;								// return if error
	ld a, ($3ee7);						// load system flag
	cp $10;								// compare with expected value
	ld c, 2;							// load result code
	ret z;								// return if match

;	// Function: Set error flag and return
set_error_carry:
	scf;								// set carry flag for error
	ret;								// return with error

;	// Function: Load screen memory and validate
load_screen0_address:
	ld de, $4000;						// load screen 0 address
	call save_bc_register;				// call memory loading function
	ret c;								// return if error
	ld a, ($3e00);						// load directory header byte
	cp $FF;								// check for valid directory marker
	ret nz;								// return if not directory
	ld hl, $3e09;						// load signature start address
	ld a, (hl);							// load first signature character
	cp $44;								// check for 'D'
	jr nz, set_error_carry;				// jump to error if not 'D'
	inc l;								// advance to next character
	ld a, (hl);							// load second signature character
	cp $49;								// check for 'I'  
	jr nz, set_error_carry;				// jump to error if not 'I'
	inc l;								// advance to next character
	ld a, (hl);							// load third signature character
	cp $52;								// check for 'R' (completing "DIR")
	jr nz, set_error_carry;				// jump to error if not 'R'
	ld c, 2;							// load success code
	ret;								// return successfully

;	// Function: Seek and read file operation
save_bc_register:
	push bc;							// save BC register
	ld bc, 0;							// set seek position to 0
	ld l, c;							// set L to 0
	ld a, ($2d4d);						// load file handle
	push af;							// save file handle
	rst $08;							// call DOS function
	defb f_seek;						// seek to position
	pop af;								// restore file handle
	ld hl, $3e00;						// load buffer address
	ld bc, $0200;						// read 512 bytes
	rst $08;							// call DOS function
	defb f_read;						// read file operation
	pop bc;								// restore BC register  
	ret;								// return with read result

;	// Function: Setup for multi-precision arithmetic
	ld h, a;							// load high byte
	ld l, 0;							// clear low byte
	ld a, 7;							// load shift count

;	// Function: Multi-precision right shift with overflow collection
shift_right_b_reg:
	srl b;								// shift right B register
	rr c;								// rotate right C register
	rr d;								// rotate right D register
	rr e;								// rotate right E register

disk_sector_buffer equ $ - 1
	rl l;								// rotate left L (collect overflow)
	dec a;								// decrement shift counter
	jr nz, shift_right_b_reg;			// repeat until counter zero
	ld a, l;							// load accumulated overflow
	and a;								// test for overflow bits
	ld a, h;							// load high byte for overflow check
	call nz, inc_32bit;					// call overflow handler if bits set
	ret;								// return from shift function

final_virtual_disk_string:
	defb "Virtual Disk", 0;				// null-terminated string constant

lower_end:
