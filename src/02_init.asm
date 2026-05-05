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
select_basic_rom:
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
reset_init:
	xor a;								// clear accumulator (A = 0)
	ld bc, $2a30;						// load delay counter (10800 decimal)
	out (mmcram), a;					// select divMMC page 0, disable CONMEM/MAPRAM

delay_loop:
	dec bc;								// decrement delay counter
	nop;								// timing delay
	ld a, c;							// get low byte of counter
	or b;								// OR with high byte to test for zero
	jr nz, delay_loop;					// loop until counter reaches zero (bus settle delay)
	call select_basic_rom;				// force BASIC ROM selection on 128K machines
	ld a, $0e;							// load status byte
	ld ($201f), a;						// store at divMMC status location
	ld a, ($2d42);						// check initialization marker
	cp $aa;								// compare with expected value (170 decimal)
	jr nz, full_init;					// if not initialized, jump to full init
	ld a, $7f;							// keyboard row for SPACE key
	in a, (ula);						// read keyboard row
	rra;								// rotate right to test SPACE in bit 0
	jp c, exit_to_basic;				// if SPACE not pressed, exit to BASIC
	;									// which sets HL to 1 then exits

;	// start of full initialization - clear screen to black
full_init:
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

;	// Check this divMMC device has more than 32K (4 pages) of memory
	ld a, 4;							// start memory test from page 4

;	org $013b
memory_test_loop:
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
	jr nz, memory_test_loop;			// if not, continue testing next page
	ld a, 4;							// select page 4 for writability test
	out (mmcram), a;					// switch back to page 4
	ld hl, $2000;						// point to start of divMMC window
	ld a, (hl);							// read current value
	inc (hl);							// increment the value
	cp (hl);							// compare original with incremented
	jr nz, memory_init_complete;		// if different, memory is writable
	ld l, $1c;							// else set L to $1C (error indicator)

;	org $0169
memory_init_complete:
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
	call setup_vector_table;			// setup system vectors and initial configuration
	call setup_divmmc_config;			// additional system initialization
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
	ld (cleanup_routine), a;			// store RET at jump target
	ld (hl), a;							// store RET in code area
	ld hl, $c937;						// pack: RET + SCF instructions
	ld ($2515), hl;						// store at address $2515
	ld (memory_address_compare), hl;	// store at address memory_address_compare
	ld hl, $0812;						// pack: EX AF,AF' + LD DE,nn high byte
	ld ($2017), hl;						// store at address $2017
	ld hl, $0c3f1;						// pack: some instructions (needs verification)
	ld ($201e), hl;						// store code at address $201E
	ld hl, $1ff7;						// address near end of divMMC window
	ld ($2020), hl;						// store address reference
	ld a, $c9;							// RET instruction opcode
	ld ($2f00), a;						// place RET at $2F00
	ld hl, cr_string;					// point to "detecting devices" message
	call pr_str;						// print device detection message
	ld a, $80;							// device ID or test parameter
	call show_device_status;			// device detection/initialization routine
	ld a, $88;							// second device ID or test parameter
	call show_device_status;			// detect/initialize second device
	ld hl, null_terminator_byte;		// point to "mounting drives" message
	call pr_str;						// print drive mounting message
	call disk_mount_init;				// mount drives and setup filesystem
	ld a, ($2d01);						// load drive configuration
	ld ($2d4a), a;						// store in alternative location
	ld ($2d46), a;						// store in another configuration location
	ld hl, sys_filename;				// point to "unodos" system filename
	call display_filename;				// setup filename for loading
	call load_main_system;				// attempt to load main system file
	push af;							// save load result flags
	call file_test;						// test if system file loaded correctly
	pop af;								// restore load result flags
	jr c, wait_space_release;			// if load failed, skip to user input wait
	ld hl, msg_nmi;						// point to NMI system filename
	call display_filename;				// setup NMI filename
	call load_nmi_handler;				// attempt to load NMI handler
	call show_result;					// show OK or ERROR for NMI system file
	jr nz, wait_space_release;			// if NMI load failed, skip to user input
	ld a, ($2e8c);						// check memory configuration result
	and a;								// test if zero (indicates error)
	jr nz, wait_space_release;			// if memory error, skip to user input
	ld hl, msg_betadisk;				// point to "betadisk" system filename
	call display_filename;				// setup betadisk filename
	call load_system_page3;				// attempt to load betadisk system
	push af;							// save load result
	call nc, execute_page3_code;		// if load successful, initialize betadisk
	pop af;								// restore load result
	call show_result;					// show OK or ERROR for betadisk load

;	org $0242
wait_space_release:
	ld a, $7f;							// keyboard row for SPACE key
	in a, (ula);						// read keyboard row
	rra;								// rotate right to test SPACE key in bit 0
	jr c, mute_and_exit;				// if SPACE not pressed, continue to exit
	jr wait_space_release;				// loop waiting for SPACE release

	org $0248
mute_and_exit:
	call mute_psg;						// turn off PSG sound generators

	org $024b
system_delay:
	ld de, $07d0;						// load delay value (2000 decimal)
	call delay_routine;					// delay routine for system settling

	org $0251
exit_to_basic:
	ld hl, $0001;						// BASIC ROM entry point after initialization
	jp jump_unmap_hl;					// unmap divMMC and jump into BASIC ROM
