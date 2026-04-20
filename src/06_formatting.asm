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

;	// called from dirs.io
;	// output a string of characters, zero terminated
;	org $083e
pr_str:
	ld a, (hl);							// get value at (HL)
	and a;								// test for zero
	ret z;								// return if zero
	rst $10;							// print_a
	inc hl;								// next address
	jr pr_str;							// repeat

;	// jumped to from RST10 - print a character in 'a'
L0845:
	push hl;							// save registers
	push de;							// save DE register
	push bc;							// save BC register
	push af;							// save accumulator and flags
	push iy;							// save index register Y
	ld iy, err_nr;						// set IY to system variables
	rst $18;							// call ROM routine
	defw print_a;						// print character in A register
	pop iy;								// restore registers
	pop af;								// restore accumulator and flags
	pop bc;								// restore BC register
	pop de;								// restore DE register
	pop hl;								// restore HL register
	ret;								// return to caller

L0859:
	ld c, $30;							// ASCII '0' (suppress leading zeros)
	ld h, 0;							// clear high byte of number
	jr L0873;							// jump to decimal conversion
	ld c, $20;							// ASCII space (don't suppress)

;	// called from dirs.io
L0861:
	ld de, $2710;						// 10000 (ten thousands place)
	call L087D;							// convert and print digit
	ld de, $03e8;						// 1000 (thousands place)

L086a:
	call L087D;							// convert and print digit
	ld de, $64;							// 100 (hundreds place)
	call L087D;							// convert and print digit

L0873:
	ld de, $0a;							// 10 (tens place)
	call L087D;							// convert and print digit
	ld e, 1;							// 1 (units place)
	ld c, $30;							// force units digit to print (no suppress)

L087D:
	ld a, $2f;							// start at ASCII '/' (one before '0')

L087F:
	inc a;								// increment to next digit character
	or a;								// clear carry flag
	sbc hl, de;							// subtract divisor from number
	jr nc, L087F;						// repeat while number >= divisor
	add hl, de;							// restore last valid remainder
	cp $3a;								// check if digit > '9'
	jr nc, L0894;						// branch if hex digit (A-F)
	cp $30;								// check if digit is '0'
	jr nz, L0896;						// if not zero, print it
	ld a, c;							// get suppression character
	or c;								// set flags (check if suppressing)
	call nz, restart_10;				// print suppression char if not zero
	ret;								// return without printing zero

L0894:
	add a, 7;							// convert to hex digit (A-F)

L0896:
	ld c, $30;							// stop suppressing zeros after first digit
	rst $10;							// print a character
	ret;								// return to caller

;	// called from dirs.io
L089A:
	ld a, e;							// check if size >= 65536 bytes
	or d;								// test high word (DE)
	jr nz, L08AD;						// if non-zero, use megabyte formatting
	ld e, h;							// shift HL left 8 bits (multiply by 256)
	ld h, l;							// for byte-level display
	ld l, 0;							// clear low byte
	sla h;								// shift left 1 more bit
	rl e;								// (total multiply by 512)
	rl d;								// to get proper scaling
	call L08D3;							// display with 'K' or 'B' suffix
	jr L08CB;							// add 'B' suffix if needed

L08AD:
	ld l, h;							// prepare 32-bit value for megabyte display
	ld h, e;							// shift right to get MB value
	ld e, d;							// move D to E for 32-bit value setup
	ld d, 0;							// clear D (now working with HLDE)
	srl e;								// shift right 3 bits
	rr h;								// (divide by 8)
	rr l;								// rotate right through carry (part of 32-bit divide)
	srl e;								// shift right logical
	rr h;								// rotate right through carry
	rr l;								// rotate right through carry
	srl e;								// second bit of divide by 8
	rr h;								// rotate right through carry
	rr l;								// rotate right through carry
	xor a;								// clear decimal fraction
	call L08DA;							// format and display with unit
	ld a, 'M';							// megabyte suffix
	rst $10;							// print a character

L08CB:
	ld a, b;							// get unit suffix from previous call
	cp 'B';								// check if already showing bytes
	ret z;								// return if bytes already shown
	ld a, 'B';							// byte suffix
	rst $10;							// print a character
	ret;								// return to caller

L08D3:
	xor a;								// clear decimal fraction
	call L08DA;							// format and display number with unit
	ld a, b;							// get unit character
	rst $10;							// print unit (K, M, etc.)
	ret;								// return to caller

L08DA:
	ld bc, $4200;						// B='B' (bytes), C=0 (no decimal)
	ex af, af';							// save decimal part
	ld a, d;							// check if >= 1024 (need K suffix)
	or e;								// OR with E to test if non-zero
	jr z, L08F0;						// if < 1024, display as-is
	call L0902;							// convert to KB with decimal
	ld a, e;							// check if >= 1024K (need M suffix)
	or e;								// test high part
	ld b, $4b;							// B='K' (kilobytes)
	jr z, L08F0;						// if < 1024K, display as KB
	call L0902;							// convert to MB with decimal
	ld b, $4d;							// B='M' (megabytes)

