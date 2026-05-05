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

;	// file I/O operation with buffer management
file_io_buffer_operation:
	push hl;							// save HL register
	set 5, (ix + 1);					// set buffer flag in descriptor
	call buffer_io_function;			// call buffer I/O function
	res 5, (ix + 1);					// clear buffer flag
	pop hl;								// restore HL register
	ret;								// return from operation

;	// file close operation
file_close_operation:
	call file_flush_update;				// call file close function
	ld (ix + 0), 0;						// clear file descriptor status
	ret;								// return from close operation

;	// file flush and update operation
file_flush_update:
	or a;								// clear carry flag initially

file_flush_loop_start equ $1699

	bit 3, (ix + 1);					// check if directory operation flag set
	jp z, flush_dirty_buffer;			// jump to cleanup if not directory
	call directory_update_function;		// call directory update function
	ret c;								// return if update failed
	ld de, $14;							// load offset to directory entry data
	add hl, de;							// add offset to HL
	call load_cluster_address;			// call file position function
	ld (hl), c;							// store low byte of position
	inc hl;								// increment to next byte
	ld (hl), b;							// store high byte of position
	inc hl;								// skip to next field
	inc hl;								// skip reserved bytes
	inc hl;								// continue skipping
	inc hl;								// skip more reserved bytes
	inc hl;								// advance to size field
	ld (hl), e;							// store size low byte
	inc hl;								// increment to next byte
	ld (hl), d;							// store size high byte
	inc hl;								// increment pointer
	call load_file_size;				// call file size function
	rst $30;							// call system function
	nop;								// no operation
	call directory_sector_write;		// call directory write function

;	// error handling and buffer management function
error_buffer_management:
	push af;							// save accumulator and flags
	ld hl, $3c1b;						// load buffer management address
	rst $30;							// call system function
	ld bc, $4fcd;						// load error recovery parameters
	ld de, $c3f1;						// load jump instruction pattern
	di;									// interrupts off

;	// directory update processing function
directory_update_function equ $16cb

	djnz file_flush_loop_start;			// loop back to file flush if B register not zero
	ld e, h;							// copy H to E register
	ld de, $1b21;						// load directory operation code
	inc a;								// increment accumulator

;	// continue directory processing after error recovery
	rst $30;							// call system function
	nop;								// no operation
	call load_directory_cluster;		// call file size get function
	call set_file_next_cluster;			// call cluster set function
	call directory_position_function;	// call directory position function
	ex de, hl;							// exchange DE and HL
	ret;								// return from function

;	// file delete operation entry point
file_delete_operation:
	ld a, b;							// load operation flags from B
	ld ($3c01), a;						// store operation flags
	ld ($3c23), de;						// store file parameters
	ld a, 1;							// load file lookup mode
	call init_file_lookup;				// call file lookup function
	jr nc, handle_existing_file;		// jump if file found
	cp 5;								// check for file not found error
	scf;								// set carry flag (error)
	ret nz;								// return if other error
	ld a, ($3c01);						// load operation flags
	and %00001100;						// mask file operation bits
	scf;								// set carry flag (error)
	ld a, 5;							// load file not found error
	ret z;								// return if no operation specified
	jp file_creation_operation;			// jump to file creation

;	// handle existing file operations
handle_existing_file:
	ld a, ($3c01);						// load operation flags
	and %00001100;						// mask file operation type bits
	cp 4;								// check for delete operation
	jr nz, determine_file_operation;	// jump if not delete
	scf;								// set carry flag (error)
	ld a, $12;							// load error code 18 (file exists)
	ret;								// return with error

;	// determine file operation type
determine_file_operation:
	cp $0c;								// check for directory creation
	jp z, directory_creation_handler;	// jump to directory creation function
	jp file_access_handler;				// jump to file access function

;	// file creation operation
file_creation_operation:
	call validate_cluster_operation;	// call cluster validation function
	ret c;								// return if validation failed
	call directory_position_function;	// call directory position function
	ret c;								// return if position failed
	ld a, (de);							// load directory entry status
	push af;							// save status
	call directory_entry_creation;		// call directory entry creation
	pop de;								// restore status to DE
	ret c;								// return if creation failed
	ld a, d;							// check entry status
	cp $e5;								// check for deleted entry marker
	jr z, init_file_descriptor;			// jump to initialization if deleted
	call clear_directory_entry;			// call directory entry clear function
	ret c;								// return if clear failed

