;	// UnoDOS 3 - An operating system for the divMMC SD card interface.
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

;	// RST08_handler
L0985:
	ex (sp), hl;						// swap HL with top of stack (return address)
	ld ($3dfa), a;						// save parameter in A
	ld a, (hl);							// retrieve syscall # from position
;										// after RST instruction
	inc hl;								// adjust return address
	ex (sp), hl;						// and saves it to the stack

L098C:
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
	call L09B4;							// dispatch system call
	pop ix;								// restore page settings
	ld iyl, a;							// save result
	ld a, ixl;							// get original page
	out (mmcram), a;					// Set divMMC RAM page
	ld a, iyl;							// restore result
	pop ix;								// restore registers
	pop iy;								// restore index register Y
	ret;								// return to caller

L09B4:
	ld a, iyl;							// get system call number
	push hl;							// save HL register
	ld hl, $091d;						// point to system call table (04_files.asm)
	add a, a;							// multiply by 2 (each entry is 2 bytes)
	add a, l;							// add to table base address
	ld l, a;							// store in L
	jr nc, L09C0;						// if no carry, continue
	inc h;								// handle carry to high byte

L09C0:
	ld a, (hl);							// get low byte of handler address
	inc hl;								// advance to high byte
	ld h, (hl);							// get high byte of handler address
	ld l, a;							// restore low byte
	ld a, ixh;							// get high byte of page settings
	ex (sp), hl;						// put handler address on stack, restore HL
	ret;								// "call" handler by returning to it

	ld a, $14;							// error code: invalid function number
	scf;								// set carry flag (error)
	ret;								// return with error

	ld a, ($2e32);						// get drive status
	or a;								// test if drive available
	ret;								// return with status

;	// default date and time for files
	ld de, $6000;						// 12:00:00
	ld bc, $28c2;						// June 2, 2000
	or a;								// clear carry flag (success)
	ret;								// return with default date/time

	and a;								// test if drive number is zero
	jr nz, L09E1;						// if not zero, set as current drive
	ld a, ($2d46);						// get current drive number
	or a;								// set flags based on drive
	ret;								// return with current drive

L09E1:
	cp '*';								// use current drive? test for file commands
	ret z;								// return if using current drive
	ld c, a;							// save drive number
	call L07C3;							// validate drive number (04_files.asm)
	ret c;								// return if invalid drive
	ld a, c;							// restore drive number
	ld ($2d46), a;						// set as current drive
	ret;								// return success

	and %11111000;						// mask to get file handle index
	ld c, a;							// save handle index
	ld hl, $2d00;						// point to file handle table
	ld b, $0c;							// 12 file handles to check

L09F6:
	ld a, (hl);							// get handle entry
	inc hl;								// advance to next field
	inc hl;								// (each entry is 3 bytes)
	inc hl;								// advance to third byte of entry
	and %11111000;						// mask handle index bits
	cp c;								// compare with target handle
	scf;								// set carry flag (assume found)
	ret z;								// return if handle found
	djnz L09F6;							// loop through all handles
	ld a, c;							// get handle number
	push bc;							// save BC register
	call L0A5F;							// call handle processing routine
	pop bc;								// restore BC register
	ret c;								// return if error occurred
	ld a, c;							// get handle number back
	jp L034C;							// jump to handle completion
	ld ($3df4), hl;						// save HL register 
	ld ($3dfa), a;						// save accumulator
	ld ($3df6), bc;						// save BC register
	ld ($3df2), de;						// save DE register
	call L0363;							// call system routine
	ccf;								// complement carry flag
	ld a, $1f;							// error code: invalid file handle
	ret c;								// return if error
	ld hl, $2d24;						// point to system data table

L0A24:
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
	call L0A36;							// get file system parameters
	pop hl;								// restore HL register
	ret nc;								// return if no error
	jr L0A24;							// handle error case

L0A36:
	ld hl, ($3df4);						// get file system base address
	ld bc, ($3df6);						// get file system parameters
	ld a, ($3dfa);						// get stored A register value
	push de;							// save DE register
	ld de, ($3df2);						// get additional parameters
	ret;								// return to caller

