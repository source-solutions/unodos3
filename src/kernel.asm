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

;	// Zeus directives (http://www.desdes.com/products/oldfiles)
;	zoWarnFlow = false;					// prevent pseudo op-codes triggering warnings.
;	output_bin "../bin/unodos.rom",0,$2000
;	output_bin "../bin/unodos0.sys",$2000,lower_end-$2000
;	output_bin "../bin/unodos1.sys",$3000,upper_end-$3000

;	// RASM directives
	save "../bin/unodos.rom", 0, $2000
	save "../bin/unodos0.sys", $2000, lower_end-$2000
	save "../bin/unodos1.sys", $3000, upper_end-$3000

	include "os.inc"
	include "io.inc"

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

sys_folder:
	defm "/dos";						// system folder
	defb 0;								// end marker

mute_psg:
	ld hl, $fe07;						// H = AY chip 0 ($FE), L = Volume register 7
	ld de, $bfff;						// D = data port ($BF), E = register port + mute ($FF)
	ld c, $fd;							// C = low byte of AY I/O port ($xxFD)
	call mute_ay;						// mute AY chip 0
	inc h;								// H = $FF for AY chip 1

mute_ay:
	ld b, e;							// B = AY register port ($FF)
	out (c), h;							// select AY chip (254 for AY-0, 255 for AY-1)
	out (c), l;							// select volume register (7)
	ld b, d;							// B = AY data port ($BF)
	out (c), e;							// write mute value (0) to volume register
	ret;								// return to caller

;	// select BASIC ROM on 128K machines
	org $00ef
L00EF:
	ld a, 4;							// set bit 2: ROM1 selected, normal memory mode
	ld bc, $1ffd;						// +3 memory control port
	out (c), a;							// configure +3 memory (%00000100)
	ld a, $10;							// bit 4 set: ROM1, normal video, RAM bank 0
	ld b, $7f;							// 128K memory control port
	out (c), a;							// configure 128K memory (%00010000)
	ret;								// BASIC ROM now selected

	nop;								// padding instruction
	nop;								// padding instruction  
	ld e, d;							// instruction in padding space
	dec a;								// instruction in padding space 

;	// Jumped to from RST0
L0101:
	xor a;								// clear accumulator (A = 0)
	ld bc, $2a30;						// load delay counter (10800 decimal)
	out (mmcram), a;					// select divMMC page 0, disable CONMEM/MAPRAM

L0107:
	dec bc;								// decrement delay counter
	nop;								// timing delay
	ld a, c;							// get low byte of counter
	or b;								// OR with high byte to test for zero
	jr nz, L0107;						// loop until counter reaches zero (bus settle delay)
	call L00EF;							// force BASIC ROM selection on 128K machines
	ld a, $0e;							// load status byte
	ld ($201f), a;						// store at divMMC status location
	ld a, ($2d42);						// check initialization marker
	cp $aa;								// compare with expected value (170 decimal)
	jr nz, L0124;						// if not initialized, jump to full init
	ld a, $7f;							// keyboard row for SPACE key
	in a, (ula);						// read keyboard row
	rra;								// rotate right to test SPACE in bit 0
	jp c, L0251;						// if SPACE not pressed, exit to BASIC
	;									// which sets HL to 1 then exits

;	// start of full initialization - clear screen to black
L0124:
	xor a;								// clear accumulator (A = 0)
	out (ula), a;						// set border to black
	out ($ff), a;						// set low resolution mode on Pentagon/Scorpion
	ld bc, $1eff;						// byte count: 7935 bytes
	ld hl, $5eff;						// source address (top of screen area)
	ld de, $5efe;						// destination address (one byte lower)
	ld (hl), a;							// set first byte to zero
	lddr;								// clear screen memory $4000-$5AFF (backwards fill)
	call boot_chime;					// play startup sound
	call logo;							// display UnoDOS logo

; Check this divMMC device has more than 32K (4 pages) of memory
	ld a, 4;							// start memory test from page 4

;	org $013b
L013D:
	out (mmcram), a;					// select divMMC memory page A
	ld bc, $1fff;						// byte count: 8191 bytes
	ld hl, $2000;						// source address start of divMMC window
	ld de, $2001;						// destination address (one byte higher)
	ld (hl), l;							// set first byte to $00 (L register value)
	ldir;								// clear 8K page from $2000-$3FFF
	ld (mmc_3), a;						// store current page number in MMC variable
	ld hl, $3dfd;						// address near top of page
	ld (hl), $c9;						// place RET instruction at $3DFD
	ld hl, $3d30;						// another strategic address
	ld (hl), $c9;						// place RET instruction at $3D30
	dec a;								// decrement to next page (page = page - 1)
	cp $ff;								// check if we've wrapped to 255 (tested page 0)
	jr nz, L013D;						// if not, continue testing next page
	ld a, 4;							// select page 4 for writability test
	out (mmcram), a;					// switch back to page 4
	ld hl, $2000;						// point to start of divMMC window
	ld a, (hl);							// read current value
	inc (hl);							// increment the value
	cp (hl);							// compare original with incremented
	jr nz, L016B;						// if different, memory is writable
	ld l, $1c;							// else set L to $1C (error indicator)

;	org $0169
L016B:
	xor a;								// clear accumulator (A = 0)
	out (mmcram), a;					// switch to divMMC page 0, disable special modes
	ld a, $aa;							// set initialization marker
	ld ($2d42), a;						// store marker to indicate UnoDOS initialized
	ld a, l;							// get memory test result from L register
	ld ($2e8c), a;						// store memory configuration result
	ld hl, chans;						// point to channel table in system variables
	ld (curchl), hl;					// set current channel pointer
	ld hl, print_out;					// point to screen print routine in ROM
	ld (chans), hl;						// set channel #0 to screen output
	ld hl, $4000;						// start of screen memory
	ld (df_cc), hl;						// set display file cursor position
	ld hl, $1821;						// H=24 (row), L=33 (column) for AT 0,0
	ld (s_posn), hl;					// set screen position variables
	ld a, 7;							// white ink on black paper (normal attributes)
	ld (attr_t), a;						// set temporary screen attributes
	call verbose;						// check for CAPS SHIFT (verbose boot mode)
	ld (chars), hl;						// set character set pointer (from verbose call)
	ld hl, copyright;					// point to copyright message string
	call pr_str;						// print copyright message
	call L031C;							// setup system vectors and initial configuration
	call L03A7;							// additional system initialization
	ld a, $3e;							// LD A,n instruction opcode
	ld hl, $2007;						// code generation area
	ld (hl), a;							// store LD A,n instruction
	ld a, $14;							// value to load (20 decimal)
	inc l;								// point to next byte
	ld (hl), a;							// store the value
	ld a, $37;							// SCF instruction opcode (set carry flag)
	inc l;								// point to next byte
	ld (hl), a;							// store SCF instruction
	ld a, $0c9;							// RET instruction opcode
	inc l;								// point to next byte
	ld (L2014), a;						// store RET at jump target
	ld (hl), a;							// store RET in code area
	ld hl, $c937;						// pack: RET + SCF instructions
	ld ($2515), hl;						// store at address $2515
	ld (L2357), hl;						// store at address L2357
	ld hl, $0812;						// pack: EX AF,AF' + LD DE,nn high byte
	ld ($2017), hl;						// store at address $2017
	ld hl, $0c3f1;						// pack: some instructions (needs verification)
	ld ($201e), hl;						// store code at address $201E
	ld hl, $1ff7;						// address near end of divMMC window
	ld ($2020), hl;						// store address reference
	ld a, $c9;							// RET instruction opcode
	ld ($2f00), a;						// place RET at $2F00
	ld hl, L0050;						// point to "detecting devices" message
	call pr_str;						// print device detection message
	ld a, $80;							// device ID or test parameter
	call L027D;							// device detection/initialization routine
	ld a, $88;							// second device ID or test parameter
	call L027D;							// detect/initialize second device
	ld hl, L0670;						// point to "mounting drives" message
	call pr_str;						// print drive mounting message
	call L06E1;							// mount drives and setup filesystem
	ld a, ($2d01);						// load drive configuration
	ld ($2d4a), a;						// store in alternative location
	ld ($2d46), a;						// store in another configuration location
	ld hl, sys_filename;				// point to "unodos" system filename
	call L0257;							// setup filename for loading
	call L02C5;							// attempt to load main system file
	push af;							// save load result flags
	call file_test;						// test if system file loaded correctly
	pop af;								// restore load result flags
	jr c, L0232;						// if load failed, skip to user input wait
	ld hl, msg_nmi;						// point to NMI system filename
	call L0257;							// setup NMI filename
	call L02B3;							// attempt to load NMI handler
	call L0272;							// show OK or ERROR for NMI system file
	jr nz, L0232;						// if NMI load failed, skip to user input
	ld a, ($2e8c);						// check memory configuration result
	and a;								// test if zero (indicates error)
	jr nz, L0232;						// if memory error, skip to user input
	ld hl, msg_betadisk;				// point to "betadisk" system filename
	call L0257;							// setup betadisk filename
	call L02A1;							// attempt to load betadisk system
	push af;							// save load result
	call nc, L03C4;						// if load successful, initialize betadisk
	pop af;								// restore load result
	call L0272;							// show OK or ERROR for betadisk load

;	org $0242
L0232:
	ld a, $7f;							// keyboard row for SPACE key
	in a, (ula);						// read keyboard row
	rra;								// rotate right to test SPACE key in bit 0
	jr c, L0248;						// if SPACE not pressed, continue to exit
	jr L0232;							// loop waiting for SPACE release

	org $0248
L0248:
	call mute_psg;						// turn off PSG sound generators

	org $024b
L024B:
	ld de, $07d0;						// load delay value (2000 decimal)
	call L0297;							// delay routine for system settling

	org $0251
L0251:
	ld hl, $0001;						// BASIC ROM entry point after initialization
	jp L1FFB;							// unmap divMMC and jump into BASIC ROM

L0257:
	call L02EF;							// construct full system file path with extension
	push hl;							// save path pointer
	ld de, 5;							// offset to filename portion (skip "/dos/")
	add hl, de;							// point to filename part
	call pr_str;						// print filename to screen
	pop hl;								// restore full path pointer
	ret;								// return with full path in HL

	org $0272
L0272:
	ld hl, msg_ok;						// point to "OK" message
	jr nc, L027A;						// jump if no carry (success)
	ld hl, msg_failed;					// else point to error/failed message

L027A:
	jp pr_str;							// print the success/error message

L027D:
	ld de, $2df2;						// point to device info buffer
	rst $08;							// call UnoDOS API
	defb disk_status;					// get disk/device status
	ret c;								// return if API call failed
	and %11111000;						// mask out lower 3 bits (keep device type info)
	rst $30;							// internal UnoDOS call
	ld c, $3e;							// [unclear purpose - may be command code]
	ld a, ($3ed7);						// load status from this address
	jr nz, $0264;						// jump to $0264 if non-zero
	ld hl, $2df2;						// point back to device info buffer
	call pr_str;						// print device information
	ld a, $0d;							// carriage return character
	rst $10;							// print newline
	ret;								// return to caller

	org $0297
L0297:
	ld b, $ff;							// delay loop counter (255 iterations)

L0299:
	djnz L0299;							// inner delay loop (256 iterations)
	dec de;								// decrement outer delay counter
	ld a, e;							// get low byte
	or d;								// OR with high byte to test for zero
	jr nz, L0297;						// repeat until DE reaches zero
	ret;								// return after delay complete

L02A1:
	call L02E8;							// open file for reading
	ret c;								// return if file open failed
	push af;							// save file handle
	ld a, 3;							// select divMMC page 3
	out (mmcram), a;					// switch to divMMC page 3
	pop af;								// restore file handle
	ld hl, $2000;						// destination: start of divMMC window
	ld bc, $1c00;						// byte count: 7168 bytes (7KB)
	jr L02BD;							// continue to file read routine

L02B3:
	call L02E8;							// open file for reading
	ret c;								// return if file open failed
	ld hl, $2f00;						// destination: $2F00 (NMI handler area)
	ld bc, $0e00;						// byte count: 3584 bytes

L02BD:
	ld e, a;							// save file handle in E
	push de;							// save file handle on stack
	rst $08;							// call UnoDOS API
	defb f_read;						// read from file
	pop de;								// restore file handle
	ld a, e;							// get file handle back
	jr L02E1;							// continue to file close routine

L02C5:
	call L02E8;							// open main system file for reading
	ret c;								// return if file open failed
	push af;							// save file handle
	ld hl, $2000;						// destination: start of divMMC window
	ld bc, lower_end-$2000;				// byte count: size of lower part
	rst $08;							// call UnoDOS API
	defb f_read;						// read lower part of system file
	ld a, 1;							// select divMMC page 1
	out (mmcram), a;					// switch to divMMC page 1
	pop af;								// restore file handle
	push af;							// save file handle again
	ld hl, $3000;						// destination: upper part area
	ld bc, upper_end-$3000;				// byte count: size of upper part
	rst $08;							// call UnoDOS API
	defb f_read;						// read upper part of system file
	pop af;								// restore file handle

L02E1:
	rst $08;							// call UnoDOS API
	defb f_close;						// close the file
	ld a, 0;							// select divMMC page 0
	out (mmcram), a;					// switch back to page 0
	ret;								// return to caller

L02E8:
	ld a, $24;							// file mode: read-only
	ld b, 1;							// drive number (drive 1)
	rst $08;							// call UnoDOS API
	defb f_open;						// open file for reading
	ret;								// return with file handle in A or carry set if error

L02EF:
	call L0305;							// construct base path ("/dos/[filename].")
	ld hl, L0040;						// point to "sys" extension string

L02F5:
	call L0598;							// copy extension string to path
	ld (de), a;							// store null terminator
	ld hl, $2dce;						// return pointer to completed path
	ret;								// return with full path in HL

L02FD:
	call L0305;							// construct base path ("/dos/[filename].")
	ld hl, L0040;						// point to "sys" extension string
	jr L02F5;							// continue to add extension

L0305:
	push hl;							// save filename pointer
	ld de, $2dce;						// destination buffer for full path
	ld hl, sys_folder;					// source: "/dos" string
	call L0598;							// copy "/dos" to buffer
	ld a, $2f;							// forward slash character
	ld (de), a;							// add slash after "/dos"
	inc de;								// advance destination pointer
	pop hl;								// restore filename pointer
	call L0598;							// copy filename to buffer
	ld a, $2e;							// dot character
	ld (de), a;							// add dot before extension
	inc de;								// advance destination pointer
	ret;								// return with DE pointing after dot

L031C:
	ld hl, $2d24;						// point to vector table location
	ld de, $1c6d;						// first vector address
	ld (hl), e;							// store low byte of vector
	inc hl;								// advance to next byte
	ld (hl), d;							// store high byte of vector
	inc hl;								// advance to next vector slot
	ld de, $2515;						// second vector address
	ld (hl), e;							// store low byte of second vector
	inc hl;								// advance to next byte
	ld (hl), d;							// store high byte of second vector
	inc hl;								// advance to next vector slot
	ret;								// vector table setup complete

L032E:
	ld c, a;							// save file handle in C
	ld a, ($2d47);						// get current file handle count
	cp 6;								// compare with maximum (6 handles)
	scf;								// set carry flag (error condition)
	ret z;								// return if maximum handles reached
	ld hl, $2c00;						// point to file handle table start

L0339:
	ld a, (hl);							// get file handle entry
	and a;								// test if slot is free (zero)
	jr z, L0343;						// jump if free slot found
	ld a, $28;							// file handle entry size (40 bytes)
	add a, l;							// advance to next handle slot
	ld l, a;							// update pointer
	jr L0339;							// check next slot

L0343:
	ld (hl), c;							// store file handle in free slot
	push hl;							// save handle slot address
	pop iy;								// copy to IY register
	ld hl, $2d47;						// point to file handle counter
	inc (hl);							// increment active handle count
	ret;								// return with handle slot in IY

L034C:
	call L0363;							// find file handle slot
	ret c;								// return if handle not found
	xor a;								// clear accumulator
	ld (hl), a;							// clear the file handle slot
	ld hl, $2d47;						// point to file handle counter
	dec (hl);							// decrement active handle count
	or a;								// clear carry flag (success)
	ret;								// return with success

L0358:
	push hl;							// save HL register
	push bc;							// save BC register
	call L0363;							// find file handle slot
	push hl;							// save handle slot address
	pop iy;								// copy to IY register
	pop bc;								// restore BC register
	pop hl;								// restore HL register
	ret;								// return with handle slot in IY

L0363:
	ld c, a;							// save target handle in C
	ld b, 6;							// maximum number of file handles
	ld hl, $2c00;						// point to start of file handle table

L0369:
	ld a, (hl);							// get file handle from current slot
	xor c;								// compare with target handle
	and %11111000;						// mask out lower 3 bits
	jr z, L0377;						// jump if match found
	ld a, $28;							// handle slot size (40 bytes)
	add a, l;							// advance to next slot
	ld l, a;							// update pointer
	djnz L0369;							// continue search
	scf;								// set carry flag (handle not found)
	ret;								// return with error

L0377:
	ld a, (hl);							// get the found handle
	cp c;								// compare with target
	ret c;								// return with carry if less than target
	ld a, c;							// get target handle
	and %00000111;						// keep only lower 3 bits
	ret;								// return with partial handle info

L037E:
	push hl;							// save HL register
	ld hl, ($3dfb);						// get stored address from divMMC area
	ex (sp), hl;						// exchange with saved HL on stack
	ret;								// return with original HL restored

	push de;							// save DE register
	push hl;							// save HL register
	ld a, iyl;							// get low byte of IY (file handle)
	ld ixl, a;							// store in IX low byte
	ld de, $2400;						// base address for screen calculations
	ld h, 0;							// clear H register
	ld a, ixh;							// get high byte of IX
	add a, a;							// multiply by 2
	add a, a;							// multiply by 4
	add a, a;							// multiply by 8
	add a, a;							// multiply by 16
	add a, a;							// multiply by 32
	ld l, a;							// store result in L
	rl h;								// rotate carry into H
	add hl, de;							// add base address
	ld a, iyh;							// get high byte of IY
	call L03D4;							// call address lookup function
	ld a, ixl;							// get low byte of IX back

L03A1:
	push hl;							// save HL register
	pop ix;								// copy to IX register
	pop hl;								// restore original HL
	pop de;								// restore original DE
	ret;								// return to caller

L03A7:
	ld hl, $2d2a;						// point to system table entry
	ld de, $0df1;						// address parameter
	ld bc, $0384;						// size/count parameter  
	ld a, 1;							// select divMMC page 1
	ld (hl), a;							// store page number
	inc hl;								// advance to next field
	ld (hl), e;							// store low byte of address
	inc hl;								// advance to next field
	ld (hl), d;							// store high byte of address
	inc hl;								// advance to next field
	ld (hl), $ff;						// store end marker
	out (mmcram), a;					// switch to divMMC page 1
	ld ($3dfb), bc;						// store BC in divMMC area
	xor a;								// clear accumulator
	out (mmcram), a;					// switch back to divMMC page 0
	ret;								// return to caller

L03C4:
	nop;								// padding/alignment
	nop;								// padding/alignment
	nop;								// padding/alignment
	nop;								// padding/alignment
	nop;								// padding/alignment
	ld a, 3;							// select divMMC page 3
	out (mmcram), a;					// switch to divMMC page 3
	call L2000;							// call loaded code at $2000
	xor a;								// clear accumulator
	out (mmcram), a;					// switch back to divMMC page 0
	ret;								// return to caller

L03D4:
	push bc;							// save BC register
	ld iy, $2000;						// point IY to divMMC window start
	ld b, 4;							// loop counter for 4 iterations

L03DB:
	cp (iy + _err_nr);					// compare with error number field
	jr z, L03E7;						// jump if match found
	inc iyh;							// advance to next page
	djnz L03DB;							// continue loop
	pop bc;								// restore BC register
	scf;								// set carry flag (not found)
	ret;								// return with error

L03E7:
	or a;								// clear carry flag (success)
	pop bc;								// restore BC register
	ret;								// return with success

L03EA:
	ld b, a;							// save request parameter in B
	ld hl, $2d2a;						// point to system table

L03EE:
	call L04E7;							// get/prepare system data
	ld ixh, a;							// store result in IX high
	ld a, (hl);							// get table entry
	cp 255;								// check for end marker
	jr z, L040B;						// jump if end of table
	ld e, a;							// save entry in E
	push de;							// save DE register
	inc hl;								// advance to address field
	ld e, (hl);							// get low byte of address
	inc hl;								// advance to high byte
	ld d, (hl);							// get high byte of address 
	inc hl;								// advance to next entry
	push hl;							// save table pointer
	push bc;							// save request parameter
	call L040F;							// process the entry
	pop bc;								// restore request parameter
	pop hl;								// restore table pointer
	pop ix;								// restore IX from DE
	ret nc;								// return if operation successful
	jr L03EE;							// continue with next table entry

L040B:
	ld a, $1e;							// error code: "invalid" (30 decimal)
	scf;								// set carry flag (error)
	ret;								// return with error

L040F:
	push hl;							// save HL register
	push hl;							// save HL register again
	out (mmcram), a;					// switch to specified divMMC page
	ld ($3df8), a;						// store current divMMC page number
	ld h, d;							// copy address to HL
	ld l, e;							// complete address transfer
	call L037E;							// call address handling routine
	jp L0B5A;							// jump to main processing routine

L041E:
	ld hl, $2df2;						// point to drive info buffer
	push hl;							// save buffer pointer
	rst $08;							// call UnoDOS API
	defb m_driveinfo;					// get drive information
	pop hl;								// restore buffer pointer
	ld b, a;							// save number of drives in B
	and a;								// test if zero drives
	ret z;								// return if no drives found

L0428:
	push bc;							// save drive counter
	call L0430;							// print information for one drive
	pop bc;								// restore drive counter
	djnz L0428;							// repeat for all drives
	ret;								// return when all drives printed

L0430:
	ld a, (hl);							// get drive type/status
	rst $30;							// internal UnoDOS call
	add hl, bc;							// advance past some fields
	ld a, ' ';							// space character
	rst $10;							// print space
	inc hl;								// advance pointer
	inc hl;								// advance pointer
	inc hl;								// advance pointer
	rst $30;							// internal UnoDOS call
	ld bc, $e5c5;						// load search pattern/instruction
	ld bc, $ff;							// byte count for string search
	xor a;								// search for null terminator
	cpir;								// scan for end of string
	call L0458;							// print string with comma
	ld b, h;							// save H to B
	ld c, l;							// save L to C
	pop hl;								// restore original HL
	call L0458;							// print another string with comma
	ld l, e;							// setup for next operation
	ld h, d;							// complete address setup
	pop de;								// restore DE
	push bc;							// save BC for later
	call L089A;							// call formatting/display routine
	ld a, $0d;							// carriage return character
	rst $10;							// print newline
	pop hl;								// restore pointer for next drive
	ret;								// return to drive loop

L0458:
	call pr_str;						// print string pointed to by HL
	inc hl;								// advance past string
	ld a, ',';							// comma character
	rst $10;							// print comma
	ld a, ' ';							// space character
	rst $10;							// print space
	ret;								// return to caller

	org $0482
L0482:
	ld l, a;							// save original value in L
	and %11100000;						// mask to get upper 3 bits
	ret z;								// return if zero (no size to display)
	ld e, $30;							// default base character '0'
	ld c, $66;							// default unit character 'f' (for bytes)
	cp ' ';								// compare with space character ($20)
	jr z, L049E;						// jump if 32 (32 bytes)
	ld c, $76;							// unit character 'v' for 'K'
	cp $60;								// compare with $60 (96 = 3 * 32K)
	jr z, L049E;						// jump if kilobyte size
	ld e, $61;							// base character 'a' for 'M'
	cp $80;								// compare with $80 (128 = 4 * 32M)
	ld c, $73;							// unit character 's' for 'M'
	jr z, L049E;						// jump if megabyte size
	ld c, $68;							// unit character 'h' for 'G'

L049E:
	ld a, c;							// get unit character
	rst $10;							// print unit character
	ld a, 'd';							// print 'd' character
	rst $10;							// (makes 'Kd', 'Md', 'Gd' etc.)
	ld a, l;							// get original value back
	rrca;								// rotate right to get bits 7-2
	rrca;								// rotate right again
	rrca;								// rotate right again  
	and %00000011;						// keep only bottom 2 bits
	add a, e;							// add base character
	rst $10;							// print tens digit
	ld a, l;							// get original value back
	and %00000111;						// keep bottom 3 bits for units
	ret z;								// return if zero (don't print units)
	add a, 30h;							// convert to ASCII digit
	rst $10;							// print units digit
	ret;								// return to caller

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

;	org $06b2
msg_betadisk:
	defm "betadisk", 0;					// null ternimated message

;	org $06bb
msg_failed:
	defb $17, $0c, $01;					// TAB 24
	defm ": failed";					// 
	defb $0d, 0;						// carriage return, null terminator

;	org $06c8
msg_ok:
	defb $17, $0c, $01;					// TAB 27
	defm ": ok";						// 
	defb $0d, 0;						// carriage return, null terminator

;	org $06d1
msg_nmi:
	defm "nmi", 0;						// null ternimated message

	org $06e1
L06E1:
	ld hl, $2df2;						// 
	push hl;							// 
	rst $08;							// 
	defb disk_info;						// 
	pop hl;								// 

