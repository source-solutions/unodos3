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

display_filename:
	call build_sys_path;				// construct full system file path with extension
	push hl;							// save path pointer
	ld de, 5;							// offset to filename portion (skip "/dos/")
	add hl, de;							// point to filename part
	call pr_str;						// print filename to screen
	pop hl;								// restore full path pointer
	ret;								// return with full path in HL

	org $0272
show_result:
	ld hl, msg_ok;						// point to "OK" message
	jr nc, print_result_msg;			// jump if no carry (success)
	ld hl, msg_failed;					// else point to error/failed message

print_result_msg:
	jp pr_str;							// print the success/error message

show_device_status:
	ld de, $2df2;						// point to device info buffer
	rst $08;							// call UnoDOS API
	defb disk_status;					// get disk/device status
	ret c;								// return if API call failed
	and %11111000;						// mask out lower 3 bits (keep device type info)
	rst $30;							// internal UnoDOS call
	ld c, $3e;							// [unclear purpose - may be command code]
	ld a, ($3ed7);						// load status from this address
	jr nz, $0264;						// jump to $0264 if non-zero
	ld hl, $2df2;						// point back to device info buffer
	call pr_str;						// print device information
	ld a, $0d;							// carriage return character
	rst $10;							// print newline
	ret;								// return to caller

	org $0297
delay_routine:
	ld b, $ff;							// delay loop counter (255 iterations)

delay_inner_loop:
	djnz delay_inner_loop;				// inner delay loop (256 iterations)
	dec de;								// decrement outer delay counter
	ld a, e;							// get low byte
	or d;								// OR with high byte to test for zero
	jr nz, delay_routine;				// repeat until DE reaches zero
	ret;								// return after delay complete

load_system_page3:
	call open_file_read;				// open file for reading
	ret c;								// return if file open failed
	push af;							// save file handle
	ld a, 3;							// select divMMC page 3
	out (mmcram), a;					// switch to divMMC page 3
	pop af;								// restore file handle
	ld hl, $2000;						// destination: start of divMMC window
	ld bc, $1c00;						// byte count: 7168 bytes (7KB)
	jr read_file_data;					// continue to file read routine

load_nmi_handler:
	call open_file_read;				// open file for reading
	ret c;								// return if file open failed
	ld hl, $2f00;						// destination: $2F00 (NMI handler area)
	ld bc, $0e00;						// byte count: 3584 bytes

read_file_data:
	ld e, a;							// save file handle in E
	push de;							// save file handle on stack
	rst $08;							// call UnoDOS API
	defb f_read;						// read from file
	pop de;								// restore file handle
	ld a, e;							// get file handle back
	jr close_file_page0;				// continue to file close routine

load_main_system:
	call open_file_read;				// open main system file for reading
	ret c;								// return if file open failed
	push af;							// save file handle
	ld hl, $2000;						// destination: start of divMMC window
	ld bc, lower_end-$2000;				// byte count: size of lower part
	rst $08;							// call UnoDOS API
	defb f_read;						// read lower part of system file
	ld a, 1;							// select divMMC page 1
	out (mmcram), a;					// switch to divMMC page 1
	pop af;								// restore file handle
	push af;							// save file handle again
	ld hl, $3000;						// destination: upper part area
	ld bc, upper_end-$3000;				// byte count: size of upper part
	rst $08;							// call UnoDOS API
	defb f_read;						// read upper part of system file
	pop af;								// restore file handle

close_file_page0:
	rst $08;							// call UnoDOS API
	defb f_close;						// close the file
	ld a, 0;							// select divMMC page 0
	out (mmcram), a;					// switch back to page 0
	ret;								// return to caller

open_file_read:
	ld a, $24;							// file mode: read-only
	ld b, 1;							// drive number (drive 1)
	rst $08;							// call UnoDOS API
	defb f_open;						// open file for reading
	ret;								// return with file handle in A or carry set if error

build_sys_path:
	call build_base_path;				// construct base path ("/dos/[filename].")
	ld hl, system_info;					// point to "sys" extension string

