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

;	// this part starts at $3000 in MMC RAM 1
	org $3000
;	// Function: Initialize memory management variables
store_hl_memory_ptr:
	ld ($3c19), hl;						// store HL in memory pointer
	ld de, ($3c11);						// load base address to DE
	ld bc, ($3c13);						// load size to BC
	ld ($3c15), de;						// store base address copy
	ld ($3c17), bc;						// store size copy
	call check_system_flag_bit;			// call initialization routine
	ret c;								// return if error
	call process_disk_operation;		// call memory setup function
	ld h, d;							// transfer D to H
	ld l, e;							// transfer E to L
	ld a, $ff;							// load marker value
	call store_at_memory_hl;			// call memory marking function
	push de;							// save DE register
	ld de, ($3c11);						// load memory base address
	ld bc, ($3c13);						// load memory size
	call mark_buffer_dirty;				// call memory initialization
	pop hl;								// restore HL register
	call fat_address_right_shift;		// call address conversion
	push bc;							// save BC register
	push de;							// save DE register
	ld bc, ($3c17);						// load saved size value
	ld de, ($3c15);						// load saved address value
	call check_drive_cluster_cache;		// call memory operation
	ld de, ($3c19);						// load memory pointer
	ld a, d;							// load high byte
	and 1;								// mask to lowest bit
	ld d, a;							// store masked value
	add hl, de;							// add address offset
	pop de;								// restore DE register
	pop bc;								// restore BC register
	call call_mem_addr_calc;			// call finalization routine
	push bc;							// save BC register again
	push de;							// save DE register again
	ld bc, ($3c17);						// reload saved size
	ld de, ($3c15);						// reload saved address
	call mark_buffer_dirty;				// call memory reinitialization
	pop de;								// restore DE register
	pop bc;								// restore BC register
	jp set_file_sector_address;			// jump to file descriptor function

;	// Function: Check system flags and process
check_system_flag_bit:
	bit 2, (iy + _oldppc);				// check system flag bit
	jr z, copy_h_to_d;					// jump if flag not set

save_hl_reg:
	push hl;							// save HL register
	push iy;							// save IY register
	pop hl;								// transfer IY to HL
	ld l, $3e;							// set offset to system area
	rst $30;							// call ROM routine
	ld bc, $fde1;						// load special value
	ld a, (hl);							// load system byte
	inc e;								// increment E register
	cp 0;								// compare with zero
	ld a, 0;							// clear accumulator
	jr z, shift_left_e_again;			// jump if zero
	sla e;								// shift left E register

;	// Function: Continue bit shifting and address calculation
shift_left_e_again:
	sla e;								// shift left E register again
	adc a, a;							// add with carry to accumulator
	ld d, a;							// store result in D
	ld a, h;							// load H register
	and $FE;							// mask to clear lowest bit
	or d;								// combine with D register
	ld d, a;							// store result in D
	or d;								// combine with D register
	ex de, hl;							// exchange DE with HL
	sbc hl, de;							// subtract DE from HL with carry
	ex de, hl;							// restore original order
	jr z, clear_system_flag;			// jump if zero result
	ld e, l;							// transfer L to E
	ld d, h;							// transfer H to D
	call load_next_line_high;			// call validation function
	jr nz, save_hl_reg;					// jump if not zero
	ret;								// return successfully

clear_system_flag:
	res 2, (iy + _oldppc);				// clear system processing flag
	ld a, 9;							// load error code 9 (system error)
	scf;								// set carry flag to indicate error
	ret;								// return with error

copy_h_to_d:
	ld d, h;							// copy H register to D
	ld e, l;							// copy L register to E
	call load_next_line_high;			// call memory validation function
	ret z;								// return if validation successful (Z flag set)
	ld a, h;							// load H register into accumulator
	cp '*';								// $2a
	jr nz, copy_h_to_d;					// loop back if not wildcard
	res 2, (iy + _oldppc);				// clear system processing flag
	ld de, ($3c11);						// load memory base address
	ld bc, ($3c13);						// load memory size
	call inc_32bit;						// call 32-bit increment function
	push bc;							// save BC register
	push de;							// save DE register
	call inc_32bit;						// call 32-bit increment again
	push iy;							// save IY register
	pop hl;								// transfer IY to HL
	ld l, $22;							// set offset to system area
	call compare_32bit;					// call memory comparison function
	pop de;								// restore DE register
	pop bc;								// restore BC register
	jr nz, call_mem_allocation;			// jump if comparison failed
	set 2, (iy + _oldppc);				// set system processing flag
	call check_drive_cluster_cache;		// call memory allocation function
	jr nc, save_hl_reg;					// jump if allocation successful
	ret;								// return to caller

call_mem_allocation:
	call check_drive_cluster_cache;		// call memory allocation function
	jr nc, copy_h_to_d;					// continue loop if allocation successful
	ret;								// return with error

load_next_line_high:
	ld a, (iy + _nxtlin_h);				// load next line high byte from system vars
	cp 1;								// compare with 1 (special mode flag)
	ld a, 0;							// clear accumulator
	call z, or_with_memory;				// call extended function if in special mode

or_with_memory:
	or (hl);							// OR accumulator with memory value at HL
	inc l;								// increment low byte of address
	or (hl);							// OR accumulator with next memory value
	inc hl;								// increment HL register
	ret;								// return with combined result

