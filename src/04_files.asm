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

;	// automatically mapped in by the hardware after M1 when PC=004C6h
;	// Automapped entry point for SAVE command
	org $04c6
L04C6:
	ld hl, $1f80;						// return address for ROM SAVE routine
	push hl;							// push return address onto stack
	ld b, a;							// save file type in B
	xor a;								// clear accumulator
	out (mmcram), a;					// select divMMC page 0
	ld a, ($2d4c);						// check SAVE intercept flag
	and a;								// test if SAVE interception enabled
	ld a, b;							// restore file type
	jr z, L04E1;						// if not enabled, use ROM SAVE
	push de;							// save filename pointer
	push bc;							// save file type and parameters
	call L23C4;							// call UnoDOS file save handler
	pop bc;								// restore parameters
	pop de;								// restore filename pointer
	pop hl;								// remove return address from stack
	ld a, b;							// get file type back
	jp nc, $2011;						// if successful, jump to completion routine

L04E1:
	ld hl, $04c9;						// address within SAVE trap area
	jp L1FF4;							// unmap divMMC and return to ROM SAVE

L04E7:
	push hl;							// save HL register
	push bc;							// save BC register
	ld hl, $2cf1;						// point to buffer area
	ld bc, $0f;							// search length (15 bytes)
	xor a;								// search for null terminator
	cpir;								// scan for first null byte
	ld a, $0c;							// error code: "invalid filename"
	scf;								// set carry flag (assume error)
	call z, L04FB;						// if null found, calculate length
	pop bc;								// restore BC register
	pop hl;								// restore HL register
	ret;								// return with result

L04FB:
	ld a, $0f;							// original search length
	sub c;								// subtract remaining count
	ret;								// return actual length in A

;	org $050d
L04FF:
	push af;							// save accumulator and flags
	push ix;							// save IX register
	push hl;							// save HL register
	pop ix;								// copy HL to IX
	ld hl, ($3df8);						// get divMMC page configuration
	ld c, mmcram;						// divMMC control port
	ld b, $7f;							// loop counter (127 bytes max)

;	org $051a
L050C:
	out (c), l;							// set divMMC page to L
	ld a, (ix + 0);						// get byte from source
	out (c), h;							// set divMMC page to H
	ld (de), a;							// store byte to destination
	inc ix;								// advance source pointer
	inc de;								// advance destination pointer
	and a;								// test if byte was null terminator
	jr z, L051C;						// if null, string copy complete
	djnz L050C;							// continue copying bytes

;	org $052a
L051C:
	push ix;							// save current IX pointer
	pop hl;								// copy IX to HL
	pop ix;								// restore original IX
	pop af;								// restore accumulator and flags
	ret;								// return to caller

;	org $0531
L0523:
	push bc;							// save BC register
	cp '*';								// check if current drive requested
	jr nz, L0538;						// if not '*', branch to display drive
	ld a, ($3df9);						// get current system page
	ld b, a;							// save in B
	ld a, 0;							// select page 0
	out (mmcram), a;					// switch to divMMC page 0
	ld a, ($2d46);						// get current drive number
	ld c, a;							// save drive number in C
	ld a, b;							// get system page back
	out (mmcram), a;					// restore original divMMC page
	ld a, c;							// get drive number back

;	org $05046
L0538:
	push af;							// save drive number/character
	and %11111000;						// mask to get drive number (upper 5 bits)
	srl a;								// shift right (divide by 2)
	srl a;								// shift right (divide by 4)
	srl a;								// shift right (divide by 8)
	or %01100000;						// convert to uppercase letter (A-Z)
	rst $10;							// print drive letter
	ld a, 'd';							// drive letter suffix
	rst $10;							// print 'd' (makes "Ad", "Bd", etc.)
	pop af;								// restore drive number
	push af;							// save it again
	and %00000111;						// get partition number (lower 3 bits)
	add a, $30;							// convert to ASCII digit
	rst $10;							// print partition number
	ld a, $3a;							// colon character
	rst $10;							// print colon (makes "Ad0:", "Bd1:", etc.)
	pop af;								// restore drive number
	pop bc;								// restore BC register
	ret;								// return to caller

