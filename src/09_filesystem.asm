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

;	// open screen channel for output
open_screen_channel:;					// called from dirs.io
	ld a, 2;							// screen
	rst $18;							// call BASIC ROM routine
	defw chan_open;						// open channel function
	ret;								// return to caller

;	// data area or function parameters
data_area_parameters:
	ld d, (hl);							// load D from address pointed by HL
	ld c, $b2;							// load immediate value $B2 into C
	ld sp, $16de;						// set stack pointer to $16DE
	adc a, a;							// add A to itself with carry
	ld d, $97;							// load immediate value $97 into D
	ld d, $de;							// load immediate value $DE into D
	jr format_output_routine;			// jump to format_output_routine
	ld sp, $369a;						// set stack pointer to $369A
	add a, $19;							// add immediate value $19 to A
	rst $38;							// restart at vector $38
	dec (hl);							// decrement value at address HL
	ld l, (hl);							// load L with value at address HL
	ld (hl), $d2;						// store $D2 at address HL
	inc sp;								// increment stack pointer
	ld (bc), a;							// store A at address BC
	inc (hl);							// increment value at address HL
	ld b, a;							// copy A to B register
	dec (hl);							// decrement value at address HL
	sub b;								// subtract B from A
	ld (hl), $94;						// store $94 at address HL
	ld (hl), $77;						// store $77 at address HL
	ld d, $ad;							// load immediate value $AD into D
	inc sp;								// increment stack pointer
	ei;									// interrupts on
	ld ($354c), a;						// store A at address $354C
	ex (sp), hl;						// exchange HL with top of stack
	dec (hl);							// decrement value at address HL
	sbc a, l;							// subtract L from A with carry
	dec (hl);							// decrement value at address HL
	ld a, ($a936);						// load A from address $A936
	ld ($31c4), a;						// store A at address $31C4
	dec bc;								// decrement BC register pair
	dec (hl);							// decrement value at address HL
	ld hl, ($290e);						// load HL from address $290E
	ld c, $c9;							// load immediate value $C9 into C
	ex de, hl;							// exchange DE and HL
	ld a, b;							// copy B to A register
	call output_byte_to_file;			// call function at output_byte_to_file
	ld a, d;							// copy D to A register
	call output_byte_to_file;			// call function at output_byte_to_file
	ld a, e;							// copy E to A register
	call output_byte_to_file;			// call function at output_byte_to_file
	push iy;							// save IY on stack
	pop hl;								// restore into HL
	ld l, $18;							// load immediate value $18 into L
	ld bc, 4;							// load immediate value 4 into BC
	rst $30;							// restart at vector $30

;	// format output routine with parameters
format_output_routine:
	ld b, $2e;							// load immediate value $2E into B
	inc b;								// increment B register
	rst $30;							// restart at vector $30
	inc b;								// increment B register
	ld l, $0c;							// load immediate value $0C into L
	rst $30;							// restart at vector $30
	inc b;								// increment B register
	ex de, hl;							// exchange DE and HL
	or a;								// clear carry flag (OR A with itself)
	ret;								// return to caller

;	// output byte to file handle
output_byte_to_file:
	ld hl, $3dfa;						// load HL with address $3DFA
	ld (hl), a;							// store A at address HL
	ld bc, 1;							// load BC with value 1
	rst $30;							// restart at vector $30
	ld b, $c9;							// load B with immediate value $C9
	push bc;							// save BC on stack
	call search_free_memory;			// call function at search_free_memory
	pop bc;								// restore BC from stack
	ret c;								// return if carry set
	push hl;							// save HL on stack
	pop iy;								// restore into IY
	ld (hl), c;							// store C at address HL
	inc l;								// increment L register
	ld (hl), b;							// store B at address HL
	inc l;								// increment L register
	ld (hl), e;							// store E at address HL
	inc l;								// increment L register
	ld (hl), d;							// store D at address HL
	call validate_fs_structure;			// call function at validate_fs_structure
	ld a, (iy + _flags);				// load A from IY+flags offset
	ret;								// return to caller