L06E8:
	ld a, (hl);							// 
	and a;								// 
	ret z;								// 
	push hl;							// 
	ld bc, 0;							// 
	rst $08;							// 
	defb f_mount;						// 
	pop hl;								// 
	ld de, 6;							// 
	add hl, de;							// 
	jr L06E8;							// 
	call L0714;							// 
	scf;								// 
	ret z;								// 
	ld l, a;							// 
	push hl;							// 
	call L0B19;							// 
	pop hl;								// 
	ret c;								// 
	ld a, l;							// 
	call L07C3;							// 
	ret c;								// 
	xor a;								// 
	push iy;							// 
	pop hl;								// 
	ld (hl), a;							// 
	inc hl;								// 
	ld (hl), a;							// 
	inc hl;								// 
	ld (hl), a;							// 
	or a;								// 
	ret;								// 

L0714:
	push bc;							// 
	ld hl, $2cf0;						// 
	ld bc, $0f;							// 
	cpir;								// 
	pop bc;								// 
	ret nz;								// 
	ld a, $1d;							// 
	ret;								// 

L0722:
	ld hl, $2d00;						// 
	ld b, $0c;							// 

L0727:
	cp (hl);							// 
	jr z, L0730;						// 
	inc hl;								// 
	inc hl;								// 
	inc hl;								// 
	djnz L0727;							// 
	ret;								// 

L0730:
	ld a, $1f;							// 
	scf;								// 
	ret;								// 

	ld l, a;							// 
	push hl;							// 
	push bc;							// 
	call L0722;							// 
	pop bc;								// 
	pop hl;								// 
	ret c;								// 
	ld a, c;							// 
	and a;								// 
	jr z, L0748;						// 
	call L07C3;							// 
	ld a, $0b;							// 
	ccf;								// 
	ret c;								// 

L0748:
	inc c;								// 
	ld a, l;							// 
	ld hl, $2df2;						// 
	push bc;							// 
	push hl;							// 
	rst $08;							// 
	defb disk_info;						// 
	pop hl;								// 
	jr nc, L0756;						// 
	pop bc;								// 
	ret;								// 

L0756:
	call L07E6;							// 
	pop bc;								// 
	ld a, (hl);							// 
	call L077F;							// 
	dec c;								// 
	jr nz, L0769;						// 
	push hl;							// 
	push bc;							// 
	call L07AB;							// 
	pop bc;								// 
	pop hl;								// 
	ld c, a;							// 

L0769:
	ex de, hl;							// 
	ld a, (de);							// 
	push hl;							// 
	push bc;							// 
	call L03EA;							// 
	pop bc;								// 
	pop hl;								// 
	ret c;								// 
	ld (hl), a;							// 
	inc hl;								// 
	ld (hl), c;							// 
	inc hl;								// 
	ld a, b;							// 
	or ixl;								// 
	or %10000000;						// 
	ld (hl), a;							// 
	ld a, c;							// 
	ret;								// 

L077F:
	push hl;							// 
	push bc;							// 
	inc hl;								// 
	and %11100000;						// 
	cp $80;								// 
	jr nz, L079B;						// 
	ld a, (hl);							// 
	bit 7, a;							// 
	ld a, $40;							// 
	jr z, L079B;						// 
	ld b, $40;							// 
	and %00000111;						// 
	cp 5;								// 
	ld a, $30;							// 
	jr nz, L079B;						// 
	ld a, 18h;							// 

L079B:
	dec hl;								// 
	ld c, a;							// 
	ld a, (hl);							// 
	and %11100000;						// 
	cp $60;								// '£'
	jr nz, L07A6;						// 
	ld c, $b0;							// 

L07A6:
	ld a, c;							// 
	pop hl;								// 
	ld c, l;							// 
	pop hl;								// 
	ret;								// 

L07AB:
	ld c, a;							// 
	call L07B4;							// 
	ld a, c;							// 
	ret c;								// 
	inc a;								// 
	jr L07AB;							// 

L07B4:
	ld hl, $2d01;						// 
	ld b, $0c;							// 

L07B9:
	ld a, (hl);							// 
	cp c;								// 
	ret z;								// 
	inc hl;								// 
	inc hl;								// 
	inc hl;								// 
	djnz L07B9;							// 
	scf;								// 
	ret;								// 

L07C3:
	push bc;							// 
	call L07FE;							// 
	jr c, L07D9;						// 
	ld iy, $2d00;						// 
	ld b, $0c;							// 

L07CF:
	cp (iy + _flags);					// 
	jr z, L07DE;						// 
	call L07F7;							// 
	djnz L07CF;							// 

L07D9:
	pop bc;								// 
	ld a, $0b;							// 
	scf;								// 
	ret;								// 

L07DE:
	ld a, (iy + _tv_flag);				// 
	and %00001111;						// 
	or a;								// 
	pop bc;								// 
	ret;								// 

L07E6:
	ld de, $2d00;						// 
	ld b, $0c;							// 

L07EB:
	ld a, (de);							// 
	and a;								// 
	ret z;								// 
	inc de;								// 
	inc de;								// 
	inc de;								// 
	djnz L07EB;							// 
	ld a, $0b;							// 
	scf;								// 
	ret;								// 

L07F7:
	inc iy;								// 
	inc iy;								// 
	inc iy;								// 
	ret;								// 

L07FE:
	ld b, a;							// 
	and a;								// 
	scf;								// 
	ret z;								// 
	cp '*';								// use current drive?
	ld a, ($2d46);						// 
	ret z;								// 
	ld a, b;							// 
	cp $24;								// 
	ld a, ($2d4a);						// 
	ret z;								// 
	ld a, b;							// 
	or a;								// 
	ret;								// 
	add a, b;							// 

;	dbtb "No system";					// Zeus - string with terminal bit 7 set
	str "No system";					// RASM - string with terminal bit 7 set

L081C:
	inc e;								// 
	ret nz;								// 
	inc d;								// 
	ret nz;								// 
	inc c;								// 
	ret nz;								// 
	inc b;								// 
	ret;								// 

L0824:
	ld a, $ff;							// 
	dec e;								// 
	cp e;								// 
	ret nz;								// 
	dec d;								// 
	cp d;								// 
	ret nz;								// 
	dec c;								// 
	cp c;								// 
	ret nz;								// 
	dec b;								// 
	ret;								// 

L0831:
	add hl, de;							// 
	ex de, hl;							// 
	ret nc;								// 
	inc bc;								// 
	ret;								// 

L0836:
	or a;								// 
	ex de, hl;							// 
	sbc hl, de;							// 
	ex de, hl;							// 
	ret nc;								// 
	dec bc;								// 
	ret;								// 

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
	call L087D;							// 
	ld de, $64;							// 
	call L087D;							// 

L0873:
	ld de, $0a;							// 
	call L087D;							// 
	ld e, 1;							// 
	ld c, $30;							// 

L087D:
	ld a, $2f;							// 

L087F:
	inc a;								// 
	or a;								// 
	sbc hl, de;							// 
	jr nc, L087F;						// 
	add hl, de;							// 
	cp $3a;								// 
	jr nc, L0894;						// 
	cp $30;								// 
	jr nz, L0896;						// 
	ld a, c;							// 
	or c;								// 
	call nz, restart_10;				// 
	ret;								// 

L0894:
	add a, 7;							// 

L0896:
	ld c, $30;							// 
	rst $10;							// print a character
	ret;								// 

;	// called from dirs.io
L089A:
	ld a, e;							// 
	or d;								// 
	jr nz, L08AD;						// 
	ld e, h;							// 
	ld h, l;							// 
	ld l, 0;							// 
	sla h;								// 
	rl e;								// 
	rl d;								// 
	call L08D3;							// 
	jr L08CB;							// 

L08AD:
	ld l, h;							// 
	ld h, e;							// 
	ld e, d;							// 
	ld d, 0;							// 
	srl e;								// 
	rr h;								// 
	rr l;								// 
	srl e;								// 
	rr h;								// 
	rr l;								// 
	srl e;								// 
	rr h;								// 
	rr l;								// 
	xor a;								// 
	call L08DA;							// 
	ld a, 'M';							// 
	rst $10;							// print a character

L08CB:
	ld a, b;							// 
	cp 'B';								// $42
	ret z;								// 
	ld a, 'B';							// 
	rst $10;							// print a character
	ret;								// 

L08D3:
	xor a;								// 
	call L08DA;							// 
	ld a, b;							// 
	rst $10;							// print a character
	ret;								// 

L08DA:
	ld bc, $4200;						// 
	ex af, af';';						// 
	ld a, d;							// 
	or e;								// 
	jr z, L08F0;						// 
	call L0902;							// 
	ld a, e;							// 
	or e;								// 
	ld b, $4b;							// 
	jr z, L08F0;						// 
	call L0902;							// 
	ld b, $4d;							// 

L08F0:
	push bc;							// 
	ex af, af';';						// 
	ld c, a;							// 
	call L0861;							// 
	pop bc;								// 
	ld a, c;							// 
	or c;								// 
	ret z;								// 
	ld a, '.';							// 
	rst $10;							// print a character
	ld a, $30;							// 
	add a, c;							// 
	rst $10;							// print a character
	ret;								// 

L0902:
	xor a;								// 
	ld l, h;							// 

L0904:
	ld h, e;							// 
	ld e, d;							// 
	ld d, a;							// 
	srl e;								// 
	rr h;								// 
	rr l;								// 
	jr nc, L0911;						// 
	add a, 2;							// 

L0911:
	srl e;								// 
	rr h;								// 
	rr l;								// 
	jr nc, L091B;						// 
	add a, 5;							// 

L091B:
	ld c, a;							// 
	ret;								// 

	inc c;								// 
	ld a, (bc);							// 
	ld d, c;							// 
	ld a, (bc);							// 
	ld d, c;							// 
	ld a, (bc);							// 
	ld e, a;							// 
	ld a, (bc);							// 
	add a, e;							// 
	dec bc;								// 
	xor %00001001;						// 
	ret z;								// 
	add hl, bc;							// 
	ret z;								// 
	add hl, bc;							// 
	ret z;								// 
	add hl, bc;							// 
	exx;								// 
	add hl, bc;							// 
	call po, $0a;						// 
	jr nz, L093D;						// 
	jr nz, L0904;						// 
	add hl, bc;							// 
	pop de;								// 
	add hl, bc;							// 
	dec a;								// 
	inc h;								// 

L093D:
	and c;								// 
	ld ($09c8), hl;						// 
	ret z;								// 
	add hl, bc;							// 
	ret z;								// 
	add hl, bc;							// 
	ret z;								// 
	add hl, bc;							// 
	ret z;								// 
	add hl, bc;							// 
	ret z;								// 
	add hl, bc;							// 
	ret z;								// 
	add hl, bc;							// 
	inc (hl);							// 
	rlca;								// 
	ret m;								// 
	ld b, $a2;							// 
	ld a, (bc);							// 
	cp d;								// 
	ld a, (bc);							// 
	ret nc;								// 
	ld a, (bc);							// 
	ret nc;								// 
	ld a, (bc);							// 
	ret nc;								// 
	ld a, (bc);							// 
	ret nc;								// 
	ld a, (bc);							// 
	ret nc;								// 
	ld a, (bc);							// 
	ret nc;								// 
	ld a, (bc);							// 
	ret nc;								// 
	ld a, (bc);							// 
	and d;								// 
	ld a, (bc);							// 
	ret nc;								// 
	ld a, (bc);							// 
	ret nc;								// 
	ld a, (bc);							// 
	ret nc;								// 
	ld a, (bc);							// 
	ret nc;								// 
	ld a, (bc);							// 
	add hl, de;							// 
	dec bc;								// 
	add hl, de;							// 
	dec bc;								// 
	add hl, de;							// 
	dec bc;								// 
	add hl, de;							// 
	dec bc;								// 
	add hl, de;							// 
	dec bc;								// 
	add hl, de;							// 
	dec bc;								// 
	add hl, de;							// 
	dec bc;								// 
	add hl, de;							// 
	dec bc;								// 
	add hl, de;							// 
	dec bc;								// 
	add hl, de;							// 
	dec bc;								// 
	ld b, $0b;							// 
	add hl, de;							// 
	dec bc;								// 

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

L0DEB:;									// called from dirs.io
	ld a, 2;							// screen
	rst $18;							// call BASIC ROM routine
	defw chan_open;						// open channel function
	ret;								// return to caller

L0DF1:
	ld d, (hl);							// load D from address pointed by HL
	ld c, $b2;							// load immediate value $B2 into C
	ld sp, $16de;						// set stack pointer to $16DE
	adc a, a;							// add A to itself with carry
	ld d, $97;							// load immediate value $97 into D
	ld d, $de;							// load immediate value $DE into D
	jr L0E40;							// jump to L0E40
	ld sp, $369a;						// set stack pointer to $369A
	add a, $19;							// add immediate value $19 to A
	rst $38;							// restart at vector $38
	dec (hl);							// decrement value at address HL
	ld l, (hl);							// load L with value at address HL
	ld (hl), $d2;						// store $D2 at address HL
	inc sp;								// increment stack pointer
	ld (bc), a;							// store A at address BC
	inc (hl);							// increment value at address HL
	ld b, a;							// copy A to B register
	dec (hl);							// decrement value at address HL
	sub b;								// subtract B from A
	ld (hl), $94;						// store $94 at address HL
	ld (hl), $77;						// store $77 at address HL
	ld d, $ad;							// load immediate value $AD into D
	inc sp;								// increment stack pointer
	ei;									// interrupts on
	ld ($354c), a;						// store A at address $354C
	ex (sp), hl;						// exchange HL with top of stack
	dec (hl);							// decrement value at address HL
	sbc a, l;							// subtract L from A with carry
	dec (hl);							// decrement value at address HL
	ld a, ($a936);						// load A from address $A936
	ld ($31c4), a;						// store A at address $31C4
	dec bc;								// decrement BC register pair
	dec (hl);							// decrement value at address HL
	ld hl, ($290e);						// load HL from address $290E
	ld c, $c9;							// load immediate value $C9 into C
	ex de, hl;							// exchange DE and HL
	ld a, b;							// copy B to A register
	call L0E4C;							// call function at L0E4C
	ld a, d;							// copy D to A register
	call L0E4C;							// call function at L0E4C
	ld a, e;							// copy E to A register
	call L0E4C;							// call function at L0E4C
	push iy;							// save IY on stack
	pop hl;								// restore into HL
	ld l, $18;							// load immediate value $18 into L
	ld bc, 4;							// load immediate value 4 into BC
	rst $30;							// restart at vector $30

L0E40:
	ld b, $2e;							// load immediate value $2E into B
	inc b;								// increment B register
	rst $30;							// restart at vector $30
	inc b;								// increment B register
	ld l, $0c;							// load immediate value $0C into L
	rst $30;							// restart at vector $30
	inc b;								// increment B register
	ex de, hl;							// exchange DE and HL
	or a;								// clear carry flag (OR A with itself)
	ret;								// return to caller

L0E4C:
	ld hl, $3dfa;						// load HL with address $3DFA
	ld (hl), a;							// store A at address HL
	ld bc, 1;							// load BC with value 1
	rst $30;							// restart at vector $30
	ld b, $c9;							// load B with immediate value $C9
	push bc;							// save BC on stack
	call L0E6D;							// call function at L0E6D
	pop bc;								// restore BC from stack
	ret c;								// return if carry set
	push hl;							// save HL on stack
	pop iy;								// restore into IY
	ld (hl), c;							// store C at address HL
	inc l;								// increment L register
	ld (hl), b;							// store B at address HL
	inc l;								// increment L register
	ld (hl), e;							// store E at address HL
	inc l;								// increment L register
	ld (hl), d;							// store D at address HL
	call L0E80;							// call function at L0E80
	ld a, (iy + _flags);				// load A from IY+flags offset
	ret;								// return to caller

L0E6D:
	ld hl, $2000;						// load HL with address $2000
	ld b, 4;							// load B with counter value 4

L0E72:
	ld a, (hl);							// load A with value at address HL
	and a;								// test A (check if zero)
	ret z;								// return if zero
	inc h;								// increment H register 
	djnz L0E72;							// decrement B and jump if not zero
	scf;								// set carry flag
	ret;								// return to caller

L0E7A:
	xor a;								// clear A register (set to 0)
	ld (iy + _err_nr), a;				// clear error number in IY
	scf;								// set carry flag
	ret;								// return to caller

L0E80:
	ld hl, $2d00;						// load HL with address $2D00
	ld bc, 0;							// clear BC register pair
	ld de, 0;							// clear DE register pair
	push hl;							// save HL on stack
	call L1096;							// call function at L1096
	pop hl;								// restore HL from stack
	jr c, L0E7A;						// jump to error handler if carry
	inc h;								// increment H register
	ld l, $fe;							// load L with value $FE
	ld a, (hl);							// load A from address HL
	inc l;								// increment L register
	and (hl);							// AND A with value at HL
	jr nz, L0E7A;						// jump to error if not zero
	dec h;								// decrement H register
	ld l, $0b;							// load L with value $0B
	ld a, (hl);							// load A from address HL
	inc l;								// increment L register
	or (hl);							// OR A with value at HL
	cp 2;								// compare A with 2
	jr nz, L0E7A;						// jump to error if not equal
	ld l, $10;							// load L with value $10
	ld a, (hl);							// load A from address HL
	cp 2;								// compare A with 2
	jr nz, L0E7A;						// jump to error if not equal
	ld hl, $2d00;						// load HL with address $2D00
	ld l, $13;							// load L with value $13
	ld e, (hl);							// load E from address HL
	inc l;								// increment L register
	ld d, (hl);							// load D from address HL
	ld a, e;							// copy E to A
	or d;								// OR A with D
	jr nz, L0EBF;						// jump if not zero
	ld l, $20;							// load L with value $20
	rst $30;							// restart at vector $30
	ld bc, $70fd;						// load BC with value $70FD
	dec de;								// decrement DE register pair
	ld (iy + 26), c;					// store C at IY+26

L0EBF:
	ld (iy + 25), d;					// store D at IY+25
	ld (iy + 24), e;					// store E at IY+24
	ld l, $0d;							// load L with value $0D
	ld a, (hl);							// load A from address HL
	ld (iy + 37), a;					// store A at IY+37
	inc l;								// increment L register
	ld e, (hl);							// load E from address HL
	inc l;								// increment L register
	ld d, (hl);							// load D from address HL
	ld (iy + 30), d;					// store D at IY+30
	ld (iy + 29), e;					// store E at IY+29
	ld l, $3a;							// point to memory location $3A
	ld a, (hl);							// load value from memory address HL
	cp '2';								// $50
	jr z, L0E7A;						// jump if character is '2'
	dec l;								// decrement L to previous memory location
	ld a, (hl);							// load value from new memory address
	ld l, $36;							// point to memory location $36
	cp '1';								// $49
	ld a, 0;							// load 0 into accumulator
	jr z, L0EE9;						// jump if character is '1'
	ld l, $52;							// point to memory location $52
	inc a;								// increment accumulator (set to 1)

L0EE9:
	ld (iy + 28), a;					// store accumulator at IY+28 (mode flag)
	push de;							// save DE register pair
	push iy;							// push IY onto stack
	pop de;								// pop into DE (copy IY to DE)
	ld e, 4;							// set E to offset 4
	ld bc, 5;							// set byte count to 5
	ldir;								// copy 5 bytes from HL to DE
	pop de;								// restore DE register pair
	cp 1;								// compare accumulator with 1
	jr z, L0F3E;						// jump if equals 1
	push hl;							// save HL register pair
	ld l, $16;							// point to memory location $16
	ld a, (hl);							// load low byte from memory
	inc l;								// increment to next memory location
	ld h, (hl);							// load high byte from memory
	ld l, a;							// move low byte to L register
	xor a;								// clear accumulator (set to 0)
	ld (iy + 34), a;					// clear high byte at IY+34
	ld (iy + 33), a;					// clear low byte at IY+33
	ld (iy + 32), h;					// store high byte at IY+32
	ld (iy + 31), l;					// store low byte at IY+31
	sla l;								// shift L left (multiply by 2)
	rl h;								// rotate H left with carry
	add hl, de;							// add DE to HL
	ex de, hl;							// exchange DE and HL
	ld (iy + 36), d;					// store D at IY+36
	ld (iy + 35), e;					// store E at IY+35
	pop hl;								// restore HL from stack
	ld l, $11;							// point to memory location $11
	ld a, (hl);							// load low byte from memory
	inc l;								// increment to next memory location
	ld h, (hl);							// load high byte from memory
	ld l, a;							// move low byte to L register
	srl h;								// shift H right (divide by 2)
	rr l;								// rotate L right with carry
	srl h;								// shift H right (divide by 4)
	rr l;								// rotate L right with carry
	srl h;								// shift H right (divide by 8)
	rr l;								// rotate L right with carry
	srl h;								// shift H right (divide by 16)
	rr l;								// rotate L right with carry
	ld (iy + 66), l;					// store result at IY+66
	ld bc, 0;							// clear BC register pair
	call L0831;							// call subroutine at L0831
	jr L0F68;							// jump to L0F68

L0F3E:
	push iy;							// push IY onto stack
	pop de;								// pop into DE (copy IY to DE)
	ld e, $26;							// set E to offset $26
	ld l, $2c;							// set L to offset $2C
	ldi;								// load and increment (copy HL to DE)
	ldi;								// load and increment (copy HL to DE)
	ldi;								// load and increment (copy HL to DE)
	ldi;								// load and increment (copy HL to DE)
	ld l, $24;							// load L with value $24
	rst $30;							// restart at vector $30
	ld bc, $70fd;						// load BC with value $70FD
	ld ($71fd), hl;						// store HL at address $71FD
	ld hl, $72fd;						// load HL with address $72FD
	jr nz, $0f58;						// jump if not zero to $0F58
	ld (hl), e;							// store E at memory location HL
	rra;								// rotate A right through carry
	sla e;								// shift E left (multiply by 2)
	rl d;								// rotate D left through carry
	rl c;								// rotate C left through carry
	rl b;								// rotate B left through carry
	call L1173;							// call subroutine at L1173

L0F68:
	ld h, 0;							// clear H register
	ld l, (iy + 37);					// load value from IY+37 into L
	sla l;								// shift L left arithmetic
	rl h;								// rotate H left through carry
	call L0836;							// call subroutine at L0836
	ld (iy + 45), b;					// store B at IY+45
	ld (iy + 44), c;					// store C at IY+44
	ld (iy + 43), d;					// store D at IY+43
	ld (iy + 42), e;					// store E at IY+42
	call L0F8E;							// call subroutine at L0F8E
	call L0FBE;							// call subroutine at L0FBE
	call L1065;							// call subroutine at L1065
	call L1021;							// call subroutine at L1021
	or a;								// clear carry flag
	ret;								// return from subroutine

L0F8E:
	ld h, (iy + 25);					// load high byte from IY+25
	ld l, (iy + 24);					// load low byte from IY+24
	or a;								// clear carry flag
	sbc hl, de;							// subtract DE from HL with carry
	ex de, hl;							// exchange DE and HL registers
	ld h, (iy + 27);					// load high byte from IY+27
	ld l, (iy + 26);					// load low byte from IY+26
	sbc hl, bc;							// subtract BC from HL with carry
	ld a, (iy + 37);					// get sectors per cluster value (power of 2)

L0Fa3:
	srl a;								// shift sectors per cluster right (find shift count)
	jr c, L0FB1;						// jump if bit was 1 (found the shift count)
	srl h;								// shift result high word right
	rr l;								// rotate result through carry
	rr d;								// rotate result through carry
	rr e;								// rotate result low byte through carry
	jr L0Fa3;							// loop back to check next bit

L0FB1:
	ld (iy + 62), e;					// store E at IY+62 (result low byte)
	ld (iy + 63), d;					// store D at IY+63 (result mid byte)
	ld (iy + 64), l;					// store L at IY+64 (result high byte)
	ld (iy + 65), h;					// store H at IY+65 (result top byte)
	ret;								// return from subroutine

L0FBE:
	ld a, (iy + 28);					// load mode flag from IY+28
	cp 1;								// compare with 1
	jr nz, $100f;						// jump if not equal to 1
	ld hl, $2d30;						// load address $2D30
	ld a, (hl);							// load value from memory
	dec a;								// decrement accumulator
	jr nz, $100f;						// jump if not zero
	ld hl, $3e00;						// load address $3E00
	ld bc, 0;							// clear BC register pair
	ld de, 1;							// set DE to 1
	push hl;							// save HL on stack
	call L1096;							// call subroutine at L1096
	pop hl;								// restore HL from stack
	jr c, $100f;						// jump if carry set (error)
	inc h;								// increment high byte of address
	ld l, $e4;							// set L to offset $E4
	ld a, (hl);							// load first byte from memory
	inc l;								// increment to next byte
	xor (hl);							// XOR with second byte
	inc l;								// increment to next byte
	add a, (hl);						// add third byte
	inc l;								// increment to next byte
	and (hl);							// AND with fourth byte
	cp 'A';								// $41
	jr nz, $100f;						// jump if not equal to 'A'
	ld l, $fe;							// set L to offset $FE
	ld a, (hl);							// load byte from memory
	inc l;								// increment to next byte
	and (hl);							// AND with next byte
	jr nz, $100f;						// jump if not zero
	ld a, 1;							// set A to 1
	ld (iy + 61), a;					// store at IY+61 (flag)
	ld a, ($2d41);						// load from memory address $2D41
	and %00000001;						// mask bit 0
	jr nz, $100f;						// jump if bit set
	ld l, $e8;							// set L to offset $E8
	rst $30;							// floating point system call
	ld bc, $b178;						// load BC with float operation code
	or e;								// OR E with A (check for zero)
	or d;								// OR D with A (check for zero)
	jr z, $100f;						// jump if zero result
	call L11D0;							// call subroutine at L11D0
	rst $30;							// floating point system call
	ld bc, $b6c3;						// load BC with float operation code
	ld de, $ff01;						// load DE with value $FF01
	rst $38;							// system call (error or comparison)
	ld de, $ffff;						// load DE with value $FFFF
	call L11D0;							// call subroutine at L11D0
	ld bc, 0;							// clear BC register pair
	ld de, 2;							// set DE to 2
	jp L11B6;							// jump to L11B6