;	// The divMMC automapper trap for the LOAD command
;	// This explains the redundant in a, (ula)
;	// automatically mapped in by the hardware after M1 when PC=$0562
	org $0562
L0562:
	in a, (ula);						// dummy read to satisfy hardware timing
	ld a, 0;							// select divMMC page 0
	out (mmcram), a;					// switch to divMMC page 0
	ld a, ($2d4b);						// check LOAD intercept flag
	and a;								// test if LOAD interception enabled
	jr nz, L0577;						// if enabled, handle UnoDOS LOAD

L056E:
	push hl;							// save HL register
	ld hl, $0564;						// return address within LOAD trap area
	in a, (ula);						// dummy read to satisfy hardware timing
	jp L1FF4;							// unmap divMMC and return to ROM LOAD

L0577:
	push de;							// save filename pointer
	call L23C4;							// call UnoDOS file load handler
	pop de;								// restore filename pointer
	jr c, L056E;						// if load failed, use ROM LOAD
	jp $200e;							// if successful, jump to completion routine

L0581:
	inc e;								// increment column (X coordinate)
	dec c;								// decrement character counter
	ret nz;								// return if more characters to process
	ld c, $10;							// reset character counter (16 chars per row)
	ld a, e;							// get current column
	sub c;								// subtract 16 to go back to start
	ld e, a;							// update column
	inc d;								// increment row (Y coordinate)
	ld a, d;							// get current row
	and %00000111;						// check if in character boundary (8 pixels)
	ret nz;								// return if not at character row boundary
	ld a, e;							// get current column
	add a, $20;							// advance to next character row (+32 bytes)
	ld e, a;							// update column
	ret c;								// return if no overflow
	ld a, d;							// get current row
	sub 8;								// go back 8 pixel rows
	ld d, a;							// update row
	ret;								// return to caller

L0598:
	ld a, (hl);							// get character from source string
	and a;								// test if null terminator
	ret z;								// return if end of string
	ld (de), a;							// copy character to destination
	inc hl;								// advance source pointer
	inc de;								// advance destination pointer
	jr L0598;							// continue copying string

;	org $05a0
vector_tbl:
	defw L06A9;							// vector 0: store 32-bit value (DEBC) at (HL)
	defw L0686;							// vector 1: load 32-bit value from (HL) to DEBC
	defw L05F3;							// vector 2: get next character from BASIC
	defw L06A5;							// vector 3: check BASIC syntax mode
	defw L064B;							// vector 4: copy null-terminated string with page switching
	defw L04FF;							// vector 5: copy string with page switching (127 char max)
	defw L0643;							// vector 6: copy data block with page switching (LDIR)
	defw L0619;							// vector 7: copy data block (LDIR or page switch)
	defw L0694;							// vector 8: compare 32-bit values (DEBC vs (HL))
	defw L0523;							// vector 9: display current drive (format "Ad0:")
	defw L05BE;							// vector 10: set DE to $2000, copy to page 4
	defw L05C3;							// vector 11: set HL to $2000, copy to page 4
	defw L05DD;							// vector 12: write data to file in page 4
	defw L068F;							// vector 13: test if 32-bit value DEBC is zero
	defw L0482;							// vector 14: format and display disk size

L05BE:
	ld de, $2000;						// set destination to start of divMMC window
	jr L05C8;							// continue to memory copy routine

L05C3:
	ld hl, $2000;						// set source to start of divMMC window
	jr L05C8;							// continue to memory copy routine

L05C8:
	call L05D6;							// check if extended memory available
	ret z;								// return if no extended memory
	ld a, 4;							// select divMMC page 4
	out (mmcram), a;					// switch to page 4
	ldir;								// copy BC bytes from HL to DE
	xor a;								// clear accumulator
	out (mmcram), a;					// switch back to page 0
	ret;								// return to caller

L05D6:
	ld a, ($2e8c);						// get memory configuration status
	cp $1c;								// compare with error indicator (28 decimal)
	scf;								// set carry flag (assume error)
	ret;								// return (Z set if memory error)

