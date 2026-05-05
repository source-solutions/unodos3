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

	org $0686
load_32bit_value:
	ld e, (hl);							// load low byte of 32-bit value
	inc hl;								// advance to next byte
	ld d, (hl);							// load second byte
	inc hl;								// advance to next byte
	ld c, (hl);							// load third byte
	inc hl;								// advance to next byte
	ld b, (hl);							// load high byte of 32-bit value
	inc hl;								// advance pointer past the value
	ret;								// return with 32-bit value in BCDE

test_32bit_zero:
	ld a, c;							// get byte C
	or b;								// OR with byte B
	or e;								// OR with byte E
	or d;								// OR with byte D
	ret;								// return with Z flag set if BCDE is zero

;	// 32-bit comparison function (compare BCDE with memory at HL)
compare_32bit:
	ld a, (hl);							// get high byte from memory
	cp b;								// compare with B
	ret nz;								// return if not equal
	dec hl;								// move to next byte down
	ld a, (hl);							// get third byte
	cp c;								// compare with C
	ret nz;								// return if not equal
	dec hl;								// move to next byte down
	ld a, (hl);							// get second byte
	cp d;								// compare with D
	ret nz;								// return if not equal
	dec hl;								// move to next byte down
	ld a, (hl);							// get low byte
	cp e;								// compare with E
	ret nz;								// return if not equal
	scf;								// set carry flag (32-bit values match)
	ret;								// return with carry set

;	// syntax checker (check if in BASIC syntax mode)
syntax_check:
	rst $18;							// call BASIC ROM routine
	defw syntax_z;						// check if in syntax checking mode
	ret;								// return with Z flag set if syntax mode

;	// 32-bit store function (store DEBC to memory at HL)
store_32bit:
	ld (hl), e;							// store low byte of 32-bit value
	inc hl;								// advance to next location
	ld (hl), d;							// store second byte
	inc hl;								// advance to next location
	ld (hl), c;							// store third byte
	inc hl;								// advance to next location
	ld (hl), b;							// store high byte of 32-bit value
	inc hl;								// advance pointer past stored value
	ret;								// return to caller

;	org $06b2
msg_betadisk:
	defm "betadisk", 0;					// null ternimated message

;	org $06bb
msg_failed:
	defb $17, $0c, $01;					// TAB 24
	defm ": failed";					// failure message text
	defb $0d, 0;						// carriage return, null terminator

;	org $06c8
msg_ok:
	defb $17, $0c, $01;					// TAB 27
	defm ": ok";						// success message text
	defb $0d, 0;						// carriage return, null terminator

;	org $06d1
msg_nmi:
	defm "nmi", 0;						// null ternimated message

;	// disk mounting and initialization routine
	org $06e1
disk_mount_init:
	ld hl, $2df2;						// load pointer to disk information table
	push hl;							// save disk info pointer on stack
	rst $08;							// call system function
	defb disk_info;						// get disk information
	pop hl;								// restore disk info pointer

;	// mount all available filesystems loop
mount_filesystems_loop:
	ld a, (hl);							// load filesystem identifier
	and a;								// check if zero (end of list)
	ret z;								// return if no more filesystems to mount
	push hl;							// save filesystem table pointer
	ld bc, 0;							// set mount parameters to zero
	rst $08;							// call system function
	defb f_mount;						// mount filesystem
	pop hl;								// restore filesystem table pointer
	ld de, 6;							// each filesystem entry is 6 bytes
	add hl, de;							// point to next filesystem entry
	jr mount_filesystems_loop;			// continue with next filesystem

filesystem_unmount:
	call search_filesystem_type;		// search for filesystem type in supported list
	scf;								// set carry flag to indicate error
	ret z;								// return if zero flag set
	ld l, a;							// store drive number in L register
	push hl;							// save drive number on stack
	call init_file_handle;				// call drive initialization routine
	pop hl;								// restore drive number from stack
	ret c;								// return if carry set (error)
	ld a, l;							// get drive number back
	call configure_system_drive;		// call drive configuration routine
	ret c;								// return if carry set (error)
	xor a;								// clear accumulator (A = 0)
	push iy;							// save IY register on stack
	pop hl;								// get IY value into HL
	ld (hl), a;							// clear first byte at IY address
	inc hl;								// advance to next byte
	ld (hl), a;							// clear second byte
	inc hl;								// advance to third byte
	ld (hl), a;							// clear third byte
	or a;								// clear carry flag (success)
	ret;								// return to caller

