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

;	// Function: Compare directory entries
compare_directory_entries:
	push de;							// save DE register
	push hl;							// save HL register
	push bc;							// save BC register
	ld b, $0b;							// set comparison length (11 chars for 8.3 filename)

;	// Function: Character-by-character filename comparison loop
filename_compare_loop:
	ld a, (de);							// load character from search pattern
	cp '*';								// check for wildcard character
	jr z, restore_after_comparison;		// jump if wildcard (auto-match)
	cp (hl);							// compare with directory entry character
	jr nz, restore_after_comparison;	// jump if no match
	inc de;								// advance search pattern pointer
	inc hl;								// advance directory entry pointer
	djnz filename_compare_loop;			// continue for all 11 characters

;	// Function: Restore registers after comparison
restore_after_comparison:
	pop bc;								// restore BC register
	pop hl;								// restore HL register
	pop de;								// restore DE register
	ret;								// return with comparison result

;	// Function: Process file operation with error checking
;	// Function: Process file operation with error checking
process_file_operation:
	ld b, a;							// save operation code
	push bc;							// save BC register
	push hl;							// save HL register
	call get_file_sector_address;		// get file current sector address
	ld hl, $3c22;						// load buffer address
	call compare_32bit;					// call comparison function
	pop hl;								// restore HL register
	pop bc;								// restore BC register
	ld a, b;							// reload operation code
	jr z, return_device_error;			// jump if zero result
	or a;								// test operation code
	ret;								// return with result

;	// Function: Return specific error code
return_device_error:
	ld a, $13;							// load error code 19 (device error)
	ret;								// return with error

;	// Function: Check file attributes and extensions
check_file_attributes:
	ld b, a;							// save operation type
	push bc;							// save BC register
	push hl;							// save HL register
	call get_file_sector_address;		// get file current sector address
	push iy;							// save IY register
	pop hl;								// transfer IY to HL
	ld l, $29;							// set offset for file attribute
	call compare_32bit;					// call comparison function
	jr nz, cleanup_and_return;			// jump if not zero
	pop hl;								// restore HL register
	push hl;							// save HL again
	ld a, (hl);							// load first character
	cp '.';								// check for period
	jr nz, cleanup_and_return;			// jump if not extension
	inc l;								// advance pointer
	ld a, (hl);							// load next character
	cp ' ';								// check for space

;	// Function: Cleanup and return operation code
cleanup_and_return:
	pop hl;								// restore HL register
	pop bc;								// restore BC register
	ld a, b;							// load operation code
	ret;								// return with operation result

;	// Function: Initialize buffer and call system routines
init_buffer_system_call:
	ld de, $2f00;						// load buffer address
	push de;							// save buffer address
	exx;								// switch to alternate registers
	call process_cluster_pointer;		// call system function
	exx;								// switch back to main registers
	call directory_entry_setup;			// call ROM routine
	pop hl;								// restore buffer address to HL
	or a;								// test result flags
	ret;								// return with status

;	// Function: Process filesystem operation with parameter handling
process_filesystem_operation:
	push af;							// save accumulator
	call get_filesystem_parameters;		// get filesystem parameters
	call store_cluster_address;			// call processing function
	call setup_file_sector;				// call sector/cluster address setup
	pop af;								// restore accumulator

;	// Function: File operation validation and processing
validate_file_operation:
	call check_file_attributes;			// call file operation processing
	jr z, init_buffer_system_call;		// jump if zero result
	call process_file_operation;		// call error checking function
	ret c;								// return if error
	res 2, (ix + 1);					// clear file status bit
	ld (iy + 51), a;					// store accumulator in volume descriptor
	res 1, (iy + 52);					// clear volume status bit
	ld ($3c04), hl;						// store HL in system variable

;	// Function: Set error and prepare buffer operations
set_error_prepare_buffer:
	ld a, $11;							// load error code 17
	ld (ix + 6), a;						// store error code in file descriptor
	ld hl, disk_sector_buffer;			// load buffer address
	push hl;							// save buffer address
	call process_file_sector;			// call buffer read function
	pop hl;								// restore HL register
	ret c;								// return if error

;	// directory entry processing loop
dir_entry_loop:
	dec (ix + 6);						// decrement entry counter
	jr nz, dir_process_entry;			// jump if more entries to process
	call process_sector_decrement;		// call sector advance function
	jr set_error_prepare_buffer;		// jump to reload buffer