;	// search for free memory block
search_free_memory:
	ld hl, $2000;						// load HL with address $2000
	ld b, 4;							// load B with counter value 4

;	// memory search loop continuation
memory_search_loop:
	ld a, (hl);							// load A with value at address HL
	and a;								// test A (check if zero)
	ret z;								// return if zero
	inc h;								// increment H register 
	djnz memory_search_loop;			// decrement B and jump if not zero
	scf;								// set carry flag
	ret;								// return to caller

;	// clear error and set carry flag
clear_error_set_carry:
	xor a;								// clear A register (set to 0)
	ld (iy + _err_nr), a;				// clear error number in IY
	scf;								// set carry flag
	ret;								// return to caller

;	// validate file system structure and data
validate_fs_structure:
	ld hl, $2d00;						// load HL with address $2D00
	ld bc, 0;							// clear BC register pair
	ld de, 0;							// clear DE register pair
	push hl;							// save HL on stack
	call read_disk_sector;				// call function at read_disk_sector
	pop hl;								// restore HL from stack
	jr c, clear_error_set_carry;		// jump to error handler if carry
	inc h;								// increment H register
	ld l, $fe;							// load L with value $FE
	ld a, (hl);							// load A from address HL
	inc l;								// increment L register
	and (hl);							// AND A with value at HL
	jr nz, clear_error_set_carry;		// jump to error if not zero
	dec h;								// decrement H register
	ld l, $0b;							// load L with value $0B
	ld a, (hl);							// load A from address HL
	inc l;								// increment L register
	or (hl);							// OR A with value at HL
	cp 2;								// compare A with 2
	jr nz, clear_error_set_carry;		// jump to error if not equal
	ld l, $10;							// load L with value $10
	ld a, (hl);							// load A from address HL
	cp 2;								// compare A with 2
	jr nz, clear_error_set_carry;		// jump to error if not equal
	ld hl, $2d00;						// load HL with address $2D00
	ld l, $13;							// load L with value $13
	ld e, (hl);							// load E from address HL
	inc l;								// increment L register
	ld d, (hl);							// load D from address HL
	ld a, e;							// copy E to A
	or d;								// OR A with D
	jr nz, process_fs_data;				// jump if not zero
	ld l, $20;							// load L with value $20
	rst $30;							// restart at vector $30
	ld bc, $70fd;						// load BC with value $70FD
	dec de;								// decrement DE register pair
	ld (iy + 26), c;					// store C at IY+26

;	// process filesystem data and parameters
process_fs_data:
	ld (iy + 25), d;					// store D at IY+25
	ld (iy + 24), e;					// store E at IY+24
	ld l, $0d;							// load L with value $0D
	ld a, (hl);							// load A from address HL
	ld (iy + 37), a;					// store A at IY+37
	inc l;								// increment L register
	ld e, (hl);							// load E from address HL
	inc l;								// increment L register
	ld d, (hl);							// load D from address HL
	ld (iy + 30), d;					// store D at IY+30
	ld (iy + 29), e;					// store E at IY+29
	ld l, $3a;							// point to memory location $3A
	ld a, (hl);							// load value from memory address HL
	cp '2';								// $50
	jr z, clear_error_set_carry;		// jump if character is '2'
	dec l;								// decrement L to previous memory location
	ld a, (hl);							// load value from new memory address
	ld l, $36;							// point to memory location $36
	cp '1';								// $49
	ld a, 0;							// load 0 into accumulator
	jr z, process_fs_mode;				// jump if character is '1'
	ld l, $52;							// point to memory location $52
	inc a;								// increment accumulator (set to 1)