;	// initialize file descriptor and setup file attributes
init_file_descriptor:
	ld hl, $3c1b;						// load file buffer address
	rst $30;							// call system function
	ld bc, $07cd;						// load initialization parameters
	ld a, (de);							// load entry data
	call reset_file_position;			// call file position reset function
	call store_file_position;			// call file position store function
	ld a, ($3c01);						// load operation flags
	push af;							// save flags
	and %00000011;						// mask access mode bits
	or %00000010;						// set write access bit
	ld (ix + 1), a;						// store access mode in descriptor
	pop af;								// restore original flags
	or a;								// check flags
	bit 6, a;							// check directory creation bit
	jr z, finalize_file_creation;		// jump if not directory
	call directory_buffer_setup;		// call directory initialization function
	call save_hl_reg_again;				// call directory setup function
	ret c;								// return if setup failed
	ld hl, $2d00;						// load directory buffer address
	call call_file_descriptor;			// call directory write function
	ret c;								// return if write failed
	set 3, (ix + 1);					// set directory flag in descriptor
	ld a, $80;							// load directory buffer offset
	ld (ix + 11), a;					// store in file descriptor
	ld (ix + 15), a;					// store buffer position
	call file_flush_update;				// call file update function
	ret c;								// return if update failed

;	// complete file creation and setup file buffer
finalize_file_creation:
	call transfer_error_number;			// call error number transfer function
	ld hl, $2c80;						// load file buffer address
	ld a, ($3df9);						// load file buffer size
	ld b, a;							// copy size to B register
	or b;								// check if size is valid
	ret;								// return with status

;	// transfer system error number to file descriptor
transfer_error_number:
	ld a, (iy + _err_nr);				// load error number from system variables
	ld (ix + 0), a;						// store error in file descriptor
	ret;								// return from function

;	// clear directory buffer based on address alignment
clear_directory_entry:
	ld a, h;							// load high byte of address
	and %00000001;						// check if address is odd (bit 0)
	add a, l;							// add to low byte for alignment check
	ld bc, next_char_rst20;				// load default clear size (31 bytes)
	jr nz, clear_buffer_operation;		// jump to clear if not aligned
	set 2, (ix + 1);					// set buffer operation flag
	call process_sector_decrement;		// call sector processing function
	res 2, (ix + 1);					// clear buffer operation flag
	ld hl, disk_sector_buffer;			// load sector buffer address
	ld bc, $01ff;						// load full sector size (511 bytes)

;	// clear memory buffer with zeros
clear_buffer_operation:
	ld a, (hl);							// load byte from buffer (will be overwritten)
	ld d, h;							// copy source address high to destination
	ld e, l;							// copy source address low to destination
	inc de;								// increment destination pointer
	ld (hl), 0;							// store zero at source address
	ldir;								// copy zeros to clear entire buffer
	call directory_sector_write;		// call directory sector write function
	ret;								// return from clear operation

;	// create new directory entry from filename
directory_entry_creation:
	ld hl, $3c06;						// load formatted filename buffer address
	ld bc, $0b;							// load filename length (11 characters FAT format)
	ldir;								// copy filename to directory entry
	xor a;								// clear accumulator
	ld (de), a;							// null-terminate filename
	ex de, hl;							// exchange DE and HL
	inc hl;								// move to attribute field

;	// initialize directory entry fields
init_dir_entry:
	ld (hl), a;							// clear attribute field
	inc hl;								// move to next field
	ld (hl), a;							// clear reserved field
	inc hl;								// move to time field
	rst $08;							// call system function
	defb m_getdate;						// get current date/time
	rst $30;							// call system function
	nop;								// no operation
	xor a;								// clear accumulator
	ld (hl), a;							// clear file size byte 1
	inc l;								// increment to next byte
	ld (hl), a;							// clear file size byte 2
	inc l;								// increment to next byte
	ld (hl), a;							// clear file size byte 3
	inc l;								// increment to next byte
	ld (hl), a;							// clear file size byte 4
	inc l;								// increment to cluster field
	rst $30;							// call system function
	nop;								// no operation
	ld (hl), a;							// clear cluster low byte
	inc l;								// increment to next byte
	ld (hl), a;							// clear cluster high byte
	inc l;								// increment pointer
	ld b, a;							// clear B register
	ld c, b;							// clear C register
	ld d, c;							// clear D register
	ld e, d;							// clear E register (32-bit zero)
	rst $30;							// call ROM calculator routine
	nop;								// padding instruction
	push hl;							// save directory entry pointer
	call directory_sector_write;		// call directory sector write function
	pop hl;								// restore directory entry pointer
	ret c;								// return if write failed
	push hl;							// save entry pointer again
	call get_file_next_cluster;			// call file descriptor function
	ld hl, $3c1b;						// load file buffer address
	rst $30;							// call ROM calculator routine
	nop;								// padding instruction
	pop hl;								// restore entry pointer
	or a;								// clear carry flag (success)
	ret;								// return from function

