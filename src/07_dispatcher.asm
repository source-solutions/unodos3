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

;	// sys call table
syscall_table:

;	// hook base
	defw handle_disk_status;			// disk_status
	defw disk_read_write;				// disk_read
	defw disk_read_write;				// disk_write
	defw handle_file_operation;			// disk_ioctl
	defw disk_info_handler;				// disk_info
	defw find_handle_by_index;			// 
	defw invalid_function_error;		// 
	defw invalid_function_error;		// 

;	// misc base
	defw invalid_function_error;		// m_dosversion
	defw get_set_drive; 				// m_getsetdrv
	defw drive_info;					// m_driveinfo
	defw system_entry;					// m_tapein
	defw system_reinit;					// m_tapeout
	defw get_drive_status;				// m_gethandle
	defw get_default_date;				// m_getdate
	defw cmd_folder_setup;				// 
	defw error_code_handler;			// 
	defw invalid_function_error;		// 
	defw invalid_function_error;		// 
	defw invalid_function_error;		// 
	defw invalid_function_error;		// 
	defw invalid_function_error;		// 
	defw invalid_function_error;		// 
	defw invalid_function_error;		// 

;	// fsys_base
	defw filesystem_mount;				// f_mount
	defw filesystem_unmount;			// f_umount
	defw file_open;						// f_open
	defw file_close;					// f_close
	defw get_file_handle;				// f_sync
	defw get_file_handle;				// f_read
	defw get_file_handle;				// f_write
	defw get_file_handle;				// f_seek
	defw get_file_handle;				// f_fgetpos
	defw get_file_handle;				// f_fstat
	defw get_file_handle;				// f_ftruncate
	defw file_open;						// f_opendir
	defw get_file_handle;				// f_readdir
	defw get_file_handle;				// f_telldir
	defw get_file_handle;				// f_seekdir
	defw get_file_handle;				// f_rewinddir
	defw init_file_handle;				// f_getcwd
	defw init_file_handle;				// f_chdir
	defw init_file_handle;				// f_mkdir
	defw init_file_handle;				// f_rmdir
	defw init_file_handle;				// f_stat
	defw init_file_handle;				// f_unlink
	defw init_file_handle;				// f_truncate
	defw init_file_handle;				// f_attrib
	defw init_file_handle;				// f_rename
	defw init_file_handle;				// f_getfree
	defw validate_drive_handle;			// 
	defw init_file_handle;				// 

;	// RST08_handler
;	// main syscall dispatcher (RST $08 entry point)
syscall_dispatcher:
	ex (sp), hl;						// swap HL with top of stack (return address)
	ld ($3dfa), a;						// save parameter in A
	ld a, (hl);							// retrieve syscall # from position
;										// after RST instruction
	inc hl;								// adjust return address
	ex (sp), hl;						// and saves it to the stack

;	// register preservation and syscall setup
syscall_reg_save:
	push iy;							// save registers
	push ix;							// save index register X
	sub $80;							// now A holds the syscall number
;										// subtract HOOK_BASE from it
	ld iyl, a;							// so the syscall number begins now at 0
;										// save in IYl
	ld ix, (mmc_3);						// get current divMMC page settings
	xor a;								// select page 0
	out (mmcram), a;					// divMMC RAM page 0 at $2000
	ld a, ixl;							// get low byte of page settings
	ld (call_num), a;					// Store syscall number
	push ix;							// save page settings
	call system_call_dispatch;			// dispatch system call
	pop ix;								// restore page settings
	ld iyl, a;							// save result
	ld a, ixl;							// get original page
	out (mmcram), a;					// Set divMMC RAM page
	ld a, iyl;							// restore result
	pop ix;								// restore registers
	pop iy;								// restore index register Y
	ret;								// return to caller

system_call_dispatch:
	ld a, iyl;							// get system call number
	push hl;							// save HL register
	ld hl, syscall_table;				// point to system call table (04_files.asm)
	add a, a;							// multiply by 2 (each entry is 2 bytes)
	add a, l;							// add to table base address
	ld l, a;							// store in L
	jr nc, get_handler_address;			// if no carry, continue
	inc h;								// handle carry to high byte