store_at_memory_hl:
	ld (hl), a;							// store accumulator at memory location HL
	inc l;								// increment low byte of address
	ld (hl), a;							// store accumulator at next location
	inc hl;								// increment HL register
	push bc;							// save BC register
	ld b, a;							// copy accumulator to B register
	ld a, (iy + _nxtlin_h);				// load next line high byte
	cp 1;								// check if in special mode
	ld a, b;							// restore original accumulator value
	pop bc;								// restore BC register
	ret nz;								// return if not in special mode
	ld (hl), a;							// store accumulator in extended area
	inc l;								// increment address
	and $0F;							// mask lower 4 bits
	ld (hl), a;							// store masked value
	inc hl;								// increment address
	ret;								// return to caller

call_mem_addr_calc:
	call set_directory_cluster;			// call memory address calculation function
	ld (hl), e;							// store E register at memory location
	inc l;								// increment address
	ld (hl), d;							// store D register at next location
	ld a, (iy + _nxtlin_h);				// load next line high byte
	cp 1;								// check if in special mode
	ret nz;								// return if not in special mode
	inc l;								// increment to extended storage area
	ld (hl), c;							// store C register
	inc l;								// increment address
	ld (hl), b;							// store B register
	ret;								// return to caller

call_rom_calculator:
	rst $30;							// call ROM calculator routine
	dec c;								// decrement counter
	ret z;								// return if counter reached zero
	call validate_cluster_operation;	// call processing function
	jr nz, call_file_operation;			// jump if result not zero
	call set_directory_cluster;			// call address calculation function

call_file_operation:
	call map_sector_from_cluster;		// call file operation function
	jr c, check_eof_marker;				// jump to error handler if carry set
	call clear_accumulator_zero;		// call memory clearing function
	jr nc, call_rom_calculator;			// loop back if no carry (continue)
	ret;								// return to caller

check_eof_marker:
	cp $80;								// check for end-of-file marker
	scf;								// set carry flag (error condition)
	ret nz;								// return if not end-of-file

clear_accumulator_zero:
	xor a;								// clear accumulator (A = 0)
	call store_at_memory_hl;			// call memory storage function with zero
	push bc;							// save BC register
	push de;							// save DE register
	ld de, ($3c11);						// load memory base address
	ld bc, ($3c13);						// load memory size
	call mark_buffer_dirty;				// call memory initialization function
	push af;							// save accumulator and flags
	scf;								// set carry flag
	call process_disk_operation;		// call memory setup function
	pop af;								// restore accumulator and flags
	pop de;								// restore DE register
	pop bc;								// restore BC register
	ret;								// return to caller

call_file_descriptor:
	call get_file_next_cluster;			// call file descriptor function
	jp write_disk_sector;				// jump to file operations handler
	bit 1, (ix + $01);					// check file operation flag bit 1
	ld a, 8;							// load error code 8 (file not open)
	scf;								// set carry flag for error
	ret z;								// return if flag not set (file not open)
	ld a, c;							// load C register
	or b;								// OR with B register (check if BC is zero)
	ret z;								// return if no bytes to process
	push bc;							// save byte count
	call load_file_size;				// call buffer preparation function
	rst $30;							// call ROM calculator routine
	dec c;								// decrement counter
	pop bc;								// restore byte count
	jr nz, set_file_proc_flag;			// jump if counter not zero
	push bc;							// save BC register
	call save_hl_reg_again;				// call file processing function
	pop bc;								// restore BC register
	ret c;								// return if error

set_file_proc_flag:
	set 2, (ix + $01);					// set file processing flag bit 2
	call file_io_byte_count;			// call file buffer management function
	push af;							// save accumulator and flags
	push bc;							// save BC register
	push hl;							// save HL register
	call load_file_position;			// call file position function
	push ix;							// save IX register
	pop hl;								// transfer IX to HL
	ld a, l;							// get low byte of IX
	add a, $0e;							// add offset to file descriptor area
	ld l, a;							// store adjusted address
	rst $30;							// call ROM calculator routine
	ex af, af';							// exchange AF with AF'
	call c, call_file_sync;				// call error handler if carry set
	set 3, (ix + $01);					// set file operation flag bit 3
	pop hl;								// restore HL register
	pop bc;								// restore BC register
	pop af;								// restore accumulator and flags
	ret nc;								// return if no carry (success)
	push af;							// save accumulator and flags
	call flush_dirty_buffer;			// call cleanup function
	pop af;								// restore accumulator and flags
	ret;								// return to caller

call_file_sync:
	call store_file_size;				// call file buffer synchronization function
	push hl;							// save HL register
	ld hl, $1a6d;						// load system call address
	ld ($3dee), hl;						// store system call pointer
	call descriptor_cleanup_validation;	// execute system call
	pop hl;								// restore HL register
	ret;								// return to caller

save_hl_reg_again:
	push hl;							// save HL register
	call process_fat_cluster_operations;// call file descriptor validation function
	pop hl;								// restore HL register
	call nc, flush_dirty_buffer;		// call cleanup if no carry (success)
	ret c;								// return if carry set (error)
	push bc;							// save BC register
	call process_disk_operation;		// call memory setup function
	pop bc;								// restore BC register
	call store_cluster_address;			// call buffer management function
	call setup_file_sector;				// call file position update function
	push hl;							// save HL register
	ld hl, $1a7c;						// load completion handler address
	ld ($3dee), hl;						// store completion handler pointer
	call descriptor_cleanup_validation;	// execute completion handler
	pop hl;								// restore HL register
	ret;								// return to caller

	call file_flush_update;				// call file initialization function
	ret c;								// return if error (carry set)
	push iy;							// save IY register
	pop hl;								// transfer IY to HL
	ld d, h;							// copy H to D
	ld e, l;							// copy L to E
	inc de;								// increment DE (destination pointer)
	ld bc, $ff;							// set clear count to 255 bytes
	ld (hl), l;							// store L value at HL (clear first byte)
	ldir;								// clear memory block (HL to HL+BC)
	or a;								// clear carry flag (success)
	ret;								// return to caller

	push de;							// save DE register
	ld a, $80;							// load file operation code $80
	call init_file_lookup;				// call file operation function
	pop de;								// restore DE register
	jr nc, load_first_filename_char;	// jump if no carry (operation successful)
	cp $11;								// check for error code $11 (file not found)
	scf;								// set carry flag (error condition)
	ret nz;								// return if not file not found error

