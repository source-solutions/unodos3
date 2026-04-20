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

;	// based on the Spectrum ROM's main_4 / main_g routine
L0C06:
	ld (err_nr), a;						// get error number
	res 5, (iy + _flags);				// no new key
	ld sp, (err_sp);					// error stack pointer to SP
	rst $18;							// call BASIC ROM routine
	defw syntax_z;						// check if in syntax check mode
	ld hl, $16c5;						// BASIC command loop address
	jp z, L1FFB;						// if syntax check, unmap and return to BASIC
	ld hl, 0;							// used to zero out system variables
	ld (iy + _flag_x), h;				// clear flag_x
	ld (iy + _x_ptr_h), h;				// clear x_ptr to hide error marker
	ld (defadd), hl;					// set no function to evaluate
	inc l;								// LD L, 1
	ld (strms_0), hl;					// keyboard stream
	rst $18;							// call BASIC ROM routine
	defw set_min;						// set minimum values
	ld a, (nmiadd);						// get NMI routine address
	and a;								// test if NMI routine is set
	jp nz, L24CD;						// if NMI set, handle differently
	res 5, (iy + _flag_x);				// no new key
	rst $18;							// call BASIC ROM routine
	defw cls_lower;						// clear lower screen
	set 5, (iy + _tv_flag);				// set TV flag bit 5
	res 3, (iy + _tv_flag);				// clear TV flag bit 3
	ld a, (err_nr);						// get error number
	and a;								// test if zero (no error)
	ld hl, ($3de8);						// get default message address
	jr z, L0C82;						// if no error, print default message
	ld b, a;							// save error number in B

L0C4d:
	ld a, ($3df9);						// get current divMMC page
	push af;							// save current page
	xor a;								// select page 0
	out (mmcram), a;					// divMMC memory page 0
	ld hl, $23bd;						// point to error message table
	push bc;							// save error number
	call L2357;							// find error message
	pop bc;								// restore error number
	jr nc, L0C78;						// if message found, use it
	cp $0c;								// check for specific error code
	jr nz, L0C67;						// if not, try generic error
	ld hl, $0caa;						// point to "Too many open files" message
	jr L0C82;							// print message

L0C67:
	ld a, b;							// get error number
	cp 1;								// check if error number is 1
	jr z, L0C78;						// if so, use BASIC ROM message
	ld hl, $0c9c;						// point to "UnoDOS error #" message
	call v_pr_msg;						// print error prefix
	ld l, b;							// put error number in L
	call L0859;							// print error number (05_api.asm)
	jr L0C85;							// restore page and exit

L0C78:
	ld hl, ($2017);						// get BASIC ROM error message table

L0C7B:
	bit 7, (hl);						// check if end of message
	inc hl;								// advance to next character
	jr z, L0C7B;						// continue until end of message
	djnz L0C7B;							// repeat for B messages

L0C82:
	call v_pr_msg;						// print error message

L0C85:
	pop af;								// restore divMMC page
	out (mmcram), a;					// set divMMC RAM page
	inc sp;								// adjust stack pointer (skip return address)
	inc sp;								// adjust stack pointer (complete skip)
	ld hl, $1349;						// BASIC editor address
	jp L1FFB;							// unmap and return to BASIC

;	// called from files.io
;	org $0c90
pr_msg:
	ld a, (hl);							// get character from message
	cp $7f;								// check if bit 7 set (end marker)
	push af;							// save character and flags
	and $7f;							// mask off bit 7
	rst $10;							// print a character
	pop af;								// restore character and flags
	ret nc;								// return if bit 7 not set (end of message)
	inc hl;								// advance to next character
	jr pr_msg;							// continue printing

;	dbtb "UnoDOS error #";				// Zeus - string with terminal bit 7 set
	str "UnoDOS error #";				// RASM - string with terminal bit 7 set

;	dbtb "Too many open files";			// Zeus - string with terminal bit 7 set
	str "Too many open files";			// RASM - string with terminal bit 7 set

;	// jumped from RST $18 (CALLBAS)
L0CBD:
	ld ($3df2),de;						// save DE as it will be used right now
	ex (sp),hl;							// HL = return address from the stack
	ld e, (hl);							// get 16-bit value
	inc hl;								// stored after the RST $18 instruction
	ld d, (hl);							// and put it in DE
	inc hl;								// while advancing the return address to skip
;										// this value
	ex (sp), hl;						// replace the new return address into the stack
	push hl;							// make room in the stack?
	ld hl, $3dfd;						// Automapper address (immediate mapping)
	ex (sp), hl;						// Store in the stack.
	push de;							// Store the address to call to in system ROM
;										// into the stack
	ld de, ($3df2);						// Restore saved DE
	jp L1FFA;							// Jump to auto-unmap address.


;	// The calling sequence is as follows: after this last jump, a RET instruction
;	// at $1ffa is executed. While it is being executed, the divMMC is unpaged, so
;	// the next instruction to fetch will have the system ROM paged in. The address
;	// fetched from the stack is the one pointing to the desired system ROM routine.
;	// After this routine ends, the return address fetched from the stack will point
;	// to 3DFD. This is a TR-DOS trap, which immediately pages divMMC again. $3dfd
;	// will have a RET instruction also, thus returning to the instruction past the
;	// immediate 16-bit value after the RST $18 instruction, thus resuming
;	// execution with divMMC paged in.

L0CD4:
	ld (x_ptr), hl;						// save HL in x_ptr system variable
	ld l, a;							// save A register in L
	ld a, ($3df9);						// get current divMMC page
	ld h, a;							// save in H
	xor a;								// clear accumulator
	out (mmcram), a;					// divMMC RAM page 0
	ld a, h;							// restore saved page
	ld ($3df8), a;						// save page number
	ld a, l;							// restore A register
	ld ($3dfa), a;						// save A register value
	pop hl;								// get return address
	rst $18;							// call BASIC ROM routine
	defw reentry;						// BASIC reentry point
	inc hl;								// adjust return address
	push hl;							// put back on stack
	cp $0ff;							// COPY command?
	jr nz, L0D08;						// if not, continue normally
	ld a, h;							// check address high byte
	cp '@';								// check if >= $4000
	jr c, L0D05;						// if < $4000, continue
	ld sp, (err_sp);					// reset error stack
	ld a, ($3df8);						// get saved page
	out (mmcram), a;					// set divMMC RAM page

L0CFF:
	ld hl, $16c5;						// BASIC command loop address
	jp L1FFB;							// unmap and return to BASIC
