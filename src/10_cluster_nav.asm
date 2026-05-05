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

;	// set file current sector address in descriptor
set_file_sector_address:
	ld (ix + 20), e;					// store sector address low byte
	ld (ix + 21), d;					// store sector address byte 1
	ld (ix + 22), c;					// store sector address byte 2  
	ld (ix + 23), b;					// store sector address high byte
	ret;								// return after storing addressreturn after storing address

;	// get file current sector address from descriptor
get_file_sector_address:
	ld e, (ix + 20);					// load sector address low byte
	ld d, (ix + 21);					// load sector address byte 2
	ld c, (ix + 22);					// load sector address byte 3
	ld b, (ix + 23);					// load sector address high byte
	ret;								// return DEBC = current sector address

;	// set file next cluster in descriptor
set_file_next_cluster:
	ld (ix + 24), e;					// store next cluster low byte
	ld (ix + 25), d;					// store next cluster byte 2
	ld (ix + 26), c;					// store next cluster byte 3
	ld (ix + 27), b;					// store next cluster high byte
	ret;								// return after storing DEBC cluster

;	// get file next cluster from descriptor
get_file_next_cluster:
	ld e, (ix + 24);					// load next cluster low byte
	ld d, (ix + 25);					// load next cluster byte 2
	ld c, (ix + 26);					// load next cluster byte 3
	ld b, (ix + 27);					// load next cluster high byte
	ret;								// return DEBC = next cluster address

;	// process cluster pointer and call 32-bit add
process_cluster_pointer:
	push hl;							// save HL register
	push iy;							// save IY register
	pop hl;								// load IY into HL
	ld l, $26;							// set low byte to offset $26
	rst $30;							// call ROM routine
	ld bc, $c9e1;						// load return instruction and pop hl

;	// call cluster processing with arithmetic
call_cluster_processing:
	push hl;							// save HL register
	ld l, (iy + 29);					// load cluster pointer low byte
	ld h, (iy + 30);					// load cluster pointer high byte
	call add_32bit;						// call cluster processing function
	pop hl;								// restore HL register
	ret;								// return from function

;	// calculate cluster address with offset
calculate_cluster_address:
	push hl;							// save HL register
	push bc;							// save BC register
	push de;							// save DE register
	call get_cluster_start_address;		// get cluster start address in BCDE
	pop hl;								// restore DE to HL
	add hl, de;							// add low 16-bits of cluster address
	ex de, hl;							// result low 16-bits to DE
	pop hl;								// restore BC to HL
	adc hl, bc;							// add high 16-bits with carry
	ld b, h;							// move result high byte to B
	ld c, l;							// move result low byte to C
	pop hl;								// restore HL register
	ret;								// return with 32-bit address in BCDE

;	// get cluster start address from volume descriptor
get_cluster_start_address:
	ld e, (iy + 31);					// load cluster start address low byte
	ld d, (iy + 32);					// load cluster start address byte 1
	ld c, (iy + 33);					// load cluster start address byte 2
	ld b, (iy + 34);					// load cluster start address high byte
	ret;								// return DEBC = cluster start addressreturn DEBC = cluster start addressreturn DEBC = cluster start address

;	// get filesystem parameters from volume descriptor
get_filesystem_parameters:
	ld b, (iy + 49);					// load filesystem parameter byte 3
	ld c, (iy + 48);					// load filesystem parameter byte 2
	ld d, (iy + 47);					// load filesystem parameter byte 1
	ld e, (iy + 46);					// load filesystem parameter low byte
	ret;								// return BCDE = filesystem parameters

;	// Function: Get directory cluster from volume descriptor
get_directory_cluster:
	ld e, (iy + 53);					// load directory cluster low byte
	ld d, (iy + 54);					// load directory cluster byte 2
	ld c, (iy + 55);					// load directory cluster byte 3
	ld b, (iy + 56);					// load directory cluster high byte
	ret;								// return DEBC = current directory cluster

;	// Function: Set directory cluster in volume descriptor
set_directory_cluster:
	ld (iy + 53), e;					// store directory cluster low byte
	ld (iy + 54), d;					// store directory cluster byte 2
	ld (iy + 55), c;					// store directory cluster byte 3
	ld (iy + 56), b;					// store directory cluster high byte
	ret;								// return after storing DEBC cluster