L05DD:
	ld e, a;							// save file handle in E
	call L05D6;							// check if extended memory available
	ret z;								// return if no extended memory
	ld a, 4;							// select divMMC page 4
	out (mmcram), a;					// switch to page 4
	ld a, e;							// restore file handle
	ld hl, $2000;						// source: start of divMMC window
	rst $08;							// call UnoDOS API
	defb f_write;						// write data to file
	ld e, a;							// save API result
	ld a, 0;							// select page 0
	out (mmcram), a;					// switch back to page 0
	ld a, e;							// restore API result
	ret;								// return to caller

L05F3:
	rst $18;							// call BASIC ROM routine
	defw next_char;						// get next character from BASIC program
	ret;								// return with character in A

L05F7:
	push ix;							// save IX register
	push hl;							// save HL register
	pop ix;								// copy HL to IX
	ld hl, ($3df8);						// get divMMC page configuration (L=source page, H=dest page)

L05FF:
	push bc;							// save byte counter
	ld c, mmcram;						// divMMC control port
	out (c), l;							// set source divMMC page
	ld a, (ix + 0);						// get byte from source
	out (c), h;							// set destination divMMC page
	ld (de), a;							// store byte to destination
	inc ix;								// advance source pointer
	inc de;								// advance destination pointer
	pop bc;								// restore byte counter
	dec bc;								// decrement byte count
	ld a, c;							// get low byte of count
	or b;								// OR with high byte
	jr nz, L05FF;						// continue if more bytes to copy
	push ix;							// save final IX position
	pop hl;								// copy IX to HL
	pop ix;								// restore original IX
	ret;								// return to caller

L0619:
	ld a, d;							// check destination address high byte
	cp '@';								// compare with $40 (16K boundary)
	jr c, L05F7;						// if below $4000, use page switching copy
	ldir;								// else use direct memory copy
	ret;								// return to caller

L0621:
	push ix;							// save IX register
	push hl;							// save HL register
	pop ix;								// copy HL to IX
	ld hl, ($3df8);						// get divMMC page configuration

L0629:
	push bc;							// save byte counter
	ld c, mmcram;						// divMMC control port
	ld a, (ix + 0);						// get byte from source
	out (c), l;							// set source divMMC page
	ld (de), a;							// store byte to destination
	out (c), h;							// set destination divMMC page
	inc ix;								// advance source pointer
	inc de;								// advance destination pointer
	pop bc;								// restore byte counter
	dec bc;								// decrement byte count
	ld a, c;							// get low byte of count
	or b;								// OR with high byte
	jr nz, L0629;						// continue if more bytes to copy
	push ix;							// save final IX position
	pop hl;								// copy IX to HL
	pop ix;								// restore original IX
	ret;								// return to caller

L0643:
	ld a, d;							// check destination address high byte
	cp '@';								// compare with $40 (16K boundary)
	jr c, L0621;						// if below $4000, use page switching copy
	ldir;								// else use direct memory copy
	ret;								// return to caller

L064B:
	push af;							// save accumulator and flags
	push ix;							// save IX register
	push hl;							// save HL register
	pop ix;								// copy HL to IX
	ld hl, ($3df8);						// get divMMC page configuration
	ld a, h;							// get destination page
	ld h, l;							// move source page to H
	ld l, a;							// move destination page to L
	ld c, mmcram;						// divMMC control port
	ld b, $7f;							// string length limit (127 bytes)

L065B:
	out (c), l;							// set destination divMMC page
	ld a, (ix + 0);						// get byte from source
	out (c), h;							// set source divMMC page
	ld (de), a;							// store byte to destination
	inc ix;								// advance source pointer
	inc de;								// advance destination pointer
	and a;								// test if byte was null terminator
	jr z, L066B;						// if null, string copy complete
	djnz L065B;							// continue copying (max 127 chars)

L066B:
	out (c), l;							// ensure destination page is selected
	jp L051C;							// jump to cleanup and return routine

L0670:
	defb 0;								// null terminator / padding byte

