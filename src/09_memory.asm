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


L0D05:
	ld a, 1;							// set error code to 1
	rst $20;							// call error handler

L0D08:
	cp $1b;								// check if command >= $1B
	jr c, L0D18;						// if less, branch to error handling
	push ix;							// save IX register
	pop hl;								// copy IX to HL
	call L098C;							// call system function dispatcher (06_disk.asm)
	push hl;							// save result
	pop ix;								// restore to IX
	jp L1FFA;							// unmap and return

L0D18:
	bit 7, (iy + _err_nr);				// check if error flag set

L0D1c:
	ld (err_nr), a;						// store error number
	ld hl, (ch_add);					// get current channel address
	ld (x_ptr), hl;						// save in x_ptr
	jp z, L0D72;						// if no error flag, jump to cleanup
	cp $0b;								// check for specific error codes
	jr z, L0D39;						// jump if error code 11
	cp $0e;								// check if error code 14
	jr z, L0D39;						// jump if error code 14
	cp $17;								// check if error code 23
	jr z, L0D39;						// jump if error code 23
	cp 1;								// check for error code 1
	jp nz, L0D72;						// if not 1, go to cleanup

L0D39:
	bit 5, (iy + 55);					// check system flag
	jp nz, L0D72;						// if set, go to cleanup
	ld de, (e_line);					// get end of program line
	and a;								// clear carry flag
	sbc hl, de;							// compare current position with end
	jr c, L0D52;						// if before end, branch
	rst $18;							// call BASIC ROM routine
	defw e_line_no;						// get line number at end
	ld hl, (ch_add);					// get current address
	dec hl;								// back up one position
	jr L0D5B;							// continue processing

L0D52:
	ld hl, (ppc);						// get program counter
	rst $18;							// call BASIC ROM routine
	defw line_addr;						// get address of line
	inc hl;								// skip line number
	inc hl;								// skip length
	inc hl;								// point to first statement

L0D5B:
	ld d, (iy + _subppc);				// get sub-statement counter
	ld e, 0;							// clear E
	rst $18;							// call BASIC ROM routine
	defw each_stmt;						// process each statement
	rst $30;							// report error
	inc bc;								// increment BC counter
	jr nz, $0d6a;						// loop if not zero
	rst $18;							// call BASIC ROM routine
	defw remove_fp;						// remove floating point number
	rst $18;							// call BASIC ROM routine
	defw set_work;						// set working area
	rst $30;							// report error
	ld (bc), a;							// store accumulator at BC address
	call L2014;							// call cleanup routine

L0D72:
	ld a, ($3df8);						// get saved divMMC page
	out (mmcram), a;					// set divMMC RAM page
	res 3, (iy + _tv_flag);				// clear TV flag bit 3
	ld hl, $58;							// set up for system exit
	rst $30;							// report error
	inc bc;								// increment BC
	jp z, L1FFB;						// if zero, unmap and exit
	ld a, (nmiadd);						// get NMI address
	and a;								// test if NMI routine set
	jp z, L1FFB;						// if not set, unmap and exit
	set 7, (iy + _err_nr);				// set error flag
	ld hl, $1b7d;						// NMI service routine address
	jp L1FFB;							// unmap and jump to NMI routine

L0D94:
	call L0DCF;							// call memory cleanup routine
	jp c, $20;							// jump if carry set
	call L0DEB;							// call additional cleanup
	ld hl, ($2e46);						// get memory pointer
	ld a, 2;							// select page 2
	out (mmcram), a;					// switch to divMMC page 2
	call L2000;							// call system initialization
	ld ($3de8), hl;						// save result pointer
	jp c, $20;							// jump if error occurred
	ld a, 0;							// select divMMC page 0
	out (mmcram), a;					// divMMC RAM page 0
	jp L24CD;							// jump to completion routine

L0DB4:
	push hl;							// save HL register
	call L0DCF;							// call memory cleanup routine
	pop hl;								// restore HL register
	jr c, L0DC2;						// jump to cleanup if error
	ld a, 2;							// select divMMC page 2
	out (mmcram), a;					// divMMC RAM page 2
	call L2000;							// call system routine

L0DC2:
	push af;							// save accumulator flags
	ld a, 0;							// select divMMC page 0
	out (mmcram), a;					// divMMC RAM page 0
	ld a, ($3df0);						// get saved page setting
	ld ($3df8), a;						// store in working area
	pop af;								// restore accumulator flags
	ret;								// return to caller

L0DCF:
	ld b, a;							// save file handle in B
	ld a, 2;							// select divMMC page 2
	out (mmcram), a;					// divMMC RAM page 0
	ld a, b;							// restore file handle
	push bc;							// save BC register
	ld hl, $2000;						// set read address ($2000)
	ld bc, $1c00;						// set read length (7168 bytes)
	rst $08;							// call system function
	defb f_read;						// read file function
	pop bc;								// restore BC register
	push af;							// save operation result
	ld a, b;							// get file handle
	rst $08;							// call system function
	defb f_close;						// close file function
	pop af;								// restore operation result
	ld b, a;							// save result in B
	ld a, 0;							// select divMMC page 0
	out (mmcram), a;					// divMMC RAM page 2
	ld a, b;							// restore B register
	ret;								// return to caller