L1021:
	ld hl, $1416;						// load address $1416
	ld a, 8;							// set A to 8
	call L1470;							// call subroutine at L1470
	jr nc, L102E;						// jump if no carry (success)
	ld hl, $2d2b;						// load address $2D2B

L102E:
	push iy;							// save IY register
	pop de;								// copy IY address to DE
	ld e, $0c;							// set E to offset $0C
	ld a, (hl);							// load value from memory
	and a;								// test if zero
	jr nz, L103A;						// jump if not zero

L1037:
	ld hl, L105C;						// point to default "NO NAME" string

L103A:
	call L103E;							// call string copy subroutine
	ret;								// return from routine

L103E:
	ld b, $0b;							// set counter to 11 characters

L1040:
	ld a, (hl);							// load character from source
	cp ' ';								// $20
	jr z, L104B;						// jump if space character

L1045:
	ld (de), a;							// store character at destination
	inc hl;								// increment source pointer
	inc de;								// increment destination pointer
	djnz L1040;							// decrement B and loop if not zero
	ret;								// return from routine

L104B:
	inc hl;								// move to next character
	ld a, (hl);							// load next character
	cp ' ';								// $20
	dec hl;								// move back to space
	ld a, (hl);							// reload space character
	jr nz, L1045;						// continue copying if next char not space
	ld a, b;							// check remaining count
	cp $0b;								// compare with 11
	jr z, L1037;						// jump to default name if no chars copied
	ld a, 0;							// load zero
	ld (de), a;							// null terminate string
	ret;								// return from routine

L105C:
	defb "NO NAME  ";					// if disk has no label
L1065:
	call L1169;							// call subroutine at L1169
	call L107B;							// call subroutine at L107B
	push iy;							// push IY register onto stack
	pop hl;								// pop into HL (copy IY to HL)
	ld l, $80;							// set L to offset $80
	ld a, $2f;							// load '/' character
	ld (hl), a;							// store '/' at memory location
	inc l;								// increment L
	ld a, l;							// copy L to A
	ld (iy + 127), l;					// store L at IY+127
	xor a;								// clear A (set to 0)
	ld (hl), a;							// store 0 (null terminator)
	ret;								// return from routine

L107B:
	ld a, (iy + 28);					// load mode flag from IY+28
	cp 1;								// compare with 1
	jr nz, L1089;						// jump if not equal to 1
	ld a, d;							// load D register
	or b;								// OR with B register
	or c;								// OR with C register

L1085:
	or e;								// OR with E register (check if all zero)
	call z, L1169;						// call L1169 if all registers are zero

L1089:
	ld (iy + 49), b;					// store B register at IY+49
	ld (iy + 48), c;					// store C register at IY+48
	ld (iy + 47), d;					// store D register at IY+47
	ld (iy + 46), e;					// store E register at IY+46
	ret;								// return from routine

L1096:
	push bc;							// save BC register pair
	push de;							// save DE register pair
	ld a, (iy + _flags);				// load flags from IY+_flags
	rst $08;							// system call
	defb disk_read;						// disk read operation
	pop de;								// restore DE register pair
	pop bc;								// restore BC register pair
	ret;								// return from routine

L10A0:
	ld a, (iy + _flags);				// load flags from IY+_flags
	rst $08;							// system call
	defb disk_write;					// disk write operation
	ret;								// return from routine

L10A6:
	push bc;							// save BC register pair
	push de;							// save DE register pair
	ld a, ($3c25);						// get disk drive number
	rst $08;							// call system function
	defb disk_write;					// write sector to disk
	pop de;								// restore DE register pair
	pop bc;								// restore BC register pair
	ret;								// return to caller

L10B0:
	call L117F;							// load cluster start address
	jr L10A6;							// jump to disk write routine

L10B5:
	call L117F;							// load cluster start address
	jr L1096;							// jump to disk read routine

L10BA:
	ld a, ($3c25);						// get current drive number
	cp (iy + _flags);					// compare with file system drive
	jr nz, L10C8;						// jump if different drive
	ld hl, $3c14;						// point to cluster number buffer
	call L0694;							// compare 32-bit cluster values

L10C8:
	ld hl, $2800;						// load default buffer address
	ccf;								// complement carry flag
	ret z;								// return if zero flag set
	call L10F3;							// call cluster validation routine
	ret c;								// return if error
	push de;							// save DE register
	push bc;							// save BC register
	push hl;							// save HL register
	call L1173;							// calculate sector address
	push hl;							// save calculated address
	call L1096;							// read sector from disk
	pop hl;								// restore calculated address
	call c, L10B5;						// if read failed, try write operation
	pop hl;								// restore HL register
	pop bc;								// restore BC register
	pop de;								// restore DE register
	push af;							// save operation result
	ld a, (iy + _flags);				// get file system flags
	ld ($3c25), a;						// store current drive number
	ld ($3c11), de;						// store sector address low word
	ld ($3c13), bc;						// store sector address high word
	pop af;								// restore operation result
	ret;								// return to caller

L10F3:
	ld a, ($3c2b);						// get dirty buffer flag
	or a;								// test if buffer needs flushing
	ret z;								// return if buffer clean
	push bc;							// save BC register
	push de;							// save DE register
	push hl;							// save HL register
	ld de, ($3c11);						// get sector address low word
	ld bc, ($3c13);						// get sector address high word
	call L1111;							// flush buffer to disk
	pop hl;								// restore HL register
	pop de;								// restore DE register
	pop bc;								// restore BC register
	ret;								// return to caller

L110A:
	ld a, $ff;							// set dirty flag value
	ld ($3c2b), a;						// mark buffer as dirty
	or a;								// set flags for return
	ret;								// return with non-zero

L1111:
	xor a;								// clear accumulator
	ld ($3c2b), a;						// clear dirty buffer flag
	ld hl, $2800;						// point to disk buffer
	push de;							// save sector address low word
	push bc;							// save sector address high word  
	push hl;							// save buffer address
	call L1173;							// calculate final sector address
	push hl;							// save calculated address
	call L10A6;							// write buffer to disk
	pop hl;								// restore calculated address
	jr c, L1129;						// jump if write error
	call L10B0;							// perform additional write operation
	or a;								// check operation result

L1129:
	call c, L10B0;						// call cleanup if error occurred
	jr c, L1131;						// jump to exit if still error
	call L11DD;							// call buffer flush function

L1131:
	pop hl;								// restore HL register
	pop bc;								// restore BC register
	pop de;								// restore DE register
	ret;								// return with final status

L1135:
	ld (ix + 20), e;					// store sector address low byte
	ld (ix + 21), d;					// store sector address byte 1
	ld (ix + 22), c;					// store sector address byte 2  
	ld (ix + 23), b;					// store sector address high byte
	ret;								// return after storing addressreturn after storing address

; Function: Get file current sector address from descriptor
L1142:
	ld e, (ix + 20);					// load sector address low byte
	ld d, (ix + 21);					// load sector address byte 2
	ld c, (ix + 22);					// load sector address byte 3
	ld b, (ix + 23);					// load sector address high byte
	ret;								// return DEBC = current sector address

; Function: Set file next cluster in descriptor
L114F:
	ld (ix + 24), e;					// store next cluster low byte
	ld (ix + 25), d;					// store next cluster byte 2
	ld (ix + 26), c;					// store next cluster byte 3
	ld (ix + 27), b;					// store next cluster high byte
	ret;								// return after storing DEBC cluster

; Function: Get file next cluster from descriptor
L115C:
	ld e, (ix + 24);					// load next cluster low byte
	ld d, (ix + 25);					// load next cluster byte 2
	ld c, (ix + 26);					// load next cluster byte 3
	ld b, (ix + 27);					// load next cluster high byte
	ret;								// return DEBC = next cluster address

L1169:
	push hl;							// save HL register
	push iy;							// save IY register
	pop hl;								// load IY into HL
	ld l, $26;							// set low byte to offset $26
	rst $30;							// call ROM routine
	ld bc, $c9e1;						// load return instruction and pop hl

L1173:
	push hl;							// save HL register
	ld l, (iy + 29);					// load cluster pointer low byte
	ld h, (iy + 30);					// load cluster pointer high byte
	call L0831;							// call cluster processing function
	pop hl;								// restore HL register
	ret;								// return from function

L117F:
	push hl;							// save HL register
	push bc;							// save BC register
	push de;							// save DE register
	call L118F;							// get cluster start address in BCDE
	pop hl;								// restore DE to HL
	add hl, de;							// add low 16-bits of cluster address
	ex de, hl;							// result low 16-bits to DE
	pop hl;								// restore BC to HL
	adc hl, bc;							// add high 16-bits with carry
	ld b, h;							// move result high byte to B
	ld c, l;							// move result low byte to C
	pop hl;								// restore HL register
	ret;								// return with 32-bit address in BCDE

L118F:
	ld e, (iy + 31);					// load cluster start address low byte
	ld d, (iy + 32);					// load cluster start address byte 1
	ld c, (iy + 33);					// load cluster start address byte 2
	ld b, (iy + 34);					// load cluster start address high byte
	ret;								// return DEBC = cluster start addressreturn DEBC = cluster start addressreturn DEBC = cluster start address

; Function: Get filesystem parameters from volume descriptor
L119C:
	ld b, (iy + 49);					// load filesystem parameter byte 3
	ld c, (iy + 48);					// load filesystem parameter byte 2
	ld d, (iy + 47);					// load filesystem parameter byte 1
	ld e, (iy + 46);					// load filesystem parameter low byte
	ret;								// return BCDE = filesystem parameters

; Function: Get directory cluster from volume descriptor
L11A9:
	ld e, (iy + 53);					// load directory cluster low byte
	ld d, (iy + 54);					// load directory cluster byte 2
	ld c, (iy + 55);					// load directory cluster byte 3
	ld b, (iy + 56);					// load directory cluster high byte
	ret;								// return DEBC = current directory cluster

; Function: Set directory cluster in volume descriptor
L11B6:
	ld (iy + 53), e;					// store directory cluster low byte
	ld (iy + 54), d;					// store directory cluster byte 2
	ld (iy + 55), c;					// store directory cluster byte 3
	ld (iy + 56), b;					// store directory cluster high byte
	ret;								// return after storing DEBC cluster

; Function: Get working cluster from volume descriptor
L11C3:
	ld e, (iy + 57);					// load working cluster low byte
	ld d, (iy + 58);					// load working cluster byte 2
	ld c, (iy + 59);					// load working cluster byte 3
	ld b, (iy + 60);					// load working cluster high byte
	ret;								// return DEBC = working cluster

; Function: Set working cluster in volume descriptor
L11D0:
	ld (iy + 57), e;					// store working cluster low byte
	ld (iy + 58), d;					// store working cluster byte 2
	ld (iy + 59), c;					// store working cluster byte 3
	ld (iy + 60), b;					// store working cluster high byte
	ret;								// return after storing DEBC cluster

; Function: Load directory sector if needed
L11DD:
	ld a, (iy + 61);					// check if directory buffer valid
	or a;								// test validity flag
	ret z;								// return if buffer already valid
	ld hl, $3fe8;						// load buffer management address
	call L11C3;							// get working cluster
	rst $30;							// call ROM routine
	nop;								// padding/alignment
	call L11A9;							// get directory cluster
	rst $30;							// call ROM routine
	nop;								// padding/alignment
	ld hl, $3e00;						// load directory buffer address
	ld bc, 0;							// clear cluster offset
	ld de, 1;							// set sector count to 1
	jp L10A0;							// jump to sector read routine

L11FB:
	call L115C;							// call sector loading function
	call L1096;							// call directory processing
	ret;								// return from function

L1202:
	call L115C;							// call sector loading function
	ld a, ($3c26);						// load system flags
	cp (iy + _flags);					// compare with file flags
	jr nz, L1213;						// jump if flags differ
	ld hl, $3c2a;						// load buffer address
	call L0694;							// call utility function

L1213:
	ld hl, $2a00;						// load sector buffer address
	ccf;								// complement carry flag
	ret z;								// return if zero
	ld a, (iy + _flags);				// load file flags
	ld ($3c26), a;						// store flags in buffer
	ld ($3c27), de;						// store DE address in buffer
	ld ($3c29), bc;						// store BC value in buffer
	push hl;							// save HL register
	call L11FB;							// call sector/directory processing
	pop hl;								// restore HL register
	ret;								// return from function

; Function: Clear memory buffer
L122C:
	push hl;							// save HL register
	ld hl, $2a00;						// load buffer address
	call $313c;							// call memory clear function
	pop hl;								// restore HL register
	ret;								// return from function

; Function: Process file flags and load sector
L1235:
	call L115C;							// call sector loading function
	ld a, (iy + _flags);				// load file flags
	exx;								// switch to alternate register set
	push bc;							// save BC register
	push de;							// save DE register
	ld c, mmcram;						// load divMMC RAM control port
	ld de, ($3df8);						// load RAM page configuration
	out (c), e;							// set divMMC RAM page (low)
	exx;								// switch to alternate registers
	rst $08;							// call disk I/O function
	defb disk_read;						// disk read operation
	exx;								// switch back to main registers
	out (c), d;							// set divMMC RAM page (high)
	pop de;								// restore DE register
	pop bc;								// restore BC register
	exx;								// switch back to alternate registers
	ret;								// return from memory page operation

; Function: Process sector decrement and load
L1250:
	dec (ix + 19);						// decrement sector count
	jr z, L125E;						// jump if all sectors processed
	call L115C;							// call sector loading function
	call $081c;							// call disk function
	jp L114F;							// jump back to processing loop

; Function: Complete sector processing
L125E:
	call L12B2;							// call completion function
	ret c;								// return if carry set
	jp L12A9;							// jump to finalization

; Function: Check file position and parameters
L1265:
	ld a, (iy + 28);					// load file position indicator
	cp 1;								// check if position is 1
	jr z, L127D;						// jump if at position 1
	ld a, d;							// load D register
	or e;								// check if DE is zero
	jr nz, L127D;						// jump if DE not zero
	ld bc, 0;							// clear BC register
	ld d, (iy + 36);					// load file size high byte
	ld e, (iy + 35);					// load file size low byte
	ld a, (iy + 66);					// load status flag
	ret;								// return with file parameters

; Function: Apply sector size shift to address calculation
L127D:
	ld a, (iy + 37);					// load sectors per cluster shift count

; Function: Shift loop for address scaling
L1280:
	srl a;								// shift right shift count
	jr c, L128E;						// exit when shift complete
	sla e;								// shift left E register
	rl d;								// rotate left D register
	rl c;								// rotate left C register
	rl b;								// rotate left B register
	jr L1280;							// continue shifting loop

; Function: Add file offset to base address (32-bit arithmetic)
L128E:
	ld a, (iy + 42);					// load file offset byte 0
	add a, e;							// add to E register
	ld e, a;							// store result in E
	ld a, (iy + 43);					// load file offset byte 1
	adc a, d;							// add with carry to D
	ld d, a;							// store result in D
	ld a, (iy + 44);					// load file offset byte 2
	adc a, c;							// add with carry to C
	ld c, a;							// store result in C
	ld a, (iy + 45);					// load file offset byte 3
	adc a, b;							// add with carry to B
	ld b, a;							// store result in B (32-bit addition complete)
	ld a, (iy + 37);					// load sectors per cluster shift count
	ret;								// return with shift count

L12A6:
	call L1135;							// call sector/cluster address setup

L12A9:
	call L1265;							// call file position check
	ld (ix + 19), a;					// store sector count in file control block
	jp L114F;							// jump to main processing loop

L12B2:
	call L1142;							// call cluster calculation function
	call L12C7;							// call sector mapping function
	jp nc, L1135;						// jump to setup if no carry
	cp $80;								// check for empty block marker
	scf;								// set carry flag (error condition)
	ret nz;								// return with error if not empty block
	bit 2, (ix + 1);					// test file flag bit 2
	ret z;								// return if bit not set
	jp $3000;							// jump to extended processing

L12C7:
	ld a, (iy + 28);					// load file position indicator
	cp 1;								// check if position is 1
	jr z, L12F4;						// jump to special handling if 1
	push de;							// save DE register
	ld e, d;							// shift registers for 32-bit calculation
	ld d, c;							// D = C (shift high)
	ld c, b;							// C = B (shift high)
	ld b, 0;							// clear B (most significant byte)
	call L10BA;							// call cluster to sector conversion
	pop de;								// restore DE register
	ret c;								// return if conversion failed
	xor a;								// clear accumulator
	sla e;								// shift E left (multiply by 2)
	ld l, e;							// load shifted value to L
	adc a, h;							// add carry to high byte
	ld h, a;							// store result in H
	ld e, (hl);							// load cluster entry low byte
	inc hl;								// advance to high byte
	ld d, (hl);							// load cluster entry high byte
	dec hl;								// restore pointer
	ld bc, 0;							// clear BC register
	ld a, d;							// load high byte to accumulator

; Function: Check for end-of-chain markers
L12E7:
	cp $ff;								// check for end-of-chain marker
	ccf;								// complement carry flag
	ret nz;								// return if not end marker
	ld a, e;							// load low byte
	and %11110000;						// mask upper 4 bits
	cp $f0;								// check for special marker
	ccf;								// complement carry flag
	ld a, $80;							// load error code
	ret;								// return with status

; Function: Process position 1 with bit shifting
L12F4:
	push de;							// save DE register
	ld a, e;							// save E in accumulator
	ld e, d;							// shift register values
	ld d, c;							// D = C
	ld c, b;							// C = B  
	ld b, 0;							// clear B
	sla a;								// shift left A (multiply by 2)
	rl e;								// rotate left E with carry
	rl d;								// rotate left D with carry
	rl c;								// rotate left C with carry
	rl b;								// rotate left B with carry
	call L10BA;							// call cluster to sector conversion
	pop de;								// restore DE register
	ret c;								// return if conversion failed
	xor a;								// clear accumulator
	sla e;								// shift E left (multiply by 2)
	sla e;								// shift E left again (multiply by 4)
	ld l, e;							// load shifted value to L
	adc a, h;							// add carry to high byte
	ld h, a;							// store result in H
	push hl;							// save HL on stack
	rst $30;							// call ROM routine
	ld bc, $78e1;						// load control value
	cp $0f;								// compare with 15
	jr nz, L12E7;						// jump if not equal
	ld a, $ff;							// load mask value
	and c;								// mask with C
	and d;								// mask with D
	jr L12E7;							// jump to check end marker

; Function: Process disk operations with error handling
L1321:
	push de;							// save DE register
	call L11C3;							// call buffer management function
	inc b;								// increment B register
	jr z, L1332;						// jump if zero result
	dec b;								// decrement B back
	call c, $081c;						// call disk function if carry set
	call nc, L0824;						// call alternate function if no carry
	call L11D0;							// call cleanup function

L1332:
	pop de;								// restore DE register
	ret;								// return from cluster operation

; Function: Validate cluster operation
L1334:
	push bc;							// save BC register
	push de;							// save DE register
	call L11C3;							// get working cluster
	rst $30;							// call ROM routine
	dec c;								// decrement cluster count
	pop de;								// restore DE register
	pop bc;								// restore BC register
	ret nz;								// return if non-zero (valid)
	ld a, 9;							// load error code 9 (invalid cluster)
	scf;								// set carry flag for error
	ret;								// return with error

; Function: Disk write operation with RAM page management
L1342:
	call L115C;							// call sector loading function
	ld a, (iy + _flags);				// load file flags
	exx;								// switch to alternate register set
	push bc;							// save BC register
	push de;							// save DE register
	ld c, mmcram;						// load divMMC RAM control port
	ld de, ($3df8);						// load RAM page configuration
	out (c), e;							// set divMMC RAM page (low)
	exx;								// switch to alternate registers
	rst $08;							// call disk I/O function
	defb disk_write;					// disk write operation
	exx;								// switch back to main registers
	out (c), d;							// restore divMMC RAM page (high)
	pop de;								// restore DE register
	pop bc;								// restore BC register
	exx;								// switch back to alternate registers
	ret;								// return from disk write

; Function: Process FAT and cluster operations
L135D:
	call L11A9;							// call FAT processing function
	call L12C7;							// call sector mapping function
	call $305e;							// call system function
	ret c;								// return if operation failed
	ld h, d;							// load D to H
	ld l, e;							// load E to L
	ld a, $ff;							// load end-of-chain marker
	call $30e2;							// call cluster marking function
	push de;							// save DE register
	ld de, ($3c11);						// load system parameter address
	ld bc, ($3c13);						// load system parameter value
	push bc;							// save BC register
	push de;							// save DE register again
	call L110A;							// call cluster calculation function
	pop de;								// restore DE register
	pop bc;								// restore BC register
	pop hl;								// restore HL register
	ret c;								// return if error occurred

; Function: Multi-precision right shifts for FAT address conversion
L1380:
	rr h;								// rotate right H register
	rr l;								// rotate right L register
	ld a, (iy + 28);					// load FAT type indicator
	cp 1;								// check if FAT12
	jr nz, L1395;						// jump if not FAT12
	srl b;								// shift right B register
	rr c;								// rotate right C register
	rr d;								// rotate right D register
	rr e;								// rotate right E register
	rr l;								// rotate right L register

; Function: Register shift operations for 32-bit calculations
L1395:
	ld b, c;							// shift register chain: B = C
	ld c, d;							// C = D
	ld d, e;							// D = E  
	ld e, l;							// E = L
	or a;								// clear carry flag
	ret;								// return with shifted registers

; Function: Process command with 8-byte limit
L139B:
	ld b, 8;							// set counter to 8 bytes
	call L13E2;							// call processing function
	call L13AB;							// call validation function
	ld a, (hl);							// load character from buffer
	cp '.';								// check for period (external command marker)
	jr nz, L13A9;						// jump if not period
	inc hl;								// advance past period

; Function: Extract 3-character extension with validation
L13A9:
	ld b, 3;							// set counter for 3-character extension

; Function: Process filename characters with validation
L13AB:
	ld a, (hl);							// load character from filename
	ld c, $20;							// set padding character (space)
	cp '.';								// check for period (extension separator)
	jr z, L13DB;						// jump to padding if period found
	and a;								// check for null terminator
	jr z, L13DB;						// jump to padding if null
	cp '/';								// check for path separator
	jr z, L13DB;						// jump to padding if path separator
	call L13F8;							// validate character is acceptable for FAT filesystem
	jr nc, L13C2;						// jump to case conversion if valid

L13BE:
	scf;								// set carry flag (invalid character)
	ld a, 7;							// load error code 7 (bad filename)
	ret;								// return with error

; Function: Convert lowercase to uppercase for FAT compatibility
L13C2:
	cp 'a';								// check if lowercase letter
	jr c, L13CC;						// jump if below 'a'
	cp '{';								// check if above 'z' ('{' is char after 'z')
	jr nc, L13CC;						// jump if above lowercase range
	and %11011111;						// clear bit 5 to convert lowercase to uppercase

L13CC:
	ld (de), a;							// store converted character
	inc de;								// advance destination pointer
	inc hl;								// advance source pointer
	djnz L13AB;							// continue processing characters
	ld a, (hl);							// load next character
	and a;								// check for null terminator
	jr z, L13D9;						// jump to completion if null
	cp '/';								// check for path separator
	jr nz, L13BE;						// error if unexpected character

; Function: Complete filename processing
L13D9:
	or a;								// clear carry flag (success)
	ret;								// return successfully

; Function: Pad remaining filename space with specified character
L13DB:
	ld a, c;							// load padding character (typically space)

L13DC:
	ld (de), a;							// store padding character
	inc de;								// advance destination pointer
	djnz L13DC;							// repeat for remaining character count
	or a;								// clear carry flag (success)
	ret;								// return after padding

; Function: Process file extension for FAT 8.3 format
L13E2:
	ld a, (hl);							// load character from extension
	cp '.';								// check for period (extension marker)
	ret nz;								// return if not extension
	ld bc, $0b00;						// B=11 chars total, C=0 for comparison
	ldi;								// copy period and increment pointers
	cp (hl);							// compare with next character
	jr nz, L13F1;						// jump if different
	ldi;								// copy another character
	dec b;								// decrement remaining character count

L13F1:
	ld c, $20;							// set space character for padding
	call L13DB;							// pad remaining extension space
	pop bc;								// restore BC register
	ret;								// return from extension processing

; Function: Validate character for FAT filesystem compatibility
L13F8:
	cp '!';								// check if below printable ASCII range
	ret c;								// return with carry if invalid
	push bc;							// save BC register
	push hl;							// save HL register
	ld hl, $140b;						// point to forbidden character table
	ld bc, $0c;							// 12 forbidden characters to check
	scf;								// set carry flag
	cpir;								// search for character in forbidden list
	pop hl;								// restore HL register
	pop bc;								// restore BC register
	ret z;								// return with carry if forbidden
	ccf;								// clear carry flag (character valid)
	ret;								// return successfully

	ccf;								// 
	ld ($3a2f), hl;						// 
	dec sp;								// 
	inc l;								// 
	inc a;								// 
	ld a, $5c;							// 
	ld a, h;							// 
	ld l, $2a;							// 

; Function: Compare directory entries
L1417:
	push de;							// save DE register
	push hl;							// save HL register
	push bc;							// save BC register
	ld b, $0b;							// set comparison length (11 chars for 8.3 filename)