;	// file position reset function
reset_file_position:
	ld b, 0;							// clear 32-bit file position
	ld c, b;							// clear C register
	ld d, c;							// clear D register
	ld e, d;							// clear E register (position = 0)
	call set_file_sector_address;		// call file position validation
	call store_file_size;				// call file size store function
	ret;								// return from position reset

;	// directory sector write function
directory_sector_write:
	ld hl, disk_sector_buffer;			// load sector buffer address
	call call_file_descriptor;			// call sector write routine
	push af;							// save write result flags
	xor a;								// clear accumulator
	ld ($3c26), a;						// clear sector modification flag
	pop af;								// restore write result
	ret;								// return with write status

;	// directory position calculation function
directory_position_function:
	ld hl, disk_sector_buffer;			// load sector buffer address
	push hl;							// save buffer address
	call process_file_sector;			// call directory sector read function
	pop hl;								// restore buffer address
	ret c;								// return if read failed

;	// directory entry sector calculation
directory_entry_sector_calc:
	ld a, $10;							// load entries per sector (16)
	sub (ix + 6);						// subtract drive number for offset
	sla a;								// shift left (multiply by 2)
	sla a;								// shift left (multiply by 4)
	sla a;								// shift left (multiply by 8)
	sla a;								// shift left (multiply by 16)
	sla a;								// shift left (multiply by 32 bytes per entry)
	ld e, a;							// store byte offset in E
	ld d, 0;							// clear high byte
	rl d;								// rotate carry into D for 16-bit offset
	add hl, de;							// add offset to base address
	ex de, hl;							// exchange DE and HL (result in DE)
	or a;								// clear carry flag (success)
	ret;								// return with calculated address

;	// directory creation and initialization function
directory_creation_handler:
	call setup_directory_cluster;		// call directory setup function
	push bc;							// save BC register pair
	push de;							// save DE register pair
	ld l, (ix + 28);					// load directory entry pointer low
	ld h, (ix + 29);					// load directory entry pointer high
	ld de, $0c;							// load offset to file size field (12 bytes)
	add hl, de;							// add offset to pointer
	call init_dir_entry;				// call file size write function
	pop de;								// restore DE register pair
	pop bc;								// restore BC register pair
	ret c;								// return if size write failed
	call call_rom_calculator;			// call system function
	call nc, flush_dirty_buffer;		// call directory update if no error
	ret c;								// return if update failed
	call reset_file_position;			// call file position reset
	call store_file_position;			// call cluster chain update
	call transfer_error_number;			// call directory finalize function
	ld hl, $1a7c;						// load function vector address
	ld ($3dee), hl;						// store function vector
	call descriptor_cleanup_validation;	// call directory completion function
	ld (ix + 0), 0;						// clear file status byte
	jp init_file_descriptor;			// jump to completion routine

;	// file access and initialization function
file_access_handler:
	ld a, ($3c01);						// load file access mode flags
	push af;							// save access flags
	and %00000011;						// mask to get access mode (read/write)
	ld (ix + 1), a;						// store access mode in file descriptor
	call get_file_next_cluster;			// call file descriptor setup
	call file_validation_function;		// call file validation function
	call setup_directory_cluster;		// call directory setup
	call file_position_init;			// call file position initialization
	ld l, (ix + 28);					// load directory entry pointer low
	ld h, (ix + 29);					// load directory entry pointer highload directory entry pointer high
	ld de, $1c;							// load offset to file data area (28 bytes)
	add hl, de;							// add offset to get data pointer
	call file_processing_validation;	// call file processing function
	pop af;								// restore access flags
	bit 6, a;							// test write access bit
	jr z, $1894;						// jump if read-only access
	ld hl, $2d00;						// load buffer address for write mode
	ld bc, $80;							// load buffer size (128 bytes)
	call file_io_buffer_operation;		// call buffer allocation function
	ret c;								// return if allocation failed
	call filename_validation_checksum;	// call filename validation
	ld l, $0f;							// load file attribute mask
	jr z, file_attribute_processing;	// jump if validation passed
	ld (ix + 15), 0;					// clear file handle
	push hl;							// save attribute mask
	call file_buffer_init;				// call file buffer initialization
	pop hl;								// restore attribute mask