;	// Function: Get working cluster from volume descriptor
get_working_cluster:
	ld e, (iy + 57);					// load working cluster low byte
	ld d, (iy + 58);					// load working cluster byte 2
	ld c, (iy + 59);					// load working cluster byte 3
	ld b, (iy + 60);					// load working cluster high byte
	ret;								// return DEBC = working cluster

;	// Function: Set working cluster in volume descriptor
set_working_cluster:
	ld (iy + 57), e;					// store working cluster low byte
	ld (iy + 58), d;					// store working cluster byte 2
	ld (iy + 59), c;					// store working cluster byte 3
	ld (iy + 60), b;					// store working cluster high byte
	ret;								// return after storing DEBC cluster

;	// Function: Load directory sector if needed
load_directory_sector:
	ld a, (iy + 61);					// check if directory buffer valid
	or a;								// test validity flag
	ret z;								// return if buffer already valid
	ld hl, $3fe8;						// load buffer management address
	call get_working_cluster;			// get working cluster
	rst $30;							// call ROM routine
	nop;								// padding/alignment
	call get_directory_cluster;			// get directory cluster
	rst $30;							// call ROM routine
	nop;								// padding/alignment
	ld hl, $3e00;						// load directory buffer address
	ld bc, 0;							// clear cluster offset
	ld de, 1;							// set sector count to 1
	jp write_disk_sector;				// jump to sector read routine

;	// Function: Process file sector loading
process_file_sector:
	call get_file_next_cluster;			// call sector loading function
	call read_disk_sector;				// call directory processing
	ret;								// return from function

;	// Function: Check sector flags and load data
check_sector_flags:
	call get_file_next_cluster;			// call sector loading function
	ld a, ($3c26);						// load system flags
	cp (iy + _flags);					// compare with file flags
	jr nz, handle_sector_buffer;		// jump if flags differ
	ld hl, $3c2a;						// load buffer address
	call compare_32bit;					// call utility function

;	// Function: Handle sector buffer operations
handle_sector_buffer:
	ld hl, $2a00;						// load sector buffer address
	ccf;								// complement carry flag
	ret z;								// return if zero
	ld a, (iy + _flags);				// load file flags
	ld ($3c26), a;						// store flags in buffer
	ld ($3c27), de;						// store DE address in buffer
	ld ($3c29), bc;						// store BC value in buffer
	push hl;							// save HL register
	call process_file_sector;			// call sector/directory processing
	pop hl;								// restore HL register
	ret;								// return from function

;	// Function: Clear memory buffer
clear_memory_buffer:
	push hl;							// save HL register
	ld hl, $2a00;						// load buffer address
	call call_file_descriptor;			// call memory clear function
	pop hl;								// restore HL register
	ret;								// return from function

;	// Function: Process file flags and load sector
process_file_flags:
	call get_file_next_cluster;			// call sector loading function
	ld a, (iy + _flags);				// load file flags
	exx;								// switch to alternate register set
	push bc;							// save BC register
	push de;							// save DE register
	ld c, mmcram;						// load divMMC RAM control port
	ld de, ($3df8);						// load RAM page configuration
	out (c), e;							// set divMMC RAM page (low)
	exx;								// switch to alternate registers
	rst $08;							// call disk I/O function
	defb disk_read;						// disk read operation
	exx;								// switch back to main registers
	out (c), d;							// set divMMC RAM page (high)
	pop de;								// restore DE register
	pop bc;								// restore BC register
	exx;								// switch back to alternate registers
	ret;								// return from memory page operation

;	// Function: Process sector decrement and load
process_sector_decrement:
	dec (ix + 19);						// decrement sector count
	jr z, complete_sector_processing;	// jump if all sectors processed
	call get_file_next_cluster;			// call sector loading function
	call inc_32bit;						// call disk function
	jp set_file_next_cluster;			// jump back to processing loop

;	// Function: Complete sector processing
complete_sector_processing:
	call process_file_sector_mapping;	// call completion function
	ret c;								// return if carry set
	jp advance_to_next_cluster;			// jump to finalization

;	// Function: Check file position and parameters
check_file_position:
	ld a, (iy + 28);					// load file position indicator
	cp 1;								// check if position is 1
	jr z, apply_sector_shift;			// jump if at position 1
	ld a, d;							// load D register
	or e;								// check if DE is zero
	jr nz, apply_sector_shift;			// jump if DE not zero
	ld bc, 0;							// clear BC register
	ld d, (iy + 36);					// load file size high byte
	ld e, (iy + 35);					// load file size low byte
	ld a, (iy + 66);					// load status flag
	ret;								// return with file parameters