get_handler_address:
	ld a, (hl);							// get low byte of handler address
	inc hl;								// advance to high byte
	ld h, (hl);							// get high byte of handler address
	ld l, a;							// restore low byte
	ld a, ixh;							// get high byte of page settings
	ex (sp), hl;						// put handler address on stack, restore HL
	ret;								// "call" handler by returning to it

invalid_function_error:
	ld a, $14;							// error code: invalid function number
	scf;								// set carry flag (error)
	ret;								// return with error

get_drive_status:
	ld a, ($2e32);						// get drive status
	or a;								// test if drive available
	ret;								// return with status

;	// default date and time for files
get_default_date:
	ld de, $6000;						// 12:00:00
	ld bc, $28c2;						// June 2, 2000
	or a;								// clear carry flag (success)
	ret;								// return with default date/time

get_set_drive:
	and a;								// test if drive number is zero
	jr nz, set_current_drive;			// if not zero, set as current drive
	ld a, ($2d46);						// get current drive number
	or a;								// set flags based on drive
	ret;								// return with current drive

set_current_drive:
	cp '*';								// use current drive? test for file commands
	ret z;								// return if using current drive
	ld c, a;							// save drive number
	call configure_system_drive;		// validate drive number (04_files.asm)
	ret c;								// return if invalid drive
	ld a, c;							// restore drive number
	ld ($2d46), a;						// set as current drive
	ret;								// return success

find_handle_by_index:
	and %11111000;						// mask to get file handle index
	ld c, a;							// save handle index
	ld hl, $2d00;						// point to file handle table
	ld b, $0c;							// 12 file handles to check

search_file_handles:
	ld a, (hl);							// get handle entry
	inc hl;								// advance to next field
	inc hl;								// (each entry is 3 bytes)
	inc hl;								// advance to third byte of entry
	and %11111000;						// mask handle index bits
	cp c;								// compare with target handle
	scf;								// set carry flag (assume found)
	ret z;								// return if handle found
	djnz search_file_handles;			// loop through all handles
	ld a, c;							// get handle number
	push bc;							// save BC register
	call handle_file_operation;			// call handle processing routine
	pop bc;								// restore BC register
	ret c;								// return if error occurred
	ld a, c;							// get handle number back
	jp close_handle_slot;				// jump to handle completion

handle_disk_status:
	ld ($3df4), hl;						// save HL register 
	ld ($3dfa), a;						// save accumulator
	ld ($3df6), bc;						// save BC register
	ld ($3df2), de;						// save DE register
	call find_file_handle;				// call system routine
	ccf;								// complement carry flag
	ld a, $1f;							// error code: invalid file handle
	ret c;								// return if error
	ld hl, $2d24;						// point to system data table

process_filesystem_table:
	ld e, (hl);							// get low byte from table
	inc hl;								// advance to next byte
	ld d, (hl);							// get high byte from table
	inc hl;								// advance to next entry
	ld a, d;							// check high byte
	and a;								// test if zero (end of table)
	ld a, $0e;							// error code: end of table
	scf;								// set carry flag (error)
	ret z;								// return if end of table
	push hl;							// save HL register
	call get_filesystem_params;			// get file system parameters
	pop hl;								// restore HL register
	ret nc;								// return if no error
	jr process_filesystem_table;		// handle error case

get_filesystem_params:
	ld hl, ($3df4);						// get file system base address
	ld bc, ($3df6);						// get file system parameters
	ld a, ($3dfa);						// get stored A register value
	push de;							// save DE register
	ld de, ($3df2);						// get additional parameters
	ret;								// return to caller

invoke_file_operation:
	push de;							// save DE register
	ld e, iyl;							// get system call number
	ld a, ixh;							// get high byte of page settings
	ld ixh, e;							// store call number in IXH
	pop de;								// restore DE register
	jp find_handle_with_setup;			// jump to handler (04_files.asm)

disk_read_write:
	call invoke_file_operation;			// invoke file operation
	ret c;								// return if error
	push hl;							// save HL register
	call process_file_comparison;		// process operation result
	pop hl;								// restore HL register
	jr nc, process_operation_result;	// if no error, continue
	ld a, $0a;							// error code: access denied
	ret;								// return with error

