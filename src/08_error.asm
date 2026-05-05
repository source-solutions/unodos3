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

;	// based on the Spectrum ROM's main_4 / main_g routine
error_handler_entry:
	ld (err_nr), a;						// get error number
	res 5, (iy + _flags);				// no new key
	ld sp, (err_sp);					// error stack pointer to SP
	rst $18;							// call BASIC ROM routine
	defw syntax_z;						// check if in syntax check mode
	ld hl, $16c5;						// BASIC command loop address
	jp z, jump_unmap_hl;				// if syntax check, unmap and return to BASIC
	ld hl, 0;							// used to zero out system variables
	ld (iy + _flag_x), h;				// clear flag_x
	ld (iy + _x_ptr_h), h;				// clear x_ptr to hide error marker
	ld (defadd), hl;					// set no function to evaluate
	inc l;								// LD L, 1
	ld (strms_0), hl;					// keyboard stream
	rst $18;							// call BASIC ROM routine
	defw set_min;						// set minimum values
	ld a, (nmiadd);						// get NMI routine address
	and a;								// test if NMI routine is set
	jp nz, error_handler_setup;			// if NMI set, handle differently
	res 5, (iy + _flag_x);				// no new key
	rst $18;							// call BASIC ROM routine
	defw cls_lower;						// clear lower screen
	set 5, (iy + _tv_flag);				// set TV flag bit 5
	res 3, (iy + _tv_flag);				// clear TV flag bit 3
	ld a, (err_nr);						// get error number
	and a;								// test if zero (no error)
	ld hl, ($3de8);						// get default message address
	jr z, print_error_message;			// if no error, print default message
	ld b, a;							// save error number in B

handle_error_message:
	ld a, ($3df9);						// get current divMMC page
	push af;							// save current page
	xor a;								// select page 0
	out (mmcram), a;					// divMMC memory page 0
	ld hl, $23bd;						// point to error message table
	push bc;							// save error number
	call memory_address_compare;		// find error message
	pop bc;								// restore error number
	jr nc, use_basic_error;				// if message found, use it
	cp $0c;								// check for specific error code
	jr nz, handle_unknown_error;		// if not, try generic error
	ld hl, $0caa;						// point to "Too many open files" message
	jr print_error_message;				// print message

handle_unknown_error:
	ld a, b;							// get error number
	cp 1;								// check if error number is 1
	jr z, use_basic_error;				// if so, use BASIC ROM message
	ld hl, $0c9c;						// point to "UnoDOS error #" message
	call v_pr_msg;						// print error prefix
	ld l, b;							// put error number in L
	call format_number_suppress_zeros;	// print error number (05_api.asm)
	jr restore_page_and_exit;			// restore page and exit

use_basic_error:
	ld hl, ($2017);						// get BASIC ROM error message table

find_error_message:
	bit 7, (hl);						// check if end of message
	inc hl;								// advance to next character
	jr z, find_error_message;			// continue until end of message
	djnz find_error_message;			// repeat for B messages

print_error_message:
	call v_pr_msg;						// print error message

restore_page_and_exit:
	pop af;								// restore divMMC page
	out (mmcram), a;					// set divMMC RAM page
	inc sp;								// adjust stack pointer (skip return address)
	inc sp;								// adjust stack pointer (complete skip)
	ld hl, $1349;						// BASIC editor address
	jp jump_unmap_hl;					// unmap and return to BASIC

;	// called from files.io
;	org $0c90
pr_msg:
	ld a, (hl);							// get character from message
	cp $7f;								// check if bit 7 set (end marker)
	push af;							// save character and flags
	and $7f;							// mask off bit 7
	rst $10;							// print a character
	pop af;								// restore character and flags
	ret nc;								// return if bit 7 not set (end of message)
	inc hl;								// advance to next character
	jr pr_msg;							// continue printing

;	dbtb "UnoDOS error #";				// Zeus - string with terminal bit 7 set
	str "UnoDOS error #";				// RASM - string with terminal bit 7 set

;	dbtb "Too many open files";			// Zeus - string with terminal bit 7 set
	str "Too many open files";			// RASM - string with terminal bit 7 set

