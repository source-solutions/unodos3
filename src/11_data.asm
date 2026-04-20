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

	org $1b37
copyright:
	defb "UnoDOS 3.2.0 (Ram)       ", $0d, $0d;
	defb $7f, " 2026 Source Solutions, Inc.", $0d, 0

;	org $1b59
logo:
	ld hl, boot_icon;					// start of data
	ld a, 18;							// line count

;	org $1b5e
gfx_loop:
	ld e, (hl);							// get low byte of screen address to D
	inc hl;								// point to next byte
	ld d, (hl);							// get high byte of screen address to E
	inc hl;								// point to data
	ld bc, 4;							// 4 bytes to write
	ldir;								// copy (HL) to (DE) then INC HL; INC DE
	dec a;								// reduce count
	jr nz, gfx_loop;					// loop until done

;	org $1b6a
attributes:
	ld hl, 22862;						// start of attributes area
	ld de, 28;							// offset to next row (32-4)
	ld b, 4;							// 4 rows to color

;	org $1b72
outer_loop:
	ld a, 4;							// 4 characters wide

;	org $1b74
inner_loop:
	ld (hl), %01000100;					// bright green
	inc hl;								// next attribute position
	dec a;								// decrement counter
	jr nz, inner_loop;					// do four cells
	add hl, de;							// move to next row
	djnz outer_loop;					// do four rows
	ret;								// return to caller

;	org $1b7e
boot_icon:

;	// Chloe logo
	defw 20302;
	defb %00000000, %00000111, %11100000, %00000000;
	defw 18542;
	defb %00000000, %00011111, %11111000, %00000000;
	defw 18798;
	defb %00000000, %00111111, %00001100, %00000000;
	defw 19054;
	defb %00000000, %01111100, %00000000, %00000000;
	defw 19310;
	defb %00000000, %11111001, %11110000, %00000000;
	defw 19566;
	defb %00000000, %11110011, %11111100, %00000000;
	defw 19822;
	defb %00000001, %11110111, %11111110, %00000000;
	defw 20078;
	defb %00000001, %11110111, %00011110, %00000000;
	defw 20334;
	defb %00000001, %11110110, %00001111, %00000000;
	defw 18574;
	defb %00000001, %11110011, %01001111, %00000000;
	defw 18830;
	defb %00000001, %11110001, %11001111, %00000000;
	defw 19086;
	defb %00000001, %11111000, %00011111, %00000000;
	defw 19342;
	defb %00000000, %11111110, %01111111, %00000000;
	defw 19598;
	defb %00000000, %11111111, %11111110, %00000000;
	defw 19854;
	defb %00000000, %01111111, %11111110, %00000000;
	defw 20110;
	defb %00000000, %00111111, %11111100, %00000000;
	defw 20366;
	defb %00000000, %00011111, %11111000, %00000000;
	defw 18606;
	defb %00000000, %00000111, %11100000, %00000000;

;	org $1bea
boot_chime:
	ld hl, $fffe;						// L = AY-0, H = AY-1 / register port
	ld d, $bf;							// D = data port
	ld c, $fd;							// low byte of AY port
	ld ix, data;						// pointer to sound data
	
	ld b, h;							// register select
	out (c), l;							// select AY-0
	ld e, 0;							// initial register to write

	ld a, 11;							// number of registers to write
	call out_11;						// set 11 registers

	ld b, h;							// register select
	out (c), h;							// select AY-1
	ld e, 0;							// initial register to write
	
	ld a, 11;							// number of registers to write

;	org $1c06
out_11:
	ex af, af';							// store count
	ld a, (ix);							// data to A
	call out_pair;						// output register/data pair
	inc e;								// next register
	inc ix;								// next data entry
	ex af, af';							// restore count
	dec a; 								// reduce count
	and a;								// zero?
	jr nz, out_11;						// loop until done
	ret;								// end of subroutine

;	org $1c16
out_pair:
	ld b, h;							// set register port
	out (c), e;							// write register number to port
	ld b, d;							// set data port
	out (c), a;							// write register value to port
	ret;								// end of subroutine

	org $1c58
sys_filename:
	defm "unodos";						// UNODOS.SYS filename
	defb 0;								// null terminator