;	// process filesystem mode and parameters
process_fs_mode:
	ld (iy + 28), a;					// store accumulator at IY+28 (mode flag)
	push de;							// save DE register pair
	push iy;							// push IY onto stack
	pop de;								// pop into DE (copy IY to DE)
	ld e, 4;							// set E to offset 4
	ld bc, 5;							// set byte count to 5
	ldir;								// copy 5 bytes from HL to DE
	pop de;								// restore DE register pair
	cp 1;								// compare accumulator with 1
	jr z, process_fat_parameters;		// jump if equals 1
	push hl;							// save HL register pair
	ld l, $16;							// point to memory location $16
	ld a, (hl);							// load low byte from memory
	inc l;								// increment to next memory location
	ld h, (hl);							// load high byte from memory
	ld l, a;							// move low byte to L register
	xor a;								// clear accumulator (set to 0)
	ld (iy + 34), a;					// clear high byte at IY+34
	ld (iy + 33), a;					// clear low byte at IY+33
	ld (iy + 32), h;					// store high byte at IY+32
	ld (iy + 31), l;					// store low byte at IY+31
	sla l;								// shift L left (multiply by 2)
	rl h;								// rotate H left with carry
	add hl, de;							// add DE to HL
	ex de, hl;							// exchange DE and HL
	ld (iy + 36), d;					// store D at IY+36
	ld (iy + 35), e;					// store E at IY+35
	pop hl;								// restore HL from stack
	ld l, $11;							// point to memory location $11
	ld a, (hl);							// load low byte from memory
	inc l;								// increment to next memory location
	ld h, (hl);							// load high byte from memory
	ld l, a;							// move low byte to L register
	srl h;								// shift H right (divide by 2)
	rr l;								// rotate L right with carry
	srl h;								// shift H right (divide by 4)
	rr l;								// rotate L right with carry
	srl h;								// shift H right (divide by 8)
	rr l;								// rotate L right with carry
	srl h;								// shift H right (divide by 16)
	rr l;								// rotate L right with carry
	ld (iy + 66), l;					// store result at IY+66
	ld bc, 0;							// clear BC register pair
	call add_32bit;						// call subroutine at add_32bit
	jr calculate_cluster_params;		// jump to calculate_cluster_params

;	// process FAT parameters for FAT16
process_fat_parameters:
	push iy;							// push IY onto stack
	pop de;								// pop into DE (copy IY to DE)
	ld e, $26;							// set E to offset $26
	ld l, $2c;							// set L to offset $2C
	ldi;								// load and increment (copy HL to DE)
	ldi;								// load and increment (copy HL to DE)
	ldi;								// load and increment (copy HL to DE)
	ldi;								// load and increment (copy HL to DE)
	ld l, $24;							// load L with value $24
	rst $30;							// restart at vector $30
	ld bc, $70fd;						// load BC with value $70FD
	ld ($71fd), hl;						// store HL at address $71FD
	ld hl, $72fd;						// load HL with address $72FD
	jr nz, $0f58;						// jump if not zero to $0F58
	ld (hl), e;							// store E at memory location HL
	rra;								// rotate A right through carry
	sla e;								// shift E left (multiply by 2)
	rl d;								// rotate D left through carry
	rl c;								// rotate C left through carry
	rl b;								// rotate B left through carry
	call call_cluster_processing;		// call subroutine at call_cluster_processing

;	// calculate cluster parameters and free space
calculate_cluster_params:
	ld h, 0;							// clear H register
	ld l, (iy + 37);					// load value from IY+37 into L
	sla l;								// shift L left arithmetic
	rl h;								// rotate H left through carry
	call sub_32bit;						// call subroutine at sub_32bit
	ld (iy + 45), b;					// store B at IY+45
	ld (iy + 44), c;					// store C at IY+44
	ld (iy + 43), d;					// store D at IY+43
	ld (iy + 42), e;					// store E at IY+42
	call calculate_free_clusters;		// call subroutine at calculate_free_clusters
	call process_directory_entry;		// call subroutine at process_directory_entry
	call init_volume_path;				// call subroutine at init_volume_path
	call process_volume_label;			// call subroutine at process_volume_label
	or a;								// clear carry flag
	ret;								// return from subroutine