load_first_filename_char:
	ld a, ($3c06);						// load first character of filename
	cp '.';								// $2e
	ld a, $13;							// load error code $13 (invalid filename)
	scf;								// set carry flag (error condition)
	jp z, file_operation_error_handler;	// jump to error handler if filename starts with '.'
	call transfer_error_number;			// call file lookup function
	ld hl, $1a65;						// load file operation handler address
	ld ($3dee), hl;						// store operation handler pointer
	call descriptor_cleanup_validation;	// execute file operation handler
	ld a, $17;							// load error code $17 (file operation failed)
	ret c;								// return if operation failed
	ld l, (ix + $1C);					// load low byte of directory entry pointer
	ld h, (ix + $1D);					// load high byte of directory entry pointer
	ld a, $0b;							// offset to file attributes byte
	add a, l;							// add offset to low byte
	ld l, a;							// store adjusted address
	bit 0, (hl);						// check read-only attribute flag
	ld a, $18;							// load error code $18 (file is read-only)
	scf;								// set carry flag (error condition)
	jp nz, file_operation_completion;	// jump to error handler if read-only
	push de;							// save DE register
	call load_cluster_address;			// call file buffer preparation function
	ld hl, $3c1b;						// load buffer address
	rst $30;							// call ROM calculator routine
	nop;								// padding/alignment
	call setup_directory_cluster;		// call directory sector read function
	ld hl, $3c1f;						// load sector buffer address
	rst $30;							// call ROM calculator routine
	nop;								// padding/alignment
	call get_file_next_cluster;			// call file descriptor function
	call file_validation_function;		// call file processing function
	ld a, (ix + $06);					// load drive number from file descriptor
	ld ($3c23), a;						// save drive number to temporary storage
	ld l, (ix + $1C);					// load directory entry address low byte
	ld h, (ix + $1D);					// load directory entry address high byte
	ld de, $2d00;						// load directory buffer address
	ld bc, $20;							// load directory entry size (32 bytes)
	ldir;								// copy directory entry to buffer
	pop hl;								// restore HL register from stack
	ld a, $80;							// load file lookup operation mode
	call setup_dir_buffer;				// call file existence check function
	jr c, check_error_code_5;			// jump to create file if not found
	ld a, $12;							// load error code 18 (file already exists)
	scf;								// set carry flag (error condition)
	jr file_operation_completion;		// jump to error return

check_error_code_5:
	cp 5								// check for error code 5 (access denied)
	scf;								// set carry flag (error condition)
	jr nz, file_operation_error_handler;	// jump to error handler if not access denied
	ld a, ($3c06);						// load first character of filename
	cp '.';								// $2e
	ld a, $13;							// load error code $13 (invalid filename)
	scf;								// set carry flag (error condition)
	jr z, file_operation_error_handler;	// jump to error handler if filename starts with '.'
	call load_cluster_address;			// call file buffer preparation function
	ld hl, $3c1E;						// load buffer address for comparison
	call compare_32bit;					// call memory comparison function
	jr nz, call_dir_entry_create;		// jump if comparison failed (file exists)
	ld a, ($3c23);						// load saved drive number
	ld (ix + $06), a;					// restore drive number to file descriptor
	call directory_update_function;		// call directory update function
	jr c, file_operation_error_handler;	// jump to error handler if update failed
	ex de, hl;							// exchange DE and HL registers
	ld hl, $3c06;						// load filename buffer address
	ld bc, $0b;							// copy 11 bytes (filename length)
	ldir;								// copy filename to directory entry
	jr call_dir_sector_write_alt;		// jump to completion handler

call_dir_entry_create:
	call directory_position_function;	// call directory entry creation function
	jr c, file_operation_error_handler;	// jump to error handler if creation failed
	ld a, (de);							// load first byte of existing entry
	push af;							// save first byte on stack
	ld hl, $3c06;						// load source filename buffer
	ld bc, $0b;							// copy 11 bytes (filename length)
	ldir;								// copy filename to directory entry
	ld hl, $2d0b;						// load source attributes buffer
	ld bc, $15;							// copy 21 bytes (file attributes)
	ldir;								// copy attributes to directory entry
	push de;							// save DE register
	call directory_sector_write;		// call directory sector write function
	pop hl;								// restore HL register from stack
	pop de;								// restore DE register from stack (original entry byte)
	jr c, file_operation_error_handler;	// jump to error handler if write failed
	ld a, d;							// load original entry byte
	cp $E5;								// RESTORE
	jr z, call_dir_sector_write;		// jump if entry was marked as deleted
	call clear_directory_entry;			// call file deletion function

call_dir_sector_write:
	call directory_sector_write;		// call directory sector write function
	ld a, ($3c23);						// load saved drive number
	ld (ix + $06), a;					// restore drive number to file descriptor
	call directory_update_function;		// call directory update function
	jr c, file_operation_error_handler;	// jump to error handler if update failed
	ld (hl), $e5;						// mark directory entry as deleted

call_dir_sector_write_alt:
	call directory_sector_write;		// call directory sector write function

;	// file operation error handler
file_operation_error_handler:
	push af;							// save accumulator and flags
	call flush_dirty_buffer;			// call cleanup function
	pop af;								// restore accumulator and flags

