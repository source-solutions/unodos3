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

;	// automatically mapped in by the hardware after M1 when PC=$0000
	org $0000;							// UnoDOS entry point at system reset
start:
	di;									// interrupts off for initialization
	ld sp, $5e00;						// set stack pointer to $5e00 (below UDG area)
	jp L0101;							// jump to main initialization routine

;	// automatically mapped in by the hardware after M1 when PC=0008h
;	// main API entry point
	org $0008
restart_08:
	jp L0985;							// jump to main syscall dispatcher

L000B:
	ld hl, (ch_add);					// get pointer to next character in BASIC program
	jr L0015;							// continue to character handler

	org $0010
restart_10:
	jp L0845;							// jump to character print routine (RST $10 vector)

	org $0015
L0015:
	jp L0CD4;							// jump to character processing routine

	org $0018
restart_18:
	jp $0cbd;							// jump to ROM routine caller (RST $18 vector)

	org $001f
L001F:
restart_20 equ L001F + 1
	jr L004B;							// jump to next character routine
	ld e, l;							// save L register to E
	ld e, h;							// save H register to E (overwrites previous)
	ld (x_ptr), hl;						// save HL to ? marker pointer in BASIC
	jr L004D;							// continue processing

	org $0028
restart_28:
	push hl;							// save HL on stack
	ld hl, (mmc_sp);					// load MMC stack pointer
	ex (sp), hl;						// exchange with saved HL on stack
	ret;								// return to address from MMC stack

;	// auxiliary routines for internal UnoDOS business
	org $0030
restart_38:
	jr L0091;							// jump to internal vector table dispatcher 

cmd_folder:
	defm "/dos/"; 						// avoids clash with keywords in tokenizers

;	// automatically mapped in by the hardware after M1 when PC=$0038
	org $0038
maskint:
	jr L001F;							// jump to restart_20 handler (maskable interrupt)
	ld hl, $0039;						// load address after interrupt vector
	jp L1FF4;							// jump to interrupt cleanup routine

L0040:
	defm "sys", 0;						// system file extension
	defm "2026";						// year of release

L0048:
	ld a, (de);							// load byte pointed to by DE

L0049:
	ld bc, $fb00;						// load test pattern for keyboard scanning
	ret;								// return to caller

L004B equ L0049 + 2;					// points to RET instruction in L0049

L004D:
	jp L0C06;							// jump to character processing continuation

L0050:
	defb $0d, 0;						// carriage return followed by string terminator

verbose:
	ld hl, 20480;						// set HL to disable verbose printing (5000h)
	ld a, $fe;							// keyboard row for CAPS SHIFT key
	in a, (ula);						// read keyboard row via ULA port
	rra;								// rotate right to test CAPS SHIFT (bit 0)
	ret c;								// return if CAPS SHIFT not pressed
	ld hl, $3c00;						// enable verbose mode (point to font/messages)
	ret;								// return with verbose mode enabled

;	// automatically mapped in by the hardware after M1 when PC=$0066
	org $0066
NMI:
	ret;								// after triggering the first NMI, the CPU will
;										// still execute the instruction stored in the
;										// system ROM, which will be ignored (hence the
;										// NOP). The first actual instruction executed
;										// from the EEPROM is the one located at $0068.
;										// if a second NMI is triggered while still
;										// inside this NMI handler, the RET instruction
;										// will be executed, terminating it. So this is a
;										// mixed software-hardware solution to avoid
;										// nesting NMI calls.
	nop;								// padding/alignment instruction

	org $0068
L0068:
	ld (mmc_2), hl;						// save HL to MMC temporary storage
	ld hl, (mmc_3);						// load previous memory page configuration
	ld h, a;							// save A register in H
	ld a, 0;							// select divMMC page 0
	out (mmcram), a;					// switch to divMMC page 0, disable CONMEM/MAPRAM
	ld a, l;							// get memory page number from L
	ld (mmc_1), hl;						// save page configuration
	out (mmcram), a;					// switch to specified divMMC page
	ld a, 0;							// reset to page 0
	ld hl, (mmc_2);						// restore saved HL
	out (mmcram), a;					// switch back to divMMC page 0
	ld a, ($2e7b);						// load status byte
	jp L201E;							// jump to handler routine
	ei;									// enable interrupts
	push af;							// save accumulator and flags
	ld a, (mmc_1);						// get current MMC page
	out (mmcram), a;					// restore MMC memory configuration
	pop af;								// restore accumulator and flags
	jp L1FFA;							// jump to exit handler

L0091:
	ld (mmc_2), hl;						// save HL register to MMC storage
	pop hl;								// get return address from stack
	inc hl;								// point to byte after RST instruction
	push hl;							// put incremented address back on stack
	dec hl;								// point back to parameter byte
	push de;							// save DE register
	ld e, (hl);							// load vector number from parameter
	ld d, 0;							// clear upper byte (E contains vector index)
	ld hl, vector_tbl;					// point to start of vector table

L009F:
	add hl, de;							// add vector index to table base address
	add hl, de;							// add again (each vector entry is 2 bytes)
	ld e, (hl);							// load low byte of vector address
	inc hl;								// point to high byte
	ld h, (hl);							// load high byte of vector address
	ld l, e;							// complete the vector address in HL
	pop de;								// restore DE register
	push hl;							// push vector address onto stack
	ld hl, (mmc_2);						// restore original HL register
	ret;								// return - will jump to vector address