L0A46:
	push de;							// save DE register
	ld e, iyl;							// get system call number
	ld a, ixh;							// get high byte of page settings
	ld ixh, e;							// store call number in IXH
	pop de;								// restore DE register
	jp L0358;							// jump to handler (04_files.asm)
	call L0A46;							// invoke file operation
	ret c;								// return if error
	push hl;							// save HL register
	call L0A77;							// process operation result
	pop hl;								// restore HL register
	jr nc, L0A63;						// if no error, continue
	ld a, $0a;							// error code: access denied
	ret;								// return with error

L0A5F:
	call L0A46;							// invoke file operation
	ret c;								// return if error

L0A63:
	push hl;							// save HL register
	ld h, (iy + _err_sp);				// get error stack pointer
	ld a, ixh;							// get operation type
	add a, a;							// multiply by 2 for word index
	add a, (iy + _tv_flag);				// add base offset
	ld l, a;							// store in L
	jr nc, L0A71;						// if no carry, continue
	inc h;								// handle carry to high byte

L0A71:
	ld a, (hl);							// get low byte of handler address
	inc hl;								// advance to high byte
	ld h, (hl);							// get high byte of handler address
	ld l, a;							// restore low byte
	ex (sp), hl;						// put handler address on stack
	ret;								// "call" handler by returning to it

L0A77:
	push iy;							// save IY register
	pop hl;								// copy IY to HL
	and a;								// test A register
	jr nz, L0A84;						// if not zero, branch
	ld a, 7;							// offset to compare value
	add a, l;							// add to address
	ld l, a;							// store result
	jp L0694;							// jump to comparison routine (04_files.asm)

L0A84:
	add a, a;							// shift A left (multiply by 2)
	add a, a;							// shift A left again (multiply by 4)
	add a, a;							// shift A left again (multiply by 8)
	add a, l;							// add base address offset
	ld l, a;							// store calculated address in L
	push hl;							// save address pointer
	add a, 7;							// add 7 to address (offset calculation)
	ld l, a;							// store offset address in L
	call L0694;							// call comparison routine (04_files.asm)
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

	call L0B19;							// call file operation handler
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
	call L0B73;							// call handle completion routine
	pop af;								// restore saved handle number
	pop hl;								// restore HL register
	ret;								// return to caller

	call L0AD0;							// call handle validation routine
	ret c;								// return if validation failed
	ld a, ixh;							// get handle number for cleanup
	push af;							// save A register
	ld hl, $2cf0;						// point to file handle table
	call L0ACB;							// clear file handle entry
	pop af;								// restore A register
	ld hl, $2e22;						// point to drive table

L0ACB:
	add a, l;							// add offset to base address
	ld l, a;							// store result in L
	xor a;								// clear accumulator
	ld (hl), a;							// clear table entry
	ret;								// return to caller

L0AD0:
	push de;							// save DE register
	ld de, $2cf0;						// point to file handle table
	add a, e;							// add handle offset
	ld e, a;							// store in E
	ld a, (de);							// get file handle value
	and a;								// test if handle is valid
	ld d, a;							// save handle value
	ld a, ixh;							// get current operation
	ld ixh, d;							// store handle in IXH
	jr nz, L0B1E;						// if valid handle, continue
	ld a, $0d;							// error code: invalid handle

L0AE1:
	pop de;								// restore DE register
	scf;								// set carry flag (error)
	ret;								// return with error

	ld de, $2d01;						// point to file handle data (skip flags)
	ld b, $0c;							// 12 file handles maximum
	ld c, 0;							// counter for open files

L0AEB:
	ld a, (de);							// get file handle number
	and a;								// test if handle is in use
	jr z, L0AFF;						// skip if handle not in use
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

L0AFF:
	inc de;								// advance to next handle entry
	inc de;								// (each entry is 3 bytes)
	inc de;								// complete handle entry skip
	djnz L0AEB;							// loop through all handles
	ld a, c;							// get count of open files
	ret;								// return with count

	push iy;							// save IY register
	call L07C3;							// validate drive (04_files.asm)
	pop bc;								// restore BC register
	ret c;								// return if drive invalid
	ld a, (iy + _flags);				// get file flags
	ld b, a;							// save in B
	ld d, (iy + _err_nr);				// get error number
	ld e, (iy + _tv_flag);				// get TV flag
	ld iyl, c;							// save drive number