; Function: Character-by-character filename comparison loop
L141C:
	ld a, (de);							// load character from search pattern
	cp '*';								// check for wildcard character
	jr z, L1428;						// jump if wildcard (auto-match)
	cp (hl);							// compare with directory entry character
	jr nz, L1428;						// jump if no match
	inc de;								// advance search pattern pointer
	inc hl;								// advance directory entry pointer
	djnz L141C;							// continue for all 11 characters

; Function: Restore registers after comparison
L1428:
	pop bc;								// restore BC register
	pop hl;								// restore HL register
	pop de;								// restore DE register
	ret;								// return with comparison result

; Function: Process file operation with error checking
L142C:
	ld b, a;							// save operation code
	push bc;							// save BC register
	push hl;							// save HL register
	call L1142;							// get file current sector address
	ld hl, $3c22;						// load buffer address
	call L0694;							// call comparison function
	pop hl;								// restore HL register
	pop bc;								// restore BC register
	ld a, b;							// reload operation code
	jr z, L143F;						// jump if zero result
	or a;								// test operation code
	ret;								// return with result

; Function: Return specific error code
L143F:
	ld a, $13;							// load error code 19 (device error)
	ret;								// return with error

L1442:
	ld b, a;							// save operation type
	push bc;							// save BC register
	push hl;							// save HL register
	call L1142;							// get file current sector address
	push iy;							// save IY register
	pop hl;								// transfer IY to HL
	ld l, $29;							// set offset for file attribute
	call L0694;							// call comparison function
	jr nz, L145D;						// jump if not zero
	pop hl;								// restore HL register
	push hl;							// save HL again
	ld a, (hl);							// load first character
	cp '.';								// check for period
	jr nz, L145D;						// jump if not extension
	inc l;								// advance pointer
	ld a, (hl);							// load next character
	cp ' ';								// check for space

; Function: Cleanup and return operation code
L145D:
	pop hl;								// restore HL register
	pop bc;								// restore BC register
	ld a, b;							// load operation code
	ret;								// return with operation result

; Function: Initialize buffer and call system routines
L1461:
	ld de, $2f00;						// load buffer address
	push de;							// save buffer address
	exx;								// switch to alternate registers
	call L1169;							// call system function
	exx;								// switch back to main registers
	call $336d;							// call ROM routine
	pop hl;								// restore buffer address to HL
	or a;								// test result flags
	ret;								// return with status

; Function: Process filesystem operation with parameter handling
L1470:
	push af;							// save accumulator
	call L119C;							// get filesystem parameters
	call L19ED;							// call processing function
	call L12A6;							// call sector/cluster address setup
	pop af;								// restore accumulator

; Function: File operation validation and processing
L147B:
	call L1442;							// call file operation processing
	jr z, L1461;						// jump if zero result
	call L142C;							// call error checking function
	ret c;								// return if error
	res 2, (ix + 1);					// clear file status bit
	ld (iy + 51), a;					// store accumulator in volume descriptor
	res 1, (iy + 52);					// clear volume status bit
	ld ($3c04), hl;						// store HL in system variable

L1492:
	ld a, $11;							// load error code 17
	ld (ix + 6), a;						// store error code in file descriptor
	ld hl, $2600;						// load buffer address
	push hl;							// save buffer address
	call L11FB;							// 
	pop hl;								// 
	ret c;								// 

L14A0:
	dec (ix + 6);						// 
	jr nz, L14AA;						// 
	call L1250;							// 
	jr L1492;							// 

L14AA:
	ld a, (hl);							// 
	and a;								// 
	jr z, L1505;						// 
	cp 229;								// RESTORE, $e5
	jr z, L14C3;						// 
	ld c, l;							// 
	ld a, l;							// 
	add a, 11;							// 
	ld l, a;							// 
	ld a, (hl);							// 
	ld l, c;							// 
	cp 15;								// $0f
	jr nz, L14EA;						// 

L14BD:
	ld bc, $20;							// 
	add hl, bc;							// 
	jr L14A0;							// 

L14C3:
	call L14C8;							// 
	jr L14BD;							// 

L14C8:
	bit 1, (iy + 52);					// 
	ret nz;								// 
	set 1, (iy + 52);					// 
	ld a, (ix + 6);						// 
	ld (ix + 30), a;					// 
	ld a, (ix + 19);					// 
	ld (ix + 31), a;					// 
	call L115C;							// 
	call L19D3;							// 
	call L1142;							// 
	call L19B9;							// 
	ret;								// 

L14EA:
	ld e, a;							// 
	ld a, (iy + 51);					// 
	and a;								// 
	jr z, L14F4;						// 
	and e;								// 
	jr z, L14BD;						// 

L14F4:
	ld de, ($3c04);						// 
	call L1417;							// 
	jr nz, L14BD;						// 
	ld (ix + 28), l;					// 
	ld (ix + 29), h;					// 
	or a;								// 
	ret;								// 

L1505:
	call L14C8;							// 
	ld a, (ix + 30);					// 
	ld (ix + 6), a;						// 
	ld a, (ix + 31);					// 
	ld (ix + 19), a;					// 
	call L19E0;							// 
	call L114F;							// 
	call L19C6;							// 
	call L1135;							// 
	ld a, 5;							// 
	scf;								// 
	ret;								// 

L1524:
	ld bc, $ffff;						// 
	ld ($3c1f), bc;						// 
	ld ($3c20), bc;						// 

L152F:
	ld de, $2c00;						// 
	push de;							// 
	rst $30;							// 
	dec b;								// 
	pop hl;								// 
	ld (iy + 52), a;					// 
	rra;								// 
	jr nc, L1555;						// 
	push hl;							// 
	push iy;							// 
	pop hl;								// 
	ld l, $80;							// 
	ld de, $2c80;						// 
	push de;							// 
	ld a, (iy + 127);					// FIXME negative offset 
	push af;							// 
	sub $80;							// 
	ld b, 0;							// 
	ld c, a;							// 
	ldir;								// 
	pop af;								// 
	pop de;								// 
	ld e, a;							// 
	pop hl;								// 

L1555:
	xor a;								// 
	ld (ix + 29), a;					// 
	ld a, (hl);							// 
	and a;								// 
	jp z, L1609;						// 
	cp '/';								// $2f
	jr nz, L156E;						// 
	bit 0, (iy + 52);					// 
	jr z, L156D;						// 
	cp a;								// 
	ld e, $80;							// 
	ld (de), a;							// 
	inc de;								// 

L156D:
	inc hl;								// 

L156E:
	ld ($3dea), de;						// 
	call z, L1169;						// 
	call nz, L119C;						// 

L1578:
	ld ($3dec), hl;						// 
	ld a, (hl);							// 
	and a;								// 
	jp z, L160D;						// 
	call L19ED;							// 
	call L12A6;							// 
	ld de, $3c06;						// 
	push de;							// 
	call L139B;							// 
	pop de;								// 
	ret c;								// 
	push hl;							// 
	ex de, hl;							// 
	xor a;								// 
	call L147B;							// 
	pop de;								// 
	jp c, L162E;						// 
	ld c, l;							// 
	ld a, l;							// 
	add a, $0b;							// 
	ld l, a;							// 
	bit 4, (hl);						// 
	ld l, c;							// 
	ex de, hl;							// 
	jr nz, L15B5;						// 
	ld a, (hl);							// 
	and a;								// 
	jr z, L15AC;						// 
	ld a, $13;							// 
	scf;								// 
	ret;								// 

L15AC:
	ld a, (iy + 52);					// 
	rla;								// 
	ld a, $11;							// 
	ret c;								// 
	jr L1615;							// 

L15B5:
	bit 0, (iy + 52);					// 
	jr z, L15FC;						// 
	push hl;							// 
	ld hl, ($3dec);						// 
	ld de, ($3dea);						// 
	ld a, (hl);							// 
	cp '.';								// external command?
	jr z, L15D5;						// 

L15C8:
	ld a, (hl);							// 
	inc hl;								// 
	and a;								// 
	jr z, L15E8;						// 
	cp '/';								// $2f
	jr z, L15E8;						// 
	ld (de), a;							// 
	inc de;								// 
	jr L15C8;							// 

L15D5:
	inc hl;								// 
	ld a, (hl);							// 
	cp '.';								// $2e
	jr nz, L15EC;						// 
	dec de;								// 
	dec de;								// 

L15DD:
	ld a, (de);							// 
	cp '/';								// $2f
	jr z, L15E5;						// 
	dec de;								// 
	jr L15DD;							// 

L15E5:
	inc de;								// 
	jr L15EC;							// 

L15E8:
	ld a, $2f;							// 
	ld (de), a;							// 
	inc de;								// 

L15EC:
	ld ($3dea), de;						// 
	pop hl;								// 
	ld a, e;							// 
	cp $81;								// 
	ld a, $15;							// 
	ret c;								// 
	call z, L1169;						// 
	jr z, L15FF;						// 

L15FC:
	call L163E;							// 

L15FF:
	ld a, (hl);							// 
	and a;								// 
	jr z, L160D;						// 
	cp '/';								// $2f
	inc hl;								// 
	jp z, L1578;						// 

L1609:
	scf;								// 
	ld a, $13;							// 
	ret;								// 

L160D:
	ld a, (iy + 52);					// 
	rla;								// 
	ccf;								// 
	ld a, $10;							// 
	ret c;								// 

L1615:
	call L161A;							// 
	or a;								// 
	ret;								// 

L161A:
	bit 0, (iy + 52);					// 
	ret z;								// 
	ld hl, ($3dec);						// 
	ld de, ($3dea);						// 

L1626:
	ld a, (hl);							// 
	ld (de), a;							// 
	inc hl;								// 
	inc de;								// 
	or a;								// 
	ret z;								// 
	jr L1626;							// 

L162E:
	ex de, hl;							// 
	ld a, (hl);							// 
	and a;								// 
	jr z, L1637;						// 
	scf;								// 
	ld a, $13;							// 
	ret;								// 

L1637:
	call L161A;							// 
	scf;								// 
	ld a, 5;							// 
	ret;								// 

L163E:
	push hl;							// 
	ld a, (ix + 29);					// 
	and a;								// 
	jr nz, L164A;						// 
	call L1169;							// 
	jr L1654;							// 

L164A:
	ld h, a;							// 
	ld a, (ix + 28);					// 
	add a, $14;							// 
	ld l, a;							// 
	call L165F;							// 

L1654:
	pop hl;								// 

L1655:
	ld a, (iy + 28);					// 
	cp 1;								// 
	ret z;								// 
	ld bc, 0;							// 
	ret;								// 

L165F:
	call L166B;							// 
	ld a, c;							// 
	or b;								// 
	or e;								// 
	or d;								// 
	call z, L1169;						// 
	jr L1655;							// 

L166B:
	ld c, (hl);							// 
	inc l;								// 
	ld b, (hl);							// 
	ld a, l;							// 
	add a, 5;							// 
	ld l, a;							// 
	ld e, (hl);							// 
	inc l;								// 
	ld d, (hl);							// 
	inc l;								// 
	ret;								// 

	ex de, hl;							// 
	push iy;							// 
	pop hl;								// 
	ld l, $80;							// 
	rst $30;							// 
	inc b;								// 
	or a;								// 
	ret;								// 

L1681:
	push hl;							// 
	set 5, (ix + 1);					// 
	call L18EE;							// 
	res 5, (ix + 1);					// 
	pop hl;								// 
	ret;								// 

L168F:
	call L1697;							// 
	ld (ix + 0), 0;						// 
	ret;								// 

L1697:
	or a;								// 

L1699 equ $1699

	bit 3, (ix + 1);					// 
	jp z, L10F3;						// 
	call L16CB;							// 
	ret c;								// 
	ld de, $14;							// 
	add hl, de;							// 
	call L19FA;							// 
	ld (hl), c;							// 
	inc hl;								// 
	ld (hl), b;							// 
	inc hl;								// 
	inc hl;								// 
	inc hl;								// 
	inc hl;								// 
	inc hl;								// 
	ld (hl), e;							// 
	inc hl;								// 
	ld (hl), d;							// 
	inc hl;								// 
	call L19E0;							// 
	rst $30;							// 
	nop;								// 
	call L17E7;							// 

L16BE:
	push af;							// 
	ld hl, $3c1b;						// 
	rst $30;							// 
	ld bc, $4fcd;						// 
	ld de, $c3f1;						// 
	di;									// interrupts off

L16CB equ $16cb

	djnz L1699;							// 
	ld e, h;							// 
	ld de, $1b21;						// 
	inc a;								// 
	rst $30;							// 
	nop;								// 
	call L1A14;							// 
	call L114F;							// 
	call L17F4;							// 
	ex de, hl;							// 
	ret;								// 

L16DE:
	ld a, b;							// 
	ld ($3c01), a;						// 
	ld ($3c23), de;						// 
	ld a, 1;							// 
	call L1524;							// 
	jr nc, L16FD;						// 
	cp 5;								// 
	scf;								// 
	ret nz;								// 
	ld a, ($3c01);						// 
	and %00001100;						// 
	scf;								// 
	ld a, 5;							// 
	ret z;								// 
	jp L1712;							// 

L16FD:
	ld a, ($3c01);						// 
	and %00001100;						// 
	cp 4;								// 
	jr nz, L170A;						// 
	scf;								// 
	ld a, $12;							// 
	ret;								// 

L170A:
	cp $0c;								// 
	jp z, L1815;						// 
	jp L184A;							// 

L1712:
	call L1334;							// 
	ret c;								// 
	call L17F4;							// 
	ret c;								// 
	ld a, (de);							// 
	push af;							// 
	call L17A0;							// 
	pop de;								// 
	ret c;								// 
	ld a, d;							// 
	cp $e5;								// RESTORE
	jr z, L172A;						// 
	call L177A;							// 
	ret c;								// 

L172A:
	ld hl, $3c1b;						// 
	rst $30;							// 
	ld bc, $07cd;						// 
	ld a, (de);							// 
	call L17DB;							// 
	call L19B9;							// 
	ld a, ($3c01);						// 
	push af;							// 
	and %00000011;						// 
	or %00000010;						// 
	ld (ix + 1), a;						// 
	pop af;								// 
	or a;								// 
	bit 6, a;							// 
	jr z, L1767;						// 
	call $34ca;							// 
	call $3192;							// 
	ret c;								// 
	ld hl, $2d00;						// 
	call $313c;							// 
	ret c;								// 
	set 3, (ix + 1);					// 
	ld a, $80;							// 
	ld (ix + 11), a;					// 
	ld (ix + 15), a;					// 
	call L1697;							// 
	ret c;								// 

L1767:
	call L1773;							// 
	ld hl, $2c80;						// 
	ld a, ($3df9);						// 
	ld b, a;							// 
	or b;								// 
	ret;								// 

L1773:
	ld a, (iy + _err_nr);				// 
	ld (ix + 0), a;						// 
	ret;								// 

L177A:
	ld a, h;							// 
	and %00000001;						// 
	add a, l;							// 
	ld bc, L001F;						// 
	jr nz, L1794;						// 
	set 2, (ix + 1);					// 
	call L1250;							// 
	res 2, (ix + 1);					// 
	ld hl, $2600;						// 
	ld bc, $01ff;						// 

L1794:
	ld a, (hl);							// 
	ld d, h;							// 
	ld e, l;							// 
	inc de;								// 
	ld (hl), 0;							// 
	ldir;								// 
	call L17E7;							// 
	ret;								// 

L17A0:
	ld hl, $3c06;						// 
	ld bc, $0b;							// 
	ldir;								// 
	xor a;								// 
	ld (de), a;							// 
	ex de, hl;							// 
	inc hl;								// 

L17AC:
	ld (hl), a;							// 
	inc hl;								// 
	ld (hl), a;							// 
	inc hl;								// 
	rst $08;							// 
	defb m_getdate;						// 
	rst $30;							// 
	nop;								// 
	xor a;								// 
	ld (hl), a;							// 
	inc l;								// 
	ld (hl), a;							// 
	inc l;								// 
	ld (hl), a;							// 
	inc l;								// 
	ld (hl), a;							// 
	inc l;								// 
	rst $30;							// 
	nop;								// 
	ld (hl), a;							// 
	inc l;								// 
	ld (hl), a;							// 
	inc l;								// 
	ld b, a;							// 
	ld c, b;							// 
	ld d, c;							// 
	ld e, d;							// 
	rst $30;							// 
	nop;								// 
	push hl;							// 
	call L17E7;							// 
	pop hl;								// 
	ret c;								// 
	push hl;							// 
	call L115C;							// 
	ld hl, $3c1b;						// 
	rst $30;							// 
	nop;								// 
	pop hl;								// 
	or a;								// 
	ret;								// 

L17DB:
	ld b, 0;							// 
	ld c, b;							// 
	ld d, c;							// 
	ld e, d;							// 
	call L1135;							// 
	call L19D3;							// 
	ret;								// 

L17E7:
	ld hl, $2600;						// 
	call $313c;							// 
	push af;							// 
	xor a;								// 
	ld ($3c26), a;						// 
	pop af;								// 
	ret;								// 

L17F4:
	ld hl, $2600;						// 
	push hl;							// 
	call L11FB;							// 
	pop hl;								// 
	ret c;								// 

L17FD:
	ld a, $10;							// 
	sub (ix + 6);						// 
	sla a;								// 
	sla a;								// 
	sla a;								// 
	sla a;								// 
	sla a;								// 
	ld e, a;							// 
	ld d, 0;							// 
	rl d;								// 
	add hl, de;							// 
	ex de, hl;							// 
	or a;								// 
	ret;								// 

L1815:
	call L163E;							// 
	push bc;							// 
	push de;							// 
	ld l, (ix + 28);					// 
	ld h, (ix + 29);					// 
	ld de, $0c;							// 
	add hl, de;							// 
	call L17AC;							// 
	pop de;								// 
	pop bc;								// 
	ret c;								// 
	call $3108;							// 
	call nc, L10F3;						// 
	ret c;								// 
	call L17DB;							// 
	call L19B9;							// 
	call L1773;							// 
	ld hl, $1a7c;						// 
	ld ($3dee), hl;						// 
	call L1A21;							// 
	ld (ix + 0), 0;						// 
	jp L172A;							// 

L184A:
	ld a, ($3c01);						// 
	push af;							// 
	and %00000011;						// 
	ld (ix + 1), a;						// 
	call L115C;							// 
	call L1A07;							// 
	call L163E;							// 
	call L18D0;							// 
	ld l, (ix + 28);					// 
	ld h, (ix + 29);					// 
	ld de, $1c;							// 
	add hl, de;							// 
	call L1897;							// 
	pop af;								// 
	bit 6, a;							// 
	jr z, $1894;						// 
	ld hl, $2d00;						// 
	ld bc, $80;							// 
	call L1681;							// 
	ret c;								// 
	call L18B3;							// 
	ld l, $0f;							// 
	jr z, L188B;						// 
	ld (ix + 15), 0;					// 
	push hl;							// 
	call L189E;							// 
	pop hl;								// 

L188B:
	ld de, ($3c23);						// 
	ld bc, 8;							// 
	rst $30;							// 
	ld b, $c3;							// 
	ld h, a;							// 
	rla;								// 

L1897:
	rst $30;							// 
	ld bc, $d3cd;						// 
	add hl, de;							// 
	or a;								// 
	ret;								// 

L189E:
	push af;							// 
	ld a, $ff;							// 
	ld (hl), a;							// 
	inc l;								// 
	call L19E0;							// 
	ld (hl), e;							// 
	inc l;								// 
	ld (hl), d;							// 
	inc l;								// 
	ld b, 5;							// 
	xor a;								// 

L18AD:
	ld (hl), a;							// 
	inc l;								// 
	djnz L18AD;							// 
	pop af;								// 
	ret;								// 

L18B3:
	push hl;							// 
	ld de, $40;							// 
	ld bc, 9;							// 

L18BA:
	ld a, (de);							// 
	cpi;								// 
	jr nz, L18C3;						// 
	inc de;								// 
	jp pe, L18BA;						// 

L18C3:
	pop hl;								// 
	ret nz;								// 
	ld c, $7f;							// 
	xor a;								// 

L18C8:
	add a, (hl);						// 
	cpi;								// 
	jp pe, L18C8;						// 
	cp (hl);							// 
	ret;								// 

L18D0:
	call L19ED;							// 
	call L12A6;							// 
	ld b, 0;							// 
	ld c, b;							// 
	ld d, c;							// 
	ld e, d;							// 
	jp L19B9;							// 
	bit 0, (ix + 1);					// 
	ld a, 8;							// 
	scf;								// 
	ret z;								// 
	push hl;							// 
	call L1989;							// 
	pop hl;								// 
	ld a, c;							// 
	or b;								// 
	ret z;								// 

L18EE:
	res 2, (ix + 1);					// 

L18F2:
	push bc;							// 

L18F3:
	ld e, (ix + 15);					// 
	ld a, (ix + 16);					// 
	and %00000001;						// 
	ld d, a;							// 
	call L1934;							// 
	jr c, L1929;						// 
	push bc;							// 
	push hl;							// 
	ld hl, $0200;						// 
	sbc hl, de;							// 
	ex de, hl;							// 
	ld h, b;							// 
	ld l, c;							// 
	sbc hl, de;							// 
	jr c, L1911;						// 
	ld b, d;							// 
	ld c, e;							// 

L1911:
	pop hl;								// 
	push bc;							// 
	call L1945;							// 
	pop de;								// 
	pop bc;								// 
	jr c, L1929;						// 
	ld a, c;							// 
	sub e;								// 
	ld c, a;							// 
	ld a, b;							// 
	sbc a, d;							// 
	ld b, a;							// 
	or c;								// 
	ex de, hl;							// 
	call L19AB;							// 
	ex de, hl;							// 
	jr nz, L18F3;						// 
	or a;								// 

L1929:
	pop de;								// 
	push af;							// 
	ex de, hl;							// 
	or a;								// 
	sbc hl, bc;							// 
	ld b, h;							// 
	ld c, l;							// 
	ex de, hl;							// 
	pop af;								// 
	ret;								// 

L1934:
	or e;								// 
	ret nz;								// 
	push de;							// 
	push bc;							// 
	push hl;							// 
	call L19C6;							// 
	rst $30;							// 
	dec c;								// 
	call nz, L1250;						// 
	pop hl;								// 
	pop bc;								// 
	pop de;								// 
	ret;								// 

L1945:
	ld a, b;							// 
	sub 2;								// 
	or c;								// 
	jr nz, L195c;						// 
	bit 2, (ix + 1);					// 
	jp nz, L1342;						// 
	bit 5, (ix + 1);					// 
	jp nz, L11FB;						// 
	jp L1235;							// 

L195c:
	push bc;							// 
	push hl;							// 
	call L1202;							// 
	pop de;								// 
	pop bc;								// 
	ret c;								// 
	ld l, (ix + 15);					// 
	ld a, (ix + 16);					// 
	and %00000001;						// 
	add a, h;							// 
	ld h, a;							// 
	bit 2, (ix + 1);					// 
	jr nz, L1983;						// 
	bit 5, (ix + 1);					// 
	jr z, L197F;						// 
	ldir;								// 
	ex de, hl;							// 
	or a;								// 
	ret;								// 

L197F:
	rst $30;							// 
	ld b, mmcspi;						// 
	ret;								// 

L1983:
	ex de, hl;							// 
	rst $30;							// 
	rlca;								// 
	jp L122C;							// 

L1989:
	push bc;							// 
	call L19C6;							// 
	ld h, (ix + 12);					// 
	ld l, (ix + 11);					// 
	or a;								// 
	sbc hl, de;							// 
	ex de, hl;							// 
	ld h, (ix + 14);					// 
	ld l, (ix + 13);					// 
	sbc hl, bc;							// 
	pop bc;								// 
	ld a, l;							// 
	or h;								// 
	ret nz;								// 
	ld h, d;							// 
	ld l, e;							// 
	sbc hl, bc;							// 
	ret nc;								// 
	ld b, d;							// 
	ld c, e;							// 
	ret;								// 

L19AB:
	push de;							// 
	push bc;							// 
	call L19C6;							// 
	call L0831;							// 
	call L19B9;							// 
	pop bc;								// 
	pop de;								// 
	ret;								// 

L19B9:
	ld (ix + 15), e;					// 
	ld (ix + 16), d;					// 
	ld (ix + 17), c;					// 
	ld (ix + 18), b;					// 
	ret;								// 

L19C6:
	ld e, (ix + 15);					// 
	ld d, (ix + 16);					// 
	ld c, (ix + 17);					// 
	ld b, (ix + 18);					// 
	ret;								// 

L19D3:
	ld (ix + 11), e;					// 
	ld (ix + 12), d;					// 
	ld (ix + 13), c;					// 
	ld (ix + 14), b;					// 
	ret;								// 

L19E0:
	ld e, (ix + 11);					// 
	ld d, (ix + 12);					// 
	ld c, (ix + 13);					// 
	ld b, (ix + 14);					// 
	ret;								// 

L19ED:
	ld (ix + 7), e;						// 
	ld (ix + 8), d;						// 
	ld (ix + 9), c;						// 
	ld (ix + 10), b;					// 
	ret;								// 

L19FA:
	ld e, (ix + 7);						// 
	ld d, (ix + 8);						// 
	ld c, (ix + 9);						// 
	ld b, (ix + 10);					// 
	ret;								// 

L1A07:
	ld (ix + 2), e;						// 
	ld (ix + 3), d;						// 
	ld (ix + 4), c;						// 
	ld (ix + 5), b;						// 
	ret;								// 

L1A14:
	ld e, (ix + 2);						// 
	ld d, (ix + 3);						// 
	ld c, (ix + 4);						// 
	ld b, (ix + 5);						// 
	ret;								// 

