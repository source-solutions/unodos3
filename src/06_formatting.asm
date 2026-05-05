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
;	// character print routine (RST $10 handler)
char_print_routine:
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

format_number_suppress_zeros:
	ld c, $30;							// ASCII '0' (suppress leading zeros)
	ld h, 0;							// clear high byte of number
	jr format_ones_remainder;			// jump to decimal conversion
	ld c, $20;							// ASCII space (don't suppress)

;	// called from dirs.io
format_decimal_10k:
	ld de, $2710;						// 10000 (ten thousands place)
	call convert_digit_to_ascii;		// convert and print digit
	ld de, $03e8;						// 1000 (thousands place)

;	// format hundreds and tens digits
format_hundreds_tens:
	call convert_digit_to_ascii;		// convert and print thousands digit
	ld de, $64;							// 100 (hundreds place)
	call convert_digit_to_ascii;		// convert and print hundreds digit

;	// format ones and remainder
format_ones_remainder:
	ld de, $0a;							// 10 (tens place)
	call convert_digit_to_ascii;		// convert and print tens digit
	ld e, 1;							// 1 (ones place)
	ld c, $30;							// ASCII '0' for digit conversion

;	// divide number by place value and convert to ASCII
convert_digit_to_ascii:
	ld a, $2f;							// start with ASCII '/' (one before '0')

;	// division loop to count digits
division_loop:
	inc a;								// increment ASCII digit counter
	or a;								// clear carry flag for subtraction
	sbc hl, de;							// subtract to count how many times DE fits in HL
	jr nc, division_loop;				// continue loop if result is positive
	add hl, de;							// restore HL by adding back DE
	cp $3a;								// check if digit is above '9' (hexadecimal)
	jr nc, convert_hex_digit;			// jump if hex digit (A-F)
	cp $30;								// check if digit is '0'
	jr nz, print_digit;					// jump if not zero
	ld a, c;							// load leading zero flag
	or c;								// test if we should suppress leading zeros
	call nz, restart_10;				// print character if not suppressing
	ret;								// return from function

;	// convert hex digit A-F by adding 7 to make it ASCII
convert_hex_digit:
	add a, 7;							// add 7 to convert hex digits A-F to ASCII

;	// print the digit and set leading zero flag
print_digit:
	ld c, $30;							// set flag to enable printing of subsequent zeros
	rst $10;							// print a character
	ret;								// return from function

;	// format file size for display - called from dirs.io
format_file_size:
	ld a, e;							// check high word of file size
	or d;								// test if file size > 64KB
	jr nz, handle_large_files;			// jump if large file (use MB/KB units)
	ld e, h;							// shift 16-bit size into DE
	ld h, l;							// move low byte to H
	ld l, 0;							// clear L (multiply by 256)
	sla h;								// shift left to multiply by 2
	rl e;								// rotate carry into E
	rl d;								// rotate carry into D
	call format_number_with_units;		// format as bytes
	jr add_bytes_suffix;				// jump to add 'B' suffix

;	// handle large files - convert to MB
handle_large_files:
	ld l, h;							// shift 32-bit value right 8 bits
	ld h, e;							// move bytes for division
	ld e, d;							// continue shifting
	ld d, 0;							// clear top byte
	srl e;								// divide by 8 (shift right 3 times)
	rr h;								// rotate right through H
	rr l;								// rotate right through L
	srl e;								// second division by 2
	rr h;								// rotate right through H
	rr l;								// rotate right through L
	srl e;								// third division by 2 (total /8)
	rr h;								// rotate right through H
	rr l;								// rotate right through L
	xor a;								// clear A for decimal places
	call format_size_with_units;		// format number with units
	ld a, 'M';							// load 'M' for megabytes
	rst $10;							// print a character

;	// add 'B' suffix for bytes if not already present
add_bytes_suffix:
	ld a, b;							// check unit suffix character
	cp 'B';								// compare with 'B' ($42)
	ret z;								// return if already 'B'
	ld a, 'B';							// load 'B' character
	rst $10;							// print a character
	ret;								// return from function

;	// format number and add unit suffix
format_number_with_units:
	xor a;								// clear A (no decimal places)
	call format_size_with_units;		// format the number
	ld a, b;							// load unit character
	rst $10;							// print a character
	ret;								// return from function

;	// format file size with appropriate units (B/KB/MB)
format_size_with_units:
	ld bc, $4200;						// B=$42 ('B' for bytes), C=0 (decimal places)
	ex af, af';';						// save decimal places count in A'
	ld a, d;							// check if size >= 1024 (test high word)
	or e;								// combine DE to test for non-zero
	jr z, format_with_decimal;			// jump if size < 1024 (use bytes)
	call divide_by_1024;				// divide by 1024 for KB
	ld a, e;							// check if result >= 1024
	or e;								// test if we need MB
	ld b, $4b;							// set unit to 'K' (kilobytes)
	jr z, format_with_decimal;			// jump if size < 1MB
	call divide_by_1024;				// divide by 1024 again for MB
	ld b, $4d;							// set unit to 'M' (megabytes)

;	// format number with decimal places and print
format_with_decimal:
	push bc;							// save unit character and decimal count
	ex af, af';';						// restore decimal places from A'
	ld c, a;							// store decimal places count in C
	call format_decimal_10k;			// format and print the number
	pop bc;								// restore unit character
	ld a, c;							// check decimal places count
	or c;								// test if we have decimal places
	ret z;								// return if no decimal places
	ld a, '.';							// load decimal point character
	rst $10;							// print a character
	ld a, $30;							// load ASCII '0'
	add a, c;							// add decimal digit
	rst $10;							// print a character
	ret;								// return from function

;	// divide 24-bit number by 1024 (shift right 10 bits)
divide_by_1024:
	xor a;								// clear A (will hold remainder bits)
	ld l, h;							// start shifting: L = H

;	// division loop - shift right 10 times total (divide by 1024)
shift_division_loop:
	ld h, e;							// H = E (continue shifting)
	ld e, d;							// E = D
	ld d, a;							// D = A (remainder accumulator)
	srl e;								// shift E right 1 bit
	rr h;								// rotate H right (carry from E)
	rr l;								// rotate L right (carry from H)
	jr nc, continue_division;			// jump if no remainder
	add a, 2;							// add 2 to remainder (bit weight)

;	// continue division by 1024 - second shift
continue_division:
	srl e;								// shift E right another bit
	rr h;								// rotate H right (carry from E)
	rr l;								// rotate L right (carry from H)
	jr nc, store_decimal_remainder;		// jump if no remainder
	add a, 5;							// add 5 to remainder (bit weight)

;	// store decimal remainder and return
store_decimal_remainder:
	ld c, a;							// store decimal remainder in C
	ret;								// return with result in HLD, remainder in C