file_attribute_processing:
	ld de, ($3c23);						// load file attribute data address
	ld bc, 8;							// load attribute data length
	rst $30;							// call ROM memory copy routine
	ld b, $c3;							// load file completion marker
	ld h, a;							// store completion status
	rla;								// rotate left for status check

;	// file processing and validation function
file_processing_validation:
	rst $30;							// call ROM calculator routine
	ld bc, $d3cd;						// load function code for file processing
	add hl, de;							// add offset to file pointer
	or a;								// clear carry flag (success)
	ret;								// return from function

;	// file buffer initialization function
file_buffer_init:
	push af;							// save accumulator flags
	ld a, $ff;							// load file marker value (empty)
	ld (hl), a;							// store marker in buffer
	inc l;								// increment buffer pointer
	call load_file_size;				// call cluster address calculation
	ld (hl), e;							// store cluster address low byte
	inc l;								// increment pointer
	ld (hl), d;							// store cluster address high byte
	inc l;								// increment pointer
	ld b, 5;							// load loop counter (5 bytes)
	xor a;								// clear accumulator

clear_buffer_loop:
	ld (hl), a;							// clear buffer byte
	inc l;								// increment pointer
	djnz clear_buffer_loop;				// decrement B and loop if not zero
	pop af;								// restore accumulator flags
	ret;								// return from initialization

;	// filename validation and checksum function
filename_validation_checksum:
	push hl;							// save filename pointer
	ld de, $40;							// load comparison buffer address
	ld bc, 9;							// load filename length (8.3 format)

checksum_compare_loop:
	ld a, (de);							// load byte from comparison buffer
	cpi;								// compare with filename and increment
	jr nz, filename_compare_finished;	// jump if no match
	inc de;								// increment comparison pointer
	jp pe, checksum_compare_loop;		// jump if more bytes to compare

filename_compare_finished:
	pop hl;								// restore filename pointer
	ret nz;								// return if filename doesn't match
	ld c, $7f;							// load checksum mask value
	xor a;								// clear accumulator for checksum

checksum_calculation_loop:
	add a, (hl);						// add filename byte to checksum
	cpi;								// increment pointer and compare
	jp pe, checksum_calculation_loop;	// loop if more bytes to process
	cp (hl);							// compare calculated checksum
	ret;								// return with comparison result

;	// file position initialization function
file_position_init:
	call store_cluster_address;			// call file size validation
	call setup_file_sector;				// call cluster chain setup
	ld b, 0;							// clear 32-bit file position
	ld c, b;							// clear C register
	ld d, c;							// clear D register
	ld e, d;							// clear E register (position = 0)
	jp store_file_position;				// jump to cluster update function
	bit 0, (ix + 1);					// test file access mode bit
	ld a, 8;							// load error code (invalid access)
	scf;								// set carry flag (error condition)
	ret z;								// return error if access mode is zero
	push hl;							// save buffer pointer
	call calculate_file_size;			// call file size calculation
	pop hl;								// restore buffer pointer
	ld a, c;							// load size low byte
	or b;								// combine with high byte
	ret z;								// return if size is zero

buffer_io_function:
	res 2, (ix + 1);					// clear file modification bit

;	// file I/O byte count preservation
file_io_byte_count:
	push bc;							// save byte count for loop processing