;	// calculate free clusters from sectors
calculate_free_clusters:
	ld h, (iy + 25);					// load high byte from IY+25
	ld l, (iy + 24);					// load low byte from IY+24
	or a;								// clear carry flag
	sbc hl, de;							// subtract DE from HL with carry
	ex de, hl;							// exchange DE and HL registers
	ld h, (iy + 27);					// load high byte from IY+27
	ld l, (iy + 26);					// load low byte from IY+26
	sbc hl, bc;							// subtract BC from HL with carry
	ld a, (iy + 37);					// get sectors per cluster value (power of 2)

;	// cluster calculation shift loop
cluster_shift_loop:
	srl a;								// shift sectors per cluster right (find shift count)
	jr c, store_cluster_results;		// jump if bit was 1 (found the shift count)
	srl h;								// shift result high word right
	rr l;								// rotate result through carry
	rr d;								// rotate result through carry
	rr e;								// rotate result low byte through carry
	jr cluster_shift_loop;				// loop back to check next bit

;	// store cluster calculation results
store_cluster_results:
	ld (iy + 62), e;					// store E at IY+62 (result low byte)
	ld (iy + 63), d;					// store D at IY+63 (result mid byte)
	ld (iy + 64), l;					// store L at IY+64 (result high byte)
	ld (iy + 65), h;					// store H at IY+65 (result top byte)
	ret;								// return from subroutine

;	// process directory entry information
process_directory_entry:
	ld a, (iy + 28);					// load mode flag from IY+28
	cp 1;								// compare with 1
	jr nz, $100f;						// jump if not equal to 1
	ld hl, $2d30;						// load address $2D30
	ld a, (hl);							// load value from memory
	dec a;								// decrement accumulator
	jr nz, $100f;						// jump if not zero
	ld hl, $3e00;						// load address $3E00
	ld bc, 0;							// clear BC register pair
	ld de, 1;							// set DE to 1
	push hl;							// save HL on stack
	call read_disk_sector;				// call subroutine at read_disk_sector
	pop hl;								// restore HL from stack
	jr c, $100f;						// jump if carry set (error)
	inc h;								// increment high byte of address
	ld l, $e4;							// set L to offset $E4
	ld a, (hl);							// load first byte from memory
	inc l;								// increment to next byte
	xor (hl);							// XOR with second byte
	inc l;								// increment to next byte
	add a, (hl);						// add third byte
	inc l;								// increment to next byte
	and (hl);							// AND with fourth byte
	cp 'A';								// $41
	jr nz, $100f;						// jump if not equal to 'A'
	ld l, $fe;							// set L to offset $FE
	ld a, (hl);							// load byte from memory
	inc l;								// increment to next byte
	and (hl);							// AND with next byte
	jr nz, $100f;						// jump if not zero
	ld a, 1;							// set A to 1
	ld (iy + 61), a;					// store at IY+61 (flag)
	ld a, ($2d41);						// load from memory address $2D41
	and %00000001;						// mask bit 0
	jr nz, $100f;						// jump if bit set
	ld l, $e8;							// set L to offset $E8
	rst $30;							// floating point system call
	ld bc, $b178;						// load BC with float operation code
	or e;								// OR E with A (check for zero)
	or d;								// OR D with A (check for zero)
	jr z, $100f;						// jump if zero result
	call set_working_cluster;			// call subroutine at set_working_cluster
	rst $30;							// floating point system call
	ld bc, $b6c3;						// load BC with float operation code
	ld de, $ff01;						// load DE with value $FF01
	rst $38;							// system call (error or comparison)
	ld de, $ffff;						// load DE with value $FFFF
	call set_working_cluster;			// call subroutine at set_working_cluster
	ld bc, 0;							// clear BC register pair
	ld de, 2;							// set DE to 2
	jp set_directory_cluster;			// jump to set_directory_cluster