;	// search for filesystem type in supported list
search_filesystem_type:
	push bc;							// save BC register on stack
	ld hl, $2cf0;						// point to supported filesystem types table
	ld bc, $0f;							// set search length (15 bytes)
	cpir;								// compare and increment until match or end
	pop bc;								// restore BC register from stack
	ret nz;								// return if not found (NZ flag set)
	ld a, $1d;							// load error code $1d (unsupported filesystem)
	ret;								// return with error code

;	// check if drive is already mounted
check_drive_mounted:
	ld hl, $2d00;						// point to mounted drives table
	ld b, $0c;							// check up to 12 drive slots

;	// search loop through mounted drives
search_mounted_drives:
	cp (hl);							// compare drive ID with current entry
	jr z, drive_already_mounted;		// jump if match found (drive already mounted)
	inc hl;								// advance to next drive entry
	inc hl;								// (each entry is 3 bytes)
	inc hl;								// complete 3-byte entry traversal
	djnz search_mounted_drives;			// decrement B and loop if not zero
	ret;								// return if not found in table

;	// drive already mounted error
drive_already_mounted:
	ld a, $1f;							// load error code $1f (drive already mounted)
	scf;								// set carry flag to indicate error
	ret;								// return with error

filesystem_mount:
	ld l, a;							// store drive identifier in L register
	push hl;							// save drive identifier on stack
	push bc;							// save BC register on stack
	call check_drive_mounted;			// check if drive is already mounted
	pop bc;								// restore BC register from stack
	pop hl;								// restore drive identifier from stack
	ret c;								// return if carry set (drive already mounted)
	ld a, c;							// get partition number
	and a;								// check if zero (primary partition)
	jr z, mount_partition;				// jump if primary partition
	call configure_system_drive;		// call partition configuration routine
	ld a, $0b;							// load error code $0b (invalid partition)
	ccf;								// complement carry flag
	ret c;								// return if carry set (error)

;	// mount partition on drive
mount_partition:
	inc c;								// increment partition number (make 1-based)
	ld a, l;							// get drive identifier
	ld hl, $2df2;						// point to disk info structure
	push bc;							// save partition info on stack
	push hl;							// save disk info pointer on stack
	rst $08;							// call system function
	defb disk_info;						// get disk information
	pop hl;								// restore disk info pointer from stack
	jr nc, process_disk_info;			// jump if no error
	pop bc;								// restore partition info from stack
	ret;								// return with error

;	// process disk information and mount
process_disk_info:
	call find_empty_drive_slot;			// call disk processing routine
	pop bc;								// restore partition info from stack
	ld a, (hl);							// load partition type from disk info
	call validate_partition_type;		// validate partition type
	dec c;								// decrement partition number (back to 0-based)
	jr nz, finalize_drive_mount;		// jump if not primary partition
	push hl;							// save HL register on stack
	push bc;							// save partition info on stack
	call find_next_drive_letter;		// find next available drive letter
	pop bc;								// restore partition info from stack
	pop hl;								// restore HL register from stack
	ld c, a;							// store drive letter in C register

;	// finalize drive mounting in system table
finalize_drive_mount:
	ex de, hl;							// exchange DE and HL (DE now points to drive info)
	ld a, (de);							// load drive ID from drive info structure
	push hl;							// save HL register on stack
	push bc;							// save BC register on stack
	call prepare_system_request;		// call drive setup routine
	pop bc;								// restore BC register from stack
	pop hl;								// restore HL register from stack
	ret c;								// return if carry set (error in drive setup)
	ld (hl), a;							// store drive ID in drive table
	inc hl;								// advance to next byte in drive table entry
	ld (hl), c;							// store drive letter in drive table
	inc hl;								// advance to flags byte in drive table entry
	ld a, b;							// get drive/partition flags from B register
	or ixl;								// combine with IXL flags
	or %10000000;						// set bit 7 (active/bootable flag)
	ld (hl), a;							// store combined flags
	ld a, c;							// get filesystem type from C register
	ret;								// return to caller