;	// file position load and validation loop
file_position_load_loop:
	ld e, (ix + 15);					// load file position low byte
	ld a, (ix + 16);					// load file position byte 1
	and %00000001;						// mask to get sector offset bit
	ld d, a;							// store masked offset in D
	call position_validation_function;	// call position validation function
	jr c, file_io_error_cleanup;		// jump to error cleanup if validation failed
	push bc;							// save byte count
	push hl;							// save buffer pointer
	ld hl, $0200;						// load sector size (512 bytes)
	sbc hl, de;							// calculate remaining space in sector
	ex de, hl;							// exchange HL and DE
	ld h, b;							// load byte count high byte
	ld l, c;							// load byte count low byte
	sbc hl, de;							// subtract available space
	jr c, restore_buffer_and_process;	// jump if all bytes fit in sector
	ld b, d;							// limit to available space
	ld c, e;							// store limited byte count

restore_buffer_and_process:
	pop hl;								// restore buffer pointer
	push bc;							// save processed byte count
	call sector_io_dispatch;			// call sector I/O operation
	pop de;								// restore processed count in DE
	pop bc;								// restore original byte count
	jr c, file_io_error_cleanup;		// jump to cleanup if I/O failed
	ld a, c;							// load original count low
	sub e;								// subtract processed count
	ld c, a;							// store remaining count
	ld a, b;							// load original count high
	sbc a, d;							// subtract processed count with borrow
	ld b, a;							// store remaining count
	or c;								// check if any bytes remain
	ex de, hl;							// exchange buffer pointers
	call update_file_position;			// call buffer position update
	ex de, hl;							// restore buffer pointers
	jr nz, file_position_load_loop;		// loop if more bytes to process
	or a;								// clear carry (success)

file_io_error_cleanup:
	pop de;								// restore stack balance
	push af;							// save error flags
	ex de, hl;							// exchange pointers
	or a;								// clear carry for subtraction
	sbc hl, bc;							// calculate bytes transferred
	ld b, h;							// store transferred count
	ld c, l;							// in BC register pair
	ex de, hl;							// restore pointers
	pop af;								// restore error flags
	ret;								// return with transfer status

position_validation_function:
	or e;								// check if E register is non-zero
	ret nz;								// return if E is not zero
	push de;							// save DE register pair
	push bc;							// save BC register pair
	push hl;							// save HL register pair
	call load_file_position;			// call file position load function
	rst $30;							// call ROM calculator routine
	dec c;								// decrement C register
	call nz, process_sector_decrement;	// call function if C not zero
	pop hl;								// restore HL register pair
	pop bc;								// restore BC register pair
	pop de;								// restore DE register pair
	ret;								// return from function

;	// sector I/O dispatch function
sector_io_dispatch:
	ld a, b;							// load byte count high
	sub 2;								// subtract 2 (512 bytes = 2x256)
	or c;								// combine with low byte
	jr nz, partial_sector_io;			// jump if not exactly 512 bytes
	bit 2, (ix + 1);					// test write mode bit
	jp nz, write_with_page_management;	// jump to write function if set
	bit 5, (ix + 1);					// test read mode bit
	jp nz, process_file_sector;			// jump to read function if set
	jp process_file_flags;				// jump to default I/O function

;	// partial sector I/O function
partial_sector_io:
	push bc;							// save byte count
	push hl;							// save buffer pointer
	call check_sector_flags;			// call sector buffer setup
	pop de;								// restore buffer as destination
	pop bc;								// restore byte count
	ret c;								// return if setup failed
	ld l, (ix + 15);					// load file position low
	ld a, (ix + 16);					// load file position byte 2
	and %00000001;						// mask to get sector offset bit
	add a, h;							// add to buffer high address
	ld h, a;							// store masked position in H register
	bit 2, (ix + 1);					// test write mode bit
	jr nz, write_mode_handler;			// jump to write handler if set
	bit 5, (ix + 1);					// test read mode bit
	jr z, spi_interface_handler;		// jump to SPI handler if not set
	ldir;								// copy BC bytes from HL to DE
	ex de, hl;							// exchange source and destination pointers
	or a;								// clear carry flag (success)
	ret;								// return from copy operation

;	// SPI interface handler function
spi_interface_handler:
	rst $30;							// call ROM calculator routine
	ld b, mmcspi;						// load MMC SPI port address
	ret;								// return from SPI handler

;	// write mode handler function
write_mode_handler:
	ex de, hl;							// exchange DE and HL registers
	rst $30;							// call ROM calculator routine
	rlca;								// rotate A left circular
	jp clear_memory_buffer;				// jump to write processing routine

