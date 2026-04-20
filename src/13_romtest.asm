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

;	org $1f3f
file_test:
	ld hl, msg_ok;						// point to OK message
	jp nc, L027A;						// jump if no error, display OK message
	ld hl, get_rom_byte;				// source: ROM byte getter routine
	ld de, $5b00;						// destination: buffer in high memory
	ld bc, 4;							// byte count (copy 4 bytes of routine)
	ldir;								// copy get_rom_byte routine to RAM
	ld bc, $7ffd;						// 128K memory management port
	xor a;								// LD A, 0 (select ROM 0)
	out (c), a;							// page in ROM 0 (SE BASIC)
	rst $18;							// call ROM routine safely
	defw $5b00;							// call copied routine (get byte at $3200)
	cp $21;								// test for LD HL instruction
;										// quick and dirty ROM detection for SE BASIC 4.2+
	jr nz, not_cordy;					// jump if not minimum SE BASIC compatibility
	rst $18;							// call ROM 0 routine
	defw $3200;							// load unodos.sys from SD to RAM
	call L00EF;							// restore ROM 1 (48K BASIC)
	ld hl, $c000;						// source: loaded system in high memory
	ld de, $2000;						// destination: divMMC window
	ld bc, lower_end-$2000;				// byte count for first part
	ldir;								// copy first part of system
	ld a, 1;							// select divMMC page 1
	out (mmcram), a;					// divMMC memory page 1
	ld de, $3000;						// destination for second part
	ld bc, upper_end-$3000;				// byte count for second part
	ldir;								// copy second part of system
	xor a;								// LD A, 0
	out (mmcram), a;					// divMMC page 0 (back to page 0)
	ret;								// return - system now loaded

;	org $1f7e
not_cordy:
	call L00EF;							// restore ROM 1 (48K BASIC)
	ld hl, msg_failed;					// point to failure message
	jp pr_str;							// display error message and exit

;	org $1f87
get_rom_byte:
	ld a, ($3200);						// read byte at $3200 in current ROM
	ret;								// return with byte in A register