L1A21:
	push bc;							// 
	push de;							// 
	ld hl, $2420;						// 
	ld b, $0f;							// 

L1A28:
	ld a, (hl);							// 
	and a;								// 
	jr z, L1A39;						// 
	ld a, ixh;							// 
	cp h;								// 
	jr nz, L1A36;						// 
	ld a, ixl;							// 
	cp l;								// 
	jr z, L1A39;						// 

L1A36:
	call L1A43;							// 

L1A39:
	ld de, $20;							// 
	add hl, de;							// 
	djnz L1A28;							// 
	pop de;								// 
	pop bc;								// 
	or a;								// 
	ret;								// 

L1A43:
	ld a, (hl);							// 
	cp (ix + 00);						// 
	ret nz;								// 
	push hl;							// 
	ld a, 6;							// 
	add a, l;							// 
	ld l, a;							// 
	ld a, (hl);							// 
	cp (ix + 6);						// 
	pop hl;								// 
	ret nz;								// 
	push bc;							// 
	push hl;							// 
	ld a, 5;							// 
	add a, l;							// 
	ld l, a;							// 
	call L1A14;							// 
	call L0694;							// 
	call z, restart_28;					// 
	pop hl;								// 
	pop bc;								// 
	ret;								// 

	pop hl;								// 
	pop hl;								// 
	pop hl;								// 
	pop hl;								// 
	pop de;								// 
	pop bc;								// 
	scf;								// 
	ret;								// 

	dec l;								// 
	dec l;								// 
	dec l;								// 
	res 4, (hl);						// 
	ld a, $0a;							// 
	add a, l;							// 
	ld l, a;							// 
	call L19E0;							// 
	jp L06A9;							// 
	dec l;								// 
	dec l;								// 
	dec l;								// 
	set 4, (hl);						// 
	res 3, (hl);						// 
	ld a, 6;							// 
	add a, l;							// 
	ld l, a;							// 
	ex de, hl;							// 
	push ix;							// 
	pop hl;								// 
	ld a, 7;							// 
	add a, l;							// 
	ld l, a;							// 
	ld bc, L0015;						// 
	ldir;								// 
	ret;								// 

	dec d;								// 
	dec h;								// 
	ret;								// 

	ld a, (de);							// 
	and e;								// 
	ld a, (de);							// 
	and c;								// 
	ld a, (de);							// 
	nop;								// 
	nop;								// 
	rrca;								// 
	dec h;								// 
	or a;								// 
	ret;								// 

	call L1B13;							// 
	ld a, ixl;							// 
	out (mmcram), a;					// Set divMMC RAM page...
	ld a, ($3df8);						// 
	ld ixh, a;							// 
	xor a;								// 
	out (mmcram), a;					// divMMC RAM page 0
	call L1AF4;							// 
	ret c;								// 
	ld e, (iy + _newppc);				// 
	ld a, ixl;							// 
	out (mmcram), a;					// Set divMMC RAM page...
	ld a, e;							// 
	push de;							// 
	rst $08;							// 
	defb f_write;						// 
	pop de;								// 
	push af;							// 
	ld a, e;							// 
	rst $08;							// 
	defb f_sync;						// 
	pop af;								// 
	jr L1AE6;							// 
	call L1B13;							// 
	ld a, ixl;							// 
	out (mmcram), a;					// Set divMMC RAM page...
	ld a, ($3df8);						// 
	ld ixh, a;							// 
	xor a;								// 
	out (mmcram), a;					// divMMC RAM page 0
	call L1AF4;							// 
	ret c;								// 
	ld e, (iy + _newppc);				// 
	ld a, ixl;							// 
	out (mmcram), a;					// Set divMMC RAM page...
	ld a, e;							// 
	rst $08;							// 
	defb f_read;						// 

L1AE6:
	ld iyl, a;							// 

L1AE8:
	ld a, ixh;							// 
	ld ($3df8), a;						// 
	ld a, 0;							// 
	out (mmcram), a;					// divMMC RAM page 0
	ld a, iyl;							// 
	ret;								// 

L1AF4:
	ld a, (iy + _newppc);				// 
	push hl;							// 
	ld l, 0;							// 
	rst $08;							// 
	defb f_seek;						// 
	pop hl;								// 
	ret c;								// 
	push hl;							// 
	ld hl, $80;							// 
	ld a, (iy + _flags);				// 
	and %00000111;						// 
	dec a;								// 
	jr z, L1B0E;						// 

L1B0A:
	add hl, hl;							// 
	dec a;								// 
	jr nz, L1B0A;						// 

L1B0E:
	ld b, h;							// 
	ld c, l;							// 
	pop hl;								// 
	or a;								// 
	ret;								// 

L1B13:
	call L1B29;							// 
	ld a, (iy + _flags);				// 
	and %00000111;						// 
	dec a;								// 
	ret z;								// 

L1B1D:
	sla e;								// 
	rl d;								// 
	rl c;								// 
	rl b;								// 
	dec a;								// 
	jr nz, L1B1D;						// 
	ret;								// 

L1B29:
	ld a, 7;							// 

L1B2B:
	sla e;								// 
	rl d;								// 
	rl c;								// 
	rl b;								// 
	dec a;								// 
	jr nz, L1B2B;						// 
	ret;								// 

	org $1b37
copyright:
	defb "UnoDOS 3.12 (Wolf)       ", $0d, $0d;
	defb $7f, " 2022 Source Solutions, Inc.", $0d, 0

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
	ld hl, 22862;						// 
	ld de, 28;							// 
	ld b, 4;							// 

;	org $1b72
outer_loop:
	ld a, 4;							// 

;	org $1b74
inner_loop:
	ld (hl), %01000111;					// bright white
	inc hl;								// 
	dec a;								// 
	jr nz, inner_loop;					// do four cells
	add hl, de;							// 
	djnz outer_loop;					// do four rows
	ret;								// 

;	org $1b7e
boot_icon:

;	// wolf
	defw 20302;
	defb %00000000, %01100000, %00000110, %00000000;
	defw 18542;
	defb %00000000, %01111011, %11011110, %00000000;
	defw 18798;
	defb %00000000, %01010111, %11101010, %00000000;
	defw 19054;
	defb %00000000, %01001011, %11010010, %00000000;
	defw 19310;
	defb %00000000, %01011111, %11111010, %00000000;
	defw 19566;
	defb %00000000, %00111111, %11111100, %00000000;
	defw 19822;
	defb %00000000, %01100011, %11000110, %00000000;
	defw 20078;
	defb %00000000, %11110101, %10101111, %00000000;
	defw 20334;
	defb %00000001, %11111001, %10011111, %10000000;
	defw 18574;
	defb %00000001, %01111101, %10111110, %10000000;
	defw 18830;
	defb %00000001, %11111011, %11011111, %10000000;
	defw 19086;
	defb %00000000, %10111011, %11011101, %00000000;
	defw 19342;
	defb %00000000, %01011111, %11111010, %00000000;
	defw 19598;
	defb %00000000, %01111100, %00111110, %00000000;
	defw 19854;
	defb %00000000, %00101100, %00110100, %00000000;
	defw 20110;
	defb %00000000, %00111111, %11111100, %00000000;
	defw 20366;
	defb %00000000, %00010100, %00101000, %00000000;
	defw 18606;
	defb %00000000, %00000011, %11000000, %00000000;

;	// UnoDOS 3 logo
;	defw 20302;
;	defb %00000001, %10011100, %11111111, %00000000;
;	defw 18542;
;	defb %00000001, %10011110, %11111111, %10000000;
;	defw 18798;
;	defb %00000001, %10011111, %11000001, %10000000;
;	defw 19054;
;	defb %00000001, %10011011, %11011001, %10000000;
;	defw 19310;
;	defb %00000001, %11111001, %11011111, %10000000;
;	defw 19566;
;	defb %00000000, %11110000, %11001111, %00000000;
;	defw 19822;
;	defb %00000000, %00000000, %00000000, %00000000;
;	defw 20078;
;	defb %00000001, %11100011, %11000111, %10000000;
;	defw 20334;
;	defb %00000001, %11110111, %11101111, %10000000;
;	defw 18574;
;	defb %00000001, %10110110, %01101100, %00000000;
;	defw 18830;
;	defb %00000001, %10110110, %01101111, %00000000;
;	defw 19086;
;	defb %00000001, %10110110, %01100111, %10000000;
;	defw 19342;
;	defb %00000001, %10110110, %01100001, %10000000;
;	defw 19598;
;	defb %00000001, %11110111, %11101111, %10000000;
;	defw 19854;
;	defb %00000001, %11100011, %11001111, %00000000;
;	defw 20110;
;	defb %00000000, %00000000, %00000000, %00000000;
;	defw 20366;
;	defb %00000001, %10110110, %11110111, %10000000;
;	defw 18606;
;	defb %00000001, %10110110, %11110111, %10000000;

;	// Chloe logo
;	defw 20302;
;	defb %00000000, %00000111, %11100000, %00000000;
;	defw 18542;
;	defb %00000000, %00011111, %11111000, %00000000;
;	defw 18798;
;	defb %00000000, %00111111, %00001100, %00000000;
;	defw 19054;
;	defb %00000000, %01111100, %00000000, %00000000;
;	defw 19310;
;	defb %00000000, %11111001, %11110000, %00000000;
;	defw 19566;
;	defb %00000000, %11110011, %11111100, %00000000;
;	defw 19822;
;	defb %00000001, %11110111, %11111110, %00000000;
;	defw 20078;
;	defb %00000001, %11110111, %00011110, %00000000;
;	defw 20334;
;	defb %00000001, %11110110, %00001111, %00000000;
;	defw 18574;
;	defb %00000001, %11110011, %01001111, %00000000;
;	defw 18830;
;	defb %00000001, %11110001, %11001111, %00000000;
;	defw 19086;
;	defb %00000001, %11111000, %00011111, %00000000;
;	defw 19342;
;	defb %00000000, %11111110, %01111111, %00000000;
;	defw 19598;
;	defb %00000000, %11111111, %11111110, %00000000;
;	defw 19854;
;	defb %00000000, %01111111, %11111110, %00000000;
;	defw 20110;
;	defb %00000000, %00111111, %11111100, %00000000;
;	defw 20366;
;	defb %00000000, %00011111, %11111000, %00000000;
;	defw 18606;
;	defb %00000000, %00000111, %11100000, %00000000;

;	org $1bea
boot_chime:
	ld hl, $fffe;						// L = AY-0, H = AY-1 / register port
	ld d, $bf;							// D = data port
	ld c, $fd;							// low byte of AY port
	ld ix, data;						// pointer
	
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
	call out_pair;						// output a pair
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
	out (c), e;							// write value in E to port
	ld b, d;							// set data port
	out (c), a;							// write value in A to port
	ret;								// end of subroutine

	org $1c58
sys_filename:
	defm "unodos";						// UNODOS.SYS filename
	defb 0;								// end marker

L1C5F:
	ld l, l;							// SPI data table entry
	inc e;								// increment index for next table entry
	ld d, c;							// move C to D
	ld e, $ea;							// set E to SPI control value
	dec e;								// decrement E
	ld l, e;							// save E in L
	inc e;								// increment E
	nop;								// padding
	nop;								// padding
	ld l, e;							// save E in L register  
	inc e;								// increment E for next operation
	or a;								// clear carry flag
	ret;								// return success

	ld l, a;							// save command
	and %11100000;						// mask upper 3 bits
	cp $80;								// check if valid SD command
	scf;								// set carry flag (assume error)
	ret nz;								// return if invalid command
	ld a, l;							// restore command
	call L1C8B;							// execute SD card command
	ret c;								// return if error
	call L1F04;							// process command result
	ld a, (iy + _err_nr);				// get error status
	ret;								// return to caller

L1C80:
	and %00001000;						// check bit 3 (card type flag)
	ld a, $f6;							// default SPI command value
	jr z, L1C87;						// if bit 3 clear, use default
	dec a;								// adjust for different card type

L1C87:
	ld ($3dfe), a;						// store SPI command value
	ret;								// return to caller

L1C8B:
	ld ($3df2), de;						// save DE parameter
	ld ($3dfa), a;						// save command
	call L1C80;							// prepare SPI interface
	call L1D40;							// send command to SD card
	ret c;								// return if error
	call L1D00;							// process response
	ret c;								// return if error
	ld hl, $3e00;						// data buffer address
	ld a, $49;							// command code
	call L1D2F;							// execute command
	ret c;								// return if error
	ld hl, $3e20;						// next buffer address
	ld a, $4a;							// next command code
	call L1D2F;							// execute command
	ret c;								// return if error
	ld a, ($3dfa);						// get stored command
	call L1E8A;							// execute SPI command
	ld a, $7a;							// set command code
	ld de, 0;							// clear DE register
	call L1D81;							// call SPI routine
	ret c;								// return if error
	ld a, b;							// get B register value
	and %01000000;						// test bit 6 (card type flag)
	or %00000011;						// set lower 2 bits
	ld (iy + _flags), a;				// store in flags register
	and %01000000;						// check bit 6 (initialization flag?)
	call z, L1CF7;						// if clear, initialize SD card
	ld hl, $3e05;						// point to SPI data
	call L1EA3;							// send SPI command
	push iy;							// save IY register
	pop hl;								// copy IY to HL
	inc hl;								// advance pointer
	inc hl;								// advance to next byte
	inc hl;								// advance to next byte
	inc hl;								// point to data offset
	rst $30;							// report error if needed
	nop;								// padding instruction
	ld hl, $3e21;						// source address
	ld de, $3e20;						// destination address
	push de;							// save destination
	ldi;								// copy byte and increment
	ldi;								// copy byte and increment
	ld a, $20;							// space character
	ld (de), a;							// store space
	pop hl;								// restore destination as source
	ld de, ($3df2);						// get target address
	ld bc, 8;							// 8 bytes to copy
	rst $30;							// report error
	ld b, $fd;							// set timeout counter
	ld a, (hl);							// get data
	nop;								// timing delay
	or a;								// set status flags
	ret;								// return to caller

L1CF7:
	ld a, $50;							// SD card initialization command
	ld de, $0200;						// timeout values
	ld b, e;							// copy E to B
	ld c, e;							// copy E to C
	jr L1D6C;							// jump to initialization routine

L1D00:
	ld a, $48;							// CMD8 - send interface condition
	ld de, $01aa;						// voltage range and check pattern
	call L1D81;							// send SD command
	ld hl, $1d65;						// address for SDHC cards
	jr c, L1D10;						// if error, try SDHC
	ld hl, $1d20;						// address for standard SD cards

L1D10:
	ld bc, $78;							// retry counter (120 attempts)

L1D13:
	push bc;							// save retry counter
	call L1D2E;							// call initialization routine
	pop bc;								// restore retry counter
	ret nc;								// return if successful
	djnz L1D13;							// decrement B and retry
	dec c;								// decrement C counter
	jr nz, L1D13;						// retry if C not zero
	scf;								// set carry flag (error)
	ret;								// return with error

	ld a, $77;							// CMD55 - application specific command
	call L1D67;							// send SD command
	ld a, $69;							// ACMD41 - SD send operating condition
	ld bc, $4000;						// HCS bit set (supports SDHC)
	ld d, c;							// clear D
	ld e, c;							// clear E
	jr L1D6C;							// send command

L1D2E:
	jp (hl);							// jump to card-specific initialization

L1D2F:
	call L1D67;							// send command to SD card
	ret c;								// return if error occurred
	call L1DC4;							// wait for FE response token
	ret c;								// return if timeout or error
	ld b, $12;							// set byte count to 18 bytes
	ld c, mmcspi;						// set port address for SPI
	inir;								// Read 12 bytes from divMMC SPI port into (HL)
	or a;								// clear carry flag (success)
	jr L1D5E;							// deselect SD card and return

L1D40:
	call L1D5E;							// deselect all SD cards
	ld b, $0a;							// set loop counter to 10

L1D45:
	ld a, $ff;							// load FF (dummy byte)
	out (mmcspi), a;					// Write FF to divMMC SPI port
	djnz L1D45;							// repeat 10 times
	call L1DE0;							// select SD card
	ld b, 8;							// set retry counter to 8

L1D50:
	ld a, $40;							// CMD0 - GO_IDLE_STATE command
	ld de, 0;							// clear argument (32-bit = 0)
	push bc;							// save retry counter
	call L1D74;							// send command and get response
	pop bc;								// restore retry counter
	ret nc;								// return if command successful
	djnz L1D50;							// retry if attempts remaining
	scf;								// set carry flag (error)

L1D5E:
	push af;							// save accumulator
	ld a, $ff;							// deselect value (all bits high)
	out (mmcdev), a;						// Select all available SD cards
	pop af;								// restore accumulator
	ret;								// return to caller

	ld a, $41;							// CMD1 - SEND_OP_COND command

L1D67:
	ld bc, 0;							// clear BC (argument high word)
	ld d, b;							// clear D (argument byte 1)
	ld e, c;							// clear E (argument byte 0)

L1D6C:
	call L1D9A;							// send SPI command
	or a;								// test response (zero = success)
	ret z;								// return if successful

L1D71:
	scf;								// set carry flag (error)
	jr L1D5E;							// deselect card and return

L1D74:
	ld bc, 0;							// clear BC (argument high word)
	call L1D9A;							// send SPI command
	ld b, a;							// save response in B
	and %11111110;						// mask out bit 0 (ignore busy bit)
	ld a, b;							// restore full response
	jr nz, L1D71;						// jump to error if bad response
	ret;								// return (carry clear = success)

L1D81:
	call L1D74;							// send command and get basic response
	ret c;								// return if command failed
	push af;							// save command response
	call L1DD2;							// poll the SPI port for a non FFh value
;										// to be returned. Result returned in A.
	ld h, a;							// store first data byte in H
	call L1DD2;							// poll the SPI port for a non FFh value
;										// to be returned. Result returned in A.
	ld l, a;							// store second data byte in L
	call L1DD2;							// poll the SPI port for a non FFh value
;										// to be returned. Result returned in A.
	ld d, a;							// store third data byte in D
	call L1DD2;							// poll the SPI port for a non FFh value
;										// to be returned. Result returned in A.
	ld e, a;							// store fourth data byte in E
	ld b, h;							// copy H to B (return data)
	ld c, l;							// copy L to C (return data)
	pop af;								// restore command response
	ret;								// return to caller

L1D9A:
	call L1DE0;							// select SD card
	out (mmcspi), a;						// write to divMMC SPI port
	push af;							// save command byte
	ld a, b;							// get argument byte 3
	nop;								// timing delay
	out (mmcspi), a;					// write to divMMC SPI port
	ld a, c;							// get argument byte 2
	nop;								// timing delay
	out (mmcspi), a;						// write to divMMC SPI port
	ld a, d;							// get argument byte 1
	nop;								// timing delay
	out (mmcspi), a;						// write to divMMC SPI port
	ld a, e;							// get argument byte 0
	nop;								// timing delay
	out (mmcspi), a;						// write to divMMC SPI port
	pop af;								// restore command byte
	cp '@';								// $40
	ld b, $95;							// CRC for CMD0
	jr z, L1DBF;						// jump if CMD0
	cp 'H';								// $48
	ld b, $87;							// CRC for CMD8
	jr z, L1DBF;						// jump if CMD8
	ld b, $ff;							// default CRC (dummy)

L1DBF:
	ld a, b;							// get CRC byte
	out (mmcspi), a;					// write to divMMC SPI port
	jr L1DD2;							// poll the SPI port for a non $FF value

L1DC4:
	ld b, $0a;							// set retry counter to 10

L1DC6:
	push bc;							// save retry counter
	call L1DD2;							// poll the SPI port for a non FFh value
;										// to be returned. Result returned in A.
	pop bc;								// restore retry counter
	cp $fe;								// was the return code FE?
	ret z;								// return if so
	djnz L1DC6;							// retry if attempts remaining
	scf;								// set carry flag (timeout)
	ret;								// return with error

;	// Poll the SPI port up to 255*50 times, waiting for a non-FFh value to be returned
;	// Return results in A;
L1DD2:
	ld bc, $32;							// number of retries (C)=50*255 (12750)

L1DD5:
	in a, (mmcspi);						// read divMMC SPI port
	cp $ff;								// did I read FFh?
	ret nz;								// RET if not FFh
	djnz L1DD5;							// decrement B and loop back if B is not 0
	dec c;								// decrement C
	jr nz, L1DD5;						// if C is not 0 , loop back
	ret;								// return after 50 lots of 255 attempts

L1DE0:
	push af;							// save accumulator
	in a, (mmcspi);						// read divMMC SPI port
	ld a, ($3dfe);						// get SD card select value
	out (mmcdev), a;					// select SD card(s)
	pop af;								// restore accumulator
	ret;								// return to caller

	ld a, (iy + _flags);				// get system flags
	and %01000000;						// test bit 6 (some specific flag)
	call z, L1E97;						// call routine if flag clear
	ld a, (iy + _err_nr);				// get error number
	ld ixh, a;							// save error in IXH
	ld a, ixl;							// get divMMC page from IXL
	out (mmcram), a;					// Set divMMC ram page...
	ld a, ixh;							// restore error number
	call L1C80;							// call error handling routine
	ld a, $58;							// CMD24 - WRITE_BLOCK command
	call L1D6C;							// send command to SD card
	ld a, 6;							// error code 6 (write error)
	jr c, L1E30;						// jump to error handler if failed
	ld a, $fe;							// start block token
	out (mmcspi), a;					// write FE to divMMC SPI port
	ld bc, $eb;							// set count for 512 bytes (2x235)
	otir;								// output 235 bytes from (HL) to SPI
	otir;								// output 235 bytes from (HL) to SPI  
	ld a, $ff;							// dummy CRC byte
	out (mmcspi), a;					// write FF to divMMC SPI port
	nop;								// timing delay
	out (mmcspi), a;					// write FF to divMMC SPI port
	call L1DD2;							// poll the SPI port for a non FFh value
;										// to be returned. Result returned in A.
	and $1f;							// mask response bits (keep lower 5 bits)
	cp 5;								// check if response is 5 (data accepted)
	ld a, 6;							// error code 6 (write error)
	scf;								// set carry flag (error)
	jr nz, L1E30;						// jump to error if not accepted

	org $1E2A
L1E2A:
	call L1DD2;							// poll the SPI port for a non FFh value
	;									// to be returned. Result returned in A.
	or a;								// test if zero
	jr z, L1E2A;						// loop if zero

L1E30:
	call L1D5E;							// this routine probably sets normal CPU / interrupt
	ld b, a;							// save value of A
	xor a;								// LD A, 0
	out (mmcram), a;					// divMMC RAM page 0
	ld a, b;							// restore value of A
	ret;								// and exit

;	org $1e39
data:
	defb 61, 13;						// r0-1		C1
	defb 159, 6;						// r2-3		C2				
	defb 201, 2;						// r4-5		D#3

	defb 0, %11111000;					// r6-7		enable tone for ABC
	defb 13, 13, 13;					// r8-10	86% volume for ABC

	defb 54, 2;							// r0-1		G3
	defb 220, 1;						// r2-3		A#3				
	defb 121, 1;						// r4-5		D4

	defb 0, %11111000;					// r6-7		enable tone for DEF
	defb 13, 13, 13;					// r8-10	86% volume for DEF

	org $1E51
L1E51:
	ld a, (iy + _flags);				// get system flags
	and %01000000;						// test bit 6 (some specific flag)
	call z, L1E97;						// call routine if flag clear
	ld a, (iy + _err_nr);				// get error number
	ld ixh, a;							// save error in IXH
	ld a, ixl;							// get divMMC page from IXL
	out (mmcram), a;					// Set divMMC RAM page...
	ld a, ixh;							// restore error number
	call L1C80;							// call error handling routine
	ld a, $51;							// CMD17 - READ_SINGLE_BLOCK command
	call L1D6C;							// send command to SD card
	jr nc, L1E75;						// jump to read data if successful

	org $1e71
L1E71:
	ld a, 6;							// error code 6 (read error)
	jr L1E30;							// jump to error handler

L1E75:
	call L1DC4;							// wait for FE response token
	jr c, L1E71;						// jump to error if timeout
	ld bc, $eb;							// set count for 512 bytes (2x235)
	inir;								// read ?255? bytes from divMMC SPI port to (HL)
	inir;								// read ?255? bytes from divMMC SPI port to (HL)
	nop;								// timing delay
	in a, (mmcspi);						// read divMMC SPI port
	nop;								// timing delay
	in a, (mmcspi);						// read divMMC SPI port
	or a;								// clear carry flag (success)
	jr L1E30;							// jump to completion

L1E8A:
	call L032E;							// call utility routine
	ld hl, L1C5F;						// load address of routine
	ld (iy + _tv_flag), l;				// store low byte in TV flag
	ld (iy + _err_sp), h;				// store high byte in error SP
	ret;								// return to caller

L1E97:
	ld b, c;							// shift register arrangement
	ld c, d;							// move D to C
	ld d, e;							// move E to D  
	ld e, 0;							// clear E register

L1E9C:
	sla d;								// shift D left (arithmetic)
	rl c;								// rotate C left through carry
	rl b;								// rotate B left through carry
	ret;								// return to caller

L1EA3:
	ld a, (iy + _flags);				// get system flags
	and %01000000;						// test bit 6 (specific flag)
	jr z, L1EBC;						// jump if flag clear
	inc hl;								// increment HL pointer
	inc hl;								// increment HL pointer again
	ld a, (hl);							// load value from address HL
	and %00111111;						// mask upper 2 bits (keep lower 6)
	ld c, a;							// store masked value in C
	inc hl;								// advance pointer
	ld d, (hl);							// load next byte into D
	inc hl;								// advance pointer
	ld e, (hl);							// load next byte into E
	call $081c;							// call utility function
	call L1E97;							// call register shift routine
	jr L1E9C;							// jump to shift left routine