L08F0:
	push bc;							// save unit character and decimal
	ex af, af';							// restore decimal part
	ld c, a;							// save decimal in C
	call L0861;							// display integer part
	pop bc;								// restore unit and decimal
	ld a, c;							// get decimal part
	or c;								// test if zero
	ret z;								// return if no decimal part
	ld a, '.';							// decimal point
	rst $10;							// print a character
	ld a, $30;							// ASCII '0'
	add a, c;							// add decimal digit
	rst $10;							// print decimal digit
	ret;								// return to caller

L0902:
	xor a;								// clear accumulator
	ld l, h;							// start division by 1024

L0904:
	ld h, e;							// shift 32-bit value right 10 bits
	ld e, d;							// (divide by 1024)
	ld d, a;							// clear high byte of shifted value
	srl e;								// shift right 2 bits
	rr h;								// rotate right through carry
	rr l;								// rotate right through carry
	jr nc, L0911;						// if no carry, skip fraction adjust
	add a, 2;							// add to fraction accumulator

L0911:
	srl e;								// shift right 2 more bits
	rr h;								// rotate right through carry  
	rr l;								// rotate right through carry
	jr nc, L091B;						// if no carry, skip fraction adjust
	add a, 5;							// add to fraction accumulator

L091B:
	ld c, a;							// save decimal fraction
	ret;								// return with result

	inc c;								// increment counter
	ld a, (bc);							// get data from BC address
	ld d, c;							// copy C to D
	ld a, (bc);							// get data from BC address
	ld d, c;							// copy C to D
	ld a, (bc);							// get data from BC address
	ld e, a;							// copy A to E
	ld a, (bc);							// get data from BC address
	add a, e;							// add E to A
	dec bc;								// decrement BC counter
	xor %00001001;						// XOR with bit pattern for validation
	ret z;								// return if zero (validation passed)
	add hl, bc;							// add BC to HL
	ret z;								// return if result is zero
	add hl, bc;							// add BC to HL
	ret z;								// return if sum equals zero
	add hl, bc;							// add BC to HL again
	exx;								// exchange register sets
	add hl, bc;							// add BC to alternate HL
	call po, $0a;						// call if parity odd
	jr nz, L093D;						// jump if not zero
	jr nz, L0904;						// jump if not zero
	add hl, bc;							// add BC to HL
	pop de;								// restore DE register
	add hl, bc;							// add BC to HL
	dec a;								// decrement A register
	inc h;								// increment H register

L093D:
	and c;								// mask with C register value
	ld ($09c8), hl;						// store HL at memory location
	ret z;								// return if zero
	add hl, bc;							// add BC to HL (table offset)
	ret z;								// return if sum is zero
	add hl, bc;							// add BC to HL again
	ret z;								// return if result is zero
	add hl, bc;							// add BC to HL (advance table pointer)
	ret z;								// return if zero result
	add hl, bc;							// add BC to HL (continue scan)
	ret z;								// return if sum equals zero
	add hl, bc;							// add BC to HL (table navigation)
	ret z;								// return if result is zero
	add hl, bc;							// add BC to HL (advance pointer)
	inc (hl);							// increment value at HL
	rlca;								// rotate A left with carry
	ret m;								// return if result is negative
	ld b, $a2;							// load comparison value
	ld a, (bc);							// get data from BC address
	cp d;								// compare with D register
	ld a, (bc);							// read data from BC pointer
	ret nc;								// return if no carry (data valid)
	ld a, (bc);							// read next data byte
	ret nc;								// return if no carry
	ld a, (bc);							// read data value
	ret nc;								// return if carry clear
	ld a, (bc);							// get next byte
	ret nc;								// return if no carry
	ld a, (bc);							// read data from pointer
	ret nc;								// return if carry clear
	ld a, (bc);							// fetch data byte
	ret nc;								// return if no carry
	ld a, (bc);							// read value from BC
	ret nc;								// return if carry clear
	ld a, (bc);							// get data from pointer
	and d;								// mask with D register
	ld a, (bc);							// read next data value
	ret nc;								// return if no carry
	ld a, (bc);							// fetch byte from BC
	ret nc;								// return if carry clear
	ld a, (bc);							// read data from pointer
	ret nc;								// return if no carry
	ld a, (bc);							// get next data byte
	ret nc;								// return if carry clear
	ld a, (bc);							// read value from BC address
	add hl, de;							// add DE to HL (computation step)
	dec bc;								// decrement BC counter
	add hl, de;							// add DE to HL (accumulate result)
	dec bc;								// decrement BC counter
	add hl, de;							// add DE to HL (iterative calculation)
	dec bc;								// decrement BC counter
	add hl, de;							// add DE to HL (continue computation)
	dec bc;								// decrement BC counter
	add hl, de;							// add DE to HL (accumulate value)
	dec bc;								// decrement BC counter
	add hl, de;							// add DE to HL (calculation step)
	dec bc;								// decrement BC counter
	add hl, de;							// add DE to HL (iterative process)
	dec bc;								// decrement BC counter
	add hl, de;							// add DE to HL (computation loop)
	dec bc;								// decrement BC counter
	add hl, de;							// add DE to HL (accumulate result)
	dec bc;								// decrement BC counter
	add hl, de;							// add DE to HL (final calculation)
	dec bc;								// decrement BC counter
	ld b, $0b;							// load counter value 11
	add hl, de;							// add DE to HL (final step)
	dec bc;								// decrement BC counter 