;	// process current directory entry
dir_process_entry:
	ld a, (hl);							// load first character of entry
	and a;								// check if entry is empty (end of directory)
	jr z, dir_end_reached;				// jump if end of directory
	cp 229;								// check for deleted entry marker ($e5)
	jr z, dir_deleted_entry;			// jump if deleted entry
	ld c, l;							// save current entry pointer in C
	ld a, l;							// load entry pointer
	add a, 11;							// add 11 to point to attributes byte
	ld l, a;							// update pointer to attributes
	ld a, (hl);							// load file attributes
	ld l, c;							// restore entry pointer
	cp 15;								// check for long filename entry ($0f)
	jr nz, dir_check_attributes;		// jump if not long filename entry

;	// skip long filename entries
dir_skip_entry:
	ld bc, $20;							// load directory entry size (32 bytes)
	add hl, bc;							// advance to next directory entry
	jr dir_entry_loop;					// jump back to process next entry

;	// handle deleted directory entry
dir_deleted_entry:
	call handle_deleted_entry;			// call deleted entry handler
	jr dir_skip_entry;					// jump to skip entry

;	// process deleted entry for reuse tracking
handle_deleted_entry:
	bit 1, (iy + 52);					// check if already tracking deleted entry
	ret nz;								// return if already tracking
	set 1, (iy + 52);					// set deleted entry tracking flag
	ld a, (ix + 6);						// load current entry number
	ld (ix + 30), a;					// store as deleted entry number
	ld a, (ix + 19);					// load current sector high
	ld (ix + 31), a;					// store as deleted entry sector
	call get_file_next_cluster;			// call file descriptor function
	call store_file_size;				// call position storage function
	call get_file_sector_address;		// call sector calculation function
	call store_file_position;			// call position update function
	ret;								// return from function

;	// check file attributes and compare filenames
dir_check_attributes:
	ld e, a;							// store file attributes in E
	ld a, (iy + 51);					// load file attribute filter
	and a;								// check if filter is set
	jr z, dir_compare_filename;			// jump if no filter
	and e;								// apply filter to file attributes
	jr z, dir_skip_entry;				// skip entry if doesn't match filter

;	// compare entry with search filename
dir_compare_filename:
	ld de, ($3c04);						// load search filename pointer
	call compare_directory_entries;		// call filename comparison function
	jr nz, dir_skip_entry;				// skip if no match
	ld (ix + 28), l;					// store matched entry low address
	ld (ix + 29), h;					// store matched entry high address
	or a;								// clear carry flag (success)
	ret;								// return with match found

;	// handle end of directory (file not found)
dir_end_reached:
	call handle_deleted_entry;			// call deleted entry handler
	ld a, (ix + 30);					// load saved deleted entry number
	ld (ix + 6), a;						// restore entry counter
	ld a, (ix + 31);					// load saved deleted entry sector
	ld (ix + 19), a;					// restore sector number
	call load_file_size;				// call position restore function
	call set_file_next_cluster;			// call sector setup function
	call load_file_position;			// call position load function
	call set_file_sector_address;		// call position store function
	ld a, 5;							// load error code 5 (file not found)
	scf;								// set carry flag (error)
	ret;								// return with error

;	// initialize file lookup operation
init_file_lookup:
	ld bc, $ffff;						// initialize counters to -1 (not found)
	ld ($3c1f), bc;						// store in first counter variable
	ld ($3c20), bc;						// store in second counter variable

;	// setup directory buffer and call system function
setup_dir_buffer:
	ld de, $2c00;						// load directory buffer address
	push de;							// save buffer address on stack
	rst $30;							// call system function (disk operation)
	dec b;								// decrement operation parameter
	pop hl;								// restore buffer address to HL
	ld (iy + 52), a;					// store operation flags
	rra;								// rotate right to check bit 0
	jr nc, path_init_filename;			// jump if directory operation
	push hl;							// save HL register
	push iy;							// save IY register
	pop hl;								// load IY value into HL
	ld l, $80;							// set L to $80 (buffer offset)
	ld de, $2c80;						// load destination buffer address
	push de;							// save destination address
	ld a, (iy + 127);					// load buffer size (FIXME: negative offset)
	push af;							// save buffer size
	sub $80;							// subtract $80 from buffer size
	ld b, 0;							// clear B register
	ld c, a;							// store adjusted size in BC
	ldir;								// copy buffer data
	pop af;								// restore original buffer size
	pop de;								// restore destination address
	ld e, a;							// store buffer size in E
	pop hl;								// restore HL register

