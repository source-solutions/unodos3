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

	org $0686
L0686:
	ld e, (hl);							// load low byte of 32-bit value
	inc hl;								// advance to next byte
	ld d, (hl);							// load second byte
	inc hl;								// advance to next byte
	ld c, (hl);							// load third byte
	inc hl;								// advance to next byte
	ld b, (hl);							// load high byte of 32-bit value
	inc hl;								// advance pointer past the value
	ret;								// return with 32-bit value in BCDE

L068F:
	ld a, c;							// get byte C
	or b;								// OR with byte B
	or e;								// OR with byte E
	or d;								// OR with byte D
	ret;								// return with Z flag set if BCDE is zero

L0694:
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

L06A5:
	rst $18;							// call BASIC ROM routine
	defw syntax_z;						// check if in syntax checking mode
	ret;								// return with Z flag set if syntax mode

L06A9:
	ld (hl), e;							// store low byte of 32-bit value
	inc hl;								// advance to next location
	ld (hl), d;							// store second byte
	inc hl;								// advance to next location
	ld (hl), c;							// store third byte
	inc hl;								// advance to next location
	ld (hl), b;							// store high byte of 32-bit value
	inc hl;								// advance pointer past stored value
	ret;								// return to caller