;	// file size calculation and validation function
calculate_file_size:
	push bc;							// save BC register pair
	call load_file_position;			// call file position load function
	ld h, (ix + 12);					// load file size high byte
	ld l, (ix + 11);					// load file size low byte
	or a;								// clear carry for subtraction
	sbc hl, de;							// subtract file position from size
	ex de, hl;							// exchange result to DE
	ld h, (ix + 14);					// load file size upper high byte
	ld l, (ix + 13);					// load file size upper low byte
	sbc hl, bc;							// subtract position high from size high
	pop bc;								// restore BC register pair
	ld a, l;							// load result low byte
	or h;								// combine with high byte
	ret nz;								// return if size calculation non-zero
	ld h, d;							// copy remaining size to HL
	ld l, e;							// for comparison with requested bytes
	sbc hl, bc;							// subtract requested from available
	ret nc;								// return if enough bytes available
	ld b, d;							// limit to available bytes
	ld c, e;							// store in BC
	ret;								// return with limited byte count

;	// file position update and store function
update_file_position:
	push de;							// save DE register pair
	push bc;							// save BC register pair
	call load_file_position;			// call file position load function
	call add_32bit;						// call 32-bit addition function
	call store_file_position;			// call file position store function
	pop bc;								// restore BC register pair
	pop de;								// restore DE register pair
	ret;								// return from function

;	// store 32-bit file position (DEBC -> file descriptor)
store_file_position:
	ld (ix + 15), e;					// store file position byte 0 (low)
	ld (ix + 16), d;					// store file position byte 1
	ld (ix + 17), c;					// store file position byte 2
	ld (ix + 18), b;					// store file position byte 3 (high)
	ret;								// return from position store

;	// load 32-bit file position (file descriptor -> DEBC)
load_file_position:
	ld e, (ix + 15);					// load file position byte 0 (low)
	ld d, (ix + 16);					// load file position byte 1
	ld c, (ix + 17);					// load file position byte 2
	ld b, (ix + 18);					// load file position byte 3 (high)
	ret;								// return with position in DEBC

;	// store 32-bit file size (DEBC -> file descriptor)
store_file_size:
	ld (ix + 11), e;					// store file size byte 0 (low)
	ld (ix + 12), d;					// store file size byte 1
	ld (ix + 13), c;					// store file size byte 2
	ld (ix + 14), b;					// store file size byte 3 (high)
	ret;								// return from size store

;	// load 32-bit file size (file descriptor -> DEBC)
load_file_size:
	ld e, (ix + 11);					// load file size byte 0 (low)
	ld d, (ix + 12);					// load file size byte 1
	ld c, (ix + 13);					// load file size byte 2
	ld b, (ix + 14);					// load file size byte 3 (high)
	ret;								// return with size in DEBC

;	// store 32-bit cluster address (DEBC -> file descriptor)
store_cluster_address:
	ld (ix + 7), e;						// store cluster address byte 0 (low)
	ld (ix + 8), d;						// store cluster address byte 1
	ld (ix + 9), c;						// store cluster address byte 2
	ld (ix + 10), b;					// store cluster address byte 3 (high)
	ret;								// return from cluster store

;	// load 32-bit cluster address (file descriptor -> DEBC)
load_cluster_address:
	ld e, (ix + 7);						// load cluster address byte 0 (low)
	ld d, (ix + 8);						// load cluster address byte 1
	ld c, (ix + 9);						// load cluster address byte 2
	ld b, (ix + 10);					// load cluster address byte 3 (high)
	ret;								// return with cluster in DEBC

;	// store 32-bit directory cluster (DEBC -> file descriptor)
file_validation_function:
	ld (ix + 2), e;						// store directory cluster byte 0 (low)
	ld (ix + 3), d;						// store directory cluster byte 1
	ld (ix + 4), c;						// store directory cluster byte 2
	ld (ix + 5), b;						// store directory cluster byte 3 (high)
	ret;								// return from directory store

;	// load 32-bit directory cluster (file descriptor -> DEBC)
load_directory_cluster:
	ld e, (ix + 2);						// load directory cluster byte 0 (low)
	ld d, (ix + 3);						// load directory cluster byte 1
	ld c, (ix + 4);						// load directory cluster byte 2
	ld b, (ix + 5);						// load directory cluster byte 3 (high)
	ret;								// return with directory cluster in DEBC