L1EBC:
	ld a, (hl);							// load byte from address HL
	and %00001111;						// mask upper nibble (keep lower 4 bits)
	push af;							// save masked value on stack
	inc hl;								// advance pointer
	ld a, (hl);							// load next byte
	and %00000011;						// mask all but lower 2 bits
	ld d, a;							// store in D
	inc hl;								// advance pointer
	ld e, (hl);							// load next byte into E
	inc hl;								// advance pointer
	ld a, (hl);							// load next byte
	and %11000000;						// mask all but upper 2 bits
	add a, a;							// shift A left (multiply by 2)
	rl e;								// rotate E left through carry
	rl d;								// rotate D left through carry
	add a, a;							// shift A left again (total *4)
	rl e;								// rotate E left through carry
	rl d;								// rotate D left through carry
	inc de;								// increment DE register pair
	inc hl;								// advance pointer
	ld a, (hl);							// load next byte
	and %00000011;						// mask all but lower 2 bits
	ld b, a;							// store masked value in B
	inc hl;								// advance pointer
	ld a, (hl);							// load next byte
	and %10000000;						// mask all but upper bit
	add a, a;							// shift left (extract bit 7 to carry)
	rl b;								// rotate B left through carry
	inc b;								// increment B
	inc b;								// increment B again
	pop af;								// restore original masked value
	add a, b;							// add B to A
	ld bc, 0;							// clear BC register pair
	call L1EF8;							// call bit shifting routine
	ld e, d;							// move D to E
	ld d, c;							// move C to D
	ld c, b;							// move B to C
	ld b, 0;							// clear B register
	srl c;								// shift C right logical
	rr d;								// rotate D right through carry
	rr e;								// rotate E right through carry
	ret;								// return to caller

L1EF8:
	sla e;								// shift E left arithmetic
	rl d;								// rotate D left through carry
	rl c;								// rotate C left through carry
	rl b;								// rotate B left through carry
	dec a;								// decrement counter
	jr nz, L1EF8;						// loop if counter not zero
	ret;								// return to caller

L1F04:
	ld bc, 0;							// clear BC register pair
	ld d, b;							// clear D register
	ld e, c;							// clear E register
	ld hl, $3e00;						// load HL with address $3E00
	rst $08;							// call system function
	defb disk_read;						// disk read function code
	ret c;								// return if error occurred
	ld hl, ($3ffe);						// load HL from address $3FFE
	ld a, h;							// copy H to A
	and l;								// AND A with L
	scf;								// set carry flag (error)
	ret nz;								// return if result not zero
	push iy;							// save IY on stack
	pop hl;								// restore into HL
	ld de, 8;							// set offset 8
	add hl, de;							// add offset to HL
	ex de, hl;							// exchange DE and HL
	ld b, 4;							// set loop counter to 4
	ld hl, $3fbe;						// load HL with address $3FBE

L1F23:
	ld a, (hl);							// load byte from address HL
	and %01111111;						// mask upper bit (clear bit 7)
	inc hl;								// increment HL pointer
	inc hl;								// increment HL pointer
	inc hl;								// increment HL pointer
	inc hl;								// increment HL pointer
	jr nz, L1F32;						// jump if not zero
	or (hl);							// OR A with value at HL
	jr z, L1F32;						// jump if zero
	inc (iy + _err_nr);					// increment error number

L1F32:
	ld a, b;							// copy B to A (preserve counter)
	ld bc, 4;							// set BC to 4 bytes to skip
	add hl, bc;							// add offset to HL
	ld c, 8;							// set byte count to 8
	ldir;								// copy 8 bytes from (HL) to (DE)
	ld b, a;							// restore counter
	djnz L1F23;							// loop if counter not zero
	ret;								// return to caller

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

;	// vector table for 'dot' commands
	org $1FCA
	jp L24F2;							// V24F2 - vector to system function
	org $1FCD
	jp L24E6;							// V24E6 - vector to system function
	org $1FD0
	jp pr_str;							// v_pr_str - print string routine (05_api.asm)
	org $1FD3
	jp L0861;							// V0861 - numeric display routine (05_api.asm)
	org $1FD6
	jp L089A;							// V089A - file size display routine (05_api.asm)
	org $1FD9
	jp L0DEB;							// V0DEB - screen channel open (08_memory.asm)
	org $1FDC
	jp L2488;							// V2488 - vector to system function
	org $1FDF
	jp L24A6;							// V24A6 - vector to system function
	org $1FE2
	jp L24C1;							// V24C1 - vector to system function
	org $1FE5
	jp L24CD;							// V24CD - vector to system function
	org $1FE8
	jp L24F5;							// V24F5 - vector to system function
	org $1FEB
	jp L2502;							// V2502 - vector to system function
	org $1FEE
	jp pr_msg;							// v_pr_msg - message print routine (07_error.asm)
	org $1FF1
	jp L0297;							// V0297 - vector to system function

	org $1ff4
L1FF4:
	ex (sp), hl;						// exchange HL with top of stack
	jr L1FFA;							// jump to unmap routine
	ei;									// enable interrupts

;	// A jump to 1FF8 - 1FFF unmaps divMMC ROM/RAM when M1 goes high
L1FF8:
	ret;								// return (causes divMMC unmap on M1)

	ei;									// enable interrupts

;	// Jump from RST $18 handler to return to a system ROM routine whose address has 
;	// been placed in the stack
;	// Also called from taps.io
L1FFA:
	ret;								// return to ROM routine (unmaps divMMC)

L1FFB:
	jp (hl);							// jump to address in HL (with divMMC unmapped)
	rst $38;							// mask interrupt (filler)
	rst $38;							// mask interrupt (filler)
	rst $38;							// mask interrupt (filler)
	rst $38;							// mask interrupt (filler)

;	// UNODOS.SYS starts here
	org $2000
L2000:
	call L23C9;							// initialize UnoDOS system
	ret c;								// return if initialization failed
	jp $2800;							// jump to BASIC extension entry point
	call L23C9;							// re-initialize system
	ret c;								// return if failed
	jp $28be;							// jump to secondary entry point

L200E:
	jp $29af;							// jump to BASIC command processor

L2011:
	jp $294b;							// jump to BASIC statement handler

L2014:
	jp L233A;							// jump to cleanup routine
	nop;								// padding

L2019 equ $2019

	jr z, L2019;						// jump if condition met
	rst $38;							// call RST $38 (error handler)

	org $201e
L201E:
	jr L202F;							// jump to main initialization
	ld hl, 0;							// clear HL register
	add hl, sp;							// get current stack pointer
	ld h, a;							// save A in H
	ld a, l;							// get low byte of stack
	cp $0A;								// check stack boundary
	jr z, L202B;						// jump if at boundary
	pop bc;								// restore BC from stack

L202B:
	ld a, h;							// restore A register
	jp L1FFA;							// unmap divMMC and return

L202F:
	ld ($2E61), sp;						// save current stack pointer
	ld sp, $2e61;						// set new stack pointer
	push af;							// save AF register
	ld a, r;							// get refresh register (randomness)
	push af;							// save refresh register
	ld sp, $3de8;						// set UnoDOS system stack
	ld a, ($2E7A);						// get system status
	push hl;							// save registers
	push de;							// save DE register
	push bc;							// save BC register
	push af;							// save accumulator and flags
	ld a, 0;							// clear a flag
	ld ($201F), a;						// store flag
	call L21F6;							// call system initialization
	pop bc;								// restore registers
	ld a, b;							// get B register
	ld ($2E7A), a;						// save system status
	ld a, $0f;							// set completion flag
	ld ($201F), a;						// store flag
	pop bc;								// restore registers
	pop de;								// restore DE register
	pop hl;								// restore HL register
	jr nz, L2064;						// if not zero, continue
	ld sp, ($2E61);						// restore original stack pointer
	pop af;								// restore AF register
	ld ($2E61), sp;						// save original stack pointer again

L2064:
	ld sp, $2e5d;						// set system data stack
	ld a, ($2e5d);						// get system flags
	and 4								// mask bit 2
	ld ($2E5D), a;						// save masked flags
	push ix;							// save index registers
	push iy;							// save index register Y
	push bc;							// save main registers
	push de;							// save DE register
	push hl;							// save HL register
	ex af, af';							// switch to alternate registers
	exx;								// exchange register set
	push af;							// save alternate registers
	push bc;							// save alternate BC
	push de;							// save alternate DE
	push hl;							// save alternate HL
	ld a, i;							// get interrupt flag
	ld ($2e4a), a;						// save interrupt status
	ld sp, $3de8;						// set system stack
	ld a, $e9;							// set ROM page 0
	call L21E7;							// call ROM paging routine
	ld a, ($5800);						// get screen attribute
	rrca;								// rotate right
	rrca;								// rotate right to get next color bit
	rrca;								// extract color bits
	and 7;								// mask to get color value
	ld ($2e64), a;						// save border color
	call L2140;							// call hardware initialization
	ld a, 1;							// set interrupt mode
	ei;									// enable interrupts
	halt;								// wait for interrupt
	ld ($2e63), a;						// save interrupt flag
	im 1;								// set interrupt mode 1
	call L215E;							// call system setup
	call L218A;							// call additional setup
	ld hl, ($2e61);						// get stack pointer address
	push hl;							// save address
	ld a, (hl);							// get low byte
	inc hl;								// advance pointer
	ld h, (hl);							// get high byte
	ld l, a;							// restore low byte
	ld ($2e65), hl;						// save original stack value
	pop hl;								// restore address
	ld a, ($2e68);						// get system mode
	cp 2;								// check for special mode
	jr nz, L20BE;						// jump if not mode 2
	inc hl;								// advance pointer
	inc hl;								// advance to next address
	ld ($2E61), hl;						// update stack pointer

L20BE:
	ld a, ($3DF8);						// get ROM status
	ld ($2E79), a;						// save ROM status
	ld hl, $2e4a;						// point to system data
	call $2f00;							// call BASIC handler
	ld a, ($2E79);						// restore ROM status
	ld ($3df8), a;						// update ROM status
	ld a, ($2e68);						// get system mode
	cp 2;								// check for mode 2
	jr nz, L20DF;						// jump if not mode 2
	ld hl, ($2e61);						// get stack pointer
	dec hl;								// adjust stack
	dec hl;								// adjust stack pointer
	ld ($2e61), hl;						// save adjusted stack

L20DF:
	ld a, $f5;							// set ROM page
	call L21E7;							// call ROM paging routine
	im 1;								// set interrupt mode 1
	ei;									// enable interrupts
	halt;								// wait for interrupt
	di;									// disable interrupts
	ld a, ($2e67);						// get memory page
	ld bc, $7ffd;						// 128 paging register
	out (c), a;							// set memory page
	ld hl, $2e69;						// point to system variables
	call L2177;							// call system variable handler
	ld a, ($2e5d);						// get system flags
	bit 2, a;							// test bit 2
	ld hl, $86;							// set default value
	jr nz, L2109;						// jump if bit set
	inc hl;								// increment value
	ld a, ($2e5e);						// get counter
	inc a;								// increment counter
	ld ($2e5e), a;						// save counter

L2109:
	ld ($213e), hl;						// save HL at system location
	ld hl, $2e64;						// point to border color
	ld a, (hl);							// get border color value
	out (ula), a;						// set ULA border color
	dec hl;								// move to interrupt mode setting
	ld a, (hl);							// get interrupt mode
	im 0;								// set interrupt mode 0
	or a;								// test interrupt mode value
	jr z, L2120;						// jump if mode 0
	im 1;								// set interrupt mode 1
	dec a;								// decrement mode counter
	jr z, L2120;						// jump if mode 1
	im 2;								// set interrupt mode 2

L2120:
	ld hl, $2e4A;						// point to saved interrupt register
	ld a, (hl);							// get saved I register value
	ld i, a;							// restore interrupt register
	inc hl;								// advance to stack save area
	ld sp, hl;							// set stack pointer to saved registers
	pop hl;								// restore HL register
	pop de;								// restore DE register
	pop bc;								// restore BC register
	pop af;								// restore AF register
	exx;								// switch to alternate register set
	ex af, af';							// switch to alternate AF register
	pop hl;								// restore alternate HL register
	pop de;								// restore alternate DE register
	pop bc;								// restore alternate BC register
	pop iy;								// restore IY index register
	pop ix;								// restore IX index register
	pop af;								// get saved R register value
	ld r, a;							// restore refresh register
	pop af;								// restore AF register
	ld sp, ($2e61);						// restore original stack pointer
	jp start;							// jump to BASIC start

// Hardware initialization routine
L2140:
	ld hl, $3e00;						// point to interrupt vector table
	ld de, $3e01;						// point to table + 1
	ld bc, $0100;						// 256 bytes to copy
	ld a, h;							// get high byte (3E)
	ld i, a;							// set interrupt vector register
	inc a;								// increment to 3F
	ld (hl), a;							// fill with 3F
	ldir;								// copy interrupt vectors
	ld h, a;							// H = 3F
	ld l, a;							// L = 3F (address $3F3F)
	ld de, $215c;						// interrupt handler address
	ld (hl), $c3;						// JP instruction
	inc hl;								// next byte
	ld (hl), e;							// low byte of address
	inc hl;								// next byte
	ld (hl), d;							// high byte of address
	ret;								// return

	inc a;								// increment accumulator
	ret;								// return incremented value

// AY sound chip register reading routine
L215E:
	ld hl, $2e69;						// point to register save area
	ld de, restart_10;					// 10 registers to read

L2164:
	ld bc, $fffd;						// AY register port
	out (c), d;							// select register
	in a, (c);							// read register value
	ld (hl), a;							// save value
	ld b, $bf;							// AY data port
	xor a;								// clear register
	out (c), a;							// write zero
	inc hl;								// next save location
	inc d;								// next register
	dec e;								// decrement counter
	jr nz, L2164;						// loop until done
	ret;								// return

// AY sound chip register writing routine
L2177:
	ld de, restart_10;					// 10 registers to write

L217A:
	ld bc, $fffd;						// AY register port
	out (c), d;							// select register
	ld b, $bf;							// AY data port
	ld a, (hl);							// get value to write
	out (c), a;							// write to register
	inc hl;								// next value
	inc d;								// next register
	dec e;								// decrement counter
	jr nz, L217A;						// loop until done
	ret;								// return

// Memory copying and system initialization routine
L218A:
	ld hl, $c000;						// source address in RAM
	ld de, $3e00;						// destination address
	ld bc, 6;							// 6 bytes to copy
	push de;							// save destination
	push hl;							// save source
	push bc;							// save count
	ldir;								// copy block
	pop bc;								// restore count
	pop de;								// restore as destination
	ld hl, $1c58;						// new source address
	push de;							// save destination
	push bc;							// save count
	ldir;								// copy block
	ld a, ($2e67);						// get memory page
	ld c, 0;							// clear C register

L21A6:
	push af;							// save current page number
	exx;								// switch to alternate registers
	ld bc, $7ffd;						// 128K memory paging port
	out (c), a;							// select memory page
	exx;								// switch back to main registers
	ld de, $c000;						// point to high memory area
	ld hl, $1c58;						// point to comparison data
	ld b, 6								// compare 6 bytes

L21B6:
	ld a, (de);							// get byte from current memory page
	cp (hl);							// compare with expected value
	jr nz, L21D9;						// jump if no match found
	inc de;								// advance memory pointer
	inc hl;								// advance comparison pointer
	djnz L21B6;							// continue byte comparison
	inc c;								// increment valid page counter
	pop af;								// restore page number
	ld ($2e67), a;						// save current page number

L21C3:
	inc a;								// move to next page
	ld b, a;							// save incremented page number
	and 7;								// mask to keep only page bits (0-7)
	ld a, b;							// restore full page number
	jr nz, L21A6;						// jump back if not at page boundary
	ld a, ($2e67);						// load saved page number
	exx;								// switch to alternate register set
	out (c), a;							// output page to memory control port
	exx;								// switch back to main register set
	ld a, c;							// load page count to accumulator
	pop bc;								// restore byte count
	pop de;								// restore destination address
	pop hl;								// restore source address
	ldir;								// block copy memory
	jr L21de;							// jump to completion

L21D9:
	pop af;								// clean up stack (page number)
	jr L21C3;							// retry next page
	jr L21de;							// jump to completion

L21de:
	and a;								// test accumulator flags
	ret z;								// return if zero (no valid pages found)
	inc a;								// increment page count
	and 7;								// mask to page boundary (0-7)
	ld ($2e68), a;						// store final page count
	ret;								// return with page count

L21E7:
	ld hl, $2e5e;						// load page offset address
	ld b, a;							// save offset value
	ld a, (hl);							// load current page offset
	and $80;							// extract sign bit
	ld c, a;							// save sign bit
	ld a, (hl);							// reload page offset
	add a, b;							// add new offset
	and $7F;							// mask to 7-bit value
	or c;								// restore sign bit
	ld (hl), a;							// store updated offset
	ret;								// return

; Function: Process data with printer buffer preservation
L21F6:
	ld hl, $5b00;						// ZX printer buffer start
	push hl;							// save printer buffer pointer
	ld de, $3e00;						// temporary storage area
	ld bc, $0e;							// 14 bytes to copy
	push bc;							// save byte count
	ldir;								// copy printer buffer to temp storage
	pop bc;								// restore byte count
	pop de;								// restore destination (printer buffer)
	ld hl, $2234;						// source data location
	ldir;								// copy data to printer buffer
	ld ($3e10), sp;						// save current stack pointer
	ld sp, $5b0e;						// set stack to end of printer buffer
	ld hl, $5b00;						// ZX printer buffer start
	call L1FFB;							// call processing function
	ld sp, ($3e10);						// restore original stack pointer
	ld hl, $3e00;						// temporary storage location
	ld de, $5b00;						// ZX printer buffer destination
	ld bc, $0e;							// 14 bytes to restore
	ldir;								// restore original printer buffer
	cp $af;								// compare result with CODE token
	push af;							// save comparison result
	ld a, $10;							// load value 16
	jr z, L222F;						// jump if CODE token matched
	ld a, 0;							// otherwise load zero

L222F:
	ld ($2E67), a;						// store result flag
	pop af;								// restore comparison result
	ret;								// return

; Function: UnoDOS system call handler
L2235:
	ld a, ($0001);						// load system call number
	jp $3DFD;							// jump to UnoDOS handler

; Function: Initialize message printer 
L223B:
	ld de, 0;							// clear message offset
	ld hl, $2d4e;						// load message table address
	call L2264;							// call message printer
	jp L1FFA;							// jump to completion handler
; Function: BASIC calculator operations
L2245:
	rst $28;							// enter calculator mode
	ld ($0d22), hl;						// store calculator result address
	rst $28;							// exit calculator mode
	ld bc, $22;							// load operation code
	ld ($f90d), hl;						// store calculation result
	ret nz;								// return if not zero
	ld sp, $3635;						// set stack pointer (embedded data)
	ld sp, $3a39;						// set stack pointer (embedded data)  
	jp pe, $f73a;						// jump if parity even (embedded data)
	dec c;								// decrement C register (embedded data)
	ld sp, hl;							// set stack pointer from HL
	ret nz;								// return if not zero (embedded data)
	ld sp, $3635;						// set stack pointer (embedded data)
	ld sp, $0d36;						// set stack pointer (embedded data)

; Function: Message/string printer
L2264:
	ld a, (de);							// load character from message
	inc de;								// advance message pointer
	and a;								// test for null terminator
	jr nz, L226C;						// jump if not null
	ex de, hl;							// swap pointers
	jr L2264;							// continue with new pointer

L226C:
	cp $0D;								// check for carriage return
	ret z;								// return if carriage return
	cp 1;								// check for special code 1
	call z, L2279;						// handle special code if found
	call L2299;							// print character
	jr L2264;							// continue printing

; Function: Handle special code 1 (attribute/graphics handling)
L2279:
	ld a, ($2e31);						// load character attribute
	cp '*';								// compare with asterisk ($2a)
	ret z;								// return if asterisk
	push af;							// save attribute value
	and $F8;							// mask upper 5 bits (ink/paper)
	srl a;								// shift right
	srl a;								// shift right  
	srl a;								// shift right (divide by 8)
	or $60;								// OR with base graphics code
	call L2299;							// print graphics character
	ld a, $64;							// load separator character 'd'
	call L2299;							// print separator
	pop af;								// restore character value
	and 7;								// extract lower 3 bits (0-7)
	add a, $30;							// convert to ASCII digit (0-7)
	or a;								// set flags
	ret;								// return

; Function: Print character preserving registers
L2299:
	push hl;							// save HL register
	push de;							// save DE register
	rst $18;							// call ROM routine
	defw add_char;						// add character to display
	pop de;								// restore DE register
	pop hl;								// restore HL register
	ret;								// return

; Function: Error code handler and system boundary checks  
L22A5:
	cp $FF;								// check for error code $FF
	jp z, L0124;						// jump to error handler if found
	cp $FE;								// check for error code $FE
	jp z, L0251;						// jump to error handler if found
	cp $FC;								// check for boundary code $FC
	jr c, L22C7;						// jump to normal handler if less
	ld de, $225c;						// load error message pointer
	jr z, L22B7;						// jump if equal to $FC
	ld de, $2250;						// load alternate message pointer

L22B7:
	ld a, ($3d00);						// load system status flag
	and a;								// test flag
	jr nz, L22C1;						// jump if flag set
	ld a, $1c;							// load error code $1C
	scf;								// set carry flag (error)
	ret;								// return with error

L22C1:
	ld a, 7;							// set border to white
	out (ula), a;						// output to ULA border register
	jr L22D8;							// jump to completion

L22C7:
	ld de, $2246;						// load standard message pointer
	ld ($2e31), a;						// store status code
	and a;								// test status
	jr z, L22D8;						// jump to completion if zero
	ld de, $2d4e;						// load message table address
	rst $30;							// call ROM routine
	inc b;								// increment B register
	ld de, $224a;						// load alternate message pointer

; Function: Complete error handling and system cleanup
L22D8:
	ld ($223b), de;						// store message pointer
	di;									// disable interrupts
	call L00EF;							// call system function
	ld hl, $5b00;						// ZX printer buffer start
	ld d, h;							// copy H to D
	ld e, 1;							// set E to 1
	ld bc, $a4ff;						// set large byte count
	ld (hl), l;							// store L value at (HL)
	ldir;								// clear memory block
	ld hl, $230c;						// load source address for system code
	ld de, $5d25;						// load destination in BASIC RAM
	ld bc, $2e;							// copy 46 bytes
	ldir;								// copy system code to BASIC area
	ld sp, $5da5;						// set stack pointer to BASIC area
	rst $18;							// call ROM routine
	defw $5d25;							// call copied routine at $5d25
	ld hl, $ffff;						// load test address
	ld a, 1;							// load test value
	ld (hl), a;							// store test value
	ld a, (hl);							// read back test value
	dec a;								// decrement and test
	jr z, L2309;						// jump if memory test passed
	res 7, h;							// clear bit 7 of H (address adjustment)

L2309:
	rst $18;							// call ROM routine
	defw $5da5;							// call copied routine at $5da5
	ld hl, $1200;						// load source of main code block
	ld de, $5da5;						// destination in BASIC RAM
	ld bc, $b1;							// copy 177 bytes
	ldir;								// copy main code block
	ld hl, $5d47;						// load additional code source
	ld bc, $0c;							// copy 12 bytes
	ldir;								// copy additional code
	ex de, hl;							// swap destination to HL
	ld de, $12b4;						// load jump target address
	ld (hl), $c3;						// store JP instruction opcode
	inc hl;								// advance to address bytes
	ld (hl), e;							// store low byte of jump address
	inc hl;								// advance pointer
	ld (hl), d;							// store high byte of jump address
	xor a;								// clear accumulator
	ld ($5dd9), a;						// clear BASIC system variable
	ret;								// return from setup

; Function: System call handler with stack setup
L2328:
	ld hl, $5e62;						// load stack address
	push hl;							// push stack address
	ld hl, $223a;						// load return address
	push hl;							// push return address
	ei;									// enable interrupts
	jp $3DFD;							// jump to UnoDOS system handler

; Function: File extension processor
L233A:
	ld ($2e33), a;						// store character for processing
	cp '.';								// check for period character
	jp z, L23DA;						// jump to extension handler if period
	call L2387;							// call character validation
	ret nc;								// return if validation failed
	push hl;							// save HL register
	ex de, hl;							// swap DE and HL
	call L2357;							// call comparison function
	pop hl;								// restore HL register
	jr nc, L2351;						// jump if comparison failed
	ld a, $1a;							// load error code $1A
	rst $20;							// call error handler

L2351:
	ld a, ($2e33);						// load processed character
	jp $2800;							// jump to completion handler

; Function: Memory address comparison
L2357:
	ld a, (L2019);						// load saved address low byte
	cp l;								// compare with current L
	jr nz, L2362;						// jump if different
	ld a, ($201a);						// load saved address high byte
	cp h;								// compare with current H
	ret z;								// return if addresses match

L2362:
	ld (L2019), hl;						// save current address
	call L02FD;							// call system function
	ld a, $24;							// load file handle $24
	ld b, 1;							// set mode to read
	rst $08;							// call DOS function
	defb f_open;						// open file operation
	jr c, L2380;						// jump if open failed
	push af;							// save file handle
	ld hl, $2800;						// load buffer address
	ld bc, $0400;						// set read length (1024 bytes)
	rst $08;							// call DOS function
	defb f_read;						// read file operation
	pop bc;								// restore file handle to B
	push af;							// save read result
	ld a, b;							// load file handle to A
	rst $08;							// call DOS function
	defb f_close;						// close file operation
	pop af;								// restore read result
	ret nc;								// return if read successful