;	// Function: Apply sector size shift to address calculation
apply_sector_shift:
	ld a, (iy + 37);					// load sectors per cluster shift count

;	// Function: Shift loop for address scaling
shift_address_loop:
	srl a;								// shift right shift count
	jr c, add_file_offset;				// exit when shift complete
	sla e;								// shift left E register
	rl d;								// rotate left D register
	rl c;								// rotate left C register
	rl b;								// rotate left B register
	jr shift_address_loop;				// continue shifting loop

;	// Function: Add file offset to base address (32-bit arithmetic)
add_file_offset:
	ld a, (iy + 42);					// load file offset byte 0
	add a, e;							// add to E register
	ld e, a;							// store result in E
	ld a, (iy + 43);					// load file offset byte 1
	adc a, d;							// add with carry to D
	ld d, a;							// store result in D
	ld a, (iy + 44);					// load file offset byte 2
	adc a, c;							// add with carry to C
	ld c, a;							// store result in C
	ld a, (iy + 45);					// load file offset byte 3
	adc a, b;							// add with carry to B
	ld b, a;							// store result in B (32-bit addition complete)
	ld a, (iy + 37);					// load sectors per cluster shift count
	ret;								// return with shift count

;	// Function: Initialize file sector setup
setup_file_sector:
	call set_file_sector_address;		// call sector/cluster address setup

;	// Function: Check file position and advance to next cluster
advance_to_next_cluster:
	call check_file_position;			// call file position check
	ld (ix + 19), a;					// store sector count in file control block
	jp set_file_next_cluster;			// jump to main processing loop

;	// Function: Get file sector and process cluster mapping
process_file_sector_mapping:
	call get_file_sector_address;		// call cluster calculation function
	call map_sector_from_cluster;		// call sector mapping function
	jp nc, set_file_sector_address;		// jump to setup if no carry
	cp $80;								// check for empty block marker
	scf;								// set carry flag (error condition)
	ret nz;								// return with error if not empty block
	bit 2, (ix + 1);					// test file flag bit 2
	ret z;								// return if bit not set
	jp store_hl_memory_ptr;				// jump to extended processing

;	// Function: Map sector from cluster with position handling
map_sector_from_cluster:
	ld a, (iy + 28);					// load file position indicator
	cp 1;								// check if position is 1
	jr z, handle_position_one;			// jump to special handling if 1
	push de;							// save DE register
	ld e, d;							// shift registers for 32-bit calculation
	ld d, c;							// D = C (shift high)
	ld c, b;							// C = B (shift high)
	ld b, 0;							// clear B (most significant byte)
	call check_drive_cluster_cache;		// call cluster to sector conversion
	pop de;								// restore DE register
	ret c;								// return if conversion failed
	xor a;								// clear accumulator
	sla e;								// shift E left (multiply by 2)
	ld l, e;							// load shifted value to L
	adc a, h;							// add carry to high byte
	ld h, a;							// store result in H
	ld e, (hl);							// load cluster entry low byte
	inc hl;								// advance to high byte
	ld d, (hl);							// load cluster entry high byte
	dec hl;								// restore pointer
	ld bc, 0;							// clear BC register
	ld a, d;							// load high byte to accumulator

;	// Function: Check for end-of-chain markers
check_chain_end_marker:
	cp $ff;								// check for end-of-chain marker
	ccf;								// complement carry flag
	ret nz;								// return if not end marker
	ld a, e;							// load low byte
	and %11110000;						// mask upper 4 bits
	cp $f0;								// check for special marker
	ccf;								// complement carry flag
	ld a, $80;							// load error code
	ret;								// return with status