add_extension:
	call copy_string_loop;				// copy extension string to path
	ld (de), a;							// store null terminator
	ld hl, $2dce;						// return pointer to completed path
	ret;								// return with full path in HL

build_alt_sys_path:
	call build_base_path;				// construct base path ("/dos/[filename].")
	ld hl, system_info;					// point to "sys" extension string
	jr add_extension;					// continue to add extension

build_base_path:
	push hl;							// save filename pointer
	ld de, $2dce;						// destination buffer for full path
	ld hl, sys_folder;					// source: "/dos" string
	call copy_string_loop;				// copy "/dos" to buffer
	ld a, $2f;							// forward slash character
	ld (de), a;							// add slash after "/dos"
	inc de;								// advance destination pointer
	pop hl;								// restore filename pointer
	call copy_string_loop;				// copy filename to buffer
	ld a, $2e;							// dot character
	ld (de), a;							// add dot before extension
	inc de;								// advance destination pointer
	ret;								// return with DE pointing after dot

setup_vector_table:
	ld hl, $2d24;						// point to vector table location
	ld de, $1c6d;						// first vector address
	ld (hl), e;							// store low byte of vector
	inc hl;								// advance to next byte
	ld (hl), d;							// store high byte of vector
	inc hl;								// advance to next vector slot
	ld de, $2515;						// second vector address
	ld (hl), e;							// store low byte of second vector
	inc hl;								// advance to next byte
	ld (hl), d;							// store high byte of second vector
	inc hl;								// advance to next vector slot
	ret;								// vector table setup complete

check_handle_limit:
	ld c, a;							// save file handle in C
	ld a, ($2d47);						// get current file handle count
	cp 6;								// compare with maximum (6 handles)
	scf;								// set carry flag (error condition)
	ret z;								// return if maximum handles reached
	ld hl, $2c00;						// point to file handle table start

find_free_handle_slot:
	ld a, (hl);							// get file handle entry
	and a;								// test if slot is free (zero)
	jr z, store_handle_in_slot;			// jump if free slot found
	ld a, $28;							// file handle entry size (40 bytes)
	add a, l;							// advance to next handle slot
	ld l, a;							// update pointer
	jr find_free_handle_slot;			// check next slot

store_handle_in_slot:
	ld (hl), c;							// store file handle in free slot
	push hl;							// save handle slot address
	pop iy;								// copy to IY register
	ld hl, $2d47;						// point to file handle counter
	inc (hl);							// increment active handle count
	ret;								// return with handle slot in IY

close_handle_slot:
	call find_file_handle;				// find file handle slot
	ret c;								// return if handle not found
	xor a;								// clear accumulator
	ld (hl), a;							// clear the file handle slot
	ld hl, $2d47;						// point to file handle counter
	dec (hl);							// decrement active handle count
	or a;								// clear carry flag (success)
	ret;								// return with success

find_handle_with_setup:
	push hl;							// save HL register
	push bc;							// save BC register
	call find_file_handle;				// find file handle slot
	push hl;							// save handle slot address
	pop iy;								// copy to IY register
	pop bc;								// restore BC register
	pop hl;								// restore HL register
	ret;								// return with handle slot in IY

find_file_handle:
	ld c, a;							// save target handle in C
	ld b, 6;							// maximum number of file handles
	ld hl, $2c00;						// point to start of file handle table

handle_search_loop:
	ld a, (hl);							// get file handle from current slot
	xor c;								// compare with target handle
	and %11111000;						// mask out lower 3 bits
	jr z, handle_found_check;			// jump if match found
	ld a, $28;							// handle slot size (40 bytes)
	add a, l;							// advance to next slot
	ld l, a;							// update pointer
	djnz handle_search_loop;			// continue search
	scf;								// set carry flag (handle not found)
	ret;								// return with error

handle_found_check:
	ld a, (hl);							// get the found handle
	cp c;								// compare with target
	ret c;								// return with carry if less than target
	ld a, c;							// get target handle
	and %00000111;						// keep only lower 3 bits
	ret;								// return with partial handle info