handle_file_operation:
	call invoke_file_operation;			// invoke file operation
	ret c;								// return if error

process_operation_result:
	push hl;							// save HL register
	ld h, (iy + _err_sp);				// get error stack pointer
	ld a, ixh;							// get operation type
	add a, a;							// multiply by 2 for word index
	add a, (iy + _tv_flag);				// add base offset
	ld l, a;							// store in L
	jr nc, get_handler_dispatch_addr;	// if no carry, continue
	inc h;								// handle carry to high byte

get_handler_dispatch_addr:
	ld a, (hl);							// get low byte of handler address
	inc hl;								// advance to high byte
	ld h, (hl);							// get high byte of handler address
	ld l, a;							// restore low byte
	ex (sp), hl;						// put handler address on stack
	ret;								// "call" handler by returning to it

process_file_comparison:
	push iy;							// save IY register
	pop hl;								// copy IY to HL
	and a;								// test A register
	jr nz, calc_address_offset;			// if not zero, branch
	ld a, 7;							// offset to compare value
	add a, l;							// add to address
	ld l, a;							// store result
	jp compare_32bit;					// jump to comparison routine (04_files.asm)

calc_address_offset:
	add a, a;							// shift A left (multiply by 2)
	add a, a;							// shift A left again (multiply by 4)
	add a, a;							// shift A left again (multiply by 8)
	add a, l;							// add base address offset
	ld l, a;							// store calculated address in L
	push hl;							// save address pointer
	add a, 7;							// add 7 to address (offset calculation)
	ld l, a;							// store offset address in L
	call compare_32bit;					// call comparison routine (04_files.asm)
	pop hl;								// restore address pointer
	ret c;								// return if comparison failed
	ld a, (hl);							// get first byte of 32-bit value
	inc hl;								// advance to next byte
	add a, e;							// add to E (low byte of result)
	ld e, a;							// store updated low byte
	ld a, (hl);							// get second byte of 32-bit value
	inc hl;								// advance to next byte
	adc a, d;							// add with carry to D
	ld d, a;							// store updated second byte
	ld a, (hl);							// get third byte of 32-bit value
	inc hl;								// advance to next byte
	adc a, c;							// add with carry to C
	ld c, a;							// store updated third byte
	ld a, (hl);							// get fourth byte of 32-bit value
	adc a, b;							// add with carry to B (high byte)
	ld b, a;							// store updated high byte
	ret;								// return with 32-bit sum in BCDE

file_open:
	call init_file_handle;				// call file operation handler
	ret c;								// return if operation failed
	push hl;							// save HL register
	ld hl, $2cf0;						// point to file handle table
	ld a, ixh;							// get handle number
	push af;							// save handle number
	add a, l;							// add handle offset to table base
	ld l, a;							// store calculated address
	ld a, iyh;							// get file flags
	ld (hl), a;							// store flags in handle entry
	ld a, ixh;							// get handle number for finalization
	call handle_drive_table_op;			// call handle completion routine
	pop af;								// restore saved handle number
	pop hl;								// restore HL register
	ret;								// return to caller

file_close:
	call get_file_handle;				// call handle validation routine
	ret c;								// return if validation failed
	ld a, ixh;							// get handle number for cleanup
	push af;							// save A register
	ld hl, $2cf0;						// point to file handle table
	call clear_handle_entry;			// clear file handle entry
	pop af;								// restore A register
	ld hl, $2e22;						// point to drive table

clear_handle_entry:
	add a, l;							// add offset to base address
	ld l, a;							// store result in L
	xor a;								// clear accumulator
	ld (hl), a;							// clear table entry
	ret;								// return to caller

get_file_handle:
	push de;							// save DE register
	ld de, $2cf0;						// point to file handle table
	add a, e;							// add handle offset
	ld e, a;							// store in E
	ld a, (de);							// get file handle value
	and a;								// test if handle is valid
	ld d, a;							// save handle value
	ld a, ixh;							// get current operation
	ld ixh, d;							// store handle in IXH
	jr nz, handle_file_with_drive;		// if valid handle, continue
	ld a, $0d;							// error code: invalid handle