;	// process volume label and disk information
process_volume_label:
	ld hl, $1416;						// load address $1416
	ld a, 8;							// set A to 8
	call process_filesystem_operation;	// call subroutine at process_filesystem_operation
	jr nc, setup_label_copy;			// jump if no carry (success)
	ld hl, $2d2b;						// load address $2D2B

;	// setup label copy parameters
setup_label_copy:
	push iy;							// save IY register
	pop de;								// copy IY address to DE
	ld e, $0c;							// set E to offset $0C
	ld a, (hl);							// load value from memory
	and a;								// test if zero
	jr nz, copy_label_string;			// jump if not zero

;	// use default no name label
use_default_label:
	ld hl, default_label_string;		// point to default "NO NAME" string

;	// call string copy subroutine
copy_label_string:
	call copy_string_limited;			// call string copy subroutine
	ret;								// return from routine

;	// copy string with length limit
copy_string_limited:
	ld b, $0b;							// set counter to 11 characters

;	// character copy loop
char_copy_loop:
	ld a, (hl);							// load character from source
	cp ' ';								// $20
	jr z, handle_space_chars;			// jump if space character

;	// store character and continue
store_char_continue:
	ld (de), a;							// store character at destination
	inc hl;								// increment source pointer
	inc de;								// increment destination pointer
	djnz char_copy_loop;				// decrement B and loop if not zero
	ret;								// return from routine

;	// handle space characters in label
handle_space_chars:
	inc hl;								// move to next character
	ld a, (hl);							// load next character
	cp ' ';								// $20
	dec hl;								// move back to space
	ld a, (hl);							// reload space character
	jr nz, store_char_continue;			// continue copying if next char not space
	ld a, b;							// check remaining count
	cp $0b;								// compare with 11
	jr z, use_default_label;			// jump to default name if no chars copied
	ld a, 0;							// load zero
	ld (de), a;							// null terminate string
	ret;								// return from routine

;	// default disk label string
default_label_string:
	defb "NO NAME  ";					// if disk has no label
;	// initialize volume path string
init_volume_path:
	call process_cluster_pointer;		// call subroutine at process_cluster_pointer
	call store_fs_parameters;			// call subroutine at store_fs_parameters
	push iy;							// push IY register onto stack
	pop hl;								// pop into HL (copy IY to HL)
	ld l, $80;							// set L to offset $80
	ld a, $2f;							// load '/' character
	ld (hl), a;							// store '/' at memory location
	inc l;								// increment L
	ld a, l;							// copy L to A
	ld (iy + 127), l;					// store L at IY+127
	xor a;								// clear A (set to 0)
	ld (hl), a;							// store 0 (null terminator)
	ret;								// return from routine

;	// store filesystem parameters
store_fs_parameters:
	ld a, (iy + 28);					// load mode flag from IY+28
	cp 1;								// compare with 1
	jr nz, store_param_values;			// jump if not equal to 1
	ld a, d;							// load D register
	or b;								// OR with B register
	or c;								// OR with C register

;	// check if all registers zero
check_all_zero:
	or e;								// OR with E register (check if all zero)
	call z, process_cluster_pointer;	// call process_cluster_pointer if all registers are zero

;	// store parameter values
store_param_values:
	ld (iy + 49), b;					// store B register at IY+49
	ld (iy + 48), c;					// store C register at IY+48
	ld (iy + 47), d;					// store D register at IY+47
	ld (iy + 46), e;					// store E register at IY+46
	ret;								// return from routine

;	// read disk sector function
read_disk_sector:
	push bc;							// save BC register pair
	push de;							// save DE register pair
	ld a, (iy + _flags);				// load flags from IY+_flags
	rst $08;							// system call
	defb disk_read;						// disk read operation
	pop de;								// restore DE register pair
	pop bc;								// restore BC register pair
	ret;								// return from routine

;	// write disk sector function
write_disk_sector:
	ld a, (iy + _flags);				// load flags from IY+_flags
	rst $08;							// system call
	defb disk_write;					// disk write operation
	ret;								// return from routine