;	// initialize filename processing
path_init_filename:
	xor a;								// clear A register
	ld (ix + 29), a;					// clear high byte of entry pointer
	ld a, (hl);							// load first character of path
	and a;								// check if path is empty
	jp z, path_empty;					// jump if empty path
	cp '/';								// check for root directory marker
	jr nz, path_setup_processing;		// jump if not root directory
	bit 0, (iy + 52);					// check if absolute path flag set
	jr z, path_advance_root;			// jump if not absolute path
	cp a;								// clear zero flag
	ld e, $80;							// load buffer offset
	ld (de), a;							// store path separator
	inc de;								// advance buffer pointer

;	// advance past root directory marker
path_advance_root:
	inc hl;								// advance path pointer past '/'

;	// setup path processing
path_setup_processing:
	ld ($3dea), de;						// store current buffer pointer
	call z, process_cluster_pointer;	// call root directory setup if needed
	call nz, get_filesystem_parameters;	// call current directory setup if not root

;	// main path component processing loop
path_component_loop:
	ld ($3dec), hl;						// store current path position
	ld a, (hl);							// load current character
	and a;								// check if end of path
	jp z, path_end_reached;				// jump if end of path reached
	call store_cluster_address;			// call path position storage
	call setup_file_sector;				// call directory setup
	ld de, $3c06;						// load filename buffer address
	push de;							// save buffer address
	call process_command_8byte;			// call filename extraction function
	pop de;								// restore buffer address
	ret c;								// return if error in filename extraction
	push hl;							// save path pointer
	ex de, hl;							// exchange DE/HL (filename buffer to HL)
	xor a;								// clear A register
	call validate_file_operation;		// call directory entry search function
	pop de;								// restore path pointer
	jp c, path_search_failed;			// jump if search failed
	ld c, l;							// save entry pointer low in C
	ld a, l;							// load entry pointer low
	add a, $0b;							// add 11 to point to attributes
	ld l, a;							// update pointer to attributes
	bit 4, (hl);						// check directory attribute bit
	ld l, c;							// restore entry pointer
	ex de, hl;							// exchange back to original order
	jr nz, path_directory_found;		// jump if directory entry
	ld a, (hl);							// load next path character
	and a;								// check if end of path
	jr z, path_file_found;				// jump if end of path (file found)
	ld a, $13;							// load error code 19 (not a directory)
	scf;								// set carry flag (error)
	ret;								// return with error

;	// handle successful file found at end of path
path_file_found:
	ld a, (iy + 52);					// load operation flags
	rla;								// rotate left to check bit 7
	ld a, $11;							// load error code 17
	ret c;								// return error if wrong operation type
	jr path_success_handler;			// jump to success handler

;	// handle directory entry found - traverse into subdirectory
path_directory_found:
	bit 0, (iy + 52);					// check if path building is enabled
	jr z, path_traverse_directory;		// jump if not building path
	push hl;							// save entry pointer
	ld hl, ($3dec);						// load current path position
	ld de, ($3dea);						// load path buffer pointer
	ld a, (hl);							// load next path character
	cp '.';								// check for '.' (current/parent directory)
	jr z, path_dot_directory;			// jump if dot directory

;	// copy directory name to path buffer
path_copy_name:
	ld a, (hl);							// load character from path
	inc hl;								// advance path pointer
	and a;								// check if end of component
	jr z, path_add_separator;			// jump if end of component (add separator)
	cp '/';								// check for path separator ($2f)
	jr z, path_add_separator;			// jump if path separator found
	ld (de), a;							// store character in path buffer
	inc de;								// increment buffer pointer
	jr path_copy_name;					// continue copying characters

;	// handle parent directory (..) navigation
path_dot_directory:
	inc hl;								// skip first dot
	ld a, (hl);							// load next character
	cp '.';								// check for second dot ($2e)
	jr nz, path_update_buffer;			// jump if not parent directory
	dec de;								// backtrack in path buffer
	dec de;								// backtrack further

;	// backtrack to find parent directory
path_find_parent:
	ld a, (de);							// load character from path buffer
	cp '/';								// check for path separator ($2f)
	jr z, path_parent_found;			// jump if separator found
	dec de;								// continue backtracking
	jr path_find_parent;				// loop until separator found

;	// position after parent directory separator
path_parent_found:
	inc de;								// move past separator
	jr path_update_buffer;				// jump to path update

;	// add path separator after directory name
path_add_separator:
	ld a, $2f;							// load path separator character
	ld (de), a;							// store separator in buffer
	inc de;								// increment buffer pointer

;	// update path buffer pointer and continue processing
path_update_buffer:
	ld ($3dea), de;						// store updated path buffer pointer
	pop hl;								// restore entry pointer
	ld a, e;							// check buffer position
	cp $81;								// compare with buffer limit
	ld a, $15;							// load error code 21 (path too long)
	ret c;								// return if path buffer overflow
	call z, process_cluster_pointer;	// call root directory setup if at root
	jr z, path_continue_processing;		// jump if root directory