;	// file operation completion handler
file_operation_completion:
	ld (ix + 0), 0;						// clear file descriptor status
	ret;								// return to caller

	push bc;							// save BC register (attribute flags)
	ld a, $80;							// load file operation code $80
	call init_file_lookup;				// call file lookup function
	pop bc;								// restore BC register (attribute flags)
	jr nc, call_filename_validation;	// jump if file not found
	cp $11;								// check for error code $11 (file not found)
	scf;								// set carry flag (error condition)
	jr z, save_bc_attribute_flags;		// jump if file not found (handle as valid case)
	ret;								// return with other errors

call_filename_validation:
	call validate_filename_special_chars;	// call filename validation function
	ret c;								// return if filename invalid

save_bc_attribute_flags:
	push bc;							// save BC register (attribute flags)
	call get_file_next_cluster;			// call file descriptor function
	call file_validation_function;		// call file processing function
	call setup_directory_cluster;		// call directory sector read function
	ld l, (ix + $1C);					// load low byte of directory entry pointer
	ld h, (ix + $1D);					// load high byte of directory entry pointer
	ld a, $0b;							// offset to file attributes byte
	add a, l;							// add offset to entry pointer
	ld l, a;							// update pointer to attributes
	pop bc;								// restore BC register (attribute flags)
	ld a, b;							// load attribute mask from B
	rra;								// rotate right to position bits
	ccf;								// complement carry flag
	rla;								// rotate left to restore position
	and c;								// mask with attribute values
	ld b, a;							// store masked attributes
	ld a, c;							// load attribute values
	and $27;							// mask valid attribute bits
	cpl;								// complement to create clear mask
	and (hl);							// clear specified attributes
	or b;								// set new attributes
	and $37;							// mask to valid attribute range
	ld (hl), a;							// store modified attributes
	call directory_sector_write;		// call directory sector write function
	ret c;								// return if error writing directory
	jp flush_dirty_buffer;				// jump to file descriptor cleanup

;	// validate filename against special characters
validate_filename_special_chars:
	ld hl, $2c00;						// load filename buffer address
	ld a, (hl);							// load first character
	cp '/';								// check for root directory marker ($2f)
	jr nz, check_invalid_filename_patterns;	// jump if not root path
	inc hl;								// skip root marker

;	// check for invalid filename patterns
check_invalid_filename_patterns:
	ld a, (hl);							// load filename character
	cp '.';								// check for dot character
	jr z, handle_invalid_filename_error;	// jump if dot (invalid pattern)
	or a;								// check if end of filename
	ret nz;								// return if valid filename

;	// handle invalid filename error
handle_invalid_filename_error:
	ld a, 8;							// load error code 8 (invalid filename)
	scf;								// set carry flag (error condition)
	ret;								// return with error

;	//  create directory function
	ld a, $80;							// load directory operation code
	call init_file_lookup;				// call file lookup function
	jr c, handle_file_lookup_errors;	// jump if file lookup failed

;	// directory already exists error
directory_exists_error:
	ld a, $12;							// load error code 18 (directory exists)
	scf;								// set carry flag (error condition)
	ret;								// return with error

;	// handle file lookup error codes
handle_file_lookup_errors:
	cp $11;								// check for error code 17 (file not found)
	jr z, directory_exists_error;		// jump to error if found (should not exist)
	cp 5;								// check for error code 5 (access denied)
	scf;								// set carry flag (error condition)
	ret nz;								// return if other error
	call load_cluster_address;			// call file buffer preparation function
	push bc;							// save BC register
	push de;							// save DE register
	call directory_creation_helper;		// call directory creation function
	pop de;								// restore DE register
	pop bc;								// restore BC register
	ret c;								// return if creation failed
	push bc;							// save BC register again
	push de;							// save DE register again
	ld de, $2d00;						// load directory buffer address
	ld hl, $33a2;						// load template address
	exx;								// exchange register sets
	call load_cluster_address;			// call buffer function with alt registers
	exx;								// restore register sets
	call directory_entry_setup;			// call directory entry setup function
	ex de, hl;							// exchange DE and HL
	exx;								// exchange register sets
	pop de;								// restore DE register
	pop bc;								// restore BC register
	exx;								// exchange register sets
	ld hl, $33a1;						// load parent directory template
	call directory_entry_setup;			// call directory entry setup for parent
	ld d, h;							// copy H to D
	ld e, l;							// copy L to E
	inc de;								// increment destination pointer
	xor a;								// clear accumulator
	ld (hl), a;							// clear first byte
	ld bc, $01BF;						// load buffer size (447 bytes for directory clear)
	ldir;								// copy zeros to clear directory buffer
	ld hl, $2d00;						// load directory buffer address
	call call_file_descriptor;			// call directory sector write function
	ret c;								// return if write operation failed
	jp file_flush_update;				// jump to file update function

;	// directory creation helper function
directory_creation_helper:
	xor a;								// clear accumulator
	ld ($3c01), a;						// clear operation flags
	call file_creation_operation;		// call file creation function
	ld (ix + 0), 0;						// clear file descriptor error status
	ret c;								// return if creation failed
	ld hl, disk_sector_buffer;			// load sector buffer address
	call directory_entry_sector_calc;	// call directory sector calculation
	ret c;								// return if calculation failed
	ld a, $0b;							// load offset to attributes field
	add a, e;							// add to directory entry pointer
	ld e, a;							// store updated pointer
	ld a, $10;							// load directory attribute flag
	ld (de), a;							// set directory attribute
	call directory_sector_write;		// call directory sector write function
	ret c;								// return if write failed
	set 3, (ix + $01);					// set directory flag in descriptor
	jp save_hl_reg_again;				// jump to completion routine