;	// validate and decode partition type
validate_partition_type:
	push hl;							// save HL register on stack
	push bc;							// save BC register on stack
	inc hl;								// advance to next byte in partition table
	and %11100000;						// mask upper 3 bits of partition type
	cp $80;								// check if type is $80 (bootable)
	jr nz, finalize_partition_type;		// jump if not bootable partition
	ld a, (hl);							// load filesystem type byte
	bit 7, a;							// check bit 7 (extended partition flag)
	ld a, $40;							// default filesystem code $40
	jr z, finalize_partition_type;		// jump if not extended partition
	ld b, $40;							// set B to $40 for extended partition
	and %00000111;						// mask lower 3 bits (filesystem subtype)
	cp 5;								// check if subtype is 5 (extended DOS)
	ld a, $30;							// filesystem code for DOS partition
	jr nz, finalize_partition_type;		// jump if not DOS extended partition
	ld a, 18h;							// filesystem code for FAT16 ($18)

;	// finalize partition type validation
finalize_partition_type:
	dec hl;								// return to original position in partition table
	ld c, a;							// store filesystem type in C register
	ld a, (hl);							// load partition type byte again
	and %11100000;						// mask upper 3 bits
	cp $60;								// check if type is $60
	jr nz, return_filesystem_type;		// jump if not $60 type
	ld c, $b0;							// set filesystem type to $b0 for type $60

;	// restore registers and return filesystem type
return_filesystem_type:
	ld a, c;							// get filesystem type from C register
	pop hl;								// restore HL from stack (BC value)
	ld c, l;							// store L in C register
	pop hl;								// restore original HL from stack
	ret;								// return to caller

;;	// find next available drive letter
find_next_drive_letter:
	ld c, a;							// save drive letter in C register
	call check_drive_letter_available;	// check if drive letter is available
	ld a, c;							// get drive letter back
	ret c;								// return if carry set (drive available)
	inc a;								// try next drive letter
	jr find_next_drive_letter;			// loop to check next letter

;	// check if drive letter is already in use
check_drive_letter_available:
	ld hl, $2d01;						// point to drive table (drive letter column)
	ld b, $0c;							// check up to 12 drive entries

;	// search loop through drive table
search_drive_table:
	ld a, (hl);							// load drive letter from table
	cp c;								// compare with requested drive letter
	ret z;								// return with Z flag set if match found (in use)
	inc hl;								// advance to next drive entry
	inc hl;								// (each entry is 3 bytes)
	inc hl;								// complete 3-byte entry traversal
	djnz search_drive_table;			// decrement B and loop if not zero
	scf;								// set carry flag (drive letter available)
	ret;								// return to caller

;	// configure drive in system drive table
configure_system_drive:
	push bc;							// save BC register on stack
	call validate_drive_id;				// validate drive configuration
	jr c, handle_drive_config_error;	// jump if error in validation
	ld iy, $2d00;						// point IY to start of drive table
	ld b, $0c;							// set counter for 12 drive slots

;	// search for matching drive in table
search_matching_drive:
	cp (iy + _flags);					// compare with drive flags in table entry
	jr z, check_drive_compatibility;	// jump if match found (drive already configured)
	call advance_drive_table_ptr;		// advance to next drive table entry
	djnz search_matching_drive;			// decrement counter and loop if more entries

;	// handle drive configuration error
handle_drive_config_error:
	pop bc;								// restore BC register from stack
	ld a, $0b;							// load error code $0b (drive configuration failed)
	scf;								// set carry flag to indicate error
	ret;								// return with error to caller