;	// Function: Process position 1 with bit shifting
handle_position_one:
	push de;							// save DE register
	ld a, e;							// save E in accumulator
	ld e, d;							// shift register values
	ld d, c;							// D = C
	ld c, b;							// C = B  
	ld b, 0;							// clear B
	sla a;								// shift left A (multiply by 2)
	rl e;								// rotate left E with carry
	rl d;								// rotate left D with carry
	rl c;								// rotate left C with carry
	rl b;								// rotate left B with carry
	call check_drive_cluster_cache;		// call cluster to sector conversion
	pop de;								// restore DE register
	ret c;								// return if conversion failed
	xor a;								// clear accumulator
	sla e;								// shift E left (multiply by 2)
	sla e;								// shift E left again (multiply by 4)
	ld l, e;							// load shifted value to L
	adc a, h;							// add carry to high byte
	ld h, a;							// store result in H
	push hl;							// save HL on stack
	rst $30;							// call ROM routine
	ld bc, $78e1;						// load control value
	cp $0f;								// compare with 15
	jr nz, check_chain_end_marker;		// jump if not equal
	ld a, $ff;							// load mask value
	and c;								// mask with C
	and d;								// mask with D
	jr check_chain_end_marker;			// jump to check end marker

;	// Function: Process disk operations with error handling
process_disk_operation:
	push de;							// save DE register
	call get_working_cluster;			// call buffer management function
	inc b;								// increment B register
	jr z, simple_return;				// jump if zero result
	dec b;								// decrement B back
	call c, inc_32bit;					// call disk function if carry set
	call nc, dec_32bit;					// call alternate function if no carry
	call set_working_cluster;			// call cleanup function

;	// Function: Simple operation return point
simple_return:
	pop de;								// restore DE register
	ret;								// return from cluster operation

;	// Function: Validate cluster operation
validate_cluster_operation:
	push bc;							// save BC register
	push de;							// save DE register
	call get_working_cluster;			// get working cluster
	rst $30;							// call ROM routine
	dec c;								// decrement cluster count
	pop de;								// restore DE register
	pop bc;								// restore BC register
	ret nz;								// return if non-zero (valid)
	ld a, 9;							// load error code 9 (invalid cluster)
	scf;								// set carry flag for error
	ret;								// return with error

;	// Function: Disk write operation with RAM page management
write_with_page_management:
	call get_file_next_cluster;			// call sector loading function
	ld a, (iy + _flags);				// load file flags
	exx;								// switch to alternate register set
	push bc;							// save BC register
	push de;							// save DE register
	ld c, mmcram;						// load divMMC RAM control port
	ld de, ($3df8);						// load RAM page configuration
	out (c), e;							// set divMMC RAM page (low)
	exx;								// switch to alternate registers
	rst $08;							// call disk I/O function
	defb disk_write;					// disk write operation
	exx;								// switch back to main registers
	out (c), d;							// restore divMMC RAM page (high)
	pop de;								// restore DE register
	pop bc;								// restore BC register
	exx;								// switch back to alternate registers
	ret;								// return from disk write

;	// Function: Process FAT and cluster operations
process_fat_cluster_operations:
	call get_directory_cluster;			// call FAT processing function
	call map_sector_from_cluster;		// call sector mapping function
	call check_system_flag_bit;			// call system function
	ret c;								// return if operation failed
	ld h, d;							// load D to H
	ld l, e;							// load E to L
	ld a, $ff;							// load end-of-chain marker
	call store_at_memory_hl;			// call cluster marking function
	push de;							// save DE register
	ld de, ($3c11);						// load system parameter address
	ld bc, ($3c13);						// load system parameter value
	push bc;							// save BC register
	push de;							// save DE register again
	call mark_buffer_dirty;				// call cluster calculation function
	pop de;								// restore DE register
	pop bc;								// restore BC register
	pop hl;								// restore HL register
	ret c;								// return if error occurred

;	// Function: Multi-precision right shifts for FAT address conversion
fat_address_right_shift:
	rr h;								// rotate right H register
	rr l;								// rotate right L register
	ld a, (iy + 28);					// load FAT type indicator
	cp 1;								// check if FAT12
	jr nz, register_shift_32bit;		// jump if not FAT12
	srl b;								// shift right B register
	rr c;								// rotate right C register
	rr d;								// rotate right D register
	rr e;								// rotate right E register
	rr l;								// rotate right L register

;	// Function: Register shift operations for 32-bit calculations
register_shift_32bit:
	ld b, c;							// shift register chain: B = C
	ld c, d;							// C = D
	ld d, e;							// D = E  
	ld e, l;							// E = L
	or a;								// clear carry flag
	ret;								// return with shifted registers