L2380:
	push af;							// save error code
	xor a;								// clear accumulator
	ld ($201a), a;						// clear address high byte
	pop af;								// restore error code
	ret;								// return with error

; Function: Character validation against token overloads
L2387:
	ld c, a;							// save character in C
	ld de, tk_overloads;				// load token overloads table
	ld a, (de);							// load first table entry

L238C:
	or a;								// test for table end
	ret z;								// return if end of table
	inc de;								// advance to next table entry
	cp c;								// compare with target character
	jr z, L239E;						// jump if character found
	ld a, (de);							// load next entry

L2393:
	cp $80;								// check for entry end marker
	jr nc, L238C;						// continue if end marker found
	inc de;								// advance pointer
	or a;								// test for null
	ld a, (de);							// load next character
	jr z, L238C;						// continue if null found
	jr L2393;							// continue scanning entry

L239E:
	ld a, (de);							// load validation result
	cp $80;								// check validation result
	ret c;								// return if validation passed
	inc de;								// advance to next data
	jr L239E;							// continue validation loop

;	org $23a5
tk_overloads:
	defb 0, 0, 0, 0, 0; 				// TOKENs that invoke BFILE.SYS
	defb "bfile";						// command name for BFILE.SYS
	defb 0, 0, 0;						// TOKENs that invoke BDIR.SYS
	defb "bdir";						// command name for BDIR.SYS
	defb 0, 0;							// TOKENs that invoke TAPE.SYS
	defb "tape";						// command name for TAPE.SYS
	defb 0;								// end marker
	defb "errors";						// command name for error reporting
	defb 0;								// end marker

; Function: Load message pointer
L23C4:
	ld hl, $23b8;						// load message table address
	jr L2357;							// jump to address comparison

; Function: Process command with register preservation
L23C9:
	push hl;							// save HL register
	push de;							// save DE register
	push bc;							// save BC register
	call L23C4;							// call message processing
	pop bc;								// restore BC register
	pop de;								// restore DE register
	pop hl;								// restore HL register
	ld a, ixl;							// load IX low byte
	ld ($3df8), a;						// store result code
	ld a, $1a;							// load error code $1A
	ret;								// return with error

; Function: Process file extension
L23DA:
	inc hl;								// advance past period character
	push hl;							// save extension pointer
	ld hl, cmd_folder;					// load folder command string
	ld de, $2dce;						// load destination buffer
	ld bc, 5;							// copy 5 bytes
	ldir;								// copy folder command
	pop hl;								// restore extension pointer
	ld c, $20;							// set space character limit

; Function: Parse extension characters
L23EA:
	ld a, (hl);							// load character from extension
	cp ' ';								// compare with space character
	jr z, L23FB;						// jump if space found
	rst $18;							// call ROM routine
	defw pr_st_end;						// check for string end
	jr z, L23FB;						// jump if end of string

	ldi;								// copy character and increment
	jp po, L23FB;						// jump if byte count expired
	jr L23EA;							// continue parsing characters

L23FB:
	cp ' ';								// $20
	jr nz, L2414;						// jump if not space character
	inc hl;								// advance past space
	ld ($2e46), hl;						// save command position

L2403:
	ld a, (hl);							// load character from command
	rst $18;							// call ROM routine
	defw pr_st_end;						// check for string end
	jr z, L240C;						// jump if end of string

	inc hl;								// advance to next character
	jr L2403;							// continue scanning

L240C:
	ld (ch_add), hl;					// set character pointer
	ld hl, ($2e46);						// load saved pointer
	jr L241A;							// jump to completion

L2414:
	ld (ch_add), hl;					// set character pointer
	ld hl, 0;							// clear HL register

L241A:
	ld ($2e46), hl;						// store pointer for later use

L241B equ $241b

; Function: Process command and handle errors
	call L24C1;							// call command processor
	call L242E;							// call error handler
	jp nc, L0D94;						// jump if no error
	cp 5;								// check for specific error code
	jp nz, restart_20;					// restart system if not error 5
	ld a, $16;							// load error code $16
	rst $20;							// call error handler

; Function: Initialize string terminator and open file
L242E:
	xor a;								// clear accumulator (null terminator)
	ld (de), a;							// store null terminator at DE

; Function: Process file path and open
L2430:
	call L2475;							// call path processing function
	ld a, $24;							// load file handle $24
	ld hl, $2dce;						// load filename buffer address
	ld b, 1;							// set mode to read
	rst $08;							// call DOS function
	defb f_open;						// open file operation
	ret;								// return with open result

	ld a, ($3df8);						// load current drive state
	ld ($3df0), a;						// save drive state for operation
	push hl;							// save HL register
	ld hl, cmd_folder;					// load folder command string
	ld de, $2dce;						// load destination buffer
	ld bc, 5;							// copy 5 bytes
	ldir;								// copy folder command
	pop hl;								// restore HL register

; Function: Copy filename characters until space
L2450:
	ld a, (hl);							// load character from filename
	inc hl;								// advance source pointer
	cp ' ';								// compare with space character
	jr z, L245A;						// jump if space found
	ld (de), a;							// store character in buffer
	inc de;								// advance destination pointer
	jr L2450;							// continue copying characters

; Function: Complete filename processing
L245A:
	ld ($2e46), hl;						// save current position
	call L242E;							// call file processing function
	ret c;								// return if error
	push af;							// save accumulator
	ld a, 2;							// load mode value 2
	ld ($3df8), a;						// store mode value
	ld hl, ($2e46);						// load saved pointer
	ld de, $3d00;						// load buffer address
	push de;							// save buffer address
	rst $30;							// call ROM routine
	inc b;								// increment B register
	pop hl;								// restore buffer address to HL
	pop af;								// restore accumulator
	jp L0DB4;							// jump to completion handler

; Function: Process path string with length check
L2475:
	ld b, $0f;							// set maximum length to 15
	ld hl, $2e22;						// load path buffer address

; Function: Scan path characters
L247A:
	ld a, (hl);							// load character from path
	and a;								// test for null terminator
	jr z, L2484;						// jump if null found
	push hl;							// save path pointer
	push bc;							// save BC register
	rst $08;							// call DOS function
	defb f_close;						// close file operation
	pop bc;								// restore BC register
	pop hl;								// restore HL register

; Function: Increment path pointer and check bounds
L2484:
	inc hl;								// advance to next character
	djnz L247A;							// continue loop if counter not zero
	ret;								// return from function

L248A equ $248a

;	// called from dirs.io
; Function: Process directory command (called from dirs.io)
L2488:
	call L249A;							// call expression evaluation
	ret z;								// return if zero result
	ld a, c;							// load C register value
	or b;								// test if BC is zero
	jp z, L24EF;						// jump to error handler if zero
	ex de, hl;							// exchange DE and HL
	ld de, $2d4e;						// load destination buffer address
	ldir;								// copy string to buffer
	xor a;								// clear accumulator
	ld (de), a;							// add null terminator
	ret;								// return from function

; Function: Evaluate BASIC expression
L249A:
	rst $18;							// call ROM routine
	defw expt_exp;						// expect expression
	rst $30;							// call calculator
	inc bc;								// increment BC
	ret z;								// return if zero
	push af;							// save accumulator
	rst $18;							// call ROM routine
	defw stk_fetch;						// fetch from calculator stack
	pop af;								// restore accumulator
	ret;								// return from function

; Function: Parameter processing (called from dirs.io)
L24A6:
	push af;							// save accumulator
	rst $30;							// call calculator
	ld (bc), a;							// store result at BC
	cp $64;								// compare with 'd' character
	jp nz, L24EC;						// jump if not 'd'
	rst $30;							// call calculator
	ld (bc), a;							// store result at BC
	jp z, L24EC;						// jump if zero
	sub $30;							// convert ASCII to numeric (subtract '0')
	and 7;								// mask to 3 bits (0-7)
	ld c, a;							// store masked value in C
	pop af;								// restore accumulator
	sla a;								// shift left (multiply by 2)
	sla a;								// shift left (multiply by 4)
	sla a;								// shift left (multiply by 8)
	or c;								// combine with lower bits
	ret;								// return combined value

; Function: Get character and process commands (called from dirs.io)
L24C1:
	rst $18;							// call ROM routine
	defw get_char;						// get current character

; Function: Check for string end
L24C4:
	rst $18;							// call ROM routine
	defw pr_st_end;						// check for program/string end
	jp nz, L24E9;						// jump if not at end
	rst $30;							// call calculator
	inc bc;								// increment BC
	ret nz;								// return if not zero

; Function: Set up error handling (called from dirs.io)
L24CD:
	ld sp, (err_sp);					// restore error stack pointer
	ld (iy + 0), $ff;					// set system flag to $FF
	ld hl, $1bf4;						// load error handler address
	rst $30;							// call calculator
	inc bc;								// increment BC
	jp z, L1FFB;						// jump to system function if zero
	ld hl, $1b7d;						// load alternate handler address
	jp L1FFB;							// jump to system function
	ld a, 1;							// load error code 1
	rst $20;							// call error handler

; Function: File error handler (called from files.io)
L24E6:
	ld a, 2;							// load error code 2
	rst $20;							// call error handler

; Function: Command processing error
L24E9:
	ld a, 3;							// load error code 3
	rst $20;							// call error handler

; Function: Parameter error
L24EC:
	ld a, $0B;							// load error code 11 ($0B)
	rst $20;							// call error handler

; Function: Invalid argument error
L24EF:
	ld a, $13;							// load error code 19 ($13)
	rst $20;							// call error handler

; Function: File operation error (called from files.io)
L24F2:
	ld a, 4;							// load error code 4
	rst $20;							// call error handler

;	// called from dirs.io
; Function: File close with state management (called from dirs.io)
L24F5:
	ld a, ($2e32);						// load file state flag
	push af;							// save state flag
	ld a, 0;							// clear accumulator
	ld ($2e32), a;						// clear file state flag
	pop af;								// restore original state
	rst $08;							// call DOS function
	defb f_close;						// close file operation
	ret;								// return from function

;	// called from dirs.io
; Function: Conditional file close (called from dirs.io)
L2502:
	ld a, ($2e32);						// load file state flag
	and a;								// test if flag is set
	ret z;								// return if no file open
	push bc;							// save BC register
	push de;							// save DE register
	call L24F5;							// call file close function
	pop de;								// restore DE register
	pop bc;								// restore BC register
	ret;								// return from function

; Function: Close file using BASIC system variable
L2512:
	ld a, (iy + _newppc);				// load BASIC system variable
	rst $08;							// call DOS function
	defb f_close;						// close file operation
	ret;								// return from function

; Function: Graphics character validation and processing
L2518:
	ld ixh, a;							// save character in IXH
	and $E0;							// mask upper 3 bits
	cp $60;								// compare with graphics character range
	scf;								// set carry flag (error condition)
	ret nz;								// return with error if not graphics
	ld a, ixh;							// restore original character
	and $F8;							// mask to graphics subset
	push bc;							// save BC register
	push af;							// save processed character
	ld ($3dea), de;						// save pointer for later use
	push bc;							// save BC register
	ld de, $2d4e;						// load filename buffer address
	push de;							// save buffer address
	rst $30;							// call calculator
	dec b;								// decrement B register
	pop hl;								// restore buffer address to HL
	pop bc;								// restore BC register
	ld a, c;							// load C register value
	ld b, 3;							// set mode to read/write
	rst $08;							// call DOS function
	defb f_open;						// open file operation
	jr nc, L253A;						// jump if successful
	pop bc;								// clean up stack
	pop bc;								// clean up stack
	ret;								// return with error

L253A:
	ld ($2D4D), a;						// save file handle
	ld hl, $2df2;						// load file status buffer
	rst $08;							// call DOS function
	defb f_fstat;						// get file status
	pop af;								// restore accumulator
	call L032E;							// call system function
	ld hl, $1a95;						// load address value
	ld (iy + 2), l;						// store low byte in IY+2
	ld (iy + 3), h;						// store high byte in IY+3
	pop bc;								// restore BC register
	call L25A9;							// call validation function
	jr nc, L255C;						// jump if no error
	call L25BA;							// call alternate validation
	jr nc, L255C;						// jump if no error
	ld c, 3;							// load error code 3

; Function: Process file attributes and flags
L255C:
	ld a, b;							// load B register (flags)
	and 7;								// mask lower 3 bits
	or c;								// combine with C register
	or b;								// combine with full B register
	ld (iy + 1), a;						// store combined flags in IY+1
	ld a, c;							// load C register value
	ld hl, $2df9;						// load data buffer address
	rst $30;							// call ROM routine
	ld bc, $f4cd;						// load immediate value
	dec h;								// adjust high byte
	ld l, a;							// set low byte from A
	dec l;								// adjust shift count
	rst $30;							// call ROM routine
	dec c;								// decrement counter
	jr z, L2587;						// jump if zero
	ld h, 0;							// clear overflow counter

; Function: Multi-precision right shift with overflow tracking
L2575:
	srl b;								// shift right B register
	rr c;								// rotate right C register
	rr d;								// rotate right D register
	rr e;								// rotate right E register
	rl h;								// rotate left H (collect overflow)
	dec l;								// decrement shift counter
	jr nz, L2575;						// repeat until done
	ld a, h;							// load overflow bits
	and a;								// test for overflow
	call nz, L081C;						// handle overflow if present

L2587:
	push iy;							// save IY register
	pop hl;								// transfer IY to HL
	ld a, 4;							// load offset value
	add a, l;							// add offset to low byte
	ld l, a;							// store adjusted address
	rst $30;							// call ROM routine
	nop;								// padding/alignment
	ld a, ($2d4d);						// load file handle
	ld (iy + _newppc), a;				// store handle in system variable
	ld a, ixl;							// load drive number
	ld ($3df8), a;						// store current drive
	ld de, ($3dea);						// load saved pointer
	ld hl, L260D;						// load routine address
	rst $30;							// call ROM routine
	inc b;								// increment B register
	ld a, (iy + 0);						// load flags from system area
	or a;								// test flags
	ret;								// return with status

; Function: Load and validate memory page
L25A9:
	ld de, $0800;						// load page address
	call L25de;							// call page loading function
	ret c;								// return if error
	ld a, ($3ee7);						// load system flag
	cp $10;								// compare with expected value
	ld c, 2;							// load result code
	ret z;								// return if match

; Function: Set error flag and return
L25B8:
	scf;								// set carry flag for error
	ret;								// return with error

; Function: Load screen memory and validate
L25BA:
	ld de, $4000;						// load screen 0 address
	call L25de;							// call memory loading function
	ret c;								// return if error
	ld a, ($3e00);						// load directory header byte
	cp $FF;								// check for valid directory marker
	ret nz;								// return if not directory
	ld hl, $3e09;						// load signature start address
	ld a, (hl);							// load first signature character
	cp $44;								// check for 'D'
	jr nz, L25B8;						// jump to error if not 'D'
	inc l;								// advance to next character
	ld a, (hl);							// load second signature character
	cp $49;								// check for 'I'  
	jr nz, L25B8;						// jump to error if not 'I'
	inc l;								// advance to next character
	ld a, (hl);							// load third signature character
	cp $52;								// check for 'R' (completing "DIR")
	jr nz, L25B8;						// jump to error if not 'R'
	ld c, 2;							// load success code
	ret;								// return successfully

; Function: Seek and read file operation
L25de:
	push bc;							// save BC register
	ld bc, 0;							// set seek position to 0
	ld l, c;							// set L to 0
	ld a, ($2d4d);						// load file handle
	push af;							// save file handle
	rst $08;							// call DOS function
	defb f_seek;						// seek to position
	pop af;								// restore file handle
	ld hl, $3e00;						// load buffer address
	ld bc, $0200;						// read 512 bytes
	rst $08;							// call DOS function
	defb f_read;						// read file operation
	pop bc;								// restore BC register  
	ret;								// return with read result

; Function: Setup for multi-precision arithmetic
	ld h, a;							// load high byte
	ld l, 0;							// clear low byte
	ld a, 7;							// load shift count

; Function: Multi-precision right shift with overflow collection
L25F9:
	srl b;								// shift right B register
	rr c;								// rotate right C register
	rr d;								// rotate right D register
	rr e;								// rotate right E register
	rl l;								// rotate left L (collect overflow)
	dec a;								// decrement shift counter
	jr nz, L25F9;						// repeat until counter zero
	ld a, l;							// load accumulated overflow
	and a;								// test for overflow bits
	ld a, h;							// 
	call nz, L081C;						// 
	ret;								// 

L260D:
	defb "Virtual Disk", 0;				// null-terminated string constant

lower_end:

;	// this part starts at $3000 in MMC RAM 1
	org $3000
; Function: Initialize memory management variables
L3000:
	ld ($3c19), hl;						// store HL in memory pointer
	ld de, ($3c11);						// load base address to DE
	ld bc, ($3c13);						// load size to BC
	ld ($3c15), de;						// store base address copy
	ld ($3c17), bc;						// store size copy
	call L305E;							// call initialization routine
	ret c;								// return if error
	call L1321;							// call memory setup function
	ld h, d;							// transfer D to H
	ld l, e;							// transfer E to L
	ld a, $ff;							// load marker value
	call L30E2;							// call memory marking function
	push de;							// save DE register
	ld de, ($3c11);						// load memory base address
	ld bc, ($3c13);						// load memory size
	call L110A;							// call memory initialization
	pop hl;								// restore HL register
	call L1380;							// call address conversion
	push bc;							// save BC register
	push de;							// save DE register
	ld bc, ($3c17);						// load saved size value
	ld de, ($3c15);						// load saved address value
	call L10BA;							// call memory operation
	ld de, ($3c19);						// load memory pointer
	ld a, d;							// load high byte
	and 1;								// mask to lowest bit
	ld d, a;							// store masked value
	add hl, de;							// add address offset
	pop de;								// restore DE register
	pop bc;								// restore BC register
	call L30F7;							// call finalization routine
	push bc;							// save BC register again
	push de;							// save DE register again
	ld bc, ($3c17);						// reload saved size
	ld de, ($3c15);						// reload saved address
	call L110A;							// call memory reinitialization
	pop de;								// restore DE register
	pop bc;								// restore BC register
	jp L1135;							// jump to file descriptor function

; Function: Check system flags and process
L305E:
	bit 2, (iy + _oldppc);				// check system flag bit
	jr z, L3098;						// jump if flag not set

L3064:
	push hl;							// save HL register
	push iy;							// save IY register
	pop hl;								// transfer IY to HL
	ld l, $3e;							// set offset to system area
	rst $30;							// call ROM routine
	ld bc, $fde1;						// load special value
	ld a, (hl);							// load system byte
	inc e;								// increment E register
	cp 0;								// compare with zero
	ld a, 0;							// clear accumulator
	jr z, L3078;						// jump if zero
	sla e;								// shift left E register

; Function: Continue bit shifting and address calculation
L3078:
	sla e;								// shift left E register again
	adc a, a;							// add with carry to accumulator
	ld d, a;							// store result in D
	ld a, h;							// load H register
	and $FE;							// mask to clear lowest bit
	or d;								// combine with D register
	ld d, a;							// store result in D
	or d;								// combine with D register
	ex de, hl;							// exchange DE with HL
	sbc hl, de;							// subtract DE from HL with carry
	ex de, hl;							// restore original order
	jr z, L3090;						// jump if zero result
	ld e, l;							// transfer L to E
	ld d, h;							// transfer H to D
	call L30D3;							// call validation function
	jr nz, L3064;						// jump if not zero
	ret;								// return successfully

L3090:
	res 2, (iy + _oldppc);				// 
	ld a, 9;							// 
	scf;								// 
	ret;								// 

L3098:
	ld d, h;							// 
	ld e, l;							// 
	call L30D3;							// 
	ret z;								// 
	ld a, h;							// 
	cp '*';								// $2a
	jr nz, L3098;						// 
	res 2, (iy + _oldppc);				// 
	ld de, ($3c11);						// 
	ld bc, ($3c13);						// 
	call L081C;							// 
	push bc;							// 
	push de;							// 
	call L081C;							// 
	push iy;							// 
	pop hl;								// 
	ld l, $22;							// 
	call L0694;							// 
	pop de;								// 
	pop bc;								// 
	jr nz, L30CD;						// 
	set 2, (iy + _oldppc);				// 
	call L10BA;							// 
	jr nc, L3064;						// 
	ret;								// 

L30CD:
	call L10BA;							// 
	jr nc, L3098;						// 
	ret;								// 

L30D3:
	ld a, (iy + _nxtlin_h);				// 
	cp 1;								// 
	ld a, 0;							// 
	call z, L30DD;						// 

L30DD:
	or (hl);							// 
	inc l;								// 
	or (hl);							// 
	inc hl;								// 
	ret;								// 

L30E2:
	ld (hl), a;							// 
	inc l;								// 
	ld (hl), a;							// 
	inc hl;								// 
	push bc;							// 
	ld b, a;							// 
	ld a, (iy + _nxtlin_h);				// 
	cp 1;								// 
	ld a, b;							// 
	pop bc;								// 
	ret nz;								// 
	ld (hl), a;							// 
	inc l;								// 
	and $0F;							// 
	ld (hl), a;							// 
	inc hl;								// 
	ret;								// 

L30F7:
	call L11B6;							// 
	ld (hl), e;							// 
	inc l;								// 
	ld (hl), d;							// 
	ld a, (iy + _nxtlin_h);				// 
	cp 1;								// 
	ret nz;								// 
	inc l;								// 
	ld (hl), c;							// 
	inc l;								// 
	ld (hl), b;							// 
	ret;								// 

L3108:
	rst $30;							// 
	dec c;								// 
	ret z;								// 
	call L1334;							// 
	jr nz, L3113;						// 
	call L11B6;							// 

L3113:
	call L12C7;							// 
	jr c, L311E;						// 
	call L3122;							// 
	jr nc, L3108;						// 
	ret;								// 

L311E:
	cp $80;								// 
	scf;								// 
	ret nz;								// 

L3122:
	xor a;								// 
	call L30E2;							// 
	push bc;							// 
	push de;							// 
	ld de, ($3c11);						// 
	ld bc, ($3c13);						// 
	call L110A;							// 
	push af;							// 
	scf;								// 
	call L1321;							// 
	pop af;								// 
	pop de;								// 
	pop bc;								// 
	ret;								// 

L313C:
	call L115C;							// 
	jp L10A0;							// 
	bit 1, (ix + $01);					// 
	ld a, 8;							// 
	scf;								// 
	ret z;								// 
	ld a, c;							// 
	or b;								// 
	ret z;								// 
	push bc;							// 
	call L19E0;							// 
	rst $30;							// 
	dec c;								// 
	pop bc;								// 
	jr nz, L315C;						// 
	push bc;							// 
	call L3192;							// 
	pop bc;								// 
	ret c;								// 

L315C:
	set 2, (ix + $01);					// 
	call L18F2;							// 
	push af;							// 
	push bc;							// 
	push hl;							// 
	call L19C6;							// 
	push ix;							// 
	pop hl;								// 
	ld a, l;							// 
	add a, $0e;							// 
	ld l, a;							// 
	rst $30;							// 
	ex af, af';							// 
	call c, L3183;						// 
	set 3, (ix + $01);					// 
	pop hl;								// 
	pop bc;								// 
	pop af;								// 
	ret nc;								// 
	push af;							// 
	call L10F3;							// 
	pop af;								// 
	ret;								// 

L3183:
	call L19D3;							// 
	push hl;							// 
	ld hl, $1a6d;						// 
	ld ($3dee), hl;						// 
	call L1A21;							// 
	pop hl;								// 
	ret;								// 

L3192:
	push hl;							// 
	call L135D;							// 
	pop hl;								// 
	call nc, L10F3;						// 
	ret c;								// 
	push bc;							// 
	call L1321;							// 
	pop bc;								// 
	call L19ED;							// 
	call L12A6;							// 
	push hl;							// 
	ld hl, $1a7c;						// 
	ld ($3dee), hl;						// 
	call L1A21;							// 
	pop hl;								// 
	ret;								// 

	call L1697;							// 
	ret c;								// 
	push iy;							// 
	pop hl;								// 
	ld d, h;							// 
	ld e, l;							// 
	inc de;								// 
	ld bc, $ff;							// 
	ld (hl), l;							// 
	ldir;								// 
	or a;								// 
	ret;								// 

	push de;							// 
	ld a, $80;							// 
	call L1524;							// 
	pop de;								// 
	jr nc, L31D1;						// 
	cp $11;								// 
	scf;								// 
	ret nz;								// 

L31D1:
	ld a, ($3c06);						// 
	cp '.';								// $2e
	ld a, $13;							// 
	scf;								// 
	jp z, L329F;						// 
	call L1773;							// 
	ld hl, $1a65;						// 
	ld ($3dee), hl;						// 
	call L1A21;							// 
	ld a, $17;							// 
	ret c;								// 
	ld l, (ix + $1C);					// 
	ld h, (ix + $1D);					// 
	ld a, $0b;							// 
	add a, l;							// 
	ld l, a;							// 
	bit 0, (hl);						// 
	ld a, $18;							// 
	scf;								// 
	jp nz, L32A4;						// 
	push de;							// 
	call L19FA;							// 
	ld hl, $3c1b;						// 
	rst $30;							// 
	nop;								// 
	call L163E;							// 
	ld hl, $3c1f;						// 
	rst $30;							// 
	nop;								// 
	call L115C;							// 
	call L1A07;							// 
	ld a, (ix + $06);					// 
	ld ($3c23), a;						// 
	ld l, (ix + $1C);					// 
	ld h, (ix + $1D);					// 
	ld de, $2d00;						// 
	ld bc, $20;							// 
	ldir;								// 
	pop hl;								// 
	ld a, $80;							// 
	call L152F;							// 
	jr c, L3235;						// 
	ld a, $12;							// 
	scf;								// 
	jr L32A4;							// 