;	// drive already configured, check compatibility
check_drive_compatibility:
	ld a, (iy + _tv_flag);				// load TV flag from drive table entry
	and %00001111;						// mask lower 4 bits (compatibility flags)
	or a;								// test if any compatibility flags are set
	pop bc;								// restore BC register from stack
	ret;								// return to caller

;	// search for empty slot in drive table
find_empty_drive_slot:
	ld de, $2d00;						// point DE to start of drive table
	ld b, $0c;							// set counter for 12 drive slots

;	// loop through drive table entries
search_empty_slot_loop:
	ld a, (de);							// load drive ID from current table entry
	and a;								// check if slot is empty (drive ID = 0)
	ret z;								// return if empty slot found (Z flag set)
	inc de;								// advance to next drive table entry
	inc de;								// (each entry is 3 bytes)
	inc de;								// complete 3-byte entry traversal
	djnz search_empty_slot_loop;		// decrement counter and loop if more entries
	ld a, $0b;							// load error code $0b (no free drive slots)
	scf;								// set carry flag to indicate error
	ret;								// return with error

;	// advance IY pointer to next drive table entry
advance_drive_table_ptr:
	inc iy;								// advance IY pointer (each entry is 3 bytes)
	inc iy;								// second byte of 3-byte entry
	inc iy;								// third byte of 3-byte entry
	ret;								// return to caller

;	// validate and select drive identifier
validate_drive_id:
	ld b, a;							// save drive identifier in B register
	and a;								// check if drive identifier is zero
	scf;								// set carry flag (error condition)
	ret z;								// return with error if zero drive ID
	cp '*';								// use current drive?
	ld a, ($2d46);						// load current drive identifier
	ret z;								// return if '*' (use current drive)
	ld a, b;							// restore original drive identifier
	cp $24;								// check for '$' character (system drive)
	ld a, ($2d4a);						// load system drive identifier
	ret z;								// return if '$' (use system drive)
	ld a, b;							// restore original drive identifier
	or a;								// clear carry flag (no error)
	ret;								// return with validated drive ID
	add a, b;							// add B register to accumulator (unused code?)

;	dbtb "No system";					// Zeus - string with terminal bit 7 set
	str "No system";					// RASM - string with terminal bit 7 set

;	// 32-bit increment function (BCDE register pair)
inc_32bit:
	inc e;								// increment low byte (E register)
	ret nz;								// return if no overflow from E
	inc d;								// increment second byte (D register)
	ret nz;								// return if no overflow from D
	inc c;								// increment third byte (C register)
	ret nz;								// return if no overflow from C
	inc b;								// increment high byte (B register)
	ret;								// return after incrementing all bytes

;	// 32-bit decrement function with underflow check
dec_32bit:
	ld a, $ff;							// load $FF (underflow detection value)
	dec e;								// decrement low byte (E register)
	cp e;								// check if E underflowed to $FF
	ret nz;								// return if no underflow from E
	dec d;								// decrement second byte (D register)
	cp d;								// check if D underflowed to $FF
	ret nz;								// return if no underflow from D
	dec c;								// decrement third byte (C register)
	cp c;								// check if C underflowed to $FF
	ret nz;								// return if no underflow from C
	dec b;								// decrement high byte (B register)
	ret;								// return after decrementing all bytes

;	// 32-bit addition (BCDE = BCDE + HLDE)
add_32bit:
	add hl, de;							// add DE to HL (low 16 bits)
	ex de, hl;							// exchange DE and HL registers
	ret nc;								// return if no carry from low 16 bits
	inc bc;								// increment high 16 bits (BC) if carry
	ret;								// return to caller

;	// 32-bit subtraction (BCDE = BCDE - HLDE)
sub_32bit:
	or a;								// clear carry flag for subtraction
	ex de, hl;							// exchange DE and HL registers
	sbc hl, de;							// subtract DE from HL with carry
	ex de, hl;							// exchange back to restore register usage
	ret nc;								// return if no borrow from low 16 bits
	dec bc;								// decrement high 16 bits (BC) if borrow
	ret;								// return to caller