;	// Function: Process command with 8-byte limit
process_command_8byte:
	ld b, 8;							// set counter to 8 bytes
	call validate_filename_chars;		// call processing function
	call process_filename_chars;		// call validation function
	ld a, (hl);							// load character from buffer
	cp '.';								// check for period (external command marker)
	jr nz, extract_extension_3char;		// jump if not period
	inc hl;								// advance past period

;	// Function: Extract 3-character extension with validation
extract_extension_3char:
	ld b, 3;							// set counter for 3-character extension

;	// Function: Process filename characters with validation
process_filename_chars:
	ld a, (hl);							// load character from filename
	ld c, $20;							// set padding character (space)
	cp '.';								// check for period (extension separator)
	jr z, pad_with_spaces;				// jump to padding if period found
	and a;								// check for null terminator
	jr z, pad_with_spaces;				// jump to padding if null
	cp '/';								// check for path separator
	jr z, pad_with_spaces;				// jump to padding if path separator
	call validate_fat_char;				// validate character is acceptable for FAT filesystem
	jr nc, convert_to_uppercase;		// jump to case conversion if valid

;	// Function: Return error for invalid filename character
invalid_filename_char:
	scf;								// set carry flag (invalid character)
	ld a, 7;							// load error code 7 (bad filename)
	ret;								// return with error

;	// Function: Convert lowercase to uppercase for FAT compatibility
convert_to_uppercase:
	cp 'a';								// check if lowercase letter
	jr c, store_char_advance;			// jump if below 'a'
	cp '{';								// check if above 'z' ('{' is char after 'z')
	jr nc, store_char_advance;			// jump if above lowercase range
	and %11011111;						// clear bit 5 to convert lowercase to uppercase

;	// Function: Store character and advance pointers
store_char_advance:
	ld (de), a;							// store converted character
	inc de;								// advance destination pointer
	inc hl;								// advance source pointer
	djnz process_filename_chars;		// continue processing characters
	ld a, (hl);							// load next character
	and a;								// check for null terminator
	jr z, complete_filename_processing;	// jump to completion if null
	cp '/';								// check for path separator
	jr nz, invalid_filename_char;		// error if unexpected character

;	// Function: Complete filename processing
complete_filename_processing:
	or a;								// clear carry flag (success)
	ret;								// return successfully

;	// Function: Pad remaining filename space with specified character
pad_with_spaces:
	ld a, c;							// load padding character (typically space)

;	// Function: Character padding loop
padding_loop:
	ld (de), a;							// store padding character
	inc de;								// advance destination pointer
	djnz padding_loop;					// repeat for remaining character count
	or a;								// clear carry flag (success)
	ret;								// return after padding

;	// Function: Process file extension for FAT 8.3 format
validate_filename_chars:
	ld a, (hl);							// load character from extension
	cp '.';								// check for period (extension marker)
	ret nz;								// return if not extension
	ld bc, $0b00;						// B=11 chars total, C=0 for comparison
	ldi;								// copy period and increment pointers
	cp (hl);							// compare with next character
	jr nz, set_extension_padding;		// jump if different
	ldi;								// copy another character
	dec b;								// decrement remaining character count

;	// Function: Set padding for extension processing
set_extension_padding:
	ld c, $20;							// set space character for padding
	call pad_with_spaces;				// pad remaining extension space
	pop bc;								// restore BC register
	ret;								// return from extension processing

;	// Function: Validate character for FAT filesystem compatibility
validate_fat_char:
	cp '!';								// check if below printable ASCII range
	ret c;								// return with carry if invalid
	push bc;							// save BC register
	push hl;							// save HL register
	ld hl, $140b;						// point to forbidden character table
	ld bc, $0c;							// 12 forbidden characters to check
	scf;								// set carry flag
	cpir;								// search for character in forbidden list
	pop hl;								// restore HL register
	pop bc;								// restore BC register
	ret z;								// return with carry if forbidden
	ccf;								// clear carry flag (character valid)
	ret;								// return successfully

;	//  data table or unused bytes
	ccf;								// data byte $3f
	ld ($3a2f), hl;						// data bytes $22 $2f $3a
	dec sp;								// data byte $3b
	inc l;								// data byte $2c
	inc a;								// data byte $3c
	ld a, $5c;							// data bytes $3e $5c
	ld a, h;							// data byte $7c
	ld l, $2a;							// data bytes $2e $2a