;	// directory entry setup function
directory_entry_setup:
	ld bc, $0b;							// load filename length (11 characters)
	ldir;								// copy filename to directory entry
	ld a, $10;							// load directory attribute
	ld (de), a;							// set directory attribute flag
	ex de, hl;							// exchange DE and HL
	inc hl;								// skip to date field
	ld (hl), a;							// set date attribute
	inc hl;								// move to next date field
	ld (hl), a;							// set date attribute
	inc hl;								// move to time field
	rst $08;							// call system function
	defb m_getdate;						// get current date/time
	rst $30;							// call system function
	nop;								// no operation
	xor a;								// clear accumulator
	ld (hl), a;							// clear file size high byte
	inc l;								// increment low byte of HL
	ld (hl), a;							// clear file size low byte
	inc l;								// increment low byte of HL
	push hl;							// save HL register
	exx;								// exchange register sets
	pop hl;								// restore HL in alt set
	ld (hl), c;							// store C value
	inc l;								// move to next directory field
	ld (hl), b;							// store cluster high byte
	inc l;								// move to next directory field
	push hl;							// save directory entry pointer
	exx;								// switch to alternate register set
	pop hl;								// restore pointer in alt registers
	rst $30;							// call ROM calculator routine
	nop;								// padding instruction
	push hl;							// save HL register
	exx;								// exchange register sets
	pop hl;								// restore HL in alt set
	ld (hl), e;							// store E value (cluster low)
	inc l;								// increment low byte of HL
	ld (hl), d;							// store D value (cluster high)
	inc l;								// increment low byte of HL
	push hl;							// save HL register
	exx;								// exchange register sets
	pop hl;								// restore HL in main set
	ld b, a;							// copy A to B
	ld c, b;							// copy B to C
	ld d, c;							// copy C to D
	ld e, d;							// copy D to E
	rst $30;							// call system function
	nop;								// no operation
	ret;								// return from function

;	//  file access function - load filename character  
load_filename_character:
	ld l, $2e;							// load filename character '.' ($2e)
	jr nz, setup_file_access_mode;		// jump if not zero
	jr nz, adjust_file_access_params;	// jump if not zero  
	jr nz, clear_b_byte_count;			// jump if not zero
	jr nz, store_byte_count_c;			// jump if not zero
	jr nz, ldir_copy_block;				// jump if not zero
	ld a, $81;							// load file access mode
	call init_file_lookup;				// call file lookup function
	ret c;								// return if lookup failed
	call setup_directory_cluster;		// call file access setup function
	call store_fs_parameters;			// call file descriptor initialization
	ld hl, $2c80;						// load file buffer address
	ld a, ($3dea);						// load system variable
	ld (iy + $7f), a;					// store in descriptor offset
	push iy;							// save IY register
	pop de;								// load descriptor address to DE

;	// setup file access mode
setup_file_access_mode:
	ld e, $80;							// load file mode flag

;	// adjust file access parameters
adjust_file_access_params:
	sub $80;							// subtract base value

clear_b_byte_count:
	ld b, 0;							// clear B register for byte count

store_byte_count_c:
	ld c, a;							// store byte count in C register

ldir_copy_block equ $33cd

	ldir;								// copy BC bytes from HL to DE
	ld a, b;							// load remaining byte count
	ld (de), a;							// store final byte count
	or a;								// clear carry flag (success)
	ret;								// return from file access function

;	// file creation and initialization function
file_creation_init:
	ld a, 1;							// load file flag value
	or b;								// combine with B register
	and $41;							// mask file attribute bits
	ld (ix + $01), a;					// store in file descriptor flags
	ld a, $80;							// load file operation mode
	call init_file_lookup;				// call file lookup function
	ret c;								// return if lookup failed
	call get_file_next_cluster;			// call file preparation function
	call file_validation_function;		// call file allocation function
	call setup_directory_cluster;		// call access setup function
	call store_cluster_address;			// call buffer initialization
	call setup_file_sector;				// call sector management function
	ld b, 0;							// clear B register
	ld c, b;							// clear C register
	ld d, c;							// clear D register
	ld e, d;							// clear E register
	call store_file_position;			// call file size setup function
	call dec_32bit;						// call 32-bit arithmetic function
	call store_file_size;				// call buffer management function
	call transfer_error_number;			// call file completion function
	or a;								// clear carry flag
	ret	;								// return from function

;	// exchange DE and HL registers
exchange_registers:
	ex de, hl;							// exchange DE and HL

;	// directory buffer read function
directory_buffer_read:
	ld hl, $2d00;						// load directory buffer address
	ld bc, $20;							// load directory entry size (32 bytes)
	push de;							// save DE register
	call file_io_buffer_operation;		// call buffer read function
	pop de;								// restore DE register
	ret c;								// return if read failed
	ld a, (hl);							// load first byte of entry
	and a;								// check if entry is empty (first byte = 0)
	ret z;								// return if empty entry found
	cp $e5;								// check for deleted entry marker
	jr z, directory_buffer_read;		// jump to continue if deleted entry
	ld l, $0b;							// load offset to attributes field
	bit 3, (hl);						// check volume label bit (bit 3)
	ld l, 0;							// reset L to start of entry
	jr nz, directory_buffer_read;		// jump to continue if volume label
	push de;							// save directory entry position
	ld de, $2d20;						// load filename output buffer address
	push de;							// save output buffer pointer
	inc de;								// increment destination pointer
	ld b, 8;							// set filename length (8 characters)
	call filename_char_copy;			// call filename copy function
	ld a, (hl);							// load character from source
	cp ' ';								// check for space character ($20)
	jr z, process_file_extension;		// jump if space (no extension)
	ld a, $2e;							// load dot character for extension
	ld (de), a;							// store dot separator
	inc de;								// increment destination pointer