;	// setup directory for subdirectory traversal
path_traverse_directory:
	call setup_directory_cluster;		// call directory cluster setup function

;	// continue path processing or handle completion
path_continue_processing:
	ld a, (hl);							// load next path character
	and a;								// check if end of path
	jr z, path_end_reached;				// jump if end of path reached
	cp '/';								// check for path separator ($2f)
	inc hl;								// advance path pointer
	jp z, path_component_loop;			// jump to continue processing if separator

;	// error - invalid path format
path_empty:
	scf;								// set carry flag (error condition)
	ld a, $13;							// load error code 19 (invalid filename)
	ret;								// return with error

;	// handle end of path - check operation type
path_end_reached:
	ld a, (iy + 52);					// load operation flags
	rla;								// rotate left to check bit 7
	ccf;								// complement carry flag
	ld a, $10;							// load error code 16 (wrong operation)
	ret c;								// return error if wrong operation type

;	// successful path resolution - call finalization
path_success_handler:
	call path_finalize_function;		// call path finalization function
	or a;								// clear carry flag (success)
	ret;								// return successfully

;	// path finalization function
path_finalize_function:
	bit 0, (iy + 52);					// check if path building enabled
	ret z;								// return if path building disabled
	ld hl, ($3dec);						// load current path position
	ld de, ($3dea);						// load path buffer pointer

;	// copy remaining path string
path_copy_string:
	ld a, (hl);							// load character from source
	ld (de), a;							// store character in destination
	inc hl;								// increment source pointer
	inc de;								// increment destination pointer
	or a;								// check if null terminator
	ret z;								// return if end of string
	jr path_copy_string;				// continue copying

;	// handle file not found error with path completion
path_search_failed:
	ex de, hl;							// exchange DE and HL
	ld a, (hl);							// load character from path
	and a;								// check if end of path
	jr z, path_not_found_finalize;		// jump if end reached
	scf;								// set carry flag (error)
	ld a, $13;							// load error code 19 (invalid filename)
	ret;								// return with error

;	// finalize path and return file not found error
path_not_found_finalize:
	call path_finalize_function;		// call path finalization function
	scf;								// set carry flag (error)
	ld a, 5;							// load error code 5 (file not found)
	ret;								// return with error

;	// setup directory cluster for operations
setup_directory_cluster:
	push hl;							// save HL register
	ld a, (ix + 29);					// load cluster high byte from descriptor
	and a;								// check if cluster is set
	jr nz, load_cluster_descriptor;		// jump if cluster exists
	call process_cluster_pointer;		// call root directory setup
	jr restore_registers_check;			// jump to completion

;	// load cluster from descriptor and setup directory
load_cluster_descriptor:
	ld h, a;							// copy cluster high byte to H
	ld a, (ix + 28);					// load cluster low byte from descriptor
	add a, $14;							// add offset to directory entry
	ld l, a;							// set cluster low byte in L
	call process_cluster_chain;			// call cluster setup function

;	// restore registers and check sector count
restore_registers_check:
	pop hl;								// restore HL register

;	// check sector parameters and return
check_sector_params:
	ld a, (iy + 28);					// load sectors per cluster
	cp 1;								// check if single sector cluster
	ret z;								// return if single sector
	ld bc, 0;							// clear BC register
	ret;								// return with cleared registers

;	// process cluster chain and validate
process_cluster_chain:
	call extract_cluster_data;			// call cluster data extraction function
	ld a, c;							// load cluster low byte
	or b;								// combine with high byte
	or e;								// combine with extended data
	or d;								// combine all cluster data
	call z, process_cluster_pointer;	// call root directory if cluster is zero
	jr check_sector_params;				// jump to parameter check

;	// extract cluster data from directory entry
extract_cluster_data:
	ld c, (hl);							// load cluster low byte
	inc l;								// increment to next byte
	ld b, (hl);							// load cluster high byte
	ld a, l;							// get current L value
	add a, 5;							// skip 5 bytes to extended cluster
	ld l, a;							// update L pointer
	ld e, (hl);							// load extended cluster low byte
	inc l;								// increment to next byte
	ld d, (hl);							// load extended cluster high byte
	inc l;								// increment pointer for return
	ret;								// return with cluster data

;	//  buffer management function with system call
	ex de, hl;							// exchange DE and HL
	push iy;							// save IY register
	pop hl;								// load IY value to HL
	ld l, $80;							// set buffer offset
	rst $30;							// call system function
	inc b;								// increment B register
	or a;								// clear carry flag
	ret;								// return from function