;	// jumped from RST $18 (CALLBAS)
command_dispatcher:
	ld ($3df2),de;						// save DE as it will be used right now
	ex (sp),hl;							// HL = return address from the stack
	ld e, (hl);							// get 16-bit value
	inc hl;								// stored after the RST $18 instruction
	ld d, (hl);							// and put it in DE
	inc hl;								// while advancing the return address to skip
;										// this value
	ex (sp), hl;						// replace the new return address into the stack
	push hl;							// make room in the stack?
	ld hl, $3dfd;						// Automapper address (immediate mapping)
	ex (sp), hl;						// Store in the stack.
	push de;							// Store the address to call to in system ROM
;										// into the stack
	ld de, ($3df2);						// Restore saved DE
	jp unmap_and_return;				// Jump to auto-unmap address.


;	// The calling sequence is as follows: after this last jump, a RET instruction
;	// at $1ffa is executed. While it is being executed, the divMMC is unpaged, so
;	// the next instruction to fetch will have the system ROM paged in. The address
;	// fetched from the stack is the one pointing to the desired system ROM routine.
;	// After this routine ends, the return address fetched from the stack will point
;	// to 3DFD. This is a TR-DOS trap, which immediately pages divMMC again. $3dfd
;	// will have a RET instruction also, thus returning to the instruction past the
;	// immediate 16-bit value after the RST $18 instruction, thus resuming
;	// execution with divMMC paged in.

;	// character processing routine
char_processing_routine:
	ld (x_ptr), hl;						// save HL in x_ptr system variable
	ld l, a;							// save A register in L
	ld a, ($3df9);						// get current divMMC page
	ld h, a;							// save in H
	xor a;								// clear accumulator
	out (mmcram), a;					// divMMC RAM page 0
	ld a, h;							// restore saved page
	ld ($3df8), a;						// save page number
	ld a, l;							// restore A register
	ld ($3dfa), a;						// save A register value
	pop hl;								// get return address
	rst $18;							// call BASIC ROM routine
	defw reentry;						// BASIC reentry point
	inc hl;								// adjust return address
	push hl;							// put back on stack
	cp $0ff;							// COPY command?
	jr nz, process_system_command;		// if not, continue normally
	ld a, h;							// check address high byte
	cp '@';								// check if >= $4000
	jr c, set_error_1;					// if < $4000, continue
	ld sp, (err_sp);					// reset error stack
	ld a, ($3df8);						// get saved page
	out (mmcram), a;					// set divMMC RAM page

return_to_basic:
	ld hl, $16c5;						// BASIC command loop address
	jp jump_unmap_hl;					// unmap and return to BASIC


set_error_1:
	ld a, 1;							// set error code to 1
	rst $20;							// call error handler

process_system_command:
	cp $1b;								// check if command >= $1B
	jr c, check_error_flag;				// if less, branch to error handling
	push ix;							// save IX register
	pop hl;								// copy IX to HL
	call syscall_reg_save;				// call system function dispatcher (06_disk.asm)
	push hl;							// save result
	pop ix;								// restore to IX
	jp unmap_and_return;				// unmap and return

check_error_flag:
	bit 7, (iy + _err_nr);				// check if error flag set

store_error_number:
	ld (err_nr), a;						// store error number
	ld hl, (ch_add);					// get current channel address
	ld (x_ptr), hl;						// save in x_ptr
	jp z, cleanup_and_exit;				// if no error flag, jump to cleanup
	cp $0b;								// check for specific error codes
	jr z, handle_specific_errors;		// jump if error code 11
	cp $0e;								// check if error code 14
	jr z, handle_specific_errors;		// jump if error code 14
	cp $17;								// check if error code 23
	jr z, handle_specific_errors;		// jump if error code 23
	cp 1;								// check for error code 1
	jp nz, cleanup_and_exit;			// if not 1, go to cleanup