;	// process file extension
process_file_extension:
	ld b, 3;							// set extension length (3 characters)
	call filename_char_copy;			// call extension copy function
	xor a;								// clear accumulator
	ld (de), a;							// null-terminate filename
	inc de;								// increment destination pointer
	ld a, (hl);							// load file attributes
	and $3F;							// mask attribute bits
	ld ($2d20), a;						// store attributes in buffer
	ld bc, 9;							// skip to cluster field (9 bytes)
	add hl, bc;							// add offset to HL
	ld c, (hl);							// load cluster low byte
	inc hl;								// increment to cluster high byte
	ld b, (hl);							// load cluster high byte
	ld ($3c21), bc;						// store cluster number
	inc hl;								// move to file size field
	ldi;								// copy file size byte 1
	ldi;								// copy file size byte 2
	ldi;								// copy file size byte 3
	ldi;								// copy file size byte 4
	ld c, (hl);							// load date/time low byte
	inc hl;								// increment to date/time high byte
	ld b, (hl);							// load date/time high byte
	ld ($3c1f), bc;						// store date/time information
	inc hl;								// move to next directory entry field
	ldi;								// copy date/time byte 1 and increment pointers
	ldi;								// copy date/time byte 2 and increment pointers
	ldi;								// copy date/time byte 3 and increment pointers
	ldi;								// copy date/time byte 4 and increment pointers
	bit 6, (ix + $01);					// check enhanced directory flag (bit 6)
	call nz, enhanced_directory_processing;	// call enhanced processing if flag set
	ld b, 0;							// clear B register for return value
	ld a, e;							// load destination pointer offset
	sub $20;							// subtract base buffer address
	ld c, a;							// store buffer size in C
	pop hl;								// restore filename buffer pointer
	pop de;								// restore directory entry pointer
	ret c;								// return if error occurred
	rst $30;							// call ROM calculator routine
	ld b, $eb;							// load completion code
	ld a, 1;							// set success flag
	or a;								// clear carry flag (success)
	ret;								// return from directory processing

;	// enhanced directory processing function
enhanced_directory_processing:
	ld a, ($2D20);						// load file attributes from buffer
	bit 4, a;							// check directory attribute flag (bit 4)
	jr nz, directory_invalid_date_handler;	// jump to directory handler if set
	ld hl, $3C1F;						// load date/time buffer address
	push de;							// save output buffer pointer
	rst $30;							// call ROM calculator routine
	ld bc, $0df7;						// load date validation code
	jr z, date_processing_completion;	// jump if date validation passed
	call check_file_position;			// call date conversion function
	ld hl, disk_sector_buffer;			// load date output buffer
	push hl;							// save buffer pointer
	call read_disk_sector;				// call date formatting function
	pop hl;								// restore buffer pointer

;	// date processing completion handler
date_processing_completion:
	pop de;								// restore output buffer pointer
	ret c;								// return if date processing failed
	push de;							// save output buffer pointer
	call filename_validation_checksum;	// call date validation function
	pop de;								// restore output buffer pointer
	jr nz, directory_invalid_date_handler;	// jump to error handler if validation failed
	ld hl, $2d20;						// load file attributes buffer
	ld a, $40;							// load valid file flag (bit 6)
	or (hl);							// combine with existing attributes
	ld (hl), a;							// store updated attributes
	ld hl, $260f;						// load formatted date buffer
	ld bc, 8;							// load date field size (8 bytes)

;	// date field copy and completion
date_field_copy_complete:
	ldir;								// copy date field to output buffer
	xor a;								// clear accumulator (success code)
	ret;								// return from date processing

;	// directory or invalid date handler
directory_invalid_date_handler:
	ld a, $ff;							// load invalid date marker (255)
	ld (de), a;							// store invalid marker in output
	inc de;								// increment output pointer
	inc a;								// increment to 0 (next invalid marker)
	ld (de), a;							// store second invalid marker
	push de;							// save output pointer
	pop hl;								// transfer to HL for copying
	inc de;								// increment destination pointer
	ld bc, 5;							// load remaining field size (5 bytes)
	jr date_field_copy_complete;		// jump to field copy completion

;	// character copy function for filename processing
filename_char_copy:
	ld a, (hl);							// load character from source filename
	inc hl;								// move to next filename character
	cp ' ';								// $20
	jr z, final_char_loop;				// skip if space character (padding)
	ld (de), a;							// store valid character in output
	inc de;								// increment output pointer

final_char_loop:
	djnz filename_char_copy;			// decrement B and loop for all characters
	ret;								// return from filename copy function

;	// directory buffer setup and validation function
directory_buffer_setup:
	ld de, $2d00;						// load directory buffer address
	ld hl, $40;							// load source filename template
	ld bc, $0b;							// load filename length (11 characters)
	ldir;								// copy filename template to buffer
	ld hl, ($3c23);						// load cluster/directory information
	ld e, $0f;							// set directory attributes offset
	ld bc, 8;							// set attribute field size
	rst $30;							// call ROM calculator routine
	rlca;								// rotate accumulator left
	xor a;								// clear accumulator
	ld (de), a;							// clear directory field
	ld h, d;							// copy D to H
	ld l, e;							// copy E to L 
	inc e;								// increment directory pointer
	ld bc, $67;							// load clear size (103 bytes)
	ldir;								// clear remaining directory fields
	push de;							// save directory entry pointer
	ld l, $10;							// offset to cluster field
	ld e, (hl);							// load cluster low byte
	inc l;								// increment to cluster high byte
	ld d, (hl);							// load cluster high byte
	ld b, a;							// copy accumulator to B
	ld c, a;							// copy accumulator to C
	push hl;							// save cluster pointer
	ld hl, $80;							// load sector size constant
	call add_32bit;						// call arithmetic function
	pop hl;								// restore cluster pointer
	ld l, $0b;							// offset to attributes field
	rst $30;							// call ROM calculator routine
	nop;								// padding instruction
	pop hl;								// restore entry pointer
	ld l, 0;							// reset to entry start
	ld c, $7f;							// load checksum counter (127 bytes)
	xor a;								// clear accumulator for checksum