memory_address_calc:
	push hl;							// save HL register
	ld hl, ($3dfb);						// get stored address from divMMC area
	ex (sp), hl;						// exchange with saved HL on stack
	ret;								// return with original HL restored

	push de;							// save DE register
	push hl;							// save HL register
	ld a, iyl;							// get low byte of IY (file handle)
	ld ixl, a;							// store in IX low byte
	ld de, $2400;						// base address for screen calculations
	ld h, 0;							// clear H register
	ld a, ixh;							// get high byte of IX
	add a, a;							// multiply by 2
	add a, a;							// multiply by 4
	add a, a;							// multiply by 8
	add a, a;							// multiply by 16
	add a, a;							// multiply by 32
	ld l, a;							// store result in L
	rl h;								// rotate carry into H
	add hl, de;							// add base address
	ld a, iyh;							// get high byte of IY
	call search_error_pages;			// call address lookup function
	ld a, ixl;							// get low byte of IX back

restore_registers:
	push hl;							// save HL register
	pop ix;								// copy to IX register
	pop hl;								// restore original HL
	pop de;								// restore original DE
	ret;								// return to caller

setup_divmmc_config:
	ld hl, $2d2a;						// point to system table entry
	ld de, $0df1;						// address parameter
	ld bc, $0384;						// size/count parameter  
	ld a, 1;							// select divMMC page 1
	ld (hl), a;							// store page number
	inc hl;								// advance to next field
	ld (hl), e;							// store low byte of address
	inc hl;								// advance to next field
	ld (hl), d;							// store high byte of address
	inc hl;								// advance to next field
	ld (hl), $ff;						// store end marker
	out (mmcram), a;					// switch to divMMC page 1
	ld ($3dfb), bc;						// store BC in divMMC area
	xor a;								// clear accumulator
	out (mmcram), a;					// switch back to divMMC page 0
	ret;								// return to caller

execute_page3_code:
	nop;								// padding/alignment
	nop;								// padding/alignment
	nop;								// padding/alignment
	nop;								// padding/alignment
	nop;								// padding/alignment
	ld a, 3;							// select divMMC page 3
	out (mmcram), a;					// switch to divMMC page 3
	call system_entry;					// call loaded code at $2000
	xor a;								// clear accumulator
	out (mmcram), a;					// switch back to divMMC page 0
	ret;								// return to caller

search_error_pages:
	push bc;							// save BC register
	ld iy, $2000;						// point IY to divMMC window start
	ld b, 4;							// loop counter for 4 iterations

page_search_loop:
	cp (iy + _err_nr);					// compare with error number field
	jr z, search_found_success;			// jump if match found
	inc iyh;							// advance to next page
	djnz page_search_loop;				// continue loop
	pop bc;								// restore BC register
	scf;								// set carry flag (not found)
	ret;								// return with error

search_found_success:
	or a;								// clear carry flag (success)
	pop bc;								// restore BC register
	ret;								// return with success

prepare_system_request:
	ld b, a;							// save request parameter in B
	ld hl, $2d2a;						// point to system table

system_table_loop:
	call validate_filename_buffer;		// get/prepare system data
	ld ixh, a;							// store result in IX high
	ld a, (hl);							// get table entry
	cp 255;								// check for end marker
	jr z, table_end_error;				// jump if end of table
	ld e, a;							// save entry in E
	push de;							// save DE register
	inc hl;								// advance to address field
	ld e, (hl);							// get low byte of address
	inc hl;								// advance to high byte
	ld d, (hl);							// get high byte of address 
	inc hl;								// advance to next entry
	push hl;							// save table pointer
	push bc;							// save request parameter
	call process_table_entry;			// process the entry
	pop bc;								// restore request parameter
	pop hl;								// restore table pointer
	pop ix;								// restore IX from DE
	ret nc;								// return if operation successful
	jr system_table_loop;				// continue with next table entry