handle_specific_errors:
	bit 5, (iy + 55);					// check system flag
	jp nz, cleanup_and_exit;			// if set, go to cleanup
	ld de, (e_line);					// get end of program line
	and a;								// clear carry flag
	sbc hl, de;							// compare current position with end
	jr c, process_before_end;			// if before end, branch
	rst $18;							// call BASIC ROM routine
	defw e_line_no;						// get line number at end
	ld hl, (ch_add);					// get current address
	dec hl;								// back up one position
	jr process_statement;				// continue processing

process_before_end:
	ld hl, (ppc);						// get program counter
	rst $18;							// call BASIC ROM routine
	defw line_addr;						// get address of line
	inc hl;								// skip line number
	inc hl;								// skip length
	inc hl;								// point to first statement

process_statement:
	ld d, (iy + _subppc);				// get sub-statement counter
	ld e, 0;							// clear E
	rst $18;							// call BASIC ROM routine
	defw each_stmt;						// process each statement
	rst $30;							// report error
	inc bc;								// increment BC counter
	jr nz, $0d6a;						// loop if not zero
	rst $18;							// call BASIC ROM routine
	defw remove_fp;						// remove floating point number
	rst $18;							// call BASIC ROM routine
	defw set_work;						// set working area
	rst $30;							// report error
	ld (bc), a;							// store accumulator at BC address
	call cleanup_routine;				// call cleanup routine

cleanup_and_exit:
	ld a, ($3df8);						// get saved divMMC page
	out (mmcram), a;					// set divMMC RAM page
	res 3, (iy + _tv_flag);				// clear TV flag bit 3
	ld hl, $58;							// set up for system exit
	rst $30;							// report error
	inc bc;								// increment BC
	jp z, jump_unmap_hl;				// if zero, unmap and exit
	ld a, (nmiadd);						// get NMI address
	and a;								// test if NMI routine set
	jp z, jump_unmap_hl;				// if not set, unmap and exit
	set 7, (iy + _err_nr);				// set error flag
	ld hl, $1b7d;						// NMI service routine address
	jp jump_unmap_hl;					// unmap and jump to NMI routine

memory_init_routine:
	call read_file_to_page2;			// call memory cleanup routine
	jp c, $20;							// jump if carry set
	call open_screen_channel;			// call additional cleanup
	ld hl, ($2e46);						// get memory pointer
	ld a, 2;							// select page 2
	out (mmcram), a;					// switch to divMMC page 2
	call system_entry;					// call system initialization
	ld ($3de8), hl;						// save result pointer
	jp c, $20;							// jump if error occurred
	ld a, 0;							// select divMMC page 0
	out (mmcram), a;					// divMMC RAM page 0
	jp error_handler_setup;				// jump to completion routine

memory_cleanup_with_hl:
	push hl;							// save HL register
	call read_file_to_page2;			// call memory cleanup routine
	pop hl;								// restore HL register
	jr c, cleanup_restore_page;			// jump to cleanup if error
	ld a, 2;							// select divMMC page 2
	out (mmcram), a;					// divMMC RAM page 2
	call system_entry;					// call system routine

;	// cleanup and restore divMMC memory page
cleanup_restore_page:
	push af;							// save accumulator flags
	ld a, 0;							// select divMMC page 0
	out (mmcram), a;					// divMMC RAM page 0
	ld a, ($3df0);						// get saved page setting
	ld ($3df8), a;						// store in working area
	pop af;								// restore accumulator flags
	ret;								// return to caller

;	// read file data to page 2 and close file
read_file_to_page2:
	ld b, a;							// save file handle in B
	ld a, 2;							// select divMMC page 2
	out (mmcram), a;					// divMMC RAM page 0
	ld a, b;							// restore file handle
	push bc;							// save BC register
	ld hl, $2000;						// set read address ($2000)
	ld bc, $1c00;						// set read length (7168 bytes)
	rst $08;							// call system function
	defb f_read;						// read file function
	pop bc;								// restore BC register
	push af;							// save operation result
	ld a, b;							// get file handle
	rst $08;							// call system function
	defb f_close;						// close file function
	pop af;								// restore operation result
	ld b, a;							// save result in B
	ld a, 0;							// select divMMC page 0
	out (mmcram), a;					// divMMC RAM page 2
	ld a, b;							// restore B register
	ret;								// return to caller