add_dir_byte_checksum:
	add a, (hl);						// add directory byte to checksum
	cpi;								// compare and increment, decrement BC
	jp pe, add_dir_byte_checksum;		// loop while parity even (BC not zero)
	ld (hl), a;							// store calculated checksum
	ret;								// return from checksum calculation

;	// memory validation and arithmetic function
memory_validation_arithmetic:
	call get_working_cluster;			// call memory bounds checking function
	ld a, b;							// load B register value
	inc a;								// increment for boundary test
	jr nz, call_memory_setup;			// jump if not at memory boundary
	call clear_memory_flag;				// call memory allocation function
	cp 9;								// check for error code 9 (out of memory)
	scf;								// set carry flag (error condition)
	ret nz;								// return if error occurred

call_memory_setup:
	call set_working_cluster;			// call memory setup function
	ld a, (iy + _x_ptr);				// load X pointer from system variables

shift_right_a_reg:
	srl a;								// shift right A register
	ccf;								// complement carry flag
	ret nc;								// return if no carry (shift complete)
	sla e;								// shift left E register
	rl d;								// rotate left D register with carry
	rl c;								// rotate left C register with carry
	rl b;								// rotate left B register with carry
	jr shift_right_a_reg;				// loop for multi-precision left shift

clear_memory_flag:
	res 3, (iy + _oldppc);				// clear memory management flag bit 3
	exx;								// switch to alternate register set
	ld bc, 0;							// clear BC register pair
	ld de, 2;							// load minimum allocation size
	call check_drive_cluster_cache;		// call memory allocation function
	ret c;								// return if allocation failed

call_memory_mgmt:
	call check_system_flag_bit;			// call memory management function
	exx;								// switch to alternate register set
	call inc_32bit;						// call 32-bit increment function
	ret c;								// return if arithmetic overflow
	exx;								// switch back to main register set
	jr call_memory_mgmt;				// loop for memory block processing
;	// return point from memory allocation loop
memory_allocation_return:
	call load_file_position;			// call file position function
	or a;								// clear carry flag (success)
	ret;								// return from memory allocation

;	// directory entry removal with state management
directory_entry_removal:
	push hl;							// save filename pointer
	ld b, 0;							// clear operation mode flag
	call file_creation_init;			// call file creation function
	pop hl;								// restore filename pointer
	ret c;								// return if operation failed
	ld a, ($3df8);						// load original state flag
	ld c, a;							// save in C register
	ld a, ($3df9);						// load new state flag
	ld ($3df8), a;						// update state flag
	push hl;							// save registers
	push bc;							// save state information
	call init_dir_entry_counter;		// call directory validation
	pop bc;								// restore state information
	pop hl;								// restore registers
	push af;							// save operation result
	ld a, c;							// load original state
	ld ($3df8), a;						// restore original state
	pop af;								// restore operation result
	ret c;								// return if validation failed
	ld a, $80;							// load file operation code
	jr call_file_lookup;				// jump to file deletion

init_dir_entry_counter:
	ld b, 0;							// initialize directory entry counter

;	// directory entry validation loop
directory_entry_validation_loop:
	ld hl, $2d40;						// load directory entry buffer
	push bc;							// save entry counter
	push hl;							// save buffer pointer
	call exchange_registers;			// call directory read function
	pop hl;								// restore buffer pointer
	pop bc;								// restore entry counter
	ret c;								// return if read failed
	and a;								// test if entry found
	jr z, validate_directory_count;		// jump if no entry found
	inc b;								// increment entry count
	inc hl;								// move to next entry
	ld a, (hl);							// load entry character
	cp '.';								// $2e
	jr z, directory_entry_validation_loop;	// loop if dot entry (current/parent dir)

;	// directory entry count validation error
directory_count_validation_error:
	ld a, $1b;							// load error code 27 (directory not empty)
	scf;								// set carry flag (error condition)
	ret;								// return with error

;	// validate directory entry count
validate_directory_count:
	ld a, b;							// load entry count
	cp 2;								// compare with 2 (only . and .. should remain)
	jr nz, directory_count_validation_error;	// jump to error if more entries exist
	ld a, ($3c06);						// load first character of filename
	cp '.';								// $2e
	jr nz, clear_carry_success;			// jump if not dot directory
	ld a, 8;							// load error code 8 (invalid operation)
	scf;								// set carry flag (error condition)
	ret;								// return with error

clear_carry_success:
	or a;								// clear carry flag (success)
	ret;								// return from validation

;	// file deletion handler continuation
file_deletion_continuation:
	ld a, 0;							// clear operation mode