L0B19:
	call L04E7;							// initialize file handle (04_files.asm)
	ret c;								// return if initialization failed
	push de;							// save DE register

L0B1E:
	ld e, a;							// save handle number
	ld d, iyl;							// get saved parameter
	ld a, ixh;							// get operation type
	cp '*';								// use current drive?
	jr nz, L0B2A;						// if not, use specified drive
	ld a, ($2d46);						// get current drive number

L0B2A:
	call L07C3;							// validate drive (04_files.asm)
	jr c, L0AE1;						// return with error if invalid
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
	call L037E;							// call handler (04_files.asm)
	sub $18;							// subtract base offset (24) for handler index
	ld l, (iy + _tv_flag);				// get TV flag for address calculation
	ld h, (iy + _err_sp);				// get error stack pointer
	add a, a;							// multiply by 2 (word entries)
	add a, l;							// add to base address
	ld l, a;							// store calculated address
	jr nc, L0B5A;						// jump if no carry
	inc h;								// handle carry to high byte

L0B5A:
	ld a, (hl);							// get low byte of handler address
	inc hl;								// advance to high byte
	ld h, (hl);							// get high byte of handler address
	ld l, a;							// restore low byte
	call L0B6E;							// call memory restoration routine
	ld ixh, a;							// save result in IXH
	ld a, 0;							// clear accumulator
	out (mmcram), a;						// divMMC RAM page 0;
	ld a, ixh;							// restore result
	pop iy;								// restore IY register
	pop ix;								// restore IX register
	ret;								// return to caller

L0B6E:
	push hl;							// save handler address
	ld hl, ($3df4);						// restore saved HL register
	ret;								// return with HL restored

L0B73:
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

	and a;								// test file system type
	jr z, L0BB8;						// jump if standard file system
	ld b, a;							// save file system type
	call L0358;							// call validation routine (04_files.asm)
	jr nc, L0B8F;						// continue if valid

L0B8c:
	ld a, $0e;							// error code: invalid file system
	ret;								// return with error

L0B8F:
	ld c, a;							// save validation result
	ld a, b;							// restore file system type
	and %00000111;						// mask lower 3 bits
	cp c;								// compare with validation result
	jr c, L0B8c;						// return error if invalid
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
	jr nc, L0BAF;						// continue if no carry
	inc h;								// handle carry to high byte

L0BAF:
	ld bc, 4;							// copy 4 bytes
	ldir;								// block copy HL to DE
	ld c, 6;							// set result length
	jr L0BFE;							// jump to completion

L0BB8:
	push hl;							// save HL register
	ld b, 6;							// process 6 file systems
	ld hl, $2c00;						// point to file system table
	ld de, $2df2;						// point to output buffer

L0BC1:
	push bc;							// save loop counter
	push hl;							// save table pointer
	ld a, (hl);							// get file system entry
	inc hl;								// advance to next byte
	and a;								// test if entry exists
	jr z, L0BED;						// skip if no file system
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

L0BD5:
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
	jr c, L0BD5;						// loop if more entries

L0BED:
	pop hl;								// restore table pointer
	ld bc, $28;							// each entry is 40 bytes
	add hl, bc;							// advance to next file system entry
	pop bc;								// restore loop counter
	djnz L0BC1;							// loop through all file systems
	xor a;								// clear accumulator
	ld (de), a;							// terminate buffer with zero
	inc de;								// advance buffer pointer
	ld hl, $d20e;						// load end marker address
	add hl, de;							// calculate buffer end
	ld b, h;							// copy high byte to B
	ld c, l;							// copy low byte to C

L0BFE:
	ld hl, $2df2;						// point to data buffer
	pop de;								// restore DE register
	rst $30;							// call ROM routine (calculator)
	ld b, $b7;							// set operation code
	ret;								// return with result