table_end_error:
	ld a, $1e;							// error code: "invalid" (30 decimal)
	scf;								// set carry flag (error)
	ret;								// return with error

process_table_entry:
	push hl;							// save HL register
	push hl;							// save HL register again
	out (mmcram), a;					// switch to specified divMMC page
	ld ($3df8), a;						// store current divMMC page number
	ld h, d;							// copy address to HL
	ld l, e;							// complete address transfer
	call memory_address_calc;			// call address handling routine
	jp get_handler_from_table;			// jump to main processing routine

get_drive_info:
	ld hl, $2df2;						// point to drive info buffer
	push hl;							// save buffer pointer
	rst $08;							// call UnoDOS API
	defb m_driveinfo;					// get drive information
	pop hl;								// restore buffer pointer
	ld b, a;							// save number of drives in B
	and a;								// test if zero drives
	ret z;								// return if no drives found

print_all_drives:
	push bc;							// save drive counter
	call print_drive_info;				// print information for one drive
	pop bc;								// restore drive counter
	djnz print_all_drives;				// repeat for all drives
	ret;								// return when all drives printed

print_drive_info:
	ld a, (hl);							// get drive type/status
	rst $30;							// internal UnoDOS call
	add hl, bc;							// advance past some fields
	ld a, ' ';							// space character
	rst $10;							// print space
	inc hl;								// advance pointer
	inc hl;								// advance pointer
	inc hl;								// advance pointer
	rst $30;							// internal UnoDOS call
	ld bc, $e5c5;						// load search pattern/instruction
	ld bc, $ff;							// byte count for string search
	xor a;								// search for null terminator
	cpir;								// scan for end of string
	call print_string_comma;			// print string with comma
	ld b, h;							// save H to B
	ld c, l;							// save L to C
	pop hl;								// restore original HL
	call print_string_comma;			// print another string with comma
	ld l, e;							// setup for next operation
	ld h, d;							// complete address setup
	pop de;								// restore DE
	push bc;							// save BC for later
	call format_file_size;				// call formatting/display routine
	ld a, $0d;							// carriage return character
	rst $10;							// print newline
	pop hl;								// restore pointer for next drive
	ret;								// return to drive loop

print_string_comma:
	call pr_str;						// print string pointed to by HL
	inc hl;								// advance past string
	ld a, ',';							// comma character
	rst $10;							// print comma
	ld a, ' ';							// space character
	rst $10;							// print space
	ret;								// return to caller

	org $0482
format_size_display:
	ld l, a;							// save original value in L
	and %11100000;						// mask to get upper 3 bits
	ret z;								// return if zero (no size to display)
	ld e, $30;							// default base character '0'
	ld c, $66;							// default unit character 'f' (for bytes)
	cp ' ';								// compare with space character ($20)
	jr z, print_size_units;				// jump if 32 (32 bytes)
	ld c, $76;							// unit character 'v' for 'K'
	cp $60;								// compare with $60 (96 = 3 * 32K)
	jr z, print_size_units;				// jump if kilobyte size
	ld e, $61;							// base character 'a' for 'M'
	cp $80;								// compare with $80 (128 = 4 * 32M)
	ld c, $73;							// unit character 's' for 'M'
	jr z, print_size_units;				// jump if megabyte size
	ld c, $68;							// unit character 'h' for 'G'

print_size_units:
	ld a, c;							// get unit character
	rst $10;							// print unit character
	ld a, 'd';							// print 'd' character
	rst $10;							// (makes 'Kd', 'Md', 'Gd' etc.)
	ld a, l;							// get original value back
	rrca;								// rotate right to get bits 7-2
	rrca;								// rotate right again
	rrca;								// rotate right again  
	and %00000011;						// keep only bottom 2 bits
	add a, e;							// add base character
	rst $10;							// print tens digit
	ld a, l;							// get original value back
	and %00000111;						// keep bottom 3 bits for units
	ret z;								// return if zero (don't print units)
	add a, 30h;							// convert to ASCII digit
	rst $10;							// print units digit
	ret;								// return to caller