call_file_lookup:
	call init_file_lookup;				// call file lookup function
	ret c;								// return if lookup failed
	call transfer_error_number;			// call file validation function
	call get_file_next_cluster;			// call file descriptor setup
	call file_validation_function;		// call file allocation function
	call setup_directory_cluster;		// call directory access setup
	ld hl, $1a65;						// load completion handler address
	ld ($3dee), hl;						// store completion handler pointer
	call descriptor_cleanup_validation;	// execute completion handler
	ld a, $17;							// load error code 23 (file operation failed)
	jr c, file_deletion_error_handler;	// jump to error handler if operation failed
	ld l, (ix + $1C);					// load directory entry pointer low byte
	ld h, (ix + $1D);					// load directory entry pointer high byte
	push hl;							// save directory entry pointer
	ld a, $0b;							// offset to file attributes
	add a, l;							// add offset to entry pointer
	ld l, a;							// update pointer to attributes
	bit 0, (hl);						// check read-only attribute
	pop hl;								// restore directory entry pointer
	ld a, $18;							// load error code 24 (file is read-only)
	scf;								// set carry flag (error condition)
	jr nz, file_deletion_error_handler;	// jump to error handler if read-only
	ld (hl), $e5;						// mark directory entry as deleted
	push bc;							// save BC register
	push de;							// save DE register
	call directory_sector_write;		// call directory sector write
	pop de;								// restore DE register
	pop bc;								// restore BC register
	call nc, call_rom_calculator;		// call cluster deallocation if write succeeded
	call nc, flush_dirty_buffer;		// call file descriptor cleanup if successful

;	// file deletion error handler
file_deletion_error_handler:
	ld (ix + 0), 0;						// clear file descriptor status
	ret;								// return with error condition

;	// directory management with file creation
directory_mgmt_file_creation:
	ld b, 1;							// set directory creation flag
	push hl;							// save directory name pointer
	push de;							// save registers
	call file_delete_operation;			// call directory creation function
	pop de;								// restore registers
	pop hl;								// restore directory name pointer
	jr nc, exchange_de_hl;				// jump if creation successful
	cp $10;								// check for error code 16 (directory exists)
	scf;								// set carry flag (error condition)
	ret nz;								// return if other error
	push de;							// save registers for file creation
	ld b, 0;							// clear creation mode (file not directory)
	call file_creation_init;			// call file creation function
	pop de;								// restore registers
	ret c;								// return if file creation failed

exchange_de_hl:
	ex de, hl;							// exchange DE and HL registers
	call directory_entry_attribute_mgmt;	// call directory processing function
	ret;								// return from directory management

;	// directory entry setup and attribute management  
directory_entry_attribute_mgmt:
	push hl;							// save directory entry pointer
	ld hl, $2d00;						// load directory buffer address
	ld a, (iy + 0);						// load system variable byte 0
	ld (hl), a;							// store in directory buffer
	inc hl;								// increment buffer pointer
	ld a, (iy + 1);						// load system variable byte 1
	ld (hl), a;							// store in directory buffer
	call directory_update_function;		// call directory sector access
	pop de;								// restore directory entry pointer
	ret c;								// return if sector access failed
	push de;							// save directory entry pointer again
	ex de, hl;							// exchange DE and HL
	ld hl, $2d02;						// load directory data buffer
	ld a, $0b;							// load attributes offset
	ld c, a;							// save offset in C
	add a, e;							// add offset to entry pointer
	ld e, a;							// update entry pointer
	ld a, (de);							// load file attributes
	ld (hl), a;							// store attributes in buffer
	inc hl;								// increment buffer pointer
	ld a, c;							// restore attributes offset
	add a, e;							// add to entry pointer
	ld e, a;							// update entry pointer
	ex de, hl;							// exchange DE and HL
	ld bc, 4;							// load copy count (4 bytes)
	ldir;								// copy directory entry data
	ex de, hl;							// exchange DE and HL back
	call load_file_size;				// call buffer management function
	rst $30;							// call ROM calculator
	nop;								// padding instruction
	pop de;								// restore directory entry pointer
	ld hl, $2d00;						// load directory buffer address
	ld bc, $0b;							// load filename length
	rst $30;							// call ROM calculator
	ld b, $b7;							// load operation code
	jp error_buffer_management;			// jump to directory completion handler
;	// file truncation function
file_truncation_function:
	ld a, 0;							// clear operation mode (truncate)
	call init_file_lookup;				// call file lookup function
	ret c;								// return if lookup failed
	call transfer_error_number;			// call file validation
	call get_file_next_cluster;			// call file descriptor setup
	call file_validation_function;		// call file allocation
	ld l, (ix + $1C);					// load directory entry pointer low
	ld h, (ix + $1D);					// load directory entry pointer high
	ld a, $0b;							// offset to attributes field
	add a, l;							// add offset to pointer
	ld l, a;							// update pointer to attributes
	bit 0, (hl);						// check read-only attribute
	ld a, $18;							// load error code 24 (read-only)
	scf;								// set carry flag (error)
	jr nz, write_error_handler;			// jump to error if read-only
	ld b, 0;							// clear 32-bit value
	ld c, b;							// clear C register
	ld d, c;							// clear D register  
	ld e, d;							// clear E register
	call call_file_sync;				// call file buffer sync
	call setup_directory_cluster;		// call directory access
	call system_processing_call;		// call truncation completion

;	// file operation error handler
write_error_handler:
	push af;							// save error code and flags
	call file_close_operation;			// call file descriptor cleanup
	pop af;								// restore error code and flags
	ret;								// return with original error condition

;	// file write operation with validation
file_write_validation:
	bit 1, (ix + $01);					// check file write flag (bit 1)
	ld a, 8;							// load error code 8 (file not open for write)
	scf;								// set carry flag (error condition)
	ret z;								// return if file not open for writing
	call load_file_position;			// call file position function
	call call_file_sync;				// call buffer synchronization
	call get_file_sector_address;		// call write operation handler

system_processing_call:
	call call_rom_calculator;			// system processing call
	call nc, flush_dirty_buffer;		// call if no carry
	ld hl, $1a7c;						// set system address
	ld ($3dee), hl;						// store system address
	call descriptor_cleanup_validation;	// call processing routine
	or a;								// test accumulator
	ret;								// return to caller