;	// file descriptor cleanup and validation function
descriptor_cleanup_validation:
	push bc;							// save BC register pair
	push de;							// save DE register pair
	ld hl, $2420;						// load file descriptor table address
	ld b, $0f;							// load loop counter (15 descriptors)

descriptor_table_scan:
	ld a, (hl);							// load descriptor status byte
	and a;								// test if descriptor is active
	jr z, descriptor_inactive;			// jump if descriptor is inactive
	ld a, ixh;							// load current descriptor high byte
	cp h;								// compare with table entry high
	jr nz, descriptor_next;				// jump if different descriptor
	ld a, ixl;							// load current descriptor low byte
	cp l;								// compare with table entry low
	jr z, descriptor_inactive;			// jump if same descriptor (skip cleanup)

descriptor_next:
	call descriptor_validation_comparison;	// call descriptor validation function

descriptor_inactive:
	ld de, $20;							// load descriptor size (32 bytes)
	add hl, de;							// advance to next descriptor
	djnz descriptor_table_scan;			// decrement counter and loop
	pop de;								// restore DE register pair
	pop bc;								// restore BC register pair
	or a;								// clear carry flag (success)
	ret;								// return from cleanup function

;	// file descriptor validation and comparison function
descriptor_validation_comparison:
	ld a, (hl);							// load descriptor status byte
	cp (ix + 00);						// compare with current descriptor status
	ret nz;								// return if status doesn't match
	push hl;							// save descriptor pointer
	ld a, 6;							// load offset to drive number
	add a, l;							// add to pointer low byte
	ld l, a;							// store updated pointer
	ld a, (hl);							// load drive number from descriptor
	cp (ix + 6);						// compare with current drive number
	pop hl;								// restore descriptor pointer
	ret nz;								// return if drive doesn't match
	push bc;							// save BC register pair
	push hl;							// save descriptor pointer
	ld a, 5;							// load offset to comparison data
	add a, l;							// add to pointer
	ld l, a;							// store updated pointer
	call load_directory_cluster;		// call directory cluster load
	call compare_32bit;					// call cluster comparison function
	call z, restart_28;					// call restart if clusters match
	pop hl;								// restore descriptor pointer
	pop bc;								// restore BC register pair
	ret;								// return from validation

	pop hl;								// restore stack balance
	pop hl;								// restore stack balance
	pop hl;								// restore stack balance
	pop hl;								// restore stack balance
	pop de;								// restore DE register pair
	pop bc;								// restore BC register pair
	scf;								// set carry flag (error condition)
	ret;								// return with error

	dec l;								// decrement pointer to status field
	dec l;								// decrement pointer further
	dec l;								// position at file flags
	res 4, (hl);						// clear bit 4 (file closed flag)
	ld a, $0a;							// load offset to size field (10)
	add a, l;							// add to pointer
	ld l, a;							// store updated pointer
	call load_file_size;				// call file size load function
	jp store_32bit;						// jump to completion routine
	dec l;								// decrement pointer to status field
	dec l;								// decrement pointer further
	dec l;								// position at file flags
	set 4, (hl);						// set bit 4 (file active flag)
	res 3, (hl);						// clear bit 3 (directory flag)
	ld a, 6;							// load offset to drive field (6)
	add a, l;							// add to pointer
	ld l, a;							// store updated pointer
	ex de, hl;							// exchange DE and HL
	push ix;							// save IX register
	pop hl;								// load IX into HL
	ld a, 7;							// load offset to data area (7)
	add a, l;							// add to pointer
	ld l, a;							// store updated pointer
	ld bc, 21;							// load data length (21 bytes)
	ldir;								// copy data from source to destination
	ret;								// return from data copy

	dec d;								// decrement D register (address high byte)
	dec h;								// decrement H register (pointer high byte)
	ret;								// return from function

	ld a, (de);							// load byte from DE address
	and e;								// mask with E register
	ld a, (de);							// load byte from DE address again
	and c;								// mask with C register
	ld a, (de);							// load byte from DE address third time
	nop;								// no operation (padding)
	nop;								// no operation (padding)
	rrca;								// rotate A right circular
	dec h;								// decrement H register
	or a;								// set flags based on A register
	ret;								// return from function

	call block_size_calc_scaling;		// call block size calculation
	ld a, ixl;							// load RAM page number
	out (mmcram), a;					// Set divMMC RAM page...
	ld a, ($3df8);						// load saved page number
	ld ixh, a;							// store in IXH for later
	xor a;								// clear accumulator
	out (mmcram), a;					// divMMC RAM page 0
	call file_seek_preparation;			// call file seek function
	ret c;								// return if seek failed
	ld e, (iy + _newppc);				// load file handle
	ld a, ixl;							// load RAM page number
	out (mmcram), a;					// Set divMMC RAM page...
	ld a, e;							// load file handle
	push de;							// save DE register pair
	rst $08;							// call esxDOS API
	defb f_write;						// write to file
	pop de;								// restore DE register pair
	push af;							// save write result flags
	ld a, e;							// load file handle
	rst $08;							// call esxDOS API
	defb f_sync;						// synchronize file (flush buffers)
	pop af;								// restore write result flags
	jr file_io_result_handler;			// jump to result handling
	call block_size_calc_scaling;		// call block size calculation
	ld a, ixl;							// load RAM page number
	out (mmcram), a;					// Set divMMC RAM page...
	ld a, ($3df8);						// load saved page number
	ld ixh, a;							// store in IXH for later
	xor a;								// clear accumulator
	out (mmcram), a;					// divMMC RAM page 0
	call file_seek_preparation;			// call file seek function
	ret c;								// return if seek failed
	ld e, (iy + _newppc);				// load file handle
	ld a, ixl;							// load RAM page number
	out (mmcram), a;					// Set divMMC RAM page...
	ld a, e;							// load file handle
	rst $08;							// call esxDOS API
	defb f_read;						// read from file