return_handle_error:
	pop de;								// restore DE register
	scf;								// set carry flag (error)
	ret;								// return with error

drive_info:
	ld de, $2d01;						// point to file handle data (skip flags)
	ld b, $0c;							// 12 file handles maximum
	ld c, 0;							// counter for open files

count_open_files_loop:
	ld a, (de);							// get file handle number
	and a;								// test if handle is in use
	jr z, advance_handle_pointer;		// skip if handle not in use
	inc c;								// increment open file count
	push de;							// save DE register
	push bc;							// save BC register
	ld c, a;							// put handle number in C
	ld a, ixl;							// get divMMC page
	out (mmcram), a;					// set divMMC RAM page
	ld a, c;							// restore handle number
	rst $08;							// call system function
	defb $b2;							// unknown hook code (close file?)
	xor a;								// clear accumulator
	out (mmcram), a;					// divMMC RAM page 0
	pop bc;								// restore BC register
	pop de;								// restore DE register

advance_handle_pointer:
	inc de;								// advance to next handle entry
	inc de;								// (each entry is 3 bytes)
	inc de;								// complete handle entry skip
	djnz count_open_files_loop;			// loop through all handles
	ld a, c;							// get count of open files
	ret;								// return with count

validate_drive_handle:
	push iy;							// save IY register
	call configure_system_drive;		// validate drive (04_files.asm)
	pop bc;								// restore BC register
	ret c;								// return if drive invalid
	ld a, (iy + _flags);				// get file flags
	ld b, a;							// save in B
	ld d, (iy + _err_nr);				// get error number
	ld e, (iy + _tv_flag);				// get TV flag
	ld iyl, c;							// save drive number

init_file_handle:
	call validate_filename_buffer;		// initialize file handle (04_files.asm)
	ret c;								// return if initialization failed
	push de;							// save DE register

handle_file_with_drive:
	ld e, a;							// save handle number
	ld d, iyl;							// get saved parameter
	ld a, ixh;							// get operation type
	cp '*';								// use current drive?
	jr nz, validate_drive_param;		// if not, use specified drive
	ld a, ($2d46);						// get current drive number

validate_drive_param:
	call configure_system_drive;		// validate drive (04_files.asm)
	jr c, return_handle_error;			// return with error if invalid
	push af;							// save drive number
	ld a, (iy + _flags);				// get file flags
	ld iyh, a;							// save in IYH
	ld iyl, d;							// save parameter
	ld ixh, e;							// save handle number
	pop af;								// restore drive number
	pop de;								// restore DE register
	push ix;							// save IX register
	push iy;							// save IY register
	out (mmcram), a;					// set divMMC RAM page
	ld a, ixl;							// get low byte of IX
	ld ($3df8), a;						// save page settings
	ld ($3df4), hl;						// save HL register
	call memory_address_calc;			// call handler (04_files.asm)
	sub $18;							// subtract base offset (24) for handler index
	ld l, (iy + _tv_flag);				// get TV flag for address calculation
	ld h, (iy + _err_sp);				// get error stack pointer
	add a, a;							// multiply by 2 (word entries)
	add a, l;							// add to base address
	ld l, a;							// store calculated address
	jr nc, get_handler_from_table;		// jump if no carry
	inc h;								// handle carry to high byte

get_handler_from_table:
	ld a, (hl);							// get low byte of handler address
	inc hl;								// advance to high byte
	ld h, (hl);							// get high byte of handler address
	ld l, a;							// restore low byte
	call restore_memory_state;			// call memory restoration routine
	ld ixh, a;							// save result in IXH
	ld a, 0;							// clear accumulator
	out (mmcram), a;					// divMMC RAM page 0;
	ld a, ixh;							// restore result
	pop iy;								// restore IY register
	pop ix;								// restore IX register
	ret;								// return to caller

restore_memory_state:
	push hl;							// save handler address
	ld hl, ($3df4);						// restore saved HL register
	ret;								// return with HL restored

handle_drive_table_op:
	ld ixh, a;							// save operation type in IXH
	ld hl, $2e22;						// point to drive table
	add a, l;							// add operation offset
	ld l, a;							// store calculated address
	ld a, ixl;							// get operation mode
	cp 2;								// check if write mode
	ret nz;								// return if not write mode
	ld a, ixh;							// restore operation type
	ld (hl), a;							// store in drive table
	ret;								// return to caller