;	// write sector with current drive
write_current_drive:
	push bc;							// save BC register pair
	push de;							// save DE register pair
	ld a, ($3c25);						// get disk drive number
	rst $08;							// call system function
	defb disk_write;					// write sector to disk
	pop de;								// restore DE register pair
	pop bc;								// restore BC register pair
	ret;								// return to caller

;	// write cluster data to disk
write_cluster_data:
	call calculate_cluster_address;		// load cluster start address
	jr write_current_drive;				// jump to disk write routine

;	// read cluster data from disk
read_cluster_data:
	call calculate_cluster_address;		// load cluster start address
	jr read_disk_sector;				// jump to disk read routine

;	// check drive and cluster cache
check_drive_cluster_cache:
	ld a, ($3c25);						// get current drive number
	cp (iy + _flags);					// compare with file system drive
	jr nz, validate_cluster_get_buffer;	// jump if different drive
	ld hl, $3c14;						// point to cluster number buffer
	call compare_32bit;					// compare 32-bit cluster values

;	// validate cluster and get buffer
validate_cluster_get_buffer:
	ld hl, $2800;						// load default buffer address
	ccf;								// complement carry flag
	ret z;								// return if zero flag set
	call flush_dirty_buffer;			// call cluster validation routine
	ret c;								// return if error
	push de;							// save DE register
	push bc;							// save BC register
	push hl;							// save HL register
	call call_cluster_processing;		// calculate sector address
	push hl;							// save calculated address
	call read_disk_sector;				// read sector from disk
	pop hl;								// restore calculated address
	call c, read_cluster_data;			// if read failed, try write operation
	pop hl;								// restore HL register
	pop bc;								// restore BC register
	pop de;								// restore DE register
	push af;							// save operation result
	ld a, (iy + _flags);				// get file system flags
	ld ($3c25), a;						// store current drive number
	ld ($3c11), de;						// store sector address low word
	ld ($3c13), bc;						// store sector address high word
	pop af;								// restore operation result
	ret;								// return to caller

;	// flush dirty buffer to disk
flush_dirty_buffer:
	ld a, ($3c2b);						// get dirty buffer flag
	or a;								// test if buffer needs flushing
	ret z;								// return if buffer clean
	push bc;							// save BC register
	push de;							// save DE register
	push hl;							// save HL register
	ld de, ($3c11);						// get sector address low word
	ld bc, ($3c13);						// get sector address high word
	call flush_buffer_to_disk;			// flush buffer to disk
	pop hl;								// restore HL register
	pop de;								// restore DE register
	pop bc;								// restore BC register
	ret;								// return to caller

;	// mark buffer as dirty
mark_buffer_dirty:
	ld a, $ff;							// set dirty flag value
	ld ($3c2b), a;						// mark buffer as dirty
	or a;								// set flags for return
	ret;								// return with non-zero

;	// flush buffer to disk with error handling
flush_buffer_to_disk:
	xor a;								// clear accumulator
	ld ($3c2b), a;						// clear dirty buffer flag
	ld hl, $2800;						// point to disk buffer
	push de;							// save sector address low word
	push bc;							// save sector address high word  
	push hl;							// save buffer address
	call call_cluster_processing;		// calculate final sector address
	push hl;							// save calculated address
	call write_current_drive;			// write buffer to disk
	pop hl;								// restore calculated address
	jr c, handle_write_errors;			// jump if write error
	call write_cluster_data;			// perform additional write operation
	or a;								// check operation result

;	// handle buffer write errors
handle_write_errors:
	call c, write_cluster_data;			// call cleanup if error occurred
	jr c, cleanup_buffer_ops;			// jump to exit if still error
	call load_directory_sector;			// call buffer flush function

;	// cleanup buffer operations
cleanup_buffer_ops:
	pop hl;								// restore HL register
	pop bc;								// restore BC register
	pop de;								// restore DE register
	ret;								// return with final status