;	// file I/O result handling function
file_io_result_handler:
	ld iyl, a;							// store result code in IYL

;	// restore divMMC page and return result
restore_divmmc_page_and_return:
	ld a, ixh;							// load saved page number
	ld ($3df8), a;						// restore saved page variable
	ld a, 0;							// clear accumulator
	out (mmcram), a;					// divMMC RAM page 0
	ld a, iyl;							// load result code
	ret;								// return with result

;	// file seek preparation function
file_seek_preparation:
	ld a, (iy + _newppc);				// load file handle
	push hl;							// save HL register
	ld l, 0;							// clear L (seek mode = absolute)
	rst $08;							// call esxDOS API
	defb f_seek;						// seek to file position
	pop hl;								// restore HL register
	ret c;								// return if seek failed
	push hl;							// save HL register
	ld hl, $80;							// load base block size (128 bytes)
	ld a, (iy + _flags);				// load file flags
	and %00000111;						// mask to get block size bits
	dec a;								// decrement (0 = 128 bytes)
	jr z, store_block_size;				// jump if 128 byte blocks

block_size_calculation_loop:
	add hl, hl;							// double the block size (left shift)
	dec a;								// decrement size counter
	jr nz, block_size_calculation_loop;	// loop until correct block size

store_block_size:
	ld b, h;							// store block size high byte
	ld c, l;							// store block size low byte
	pop hl;								// restore HL register
	or a;								// clear carry flag (success)
	ret;								// return with block size in BC

;	// block size calculation with sector scaling
block_size_calc_scaling:
	call sector_scaling_function;		// call sector-based scaling function
	ld a, (iy + _flags);				// load file flags
	and %00000111;						// mask to get block size bits
	dec a;								// decrement (0 = base size)
	ret z;								// return if base size (128 bytes)

scaling_shift_loop:
	sla e;								// shift E left (multiply by 2)
	rl d;								// rotate D left with carry
	rl c;								// rotate C left with carry
	rl b;								// rotate B left with carry (32-bit left shift)
	dec a;								// decrement scaling counter
	jr nz, scaling_shift_loop;			// loop until scaling complete
	ret;								// return with scaled value

;	// sector-based scaling function (multiply by 128)
sector_scaling_function:
	ld a, 7;							// load shift count (2^7 = 128)

sector_shift_loop:
	sla e;								// shift E left (multiply by 2)
	rl d;								// rotate D left with carry
	rl c;								// rotate C left with carry
	rl b;								// rotate B left with carry (32-bit left shift)
	dec a;								// decrement shift counter
	jr nz, sector_shift_loop;			// loop until 7 shifts complete
	ret;								// return with value multiplied by 128