disk_info_handler:
	and a;								// test file system type
	jr z, handle_standard_filesystem;	// jump if standard file system
	ld b, a;							// save file system type
	call find_handle_with_setup;		// call validation routine (04_files.asm)
	jr nc, validate_filesystem;			// continue if valid

filesystem_error:
	ld a, $0e;							// error code: invalid file system
	ret;								// return with error

validate_filesystem:
	ld c, a;							// save validation result
	ld a, b;							// restore file system type
	and %00000111;						// mask lower 3 bits
	cp c;								// compare with validation result
	jr c, filesystem_error;				// return error if invalid
	push hl;							// save HL register
	push iy;							// save IY register
	pop hl;								// copy IY to HL
	ld de, $2df2;						// point to data buffer
	ld a, b;							// get file system type
	ld (de), a;							// store in data buffer
	inc de;								// advance buffer pointer
	inc hl;								// advance source pointer
	ldi;								// copy one byte (auto increment)
	inc hl;								// skip next byte
	inc hl;								// skip another byte
	and %00000111;						// mask file system index
	add a, a;							// multiply by 2
	add a, a;							// multiply by 4
	add a, a;							// multiply by 8 (8-byte entries)
	add a, l;							// add to source address
	ld l, a;							// store calculated address
	jr nc, process_filesystem_entry;	// continue if no carry
	inc h;								// handle carry to high byte

process_filesystem_entry:
	ld bc, 4;							// copy 4 bytes
	ldir;								// block copy HL to DE
	ld c, 6;							// set result length
	jr complete_buffer_operation;		// jump to completion

handle_standard_filesystem:
	push hl;							// save HL register
	ld b, 6;							// process 6 file systems
	ld hl, $2c00;						// point to file system table
	ld de, $2df2;						// point to output buffer

filesystem_table_loop:
	push bc;							// save loop counter
	push hl;							// save table pointer
	ld a, (hl);							// get file system entry
	inc hl;								// advance to next byte
	and a;								// test if entry exists
	jr z, advance_filesystem_ptr;		// skip if no file system
	ld b, a;							// save file system type
	and %11111000;						// mask high 5 bits
	ld c, a;							// save masked value
	ld a, b;							// restore file system type
	and %00000111;						// mask lower 3 bits (index)
	ld b, a;							// save index
	ld a, (hl);							// get drive number
	ld ixl, a;							// save in IXL
	dec hl;								// return to file system entry
	xor a;								// clear accumulator

copy_filesystem_data:
	push af;							// save entry index
	or c;								// combine with file system type
	ld (de), a;							// store in output buffer
	inc de;								// advance buffer pointer
	ld a, ixl;							// get drive number
	ld (de), a;							// store drive number
	inc de;								// advance buffer pointer
	push bc;							// save counters
	inc hl;								// advance to data section
	inc hl;								// skip to file system info
	inc hl;								// skip to data start
	inc hl;								// advance data pointer
	ld bc, 4;							// copy 4 bytes of data
	ldir;								// block copy from HL to DE
	pop bc;								// restore counters
	pop af;								// restore entry index
	cp b;								// compare with maximum index
	inc a;								// increment index
	jr c, copy_filesystem_data;			// loop if more entries

advance_filesystem_ptr:
	pop hl;								// restore table pointer
	ld bc, $28;							// each entry is 40 bytes
	add hl, bc;							// advance to next file system entry
	pop bc;								// restore loop counter
	djnz filesystem_table_loop;			// loop through all file systems
	xor a;								// clear accumulator
	ld (de), a;							// terminate buffer with zero
	inc de;								// advance buffer pointer
	ld hl, $d20e;						// load end marker address
	add hl, de;							// calculate buffer end
	ld b, h;							// copy high byte to B
	ld c, l;							// copy low byte to C

complete_buffer_operation:
	ld hl, $2df2;						// point to data buffer
	pop de;								// restore DE register
	rst $30;							// call ROM routine (calculator)
	ld b, $b7;							// set operation code
	ret;								// return with result