L3235:
	cp 5
	scf;								// 
	jr nz, L329F;						// 
	ld a, ($3c06);						// 
	cp '.';								// $2e
	ld a, $13;							// 
	scf;								// 
	jr z, L329F;						// 
	call L19FA;							// 
	ld hl, $3c1E;						// 
	call L0694;							// 
	jr nz, L3265;						// 
	ld a, ($3c23);						// 
	ld (ix + $06), a;					// 
	call L16CB;							// 
	jr c, L329F;						// 
	ex de, hl;							// 
	ld hl, $3c06;						// 
	ld bc, $0b;							// 
	ldir;								// 
	jr L329C;							// 

L3265:
	call L17F4;							// 
	jr c, L329F;						// 
	ld a, (de);							// 
	push af;							// 
	ld hl, $3c06;						// 
	ld bc, $0b;							// 
	ldir;								// 
	ld hl, $2d0b;						// 
	ld bc, $15;							// 
	ldir;								// 
	push de;							// 
	call L17E7;							// 
	pop hl;								// 
	pop de;								// 
	jr c, L329F;						// 
	ld a, d;							// 
	cp $E5;								// RESTORE
	jr z, L328C;						// 
	call L177A;							// 

L328C:
	call L17E7;							// 
	ld a, ($3c23);						// 
	ld (ix + $06), a;					// 
	call L16CB;							// 
	jr c, L329F;						// 
	ld (hl), $e5;						// 

L329C:
	call L17E7;							// 

L329F:
	push af;							// 
	call L10F3;							// 
	pop af;								// 

L32A4:
	ld (ix + 0), 0;						// 
	ret;								// 

	push bc;							// 
	ld a, $80;							// 
	call L1524;							// 
	pop bc;								// 
	jr nc, L32B8;						// 
	cp $11;								// 
	scf;								// 
	jr z, L32BC;						// 
	ret;								// 

L32B8:
	call L32E7;							// 
	ret c;								// 

L32BC:
	push bc;							// 
	call L115C;							// 
	call L1A07;							// 
	call L163E;							// 
	ld l, (ix + $1C);					// 
	ld h, (ix + $1D);					// 
	ld a, $0b;							// 
	add a, l;							// 
	ld l, a;							// 
	pop bc;								// 
	ld a, b;							// 
	rra;								// 
	ccf;								// 
	rla;								// 
	and c;								// 
	ld b, a;							// 
	ld a, c;							// 
	and $27;							// 
	cpl;								// 
	and (hl);							// 
	or b;								// 
	and $37;							// 
	ld (hl), a;							// 
	call L17E7;							// 
	ret c;								// 
	jp L10F3;							// 

L32E7:
	ld hl, $2c00;						// 
	ld a, (hl);							// 
	cp '/';								// $2f
	jr nz, L32F0;						// 
	inc hl;								// 

L32F0:
	ld a, (hl);							// 
	cp '.';								// $2e
	jr z, L32F7;						// 
	or a;								// 
	ret nz;								// 

L32F7:
	ld a, 8
	scf;								// 
	ret;								// 

	ld a, $80;							// 
	call L1524;							// 
	jr c, L3306;						// 

L3302:
	ld a, $12;							// 
	scf;								// 
	ret;								// 

L3306:
	cp $11;								// 
	jr z, L3302;						// 
	cp 5;								// 
	scf;								// 
	ret nz;								// 
	call L19FA;							// 
	push bc;							// 
	push de;							// 
	call L3348;							// 
	pop de;								// 
	pop bc;								// 
	ret c;								// 
	push bc;							// 
	push de;							// 
	ld de, $2d00;						// 
	ld hl, $33a2;						// 
	exx;								// 
	call L19FA;							// 
	exx;								// 
	call L336D;							// 
	ex de, hl;							// 
	exx;								// 
	pop de;								// 
	pop bc;								// 
	exx;								// 
	ld hl, $33a1;						// 
	call L336D;							// 
	ld d, h;							// 
	ld e, l;							// 
	inc de;								// 
	xor a;								// 
	ld (hl), a;							// 
	ld bc, $01BF;						// 
	ldir;								// 
	ld hl, $2d00;						// 
	call L313C;							// 
	ret c;								// 
	jp L1697;							// 

L3348:
	xor a;								// 
	ld ($3c01), a;						// 
	call L1712;							// 
	ld (ix + 0), 0;						// 
	ret c;								// 
	ld hl, $2600;						// 
	call L17FD;							// 
	ret c;								// 
	ld a, $0b;							// 
	add a, e;							// 
	ld e, a;							// 
	ld a, $10;							// 
	ld (de), a;							// 
	call L17E7;							// 
	ret c;								// 
	set 3, (ix + $01);					// 
	jp L3192;							// 

L336D:
	ld bc, $0b;							// 
	ldir;								// 
	ld a, $10;							// 
	ld (de), a;							// 
	ex de, hl;							// 
	inc hl;								// 
	ld (hl), a;							// 
	inc hl;								// 
	ld (hl), a;							// 
	inc hl;								// 
	rst $08;							// 
	defb m_getdate;						// 
	rst $30;							// 
	nop;								// 
	xor a;								// 
	ld (hl), a;							// 
	inc l;								// 
	ld (hl), a;							// 
	inc l;								// 
	push hl;							// 
	exx;								// 
	pop hl;								// 
	ld (hl), c;							// 
	inc l;								// 
	ld (hl), b;							// 
	inc l;								// 
	push hl;							// 
	exx;								// 
	pop hl;								// 
	rst $30;							// 
	nop;								// 
	push hl;							// 
	exx;								// 
	pop hl;								// 
	ld (hl), e;							// 
	inc l;								// 
	ld (hl), d;							// 
	inc l;								// 
	push hl;							// 
	exx;								// 
	pop hl;								// 
	ld b, a;							// 
	ld c, b;							// 
	ld d, c;							// 
	ld e, d;							// 
	rst $30;							// 
	nop;								// 
	ret;								// 

	ld l, $2e;							// 
	jr nz, L33C5;						// 
	jr nz, L33C7;						// 
	jr nz, L33C9;						// 
	jr nz, L33CB;						// 
	jr nz, L33CD;						// 
	ld a, $81;							// 
	call L1524;							// 
	ret c;								// 
	call L163E;							// 
	call L107B;							// 
	ld hl, $2c80;						// 
	ld a, ($3dea);						// 
	ld (iy + $7f), a;					// 
	push iy;							// 
	pop de;								// 

L33C5:
	ld e, $80;							// 

L33C7:
	sub $80;							// 

L33C9:
	ld b, 0;							// 

L33CB:
	ld c, a;							// 

L33CD equ $33cd

	ldir;								// 
	ld a, b;							// 
	ld (de), a;							// 
	or a;								// 
	ret;								// 

L33D2:
	ld a, 1;							// 
	or b;								// 
	and $41;							// 
	ld (ix + $01), a;					// 
	ld a, $80;							// 
	call L1524;							// 
	ret c;								// 
	call L115C;							// 
	call L1A07;							// 
	call L163E;							// 
	call L19ED;							// 
	call L12A6;							// 
	ld b, 0;							// 
	ld c, b;							// 
	ld d, c;							// 
	ld e, d;							// 
	call L19B9;							// 
	call L0824;							// 
	call L19D3;							// 
	call L1773;							// 
	or a;								// 
	ret	;								// 

L3402:
	ex de, hl;							// 

L3403:
	ld hl, $2d00;						// 
	ld bc, $20;							// 
	push de;							// 
	call L1681;							// 
	pop de;								// 
	ret c;								// 
	ld a, (hl);							// 
	and a;								// 
	ret z;								// 
	cp $e5;								// RESTORE
	jr z, L3403;						// 
	ld l, $0b;							// 
	bit 3, (hl);						// 
	ld l, 0;							// 
	jr nz, L3403;						// 
	push de;							// 
	ld de, $2d20;						// 
	push de;							// 
	inc de;								// 
	ld b, 8;							// 
	call L34BF;							// 
	ld a, (hl);							// 
	cp ' ';								// $20
	jr z, L3432;						// 
	ld a, $2e;							// 
	ld (de), a;							// 
	inc de;								// 

L3432:
	ld b, 3;							// 
	call L34BF;							// 
	xor a;								// 
	ld (de), a;							// 
	inc de;								// 
	ld a, (hl);							// 
	and $3F;							// 
	ld ($2d20), a;						// 
	ld bc, 9;							// 
	add hl, bc;							// 
	ld c, (hl);							// 
	inc hl;								// 
	ld b, (hl);							// 
	ld ($3c21), bc;						// 
	inc hl;								// 
	ldi;								// 
	ldi;								// 
	ldi;								// 
	ldi;								// 
	ld c, (hl);							// 
	inc hl;								// 
	ld b, (hl);							// 
	ld ($3c1f), bc;						// 
	inc hl;								// 
	ldi;								// 
	ldi;								// 
	ldi;								// 
	ldi;								// 
	bit 6, (ix + $01);					// 
	call nz, L347B;						// 
	ld b, 0;							// 
	ld a, e;							// 
	sub $20;							// 
	ld c, a;							// 
	pop hl;								// 
	pop de;								// 
	ret c;								// 
	rst $30;							// 
	ld b, $eb;							// 
	ld a, 1;							// 
	or a;								// 
	ret;								// 

L347B:
	ld a, ($2D20);						// 
	bit 4, a;							// 
	jr nz, L34B1;						// 
	ld hl, $3C1F;						// 
	push de;							// 
	rst $30;							// 
	ld bc, $0df7;						// 
	jr z, L3497;						// 
	call L1265;							// 
	ld hl, $2600;						// 
	push hl;							// 
	call L1096;							// 
	pop hl;								// 

L3497:
	pop de;								// 
	ret c;								// 
	push de;							// 
	call L18B3;							// 
	pop de;								// 
	jr nz, L34B1;						// 
	ld hl, $2d20;						// 
	ld a, $40;							// 
	or (hl);							// 
	ld (hl), a;							// 
	ld hl, $260f;						// 
	ld bc, 8;							// 

L34AD:
	ldir;								// 
	xor a;								// 
	ret;								// 

L34B1:
	ld a, $ff;							// 
	ld (de), a;							// 
	inc de;								// 
	inc a;								// 
	ld (de), a;							// 
	push de;							// 
	pop hl;								// 
	inc de;								// 
	ld bc, 5;							// 
	jr L34AD;							// 

L34BF:
	ld a, (hl);							// 
	inc hl;								// 
	cp ' ';								// $20
	jr z, L34C7;						// 
	ld (de), a;							// 
	inc de;								// 

L34C7:
	djnz L34BF;							// 
	ret;								// 

	ld de, $2d00;						// 
	ld hl, $40;							// 
	ld bc, $0b;							// 
	ldir;								// 
	ld hl, ($3c23);						// 
	ld e, $0f;							// 
	ld bc, 8;							// 
	rst $30;							// 
	rlca;								// 
	xor a;								// 
	ld (de), a;							// 
	ld h, d;							// 
	ld l, e;							// 
	inc e;								// 
	ld bc, $67;							// 
	ldir;								// 
	push de;							// 
	ld l, $10;							// 
	ld e, (hl);							// 
	inc l;								// 
	ld d, (hl);							// 
	ld b, a;							// 
	ld c, a;							// 
	push hl;							// 
	ld hl, $80;							// 
	call L0831;							// 
	pop hl;								// 
	ld l, $0b;							// 
	rst $30;							// 
	nop;								// 
	pop hl;								// 
	ld l, 0;							// 
	ld c, $7f;							// 
	xor a;								// 

L3503:
	add a, (hl);						// 
	cpi;								// 
	jp pe, L3503;						// 
	ld (hl), a;							// 
	ret;								// 

	call L11C3;							// 
	ld a, b;							// 
	inc a;								// 
	jr nz, L3519;						// 
	call L352D;							// 
	cp 9;								// 
	scf;								// 
	ret nz;								// 

L3519:
	call L11D0;							// 
	ld a, (iy + _x_ptr);				// 

L351F:
	srl a;								// 
	ccf;								// 
	ret nc;								// 
	sla e;								// 
	rl d;								// 
	rl c;								// 
	rl b;								// 
	jr L351F;							// 

L352D:
	res 3, (iy + _oldppc);				// 
	exx;								// 
	ld bc, 0;							// 
	ld de, 2;							// 
	call L10BA;							// 
	ret c;								// 

L353C:
	call L305E;							// 
	exx;								// 
	call L081C;							// 
	ret c;								// 
	exx;								// 
	jr L353C;							// 
	call L19C6;							// 
	or a;								// 
	ret;								// 

	push hl;							// 
	ld b, 0;							// 
	call L33D2;							// 
	pop hl;								// 
	ret c;								// 
	ld a, ($3df8);						// 
	ld c, a;							// 
	ld a, ($3df9);						// 
	ld ($3df8), a;						// 
	push hl;							// 
	push bc;							// 
	call L3570;							// 
	pop bc;								// 
	pop hl;								// 
	push af;							// 
	ld a, c;							// 
	ld ($3df8), a;						// 
	pop af;								// 
	ret c;								// 
	ld a, $80;							// 
	jr L359F;							// 

L3570:
	ld b, 0;							// 

L3572:
	ld hl, $2d40;						// 
	push bc;							// 
	push hl;							// 
	call L3402;							// 
	pop hl;								// 
	pop bc;								// 
	ret c;								// 
	and a;								// 
	jr z, L358B;						// 
	inc b;								// 
	inc hl;								// 
	ld a, (hl);							// 
	cp '.';								// $2e
	jr z, L3572;						// 

L3587:
	ld a, $1b;							// 
	scf;								// 
	ret;								// 

L358B:
	ld a, b;							// 
	cp 2;								// 
	jr nz, L3587;						// 
	ld a, ($3c06);						// 
	cp '.';								// $2e
	jr nz, L359B;						// 
	ld a, 8;							// 
	scf;								// 
	ret;								// 

L359B:
	or a;								// 
	ret;								// 

	ld a, 0;							// 

L359F:
	call L1524;							// 
	ret c;								// 
	call L1773;							// 
	call L115C;							// 
	call L1A07;							// 
	call L163E;							// 
	ld hl, $1a65;						// 
	ld ($3dee), hl;						// 
	call L1A21;							// 
	ld a, $17;							// 
	jr c, L35DE;						// 
	ld l, (ix + $1C);					// 
	ld h, (ix + $1D);					// 
	push hl;							// 
	ld a, $0b;							// 
	add a, l;							// 
	ld l, a;							// 
	bit 0, (hl);						// 
	pop hl;								// 
	ld a, $18;							// 
	scf;								// 
	jr nz, L35DE;						// 
	ld (hl), $e5;						// 
	push bc;							// 
	push de;							// 
	call L17E7;							// 
	pop de;								// 
	pop bc;								// 
	call nc, L3108;						// 
	call nc, L10F3;						// 

L35DE:
	ld (ix + 0), 0;						// 
	ret;								// 

	ld b, 1;							// 
	push hl;							// 
	push de;							// 
	call L16DE;							// 
	pop de;								// 
	pop hl;								// 
	jr nc, L35FA;						// 
	cp $10;								// 
	scf;								// 
	ret nz;								// 
	push de;							// 
	ld b, 0;							// 
	call L33D2;							// 
	pop de;								// 
	ret c;								// 

L35FA:
	ex de, hl;							// 
	call L35FF;							// 
	ret;								// 

L35FF:
	push hl;							// 
	ld hl, $2d00;						// 
	ld a, (iy + 0);						// 
	ld (hl), a;							// 
	inc hl;								// 
	ld a, (iy + 1);						// 
	ld (hl), a;							// 
	call L16CB;							// 
	pop de;								// 
	ret c;								// 
	push de;							// 
	ex de, hl;							// 
	ld hl, $2d02;						// 
	ld a, $0b;							// 
	ld c, a;							// 
	add a, e;							// 
	ld e, a;							// 
	ld a, (de);							// 
	ld (hl), a;							// 
	inc hl;								// 
	ld a, c;							// 
	add a, e;							// 
	ld e, a;							// 
	ex de, hl;							// 
	ld bc, 4;							// 
	ldir;								// 
	ex de, hl;							// 
	call L19E0;							// 
	rst $30;							// 
	nop;								// 
	pop de;								// 
	ld hl, $2d00;						// 
	ld bc, $0b;							// 
	rst $30;							// 
	ld b, $b7;							// 
	jp L16BE;							// 
	ld a, 0;							// 
	call L1524;							// 
	ret c;								// 
	call L1773;							// 
	call L115C;							// 
	call L1A07;							// 
	ld l, (ix + $1C);					// 
	ld h, (ix + $1D);					// 
	ld a, $0b;							// 
	add a, l;							// 
	ld l, a;							// 
	bit 0, (hl);						// 
	ld a, $18;							// 
	scf;								// 
	jr nz, L3668;						// 
	ld b, 0;							// 
	ld c, b;							// 
	ld d, c;							// 
	ld e, d;							// 
	call L3183;							// 
	call L163E;							// 
	call L367F;							// 

L3668:
	push af;							// 
	call L168F;							// 
	pop af;								// 
	ret;								// 

	bit 1, (ix + $01);					// 
	ld a, 8;							// 
	scf;								// 
	ret z;								// 
	call L19C6;							// 
	call L3183;							// 
	call L1142;							// 

L367F:
	call L3108;							// system processing call
	call nc, L10F3;						// call if no carry
	ld hl, $1a7c;						// set system address
	ld ($3dee), hl;						// store system address
	call L1A21;							// call processing routine
	or a;								// test accumulator
	ret;								// return to caller

L3690:
	ld l, 0;							// clear L register
	jr L369A;							// jump to initialization
	ld l, 0;							// clear L register
	ld b, l;							// clear B register
	ld c, l;							// clear C register
	ld d, l;							// clear D register
	ld e, l;							// clear E register

L369A:
	push bc;							// save BC registers
	push de;							// save DE registers
	ld a, (iy + _nxtlin_h);				// get next line high byte
	cp 0;								// test if zero
	jr nz, L36B2;						// jump if not zero
	call L19FA;							// call processing routine
	rst $30;							// restart 30 (calculator)
	dec c;								// decrement C register
	ld b, 0;							// clear B register
	jr nz, L36B2;						// jump if not zero
	inc b;								// increment B register
	ld a, (iy + _udg_h);				// get UDG high byte
	jr L36B5;							// jump to coordinate setting

L36B2:
	ld a, (iy + _x_ptr);				// get X pointer

L36B5:
	ld (iy + _coord_y), a;				// set Y coordinate
	ld (iy + _coord_x), b;				// set X coordinate
	pop de;								// restore DE registers
	pop bc;								// restore BC registers
	ld a, l;							// get L register value
	cp 0;								// test if zero
	jr z, L36F0;						// jump if zero
	push bc;							// save BC registers
	push de;							// save DE registers
	call L19C6;							// call processing routine
	ex de, hl;							// exchange DE and HL
	pop de;								// restore DE registers
	cp 1;								// compare with 1
	jr z, L36E0;						// jump if equal to 1
	cp 2;								// compare with 2
	jr z, L36D6;						// jump if equal to 2
	ld a, 2;							// load error code 2
	pop bc;								// restore BC registers
	scf;								// set carry flag
	ret;								// return with error

L36D6:
	sbc hl, de;							// subtract DE from HL with carry
	ex de, hl;							// exchange DE and HL
	ld l, c;							// load C into L
	ld h, b;							// load B into H
	pop bc;								// restore BC registers
	sbc hl, bc;							// subtract BC from HL with carry
	jr L36E7;							// jump to result handling

L36E0:
	add hl, de;							// add DE to HL
	ex de, hl;							// exchange DE and HL
	ld l, c;							// load C into L
	ld h, b;							// load B into H
	pop bc;								// restore BC registers
	adc hl, bc;							// add BC to HL with carry

L36E7:
	ld c, l;							// store L back to C
	ld b, h;							// store H back to B
	jr nc, L36F0;						// jump if no carry (no overflow)
	ld de, 0;							// clear DE (overflow handling)
	ld b, d; 							//
	ld c, e;							// clear BC (overflow handling)

L36F0:
	ld a, $0e;							// load system call code
	call L37C4;							// call system routine
	rst $30;							// restart 30 (calculator)
	ex af, af';							// exchange AF registers
	jr nc, L36FC;						// jump if no carry
	call L19E0;							// call error routine

L36FC:
	ld a, $12;							// load system call code 12
	call L37C4;							// call system routine
	rst $30;							// restart 30 (calculator)
	ex af, af';							// exchange AF registers
	jp z, L3792;						// jump if zero to handler
	jr c, L3714;						// jump if carry to processing
	push de;							// save DE registers
	push bc;							// save BC registers
	call L19FA;							// call processing routine
	call L18D0;							// call display routine
	pop bc;								// restore BC registers
	pop de;								// restore DE registers
	jr L36FC;							// loop back for more processing

L3714:
	push bc;							// save BC registers
	push de;							// save DE registers
	rst $30;							// restart 30 (calculator)
	dec c;								// decrement counter
	jr nz, L371F;						// jump if not zero
	call L37BC;							// call completion routine
	jr L372F;							// jump to continuation

L371F:
	push de;							// save DE registers
	push bc;							// save BC registers
	xor a;								// clear accumulator
	call L3796;							// call display routine
	call L37BC;							// call completion routine
	ld a, 1;							// load value 1
	pop bc;								// restore BC registers
	pop de;								// restore DE registers
	call L3796;							// call display routine

L372F:
	push de;							// save DE registers
	call L19C6;							// call graphics routine
	rst $30;							// restart 30 (calculator)
	dec c;								// decrement counter
	jr z, L3743;						// jump if zero
	ld a, (iy + _coord_x);				// get X coordinate
	or a;								// test if zero
	jr nz, L375E;						// jump if not zero
	call L19C6;							// call graphics routine
	call L3796;							// call display routine

L3743:
	ld a, $1f;							// load control code 31 (print position)
	call L37C4;							// call system routine
	rst $30;							// restart 30 (calculator)
	ex af, af';							// exchange AF registers
	jr z, L375E;						// jump if zero
	push bc;							// save BC registers
	push de;							// save DE registers
	call L125E;							// call processing routine
	pop de;								// restore DE registers
	pop bc;								// restore BC registers
	jr nc, L3759;						// jump if no carry
	pop hl;								// restore HL registers
	pop de;								// restore DE registers
	pop bc;								// restore BC registers
	ret;								// return to caller

L3759:
	call L081C;							// call error handling routine
	jr L3743;							// loop back for retry

L375E:
	call L115C;							// call coordinate routine
	ld a, (iy + _coord_y);				// get Y coordinate
	sub (ix + $13);						// subtract offset value
	ld h, 0;							// clear H register
	ld l, a;							// load result into L
	call L0836;							// call graphics calculation routine
	ld a, (iy + _coord_y);				// get Y coordinate
	pop hl;								// restore HL registers
	dec a;								// decrement Y coordinate
	and l;								// mask with L register
	ld h, 0;							// clear H register
	ld l, a;							// load masked value into L
	call L0831;							// call coordinate routine
	call L114F;							// call display routine
	pop de;								// restore DE registers
	pop bc;								// restore BC registers
	ld l, e;							// copy E to L
	ld h, d;							// copy D to H
	inc h;								// increment H
	inc h;								// increment H again
	dec hl;								// decrement HL
	srl h;								// shift H right
	dec h;								// decrement H
	ld a, (iy + _coord_y);				// get Y coordinate
	ld l, a;							// load Y into L
	dec a;								// decrement Y
	and h;								// mask with H
	ld h, a;							// store masked result in H
	ld a, l;							// get original Y
	sub h;								// subtract masked value
	ld (ix + $13), a;					// store offset result

L3792:
	or a;								// test accumulator
	jp L19B9;							// jump to handler routine

L3796:
	or a;								// test accumulator
	ld hl, $0200;						// load value 512
	jr nz, L37A7;						// jump if not zero
	ld a, (iy + _coord_y);				// get Y coordinate
	push af;							// save Y coordinate

L37A0:
	rrca;								// rotate right with carry
	jr c, L37A6;						// jump if carry set
	add hl, hl;							// shift HL left
	jr L37A0;							// loop back

L37A6:
	pop af;								// restore accumulator

L37A7:
	dec hl;								// decrement HL
	call L0831;							// call coordinate routine
	ld e, d;							// move D to E
	ld d, c;							// move C to D
	ld c, b;							// move B to C
	ld b, 0;							// clear B register

L37B0:
	srl c;								// shift C right logical
	rr d;								// rotate D right through carry
	rr e;								// rotate E right through carry
	rrca;								// rotate accumulator right with carry
	jr nc, L37B0;						// loop while no carry
	jp L0824;							// jump to processing routine

L37BC:
	ld a, $1c;							// load control code 28 (print inverse)
	call L37C4;							// call offset calculation
	rst $30;							// restart 30 (calculator)
	nop;								// no operation
	ret;								// return to caller

L37C4:
	push ix;							// save IX register
	pop hl;								// get IX value into HL
	add a, l;							// add A to L
	ld l, a;							// store result in L
	ret;								// return with offset address

upper_end:
// End of UnoDOS 3 BASIC integration module
// This module provides complete BASIC interpreter integration
// including system calls, file I/O, and ROM interfacing
