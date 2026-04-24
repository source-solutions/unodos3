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

;;; 01_restarts.asm

;	// automatically mapped in by the hardware after M1 when PC=$0000
	org $0000;							// UnoDOS entry point at system reset
start:
	di;									// interrupts off for initialization
	ld sp, $5e00;						// set stack pointer to $5e00 (below UDG area)
	jp reset_init;						// jump to main initialization routine

;	// automatically mapped in by the hardware after M1 when PC=0008h
;	// main API entry point
	org $0008
restart_08:
	jp syscall_dispatcher;				// jump to main syscall dispatcher

next_char_basic:
	ld hl, (ch_add);					// get pointer to next character in BASIC program
	jr char_handler_entry;				// continue to character handler

	org $0010
restart_10:
	jp char_print_routine;				// jump to character print routine (RST $10 vector)

	org $0015
char_handler_entry:
	jp char_processing_routine;			// jump to character processing routine

	org $0018
restart_18:
	jp command_dispatcher;				// jump to ROM routine caller (RST $18 vector)

	org $001f
next_char_rst20:
restart_20 equ next_char_rst20 + 1
	jr keyboard_ret_instruction;		// jump to next character routine
	ld e, l;							// save L register to E
	ld e, h;							// save H register to E (overwrites previous)
	ld (x_ptr), hl;						// save HL to ? marker pointer in BASIC
	jr char_process_continue;			// continue processing

	org $0028
restart_28:
	push hl;							// save HL on stack
	ld hl, (mmc_sp);					// load MMC stack pointer
	ex (sp), hl;						// exchange with saved HL on stack
	ret;								// return to address from MMC stack

;	// auxiliary routines for internal UnoDOS business
	org $0030
restart_38:
	jr vector_dispatcher;				// jump to internal vector table dispatcher 

cmd_folder:
	defm "/dos/"; 						// avoids clash with keywords in tokenizers

;	// automatically mapped in by the hardware after M1 when PC=$0038
	org $0038
maskint:
	jr next_char_rst20;					// jump to restart_20 handler (maskable interrupt)
	ld hl, $0039;						// load address after interrupt vector
	jp interrupt_cleanup_exit;			// jump to interrupt cleanup routine

system_info:
	defm "sys", 0;						// system file extension
	defm "2026";						// year of release

load_byte_de:
	ld a, (de);							// load byte pointed to by DE

keyboard_test_pattern:
	ld bc, $fb00;						// load test pattern for keyboard scanning
	ret;								// return to caller

keyboard_ret_instruction equ keyboard_test_pattern + 2;	// points to RET instruction in keyboard_test_pattern

char_process_continue:
	jp error_handler_entry;				// jump to character processing continuation

cr_string:
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
nmi_handler:
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
	jp nmi_status_handler;				// jump to handler routine
	ei;									// enable interrupts
	push af;							// save accumulator and flags
	ld a, (mmc_1);						// get current MMC page
	out (mmcram), a;					// restore MMC memory configuration
	pop af;								// restore accumulator and flags
	jp unmap_and_return;				// jump to exit handler

; // internal vector table dispatcher (RST $30 handler)
vector_dispatcher:
	ld (mmc_2), hl;						// save HL register to MMC storage
	pop hl;								// get return address from stack
	inc hl;								// point to byte after RST instruction
	push hl;							// put incremented address back on stack
	dec hl;								// point back to parameter byte
	push de;							// save DE register
	ld e, (hl);							// load vector number from parameter
	ld d, 0;							// clear upper byte (E contains vector index)
	ld hl, vector_tbl;					// point to start of vector table

; // vector table lookup and dispatch
vector_lookup:
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

;;; 02_init.asm

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

; Check this divMMC device has more than 32K (4 pages) of memory
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

;;; 03_system_loader.asm

display_filename:
	call build_sys_path;				// construct full system file path with extension
	push hl;							// save path pointer
	ld de, 5;							// offset to filename portion (skip "/dos/")
	add hl, de;							// point to filename part
	call pr_str;						// print filename to screen
	pop hl;								// restore full path pointer
	ret;								// return with full path in HL

	org $0272
show_result:
	ld hl, msg_ok;						// point to "OK" message
	jr nc, print_result_msg;			// jump if no carry (success)
	ld hl, msg_failed;					// else point to error/failed message

print_result_msg:
	jp pr_str;							// print the success/error message

show_device_status:
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
delay_routine:
	ld b, $ff;							// delay loop counter (255 iterations)

delay_inner_loop:
	djnz delay_inner_loop;				// inner delay loop (256 iterations)
	dec de;								// decrement outer delay counter
	ld a, e;							// get low byte
	or d;								// OR with high byte to test for zero
	jr nz, delay_routine;				// repeat until DE reaches zero
	ret;								// return after delay complete

load_system_page3:
	call open_file_read;				// open file for reading
	ret c;								// return if file open failed
	push af;							// save file handle
	ld a, 3;							// select divMMC page 3
	out (mmcram), a;					// switch to divMMC page 3
	pop af;								// restore file handle
	ld hl, $2000;						// destination: start of divMMC window
	ld bc, $1c00;						// byte count: 7168 bytes (7KB)
	jr read_file_data;					// continue to file read routine

load_nmi_handler:
	call open_file_read;				// open file for reading
	ret c;								// return if file open failed
	ld hl, $2f00;						// destination: $2F00 (NMI handler area)
	ld bc, $0e00;						// byte count: 3584 bytes

read_file_data:
	ld e, a;							// save file handle in E
	push de;							// save file handle on stack
	rst $08;							// call UnoDOS API
	defb f_read;						// read from file
	pop de;								// restore file handle
	ld a, e;							// get file handle back
	jr close_file_page0;				// continue to file close routine

load_main_system:
	call open_file_read;				// open main system file for reading
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

close_file_page0:
	rst $08;							// call UnoDOS API
	defb f_close;						// close the file
	ld a, 0;							// select divMMC page 0
	out (mmcram), a;					// switch back to page 0
	ret;								// return to caller

open_file_read:
	ld a, $24;							// file mode: read-only
	ld b, 1;							// drive number (drive 1)
	rst $08;							// call UnoDOS API
	defb f_open;						// open file for reading
	ret;								// return with file handle in A or carry set if error

build_sys_path:
	call build_base_path;				// construct base path ("/dos/[filename].")
	ld hl, system_info;					// point to "sys" extension string

add_extension:
	call copy_string_loop;				// copy extension string to path
	ld (de), a;							// store null terminator
	ld hl, $2dce;						// return pointer to completed path
	ret;								// return with full path in HL

build_alt_sys_path:
	call build_base_path;				// construct base path ("/dos/[filename].")
	ld hl, system_info;					// point to "sys" extension string
	jr add_extension;					// continue to add extension

build_base_path:
	push hl;							// save filename pointer
	ld de, $2dce;						// destination buffer for full path
	ld hl, sys_folder;					// source: "/dos" string
	call copy_string_loop;				// copy "/dos" to buffer
	ld a, $2f;							// forward slash character
	ld (de), a;							// add slash after "/dos"
	inc de;								// advance destination pointer
	pop hl;								// restore filename pointer
	call copy_string_loop;				// copy filename to buffer
	ld a, $2e;							// dot character
	ld (de), a;							// add dot before extension
	inc de;								// advance destination pointer
	ret;								// return with DE pointing after dot

setup_vector_table:
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

check_handle_limit:
	ld c, a;							// save file handle in C
	ld a, ($2d47);						// get current file handle count
	cp 6;								// compare with maximum (6 handles)
	scf;								// set carry flag (error condition)
	ret z;								// return if maximum handles reached
	ld hl, $2c00;						// point to file handle table start

find_free_handle_slot:
	ld a, (hl);							// get file handle entry
	and a;								// test if slot is free (zero)
	jr z, store_handle_in_slot;			// jump if free slot found
	ld a, $28;							// file handle entry size (40 bytes)
	add a, l;							// advance to next handle slot
	ld l, a;							// update pointer
	jr find_free_handle_slot;			// check next slot

store_handle_in_slot:
	ld (hl), c;							// store file handle in free slot
	push hl;							// save handle slot address
	pop iy;								// copy to IY register
	ld hl, $2d47;						// point to file handle counter
	inc (hl);							// increment active handle count
	ret;								// return with handle slot in IY

close_handle_slot:
	call find_file_handle;				// find file handle slot
	ret c;								// return if handle not found
	xor a;								// clear accumulator
	ld (hl), a;							// clear the file handle slot
	ld hl, $2d47;						// point to file handle counter
	dec (hl);							// decrement active handle count
	or a;								// clear carry flag (success)
	ret;								// return with success

find_handle_with_setup:
	push hl;							// save HL register
	push bc;							// save BC register
	call find_file_handle;				// find file handle slot
	push hl;							// save handle slot address
	pop iy;								// copy to IY register
	pop bc;								// restore BC register
	pop hl;								// restore HL register
	ret;								// return with handle slot in IY

find_file_handle:
	ld c, a;							// save target handle in C
	ld b, 6;							// maximum number of file handles
	ld hl, $2c00;						// point to start of file handle table

handle_search_loop:
	ld a, (hl);							// get file handle from current slot
	xor c;								// compare with target handle
	and %11111000;						// mask out lower 3 bits
	jr z, handle_found_check;			// jump if match found
	ld a, $28;							// handle slot size (40 bytes)
	add a, l;							// advance to next slot
	ld l, a;							// update pointer
	djnz handle_search_loop;			// continue search
	scf;								// set carry flag (handle not found)
	ret;								// return with error

handle_found_check:
	ld a, (hl);							// get the found handle
	cp c;								// compare with target
	ret c;								// return with carry if less than target
	ld a, c;							// get target handle
	and %00000111;						// keep only lower 3 bits
	ret;								// return with partial handle info

memory_address_calc:
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
	call search_error_pages;			// call address lookup function
	ld a, ixl;							// get low byte of IX back

restore_registers:
	push hl;							// save HL register
	pop ix;								// copy to IX register
	pop hl;								// restore original HL
	pop de;								// restore original DE
	ret;								// return to caller

setup_divmmc_config:
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

execute_page3_code:
	nop;								// padding/alignment
	nop;								// padding/alignment
	nop;								// padding/alignment
	nop;								// padding/alignment
	nop;								// padding/alignment
	ld a, 3;							// select divMMC page 3
	out (mmcram), a;					// switch to divMMC page 3
	call system_entry;					// call loaded code at $2000
	xor a;								// clear accumulator
	out (mmcram), a;					// switch back to divMMC page 0
	ret;								// return to caller

search_error_pages:
	push bc;							// save BC register
	ld iy, $2000;						// point IY to divMMC window start
	ld b, 4;							// loop counter for 4 iterations

page_search_loop:
	cp (iy + _err_nr);					// compare with error number field
	jr z, search_found_success;			// jump if match found
	inc iyh;							// advance to next page
	djnz page_search_loop;				// continue loop
	pop bc;								// restore BC register
	scf;								// set carry flag (not found)
	ret;								// return with error

search_found_success:
	or a;								// clear carry flag (success)
	pop bc;								// restore BC register
	ret;								// return with success

prepare_system_request:
	ld b, a;							// save request parameter in B
	ld hl, $2d2a;						// point to system table

system_table_loop:
	call validate_filename_buffer;		// get/prepare system data
	ld ixh, a;							// store result in IX high
	ld a, (hl);							// get table entry
	cp 255;								// check for end marker
	jr z, table_end_error;				// jump if end of table
	ld e, a;							// save entry in E
	push de;							// save DE register
	inc hl;								// advance to address field
	ld e, (hl);							// get low byte of address
	inc hl;								// advance to high byte
	ld d, (hl);							// get high byte of address 
	inc hl;								// advance to next entry
	push hl;							// save table pointer
	push bc;							// save request parameter
	call process_table_entry;			// process the entry
	pop bc;								// restore request parameter
	pop hl;								// restore table pointer
	pop ix;								// restore IX from DE
	ret nc;								// return if operation successful
	jr system_table_loop;				// continue with next table entry

table_end_error:
	ld a, $1e;							// error code: "invalid" (30 decimal)
	scf;								// set carry flag (error)
	ret;								// return with error

process_table_entry:
	push hl;							// save HL register
	push hl;							// save HL register again
	out (mmcram), a;					// switch to specified divMMC page
	ld ($3df8), a;						// store current divMMC page number
	ld h, d;							// copy address to HL
	ld l, e;							// complete address transfer
	call memory_address_calc;			// call address handling routine
	jp get_handler_from_table;			// jump to main processing routine

get_drive_info:
	ld hl, $2df2;						// point to drive info buffer
	push hl;							// save buffer pointer
	rst $08;							// call UnoDOS API
	defb m_driveinfo;					// get drive information
	pop hl;								// restore buffer pointer
	ld b, a;							// save number of drives in B
	and a;								// test if zero drives
	ret z;								// return if no drives found

print_all_drives:
	push bc;							// save drive counter
	call print_drive_info;				// print information for one drive
	pop bc;								// restore drive counter
	djnz print_all_drives;				// repeat for all drives
	ret;								// return when all drives printed

print_drive_info:
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
	call print_string_comma;			// print string with comma
	ld b, h;							// save H to B
	ld c, l;							// save L to C
	pop hl;								// restore original HL
	call print_string_comma;			// print another string with comma
	ld l, e;							// setup for next operation
	ld h, d;							// complete address setup
	pop de;								// restore DE
	push bc;							// save BC for later
	call format_file_size;				// call formatting/display routine
	ld a, $0d;							// carriage return character
	rst $10;							// print newline
	pop hl;								// restore pointer for next drive
	ret;								// return to drive loop

print_string_comma:
	call pr_str;						// print string pointed to by HL
	inc hl;								// advance past string
	ld a, ',';							// comma character
	rst $10;							// print comma
	ld a, ' ';							// space character
	rst $10;							// print space
	ret;								// return to caller

	org $0482
format_size_display:
	ld l, a;							// save original value in L
	and %11100000;						// mask to get upper 3 bits
	ret z;								// return if zero (no size to display)
	ld e, $30;							// default base character '0'
	ld c, $66;							// default unit character 'f' (for bytes)
	cp ' ';								// compare with space character ($20)
	jr z, print_size_units;				// jump if 32 (32 bytes)
	ld c, $76;							// unit character 'v' for 'K'
	cp $60;								// compare with $60 (96 = 3 * 32K)
	jr z, print_size_units;				// jump if kilobyte size
	ld e, $61;							// base character 'a' for 'M'
	cp $80;								// compare with $80 (128 = 4 * 32M)
	ld c, $73;							// unit character 's' for 'M'
	jr z, print_size_units;				// jump if megabyte size
	ld c, $68;							// unit character 'h' for 'G'

print_size_units:
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

;;; 04_tape.asm

;	// automatically mapped in by the hardware after M1 when PC=004C6h
;	// Automapped entry point for SAVE command
	org $04c6
save_command_trap:
	ld hl, $1f80;						// return address for ROM SAVE routine
	push hl;							// push return address onto stack
	ld b, a;							// save file type in B
	xor a;								// clear accumulator
	out (mmcram), a;					// select divMMC page 0
	ld a, ($2d4c);						// check SAVE intercept flag
	and a;								// test if SAVE interception enabled
	ld a, b;							// restore file type
	jr z, fallback_rom_save;			// if not enabled, use ROM SAVE
	push de;							// save filename pointer
	push bc;							// save file type and parameters
	call alt_load_message_pointer;		// call UnoDOS file save handler
	pop bc;								// restore parameters
	pop de;								// restore filename pointer
	pop hl;								// remove return address from stack
	ld a, b;							// get file type back
	jp nc, $2011;						// if successful, jump to completion routine

fallback_rom_save:
	ld hl, $04c9;						// address within SAVE trap area
	jp interrupt_cleanup_exit;			// unmap divMMC and return to ROM SAVE

validate_filename_buffer:
	push hl;							// save HL register
	push bc;							// save BC register
	ld hl, $2cf1;						// point to buffer area
	ld bc, $0f;							// search length (15 bytes)
	xor a;								// search for null terminator
	cpir;								// scan for first null byte
	ld a, $0c;							// error code: "invalid filename"
	scf;								// set carry flag (assume error)
	call z, calc_string_length;			// if null found, calculate length
	pop bc;								// restore BC register
	pop hl;								// restore HL register
	ret;								// return with result

calc_string_length:
	ld a, $0f;							// original search length
	sub c;								// subtract remaining count
	ret;								// return actual length in A

;	org $050d
copy_with_page_switch:
	push af;							// save accumulator and flags
	push ix;							// save IX register
	push hl;							// save HL register
	pop ix;								// copy HL to IX
	ld hl, ($3df8);						// get divMMC page configuration
	ld c, mmcram;						// divMMC control port
	ld b, $7f;							// loop counter (127 bytes max)

;	org $051a
string_copy_loop:
	out (c), l;							// set divMMC page to L
	ld a, (ix + 0);						// get byte from source
	out (c), h;							// set divMMC page to H
	ld (de), a;							// store byte to destination
	inc ix;								// advance source pointer
	inc de;								// advance destination pointer
	and a;								// test if byte was null terminator
	jr z, string_copy_complete;			// if null, string copy complete
	djnz string_copy_loop;				// continue copying bytes

;	org $052a
string_copy_complete:
	push ix;							// save current IX pointer
	pop hl;								// copy IX to HL
	pop ix;								// restore original IX
	pop af;								// restore accumulator and flags
	ret;								// return to caller

;	org $0531
select_drive_number:
	push bc;							// save BC register
	cp '*';								// check if current drive requested
	jr nz, process_drive_number;		// if not '*', branch to display drive
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
process_drive_number:
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
load_command_trap:
	in a, (ula);						// dummy read to satisfy hardware timing
	ld a, 0;							// select divMMC page 0
	out (mmcram), a;					// switch to divMMC page 0
	ld a, ($2d4b);						// check LOAD intercept flag
	and a;								// test if LOAD interception enabled
	jr nz, handle_unodos_load;			// if enabled, handle UnoDOS LOAD

fallback_rom_load:
	push hl;							// save HL register
	ld hl, $0564;						// return address within LOAD trap area
	in a, (ula);						// dummy read to satisfy hardware timing
	jp interrupt_cleanup_exit;			// unmap divMMC and return to ROM LOAD

handle_unodos_load:
	push de;							// save filename pointer
	call alt_load_message_pointer;		// call UnoDOS file load handler
	pop de;								// restore filename pointer
	jr c, fallback_rom_load;			// if load failed, use ROM LOAD
	jp basic_command_entry;				// if successful, jump to completion routine

screen_coord_wrap:
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

copy_string_loop:
	ld a, (hl);							// get character from source string
	and a;								// test if null terminator
	ret z;								// return if end of string
	ld (de), a;							// copy character to destination
	inc hl;								// advance source pointer
	inc de;								// advance destination pointer
	jr copy_string_loop;				// continue copying string

;	org $05a0
vector_tbl:
	defw store_32bit;					// vector 0: store 32-bit value (DEBC) at (HL)
	defw load_32bit_value;				// vector 1: load 32-bit value from (HL) to DEBC
	defw get_basic_char;				// vector 2: get next character from BASIC
	defw syntax_check;					// vector 3: check BASIC syntax mode
	defw copy_string_with_paging;		// vector 4: copy null-terminated string with page switching
	defw copy_with_page_switch;			// vector 5: copy string with page switching (127 char max)
	defw copy_block_with_paging;		// vector 6: copy data block with page switching (LDIR)
	defw copy_data_block;				// vector 7: copy data block (LDIR or page switch)
	defw compare_32bit;					// vector 8: compare 32-bit values (DEBC vs (HL))
	defw select_drive_number;			// vector 9: display current drive (format "Ad0:")
	defw set_dest_divmmc_window;		// vector 10: set DE to $2000, copy to page 4
	defw set_src_divmmc_window;			// vector 11: set HL to $2000, copy to page 4
	defw write_file_page4;				// vector 12: write data to file in page 4
	defw test_32bit_zero;				// vector 13: test if 32-bit value DEBC is zero
	defw format_size_display;			// vector 14: format and display disk size

set_dest_divmmc_window:
	ld de, $2000;						// set destination to start of divMMC window
	jr copy_with_page4;					// continue to memory copy routine

set_src_divmmc_window:
	ld hl, $2000;						// set source to start of divMMC window
	jr copy_with_page4;					// continue to memory copy routine

copy_with_page4:
	call check_ext_memory;				// check if extended memory available
	ret z;								// return if no extended memory
	ld a, 4;							// select divMMC page 4
	out (mmcram), a;					// switch to page 4
	ldir;								// copy BC bytes from HL to DE
	xor a;								// clear accumulator
	out (mmcram), a;					// switch back to page 0
	ret;								// return to caller

check_ext_memory:
	ld a, ($2e8c);						// get memory configuration status
	cp $1c;								// compare with error indicator (28 decimal)
	scf;								// set carry flag (assume error)
	ret;								// return (Z set if memory error)

write_file_page4:
	ld e, a;							// save file handle in E
	call check_ext_memory;				// check if extended memory available
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

get_basic_char:
	rst $18;							// call BASIC ROM routine
	defw next_char;						// get next character from BASIC program
	ret;								// return with character in A

setup_page_copy:
	push ix;							// save IX register
	push hl;							// save HL register
	pop ix;								// copy HL to IX
	ld hl, ($3df8);						// get divMMC page configuration (L=source page, H=dest page)

page_copy_loop:
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
	jr nz, page_copy_loop;				// continue if more bytes to copy
	push ix;							// save final IX position
	pop hl;								// copy IX to HL
	pop ix;								// restore original IX
	ret;								// return to caller

copy_data_block:
	ld a, d;							// check destination address high byte
	cp '@';								// compare with $40 (16K boundary)
	jr c, setup_page_copy;				// if below $4000, use page switching copy
	ldir;								// else use direct memory copy
	ret;								// return to caller

setup_reverse_page_copy:
	push ix;							// save IX register
	push hl;							// save HL register
	pop ix;								// copy HL to IX
	ld hl, ($3df8);						// get divMMC page configuration

reverse_page_copy_loop:
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
	jr nz, reverse_page_copy_loop;		// continue if more bytes to copy
	push ix;							// save final IX position
	pop hl;								// copy IX to HL
	pop ix;								// restore original IX
	ret;								// return to caller

copy_block_with_paging:
	ld a, d;							// check destination address high byte
	cp '@';								// compare with $40 (16K boundary)
	jr c, setup_reverse_page_copy;		// if below $4000, use page switching copy
	ldir;								// else use direct memory copy
	ret;								// return to caller

copy_string_with_paging:
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

string_page_copy_loop:
	out (c), l;							// set destination divMMC page
	ld a, (ix + 0);						// get byte from source
	out (c), h;							// set source divMMC page
	ld (de), a;							// store byte to destination
	inc ix;								// advance source pointer
	inc de;								// advance destination pointer
	and a;								// test if byte was null terminator
	jr z, string_copy_done;				// if null, string copy complete
	djnz string_page_copy_loop;			// continue copying (max 127 chars)

string_copy_done:
	out (c), l;							// ensure destination page is selected
	jp string_copy_complete;			// jump to cleanup and return routine

null_terminator_byte:
	defb 0;								// null terminator / padding byte

;;; 05_arithmetic.asm

	org $0686
load_32bit_value:
	ld e, (hl);							// load low byte of 32-bit value
	inc hl;								// advance to next byte
	ld d, (hl);							// load second byte
	inc hl;								// advance to next byte
	ld c, (hl);							// load third byte
	inc hl;								// advance to next byte
	ld b, (hl);							// load high byte of 32-bit value
	inc hl;								// advance pointer past the value
	ret;								// return with 32-bit value in BCDE

test_32bit_zero:
	ld a, c;							// get byte C
	or b;								// OR with byte B
	or e;								// OR with byte E
	or d;								// OR with byte D
	ret;								// return with Z flag set if BCDE is zero

; // 32-bit comparison function (compare BCDE with memory at HL)
compare_32bit:
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

; // syntax checker (check if in BASIC syntax mode)
syntax_check:
	rst $18;							// call BASIC ROM routine
	defw syntax_z;						// check if in syntax checking mode
	ret;								// return with Z flag set if syntax mode

; // 32-bit store function (store DEBC to memory at HL)
store_32bit:
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
	defm ": failed";					// failure message text
	defb $0d, 0;						// carriage return, null terminator

;	org $06c8
msg_ok:
	defb $17, $0c, $01;					// TAB 27
	defm ": ok";						// success message text
	defb $0d, 0;						// carriage return, null terminator

;	org $06d1
msg_nmi:
	defm "nmi", 0;						// null ternimated message

;	// disk mounting and initialization routine
	org $06e1
disk_mount_init:
	ld hl, $2df2;						// load pointer to disk information table
	push hl;							// save disk info pointer on stack
	rst $08;							// call system function
	defb disk_info;						// get disk information
	pop hl;								// restore disk info pointer

;	// mount all available filesystems loop
mount_filesystems_loop:
	ld a, (hl);							// load filesystem identifier
	and a;								// check if zero (end of list)
	ret z;								// return if no more filesystems to mount
	push hl;							// save filesystem table pointer
	ld bc, 0;							// set mount parameters to zero
	rst $08;							// call system function
	defb f_mount;						// mount filesystem
	pop hl;								// restore filesystem table pointer
	ld de, 6;							// each filesystem entry is 6 bytes
	add hl, de;							// point to next filesystem entry
	jr mount_filesystems_loop;			// continue with next filesystem

filesystem_unmount:
	call search_filesystem_type;		// search for filesystem type in supported list
	scf;								// set carry flag to indicate error
	ret z;								// return if zero flag set
	ld l, a;							// store drive number in L register
	push hl;							// save drive number on stack
	call init_file_handle;				// call drive initialization routine
	pop hl;								// restore drive number from stack
	ret c;								// return if carry set (error)
	ld a, l;							// get drive number back
	call configure_system_drive;		// call drive configuration routine
	ret c;								// return if carry set (error)
	xor a;								// clear accumulator (A = 0)
	push iy;							// save IY register on stack
	pop hl;								// get IY value into HL
	ld (hl), a;							// clear first byte at IY address
	inc hl;								// advance to next byte
	ld (hl), a;							// clear second byte
	inc hl;								// advance to third byte
	ld (hl), a;							// clear third byte
	or a;								// clear carry flag (success)
	ret;								// return to caller

;	// search for filesystem type in supported list
search_filesystem_type:
	push bc;							// save BC register on stack
	ld hl, $2cf0;						// point to supported filesystem types table
	ld bc, $0f;							// set search length (15 bytes)
	cpir;								// compare and increment until match or end
	pop bc;								// restore BC register from stack
	ret nz;								// return if not found (NZ flag set)
	ld a, $1d;							// load error code $1d (unsupported filesystem)
	ret;								// return with error code

;	// check if drive is already mounted
check_drive_mounted:
	ld hl, $2d00;						// point to mounted drives table
	ld b, $0c;							// check up to 12 drive slots

;	// search loop through mounted drives
search_mounted_drives:
	cp (hl);							// compare drive ID with current entry
	jr z, drive_already_mounted;		// jump if match found (drive already mounted)
	inc hl;								// advance to next drive entry
	inc hl;								// (each entry is 3 bytes)
	inc hl;								// complete 3-byte entry traversal
	djnz search_mounted_drives;			// decrement B and loop if not zero
	ret;								// return if not found in table

;	// drive already mounted error
drive_already_mounted:
	ld a, $1f;							// load error code $1f (drive already mounted)
	scf;								// set carry flag to indicate error
	ret;								// return with error

filesystem_mount:
	ld l, a;							// store drive identifier in L register
	push hl;							// save drive identifier on stack
	push bc;							// save BC register on stack
	call check_drive_mounted;			// check if drive is already mounted
	pop bc;								// restore BC register from stack
	pop hl;								// restore drive identifier from stack
	ret c;								// return if carry set (drive already mounted)
	ld a, c;							// get partition number
	and a;								// check if zero (primary partition)
	jr z, mount_partition;				// jump if primary partition
	call configure_system_drive;		// call partition configuration routine
	ld a, $0b;							// load error code $0b (invalid partition)
	ccf;								// complement carry flag
	ret c;								// return if carry set (error)

;	// mount partition on drive
mount_partition:
	inc c;								// increment partition number (make 1-based)
	ld a, l;							// get drive identifier
	ld hl, $2df2;						// point to disk info structure
	push bc;							// save partition info on stack
	push hl;							// save disk info pointer on stack
	rst $08;							// call system function
	defb disk_info;						// get disk information
	pop hl;								// restore disk info pointer from stack
	jr nc, process_disk_info;			// jump if no error
	pop bc;								// restore partition info from stack
	ret;								// return with error

;	// process disk information and mount
process_disk_info:
	call find_empty_drive_slot;			// call disk processing routine
	pop bc;								// restore partition info from stack
	ld a, (hl);							// load partition type from disk info
	call validate_partition_type;		// validate partition type
	dec c;								// decrement partition number (back to 0-based)
	jr nz, finalize_drive_mount;		// jump if not primary partition
	push hl;							// save HL register on stack
	push bc;							// save partition info on stack
	call find_next_drive_letter;		// find next available drive letter
	pop bc;								// restore partition info from stack
	pop hl;								// restore HL register from stack
	ld c, a;							// store drive letter in C register

;	// finalize drive mounting in system table
finalize_drive_mount:
	ex de, hl;							// exchange DE and HL (DE now points to drive info)
	ld a, (de);							// load drive ID from drive info structure
	push hl;							// save HL register on stack
	push bc;							// save BC register on stack
	call prepare_system_request;		// call drive setup routine
	pop bc;								// restore BC register from stack
	pop hl;								// restore HL register from stack
	ret c;								// return if carry set (error in drive setup)
	ld (hl), a;							// store drive ID in drive table
	inc hl;								// advance to next byte in drive table entry
	ld (hl), c;							// store drive letter in drive table
	inc hl;								// advance to flags byte in drive table entry
	ld a, b;							// get drive/partition flags from B register
	or ixl;								// combine with IXL flags
	or %10000000;						// set bit 7 (active/bootable flag)
	ld (hl), a;							// store combined flags
	ld a, c;							// get filesystem type from C register
	ret;								// return to caller

;	// validate and decode partition type
validate_partition_type:
	push hl;							// save HL register on stack
	push bc;							// save BC register on stack
	inc hl;								// advance to next byte in partition table
	and %11100000;						// mask upper 3 bits of partition type
	cp $80;								// check if type is $80 (bootable)
	jr nz, finalize_partition_type;		// jump if not bootable partition
	ld a, (hl);							// load filesystem type byte
	bit 7, a;							// check bit 7 (extended partition flag)
	ld a, $40;							// default filesystem code $40
	jr z, finalize_partition_type;		// jump if not extended partition
	ld b, $40;							// set B to $40 for extended partition
	and %00000111;						// mask lower 3 bits (filesystem subtype)
	cp 5;								// check if subtype is 5 (extended DOS)
	ld a, $30;							// filesystem code for DOS partition
	jr nz, finalize_partition_type;		// jump if not DOS extended partition
	ld a, 18h;							// filesystem code for FAT16 ($18)

;	// finalize partition type validation
finalize_partition_type:
	dec hl;								// return to original position in partition table
	ld c, a;							// store filesystem type in C register
	ld a, (hl);							// load partition type byte again
	and %11100000;						// mask upper 3 bits
	cp $60;								// check if type is $60
	jr nz, return_filesystem_type;		// jump if not $60 type
	ld c, $b0;							// set filesystem type to $b0 for type $60

;	// restore registers and return filesystem type
return_filesystem_type:
	ld a, c;							// get filesystem type from C register
	pop hl;								// restore HL from stack (BC value)
	ld c, l;							// store L in C register
	pop hl;								// restore original HL from stack
	ret;								// return to caller

;;	// find next available drive letter
find_next_drive_letter:
	ld c, a;							// save drive letter in C register
	call check_drive_letter_available;	// check if drive letter is available
	ld a, c;							// get drive letter back
	ret c;								// return if carry set (drive available)
	inc a;								// try next drive letter
	jr find_next_drive_letter;			// loop to check next letter

;	// check if drive letter is already in use
check_drive_letter_available:
	ld hl, $2d01;						// point to drive table (drive letter column)
	ld b, $0c;							// check up to 12 drive entries

;	// search loop through drive table
search_drive_table:
	ld a, (hl);							// load drive letter from table
	cp c;								// compare with requested drive letter
	ret z;								// return with Z flag set if match found (in use)
	inc hl;								// advance to next drive entry
	inc hl;								// (each entry is 3 bytes)
	inc hl;								// complete 3-byte entry traversal
	djnz search_drive_table;			// decrement B and loop if not zero
	scf;								// set carry flag (drive letter available)
	ret;								// return to caller

;	// configure drive in system drive table
configure_system_drive:
	push bc;							// save BC register on stack
	call validate_drive_id;				// validate drive configuration
	jr c, handle_drive_config_error;	// jump if error in validation
	ld iy, $2d00;						// point IY to start of drive table
	ld b, $0c;							// set counter for 12 drive slots

;	// search for matching drive in table
search_matching_drive:
	cp (iy + _flags);					// compare with drive flags in table entry
	jr z, check_drive_compatibility;	// jump if match found (drive already configured)
	call advance_drive_table_ptr;		// advance to next drive table entry
	djnz search_matching_drive;			// decrement counter and loop if more entries

;	// handle drive configuration error
handle_drive_config_error:
	pop bc;								// restore BC register from stack
	ld a, $0b;							// load error code $0b (drive configuration failed)
	scf;								// set carry flag to indicate error
	ret;								// return with error to caller

;	// drive already configured, check compatibility
check_drive_compatibility:
	ld a, (iy + _tv_flag);				// load TV flag from drive table entry
	and %00001111;						// mask lower 4 bits (compatibility flags)
	or a;								// test if any compatibility flags are set
	pop bc;								// restore BC register from stack
	ret;								// return to caller

;	// search for empty slot in drive table
find_empty_drive_slot:
	ld de, $2d00;						// point DE to start of drive table
	ld b, $0c;							// set counter for 12 drive slots

;	// loop through drive table entries
search_empty_slot_loop:
	ld a, (de);							// load drive ID from current table entry
	and a;								// check if slot is empty (drive ID = 0)
	ret z;								// return if empty slot found (Z flag set)
	inc de;								// advance to next drive table entry
	inc de;								// (each entry is 3 bytes)
	inc de;								// complete 3-byte entry traversal
	djnz search_empty_slot_loop;		// decrement counter and loop if more entries
	ld a, $0b;							// load error code $0b (no free drive slots)
	scf;								// set carry flag to indicate error
	ret;								// return with error

;	// advance IY pointer to next drive table entry
advance_drive_table_ptr:
	inc iy;								// advance IY pointer (each entry is 3 bytes)
	inc iy;								// second byte of 3-byte entry
	inc iy;								// third byte of 3-byte entry
	ret;								// return to caller

;	// validate and select drive identifier
validate_drive_id:
	ld b, a;							// save drive identifier in B register
	and a;								// check if drive identifier is zero
	scf;								// set carry flag (error condition)
	ret z;								// return with error if zero drive ID
	cp '*';								// use current drive?
	ld a, ($2d46);						// load current drive identifier
	ret z;								// return if '*' (use current drive)
	ld a, b;							// restore original drive identifier
	cp $24;								// check for '$' character (system drive)
	ld a, ($2d4a);						// load system drive identifier
	ret z;								// return if '$' (use system drive)
	ld a, b;							// restore original drive identifier
	or a;								// clear carry flag (no error)
	ret;								// return with validated drive ID
	add a, b;							// add B register to accumulator (unused code?)

;	dbtb "No system";					// Zeus - string with terminal bit 7 set
	str "No system";					// RASM - string with terminal bit 7 set

;	// 32-bit increment function (BCDE register pair)
inc_32bit:
	inc e;								// increment low byte (E register)
	ret nz;								// return if no overflow from E
	inc d;								// increment second byte (D register)
	ret nz;								// return if no overflow from D
	inc c;								// increment third byte (C register)
	ret nz;								// return if no overflow from C
	inc b;								// increment high byte (B register)
	ret;								// return after incrementing all bytes

;	// 32-bit decrement function with underflow check
dec_32bit:
	ld a, $ff;							// load $FF (underflow detection value)
	dec e;								// decrement low byte (E register)
	cp e;								// check if E underflowed to $FF
	ret nz;								// return if no underflow from E
	dec d;								// decrement second byte (D register)
	cp d;								// check if D underflowed to $FF
	ret nz;								// return if no underflow from D
	dec c;								// decrement third byte (C register)
	cp c;								// check if C underflowed to $FF
	ret nz;								// return if no underflow from C
	dec b;								// decrement high byte (B register)
	ret;								// return after decrementing all bytes

;	// 32-bit addition (BCDE = BCDE + HLDE)
add_32bit:
	add hl, de;							// add DE to HL (low 16 bits)
	ex de, hl;							// exchange DE and HL registers
	ret nc;								// return if no carry from low 16 bits
	inc bc;								// increment high 16 bits (BC) if carry
	ret;								// return to caller

;	// 32-bit subtraction (BCDE = BCDE - HLDE)
sub_32bit:
	or a;								// clear carry flag for subtraction
	ex de, hl;							// exchange DE and HL registers
	sbc hl, de;							// subtract DE from HL with carry
	ex de, hl;							// exchange back to restore register usage
	ret nc;								// return if no borrow from low 16 bits
	dec bc;								// decrement high 16 bits (BC) if borrow
	ret;								// return to caller

;;; 06_formatting.asm

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
; // character print routine (RST $10 handler)
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

; // convert hex digit A-F by adding 7 to make it ASCII
convert_hex_digit:
	add a, 7;							// add 7 to convert hex digits A-F to ASCII

; // print the digit and set leading zero flag
print_digit:
	ld c, $30;							// set flag to enable printing of subsequent zeros
	rst $10;							// print a character
	ret;								// return from function

; // format file size for display - called from dirs.io
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

; // handle large files - convert to MB
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

; // add 'B' suffix for bytes if not already present
add_bytes_suffix:
	ld a, b;							// check unit suffix character
	cp 'B';								// compare with 'B' ($42)
	ret z;								// return if already 'B'
	ld a, 'B';							// load 'B' character
	rst $10;							// print a character
	ret;								// return from function

; // format number and add unit suffix
format_number_with_units:
	xor a;								// clear A (no decimal places)
	call format_size_with_units;		// format the number
	ld a, b;							// load unit character
	rst $10;							// print a character
	ret;								// return from function

; // format file size with appropriate units (B/KB/MB)
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

; // format number with decimal places and print
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

; // divide 24-bit number by 1024 (shift right 10 bits)
divide_by_1024:
	xor a;								// clear A (will hold remainder bits)
	ld l, h;							// start shifting: L = H

; // division loop - shift right 10 times total (divide by 1024)
shift_division_loop:
	ld h, e;							// H = E (continue shifting)
	ld e, d;							// E = D
	ld d, a;							// D = A (remainder accumulator)
	srl e;								// shift E right 1 bit
	rr h;								// rotate H right (carry from E)
	rr l;								// rotate L right (carry from H)
	jr nc, continue_division;			// jump if no remainder
	add a, 2;							// add 2 to remainder (bit weight)

; // continue division by 1024 - second shift
continue_division:
	srl e;								// shift E right another bit
	rr h;								// rotate H right (carry from E)
	rr l;								// rotate L right (carry from H)
	jr nc, store_decimal_remainder;		// jump if no remainder
	add a, 5;							// add 5 to remainder (bit weight)

; // store decimal remainder and return
store_decimal_remainder:
	ld c, a;							// store decimal remainder in C
	ret;								// return with result in HLD, remainder in C

;;; 07_dispatcher.asm

; // sys call table
syscall_table:

; // hook base
	defw handle_disk_status;			// disk_status
	defw disk_read_write;				// disk_read
	defw disk_read_write;				// disk_write
	defw handle_file_operation;			// disk_ioctl
	defw disk_info_handler;				// disk_info
	defw find_handle_by_index;			// 
	defw invalid_function_error;		// 
	defw invalid_function_error;		// 

; // misc base
	defw invalid_function_error;		// m_dosversion
	defw get_set_drive; 				// m_getsetdrv
	defw drive_info;					// m_driveinfo
	defw system_entry;					// m_tapein
	defw system_reinit;					// m_tapeout
	defw get_drive_status;				// m_gethandle
	defw get_default_date;				// m_getdate
	defw cmd_folder_setup;				// 
	defw error_code_handler;			// 
	defw invalid_function_error;		// 
	defw invalid_function_error;		// 
	defw invalid_function_error;		// 
	defw invalid_function_error;		// 
	defw invalid_function_error;		// 
	defw invalid_function_error;		// 
	defw invalid_function_error;		// 

; // fsys_base
	defw filesystem_mount;				// f_mount
	defw filesystem_unmount;			// f_umount
	defw file_open;						// f_open
	defw file_close;					// f_close
	defw get_file_handle;				// f_sync
	defw get_file_handle;				// f_read
	defw get_file_handle;				// f_write
	defw get_file_handle;				// f_seek
	defw get_file_handle;				// f_fgetpos
	defw get_file_handle;				// f_fstat
	defw get_file_handle;				// f_ftruncate
	defw file_open;						// f_opendir
	defw get_file_handle;				// f_readdir
	defw get_file_handle;				// f_telldir
	defw get_file_handle;				// f_seekdir
	defw get_file_handle;				// f_rewinddir
	defw init_file_handle;				// f_getcwd
	defw init_file_handle;				// f_chdir
	defw init_file_handle;				// f_mkdir
	defw init_file_handle;				// f_rmdir
	defw init_file_handle;				// f_stat
	defw init_file_handle;				// f_unlink
	defw init_file_handle;				// f_truncate
	defw init_file_handle;				// f_attrib
	defw init_file_handle;				// f_rename
	defw init_file_handle;				// f_getfree
	defw validate_drive_handle;			// 
	defw init_file_handle;				// 

;	// RST08_handler
; // main syscall dispatcher (RST $08 entry point)
syscall_dispatcher:
	ex (sp), hl;						// swap HL with top of stack (return address)
	ld ($3dfa), a;						// save parameter in A
	ld a, (hl);							// retrieve syscall # from position
;										// after RST instruction
	inc hl;								// adjust return address
	ex (sp), hl;						// and saves it to the stack

; // register preservation and syscall setup
syscall_reg_save:
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
	call system_call_dispatch;			// dispatch system call
	pop ix;								// restore page settings
	ld iyl, a;							// save result
	ld a, ixl;							// get original page
	out (mmcram), a;					// Set divMMC RAM page
	ld a, iyl;							// restore result
	pop ix;								// restore registers
	pop iy;								// restore index register Y
	ret;								// return to caller

system_call_dispatch:
	ld a, iyl;							// get system call number
	push hl;							// save HL register
	ld hl, syscall_table;				// point to system call table (04_files.asm)
	add a, a;							// multiply by 2 (each entry is 2 bytes)
	add a, l;							// add to table base address
	ld l, a;							// store in L
	jr nc, get_handler_address;			// if no carry, continue
	inc h;								// handle carry to high byte

get_handler_address:
	ld a, (hl);							// get low byte of handler address
	inc hl;								// advance to high byte
	ld h, (hl);							// get high byte of handler address
	ld l, a;							// restore low byte
	ld a, ixh;							// get high byte of page settings
	ex (sp), hl;						// put handler address on stack, restore HL
	ret;								// "call" handler by returning to it

invalid_function_error:
	ld a, $14;							// error code: invalid function number
	scf;								// set carry flag (error)
	ret;								// return with error

get_drive_status:
	ld a, ($2e32);						// get drive status
	or a;								// test if drive available
	ret;								// return with status

;	// default date and time for files
get_default_date:
	ld de, $6000;						// 12:00:00
	ld bc, $28c2;						// June 2, 2000
	or a;								// clear carry flag (success)
	ret;								// return with default date/time

get_set_drive:
	and a;								// test if drive number is zero
	jr nz, set_current_drive;			// if not zero, set as current drive
	ld a, ($2d46);						// get current drive number
	or a;								// set flags based on drive
	ret;								// return with current drive

set_current_drive:
	cp '*';								// use current drive? test for file commands
	ret z;								// return if using current drive
	ld c, a;							// save drive number
	call configure_system_drive;		// validate drive number (04_files.asm)
	ret c;								// return if invalid drive
	ld a, c;							// restore drive number
	ld ($2d46), a;						// set as current drive
	ret;								// return success

find_handle_by_index:
	and %11111000;						// mask to get file handle index
	ld c, a;							// save handle index
	ld hl, $2d00;						// point to file handle table
	ld b, $0c;							// 12 file handles to check

search_file_handles:
	ld a, (hl);							// get handle entry
	inc hl;								// advance to next field
	inc hl;								// (each entry is 3 bytes)
	inc hl;								// advance to third byte of entry
	and %11111000;						// mask handle index bits
	cp c;								// compare with target handle
	scf;								// set carry flag (assume found)
	ret z;								// return if handle found
	djnz search_file_handles;			// loop through all handles
	ld a, c;							// get handle number
	push bc;							// save BC register
	call handle_file_operation;			// call handle processing routine
	pop bc;								// restore BC register
	ret c;								// return if error occurred
	ld a, c;							// get handle number back
	jp close_handle_slot;				// jump to handle completion

handle_disk_status:
	ld ($3df4), hl;						// save HL register 
	ld ($3dfa), a;						// save accumulator
	ld ($3df6), bc;						// save BC register
	ld ($3df2), de;						// save DE register
	call find_file_handle;				// call system routine
	ccf;								// complement carry flag
	ld a, $1f;							// error code: invalid file handle
	ret c;								// return if error
	ld hl, $2d24;						// point to system data table

process_filesystem_table:
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
	call get_filesystem_params;			// get file system parameters
	pop hl;								// restore HL register
	ret nc;								// return if no error
	jr process_filesystem_table;		// handle error case

get_filesystem_params:
	ld hl, ($3df4);						// get file system base address
	ld bc, ($3df6);						// get file system parameters
	ld a, ($3dfa);						// get stored A register value
	push de;							// save DE register
	ld de, ($3df2);						// get additional parameters
	ret;								// return to caller

invoke_file_operation:
	push de;							// save DE register
	ld e, iyl;							// get system call number
	ld a, ixh;							// get high byte of page settings
	ld ixh, e;							// store call number in IXH
	pop de;								// restore DE register
	jp find_handle_with_setup;			// jump to handler (04_files.asm)

disk_read_write:
	call invoke_file_operation;			// invoke file operation
	ret c;								// return if error
	push hl;							// save HL register
	call process_file_comparison;		// process operation result
	pop hl;								// restore HL register
	jr nc, process_operation_result;	// if no error, continue
	ld a, $0a;							// error code: access denied
	ret;								// return with error

handle_file_operation:
	call invoke_file_operation;			// invoke file operation
	ret c;								// return if error

process_operation_result:
	push hl;							// save HL register
	ld h, (iy + _err_sp);				// get error stack pointer
	ld a, ixh;							// get operation type
	add a, a;							// multiply by 2 for word index
	add a, (iy + _tv_flag);				// add base offset
	ld l, a;							// store in L
	jr nc, get_handler_dispatch_addr;	// if no carry, continue
	inc h;								// handle carry to high byte

get_handler_dispatch_addr:
	ld a, (hl);							// get low byte of handler address
	inc hl;								// advance to high byte
	ld h, (hl);							// get high byte of handler address
	ld l, a;							// restore low byte
	ex (sp), hl;						// put handler address on stack
	ret;								// "call" handler by returning to it

process_file_comparison:
	push iy;							// save IY register
	pop hl;								// copy IY to HL
	and a;								// test A register
	jr nz, calc_address_offset;			// if not zero, branch
	ld a, 7;							// offset to compare value
	add a, l;							// add to address
	ld l, a;							// store result
	jp compare_32bit;					// jump to comparison routine (04_files.asm)

calc_address_offset:
	add a, a;							// shift A left (multiply by 2)
	add a, a;							// shift A left again (multiply by 4)
	add a, a;							// shift A left again (multiply by 8)
	add a, l;							// add base address offset
	ld l, a;							// store calculated address in L
	push hl;							// save address pointer
	add a, 7;							// add 7 to address (offset calculation)
	ld l, a;							// store offset address in L
	call compare_32bit;					// call comparison routine (04_files.asm)
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

file_open:
	call init_file_handle;				// call file operation handler
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
	call handle_drive_table_op;			// call handle completion routine
	pop af;								// restore saved handle number
	pop hl;								// restore HL register
	ret;								// return to caller

file_close:
	call get_file_handle;				// call handle validation routine
	ret c;								// return if validation failed
	ld a, ixh;							// get handle number for cleanup
	push af;							// save A register
	ld hl, $2cf0;						// point to file handle table
	call clear_handle_entry;			// clear file handle entry
	pop af;								// restore A register
	ld hl, $2e22;						// point to drive table

clear_handle_entry:
	add a, l;							// add offset to base address
	ld l, a;							// store result in L
	xor a;								// clear accumulator
	ld (hl), a;							// clear table entry
	ret;								// return to caller

get_file_handle:
	push de;							// save DE register
	ld de, $2cf0;						// point to file handle table
	add a, e;							// add handle offset
	ld e, a;							// store in E
	ld a, (de);							// get file handle value
	and a;								// test if handle is valid
	ld d, a;							// save handle value
	ld a, ixh;							// get current operation
	ld ixh, d;							// store handle in IXH
	jr nz, handle_file_with_drive;		// if valid handle, continue
	ld a, $0d;							// error code: invalid handle

return_handle_error:
	pop de;								// restore DE register
	scf;								// set carry flag (error)
	ret;								// return with error

drive_info:
	ld de, $2d01;						// point to file handle data (skip flags)
	ld b, $0c;							// 12 file handles maximum
	ld c, 0;							// counter for open files

count_open_files_loop:
	ld a, (de);							// get file handle number
	and a;								// test if handle is in use
	jr z, advance_handle_pointer;		// skip if handle not in use
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

advance_handle_pointer:
	inc de;								// advance to next handle entry
	inc de;								// (each entry is 3 bytes)
	inc de;								// complete handle entry skip
	djnz count_open_files_loop;			// loop through all handles
	ld a, c;							// get count of open files
	ret;								// return with count

validate_drive_handle:
	push iy;							// save IY register
	call configure_system_drive;		// validate drive (04_files.asm)
	pop bc;								// restore BC register
	ret c;								// return if drive invalid
	ld a, (iy + _flags);				// get file flags
	ld b, a;							// save in B
	ld d, (iy + _err_nr);				// get error number
	ld e, (iy + _tv_flag);				// get TV flag
	ld iyl, c;							// save drive number

init_file_handle:
	call validate_filename_buffer;		// initialize file handle (04_files.asm)
	ret c;								// return if initialization failed
	push de;							// save DE register

handle_file_with_drive:
	ld e, a;							// save handle number
	ld d, iyl;							// get saved parameter
	ld a, ixh;							// get operation type
	cp '*';								// use current drive?
	jr nz, validate_drive_param;		// if not, use specified drive
	ld a, ($2d46);						// get current drive number

validate_drive_param:
	call configure_system_drive;		// validate drive (04_files.asm)
	jr c, return_handle_error;			// return with error if invalid
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
	call memory_address_calc;			// call handler (04_files.asm)
	sub $18;							// subtract base offset (24) for handler index
	ld l, (iy + _tv_flag);				// get TV flag for address calculation
	ld h, (iy + _err_sp);				// get error stack pointer
	add a, a;							// multiply by 2 (word entries)
	add a, l;							// add to base address
	ld l, a;							// store calculated address
	jr nc, get_handler_from_table;		// jump if no carry
	inc h;								// handle carry to high byte

get_handler_from_table:
	ld a, (hl);							// get low byte of handler address
	inc hl;								// advance to high byte
	ld h, (hl);							// get high byte of handler address
	ld l, a;							// restore low byte
	call restore_memory_state;			// call memory restoration routine
	ld ixh, a;							// save result in IXH
	ld a, 0;							// clear accumulator
	out (mmcram), a;					// divMMC RAM page 0;
	ld a, ixh;							// restore result
	pop iy;								// restore IY register
	pop ix;								// restore IX register
	ret;								// return to caller

restore_memory_state:
	push hl;							// save handler address
	ld hl, ($3df4);						// restore saved HL register
	ret;								// return with HL restored

handle_drive_table_op:
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

disk_info_handler:
	and a;								// test file system type
	jr z, handle_standard_filesystem;	// jump if standard file system
	ld b, a;							// save file system type
	call find_handle_with_setup;		// call validation routine (04_files.asm)
	jr nc, validate_filesystem;			// continue if valid

filesystem_error:
	ld a, $0e;							// error code: invalid file system
	ret;								// return with error

validate_filesystem:
	ld c, a;							// save validation result
	ld a, b;							// restore file system type
	and %00000111;						// mask lower 3 bits
	cp c;								// compare with validation result
	jr c, filesystem_error;				// return error if invalid
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
	jr nc, process_filesystem_entry;	// continue if no carry
	inc h;								// handle carry to high byte

process_filesystem_entry:
	ld bc, 4;							// copy 4 bytes
	ldir;								// block copy HL to DE
	ld c, 6;							// set result length
	jr complete_buffer_operation;		// jump to completion

handle_standard_filesystem:
	push hl;							// save HL register
	ld b, 6;							// process 6 file systems
	ld hl, $2c00;						// point to file system table
	ld de, $2df2;						// point to output buffer

filesystem_table_loop:
	push bc;							// save loop counter
	push hl;							// save table pointer
	ld a, (hl);							// get file system entry
	inc hl;								// advance to next byte
	and a;								// test if entry exists
	jr z, advance_filesystem_ptr;		// skip if no file system
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

copy_filesystem_data:
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
	jr c, copy_filesystem_data;			// loop if more entries

advance_filesystem_ptr:
	pop hl;								// restore table pointer
	ld bc, $28;							// each entry is 40 bytes
	add hl, bc;							// advance to next file system entry
	pop bc;								// restore loop counter
	djnz filesystem_table_loop;			// loop through all file systems
	xor a;								// clear accumulator
	ld (de), a;							// terminate buffer with zero
	inc de;								// advance buffer pointer
	ld hl, $d20e;						// load end marker address
	add hl, de;							// calculate buffer end
	ld b, h;							// copy high byte to B
	ld c, l;							// copy low byte to C

complete_buffer_operation:
	ld hl, $2df2;						// point to data buffer
	pop de;								// restore DE register
	rst $30;							// call ROM routine (calculator)
	ld b, $b7;							// set operation code
	ret;								// return with result

;;; 08_error_dispatch.asm

;	// based on the Spectrum ROM's main_4 / main_g routine
error_handler_entry:
	ld (err_nr), a;						// get error number
	res 5, (iy + _flags);				// no new key
	ld sp, (err_sp);					// error stack pointer to SP
	rst $18;							// call BASIC ROM routine
	defw syntax_z;						// check if in syntax check mode
	ld hl, $16c5;						// BASIC command loop address
	jp z, jump_unmap_hl;				// if syntax check, unmap and return to BASIC
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
	jp nz, error_handler_setup;			// if NMI set, handle differently
	res 5, (iy + _flag_x);				// no new key
	rst $18;							// call BASIC ROM routine
	defw cls_lower;						// clear lower screen
	set 5, (iy + _tv_flag);				// set TV flag bit 5
	res 3, (iy + _tv_flag);				// clear TV flag bit 3
	ld a, (err_nr);						// get error number
	and a;								// test if zero (no error)
	ld hl, ($3de8);						// get default message address
	jr z, print_error_message;			// if no error, print default message
	ld b, a;							// save error number in B

handle_error_message:
	ld a, ($3df9);						// get current divMMC page
	push af;							// save current page
	xor a;								// select page 0
	out (mmcram), a;					// divMMC memory page 0
	ld hl, $23bd;						// point to error message table
	push bc;							// save error number
	call memory_address_compare;		// find error message
	pop bc;								// restore error number
	jr nc, use_basic_error;				// if message found, use it
	cp $0c;								// check for specific error code
	jr nz, handle_unknown_error;		// if not, try generic error
	ld hl, $0caa;						// point to "Too many open files" message
	jr print_error_message;				// print message

handle_unknown_error:
	ld a, b;							// get error number
	cp 1;								// check if error number is 1
	jr z, use_basic_error;				// if so, use BASIC ROM message
	ld hl, $0c9c;						// point to "UnoDOS error #" message
	call v_pr_msg;						// print error prefix
	ld l, b;							// put error number in L
	call format_number_suppress_zeros;	// print error number (05_api.asm)
	jr restore_page_and_exit;			// restore page and exit

use_basic_error:
	ld hl, ($2017);						// get BASIC ROM error message table

find_error_message:
	bit 7, (hl);						// check if end of message
	inc hl;								// advance to next character
	jr z, find_error_message;			// continue until end of message
	djnz find_error_message;			// repeat for B messages

print_error_message:
	call v_pr_msg;						// print error message

restore_page_and_exit:
	pop af;								// restore divMMC page
	out (mmcram), a;					// set divMMC RAM page
	inc sp;								// adjust stack pointer (skip return address)
	inc sp;								// adjust stack pointer (complete skip)
	ld hl, $1349;						// BASIC editor address
	jp jump_unmap_hl;					// unmap and return to BASIC

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
command_dispatcher:
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
	jp unmap_and_return;				// Jump to auto-unmap address.


;	// The calling sequence is as follows: after this last jump, a RET instruction
;	// at $1ffa is executed. While it is being executed, the divMMC is unpaged, so
;	// the next instruction to fetch will have the system ROM paged in. The address
;	// fetched from the stack is the one pointing to the desired system ROM routine.
;	// After this routine ends, the return address fetched from the stack will point
;	// to 3DFD. This is a TR-DOS trap, which immediately pages divMMC again. $3dfd
;	// will have a RET instruction also, thus returning to the instruction past the
;	// immediate 16-bit value after the RST $18 instruction, thus resuming
;	// execution with divMMC paged in.

; // character processing routine
char_processing_routine:
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
	jr nz, process_system_command;		// if not, continue normally
	ld a, h;							// check address high byte
	cp '@';								// check if >= $4000
	jr c, set_error_1;					// if < $4000, continue
	ld sp, (err_sp);					// reset error stack
	ld a, ($3df8);						// get saved page
	out (mmcram), a;					// set divMMC RAM page

return_to_basic:
	ld hl, $16c5;						// BASIC command loop address
	jp jump_unmap_hl;					// unmap and return to BASIC


set_error_1:
	ld a, 1;							// set error code to 1
	rst $20;							// call error handler

process_system_command:
	cp $1b;								// check if command >= $1B
	jr c, check_error_flag;				// if less, branch to error handling
	push ix;							// save IX register
	pop hl;								// copy IX to HL
	call syscall_reg_save;				// call system function dispatcher (06_disk.asm)
	push hl;							// save result
	pop ix;								// restore to IX
	jp unmap_and_return;				// unmap and return

check_error_flag:
	bit 7, (iy + _err_nr);				// check if error flag set

store_error_number:
	ld (err_nr), a;						// store error number
	ld hl, (ch_add);					// get current channel address
	ld (x_ptr), hl;						// save in x_ptr
	jp z, cleanup_and_exit;				// if no error flag, jump to cleanup
	cp $0b;								// check for specific error codes
	jr z, handle_specific_errors;		// jump if error code 11
	cp $0e;								// check if error code 14
	jr z, handle_specific_errors;		// jump if error code 14
	cp $17;								// check if error code 23
	jr z, handle_specific_errors;		// jump if error code 23
	cp 1;								// check for error code 1
	jp nz, cleanup_and_exit;			// if not 1, go to cleanup

handle_specific_errors:
	bit 5, (iy + 55);					// check system flag
	jp nz, cleanup_and_exit;			// if set, go to cleanup
	ld de, (e_line);					// get end of program line
	and a;								// clear carry flag
	sbc hl, de;							// compare current position with end
	jr c, process_before_end;			// if before end, branch
	rst $18;							// call BASIC ROM routine
	defw e_line_no;						// get line number at end
	ld hl, (ch_add);					// get current address
	dec hl;								// back up one position
	jr process_statement;				// continue processing

process_before_end:
	ld hl, (ppc);						// get program counter
	rst $18;							// call BASIC ROM routine
	defw line_addr;						// get address of line
	inc hl;								// skip line number
	inc hl;								// skip length
	inc hl;								// point to first statement

process_statement:
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
	call cleanup_routine;				// call cleanup routine

cleanup_and_exit:
	ld a, ($3df8);						// get saved divMMC page
	out (mmcram), a;					// set divMMC RAM page
	res 3, (iy + _tv_flag);				// clear TV flag bit 3
	ld hl, $58;							// set up for system exit
	rst $30;							// report error
	inc bc;								// increment BC
	jp z, jump_unmap_hl;				// if zero, unmap and exit
	ld a, (nmiadd);						// get NMI address
	and a;								// test if NMI routine set
	jp z, jump_unmap_hl;				// if not set, unmap and exit
	set 7, (iy + _err_nr);				// set error flag
	ld hl, $1b7d;						// NMI service routine address
	jp jump_unmap_hl;					// unmap and jump to NMI routine

memory_init_routine:
	call read_file_to_page2;			// call memory cleanup routine
	jp c, $20;							// jump if carry set
	call open_screen_channel;			// call additional cleanup
	ld hl, ($2e46);						// get memory pointer
	ld a, 2;							// select page 2
	out (mmcram), a;					// switch to divMMC page 2
	call system_entry;					// call system initialization
	ld ($3de8), hl;						// save result pointer
	jp c, $20;							// jump if error occurred
	ld a, 0;							// select divMMC page 0
	out (mmcram), a;					// divMMC RAM page 0
	jp error_handler_setup;				// jump to completion routine

memory_cleanup_with_hl:
	push hl;							// save HL register
	call read_file_to_page2;			// call memory cleanup routine
	pop hl;								// restore HL register
	jr c, cleanup_restore_page;			// jump to cleanup if error
	ld a, 2;							// select divMMC page 2
	out (mmcram), a;					// divMMC RAM page 2
	call system_entry;					// call system routine

; // cleanup and restore divMMC memory page
cleanup_restore_page:
	push af;							// save accumulator flags
	ld a, 0;							// select divMMC page 0
	out (mmcram), a;					// divMMC RAM page 0
	ld a, ($3df0);						// get saved page setting
	ld ($3df8), a;						// store in working area
	pop af;								// restore accumulator flags
	ret;								// return to caller

; // read file data to page 2 and close file
read_file_to_page2:
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

;;; 09_filesystem.asm

; // open screen channel for output
open_screen_channel:;					// called from dirs.io
	ld a, 2;							// screen
	rst $18;							// call BASIC ROM routine
	defw chan_open;						// open channel function
	ret;								// return to caller

; // data area or function parameters
data_area_parameters:
	ld d, (hl);							// load D from address pointed by HL
	ld c, $b2;							// load immediate value $B2 into C
	ld sp, $16de;						// set stack pointer to $16DE
	adc a, a;							// add A to itself with carry
	ld d, $97;							// load immediate value $97 into D
	ld d, $de;							// load immediate value $DE into D
	jr format_output_routine;			// jump to format_output_routine
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
	call output_byte_to_file;			// call function at output_byte_to_file
	ld a, d;							// copy D to A register
	call output_byte_to_file;			// call function at output_byte_to_file
	ld a, e;							// copy E to A register
	call output_byte_to_file;			// call function at output_byte_to_file
	push iy;							// save IY on stack
	pop hl;								// restore into HL
	ld l, $18;							// load immediate value $18 into L
	ld bc, 4;							// load immediate value 4 into BC
	rst $30;							// restart at vector $30

; // format output routine with parameters
format_output_routine:
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

; // output byte to file handle
output_byte_to_file:
	ld hl, $3dfa;						// load HL with address $3DFA
	ld (hl), a;							// store A at address HL
	ld bc, 1;							// load BC with value 1
	rst $30;							// restart at vector $30
	ld b, $c9;							// load B with immediate value $C9
	push bc;							// save BC on stack
	call search_free_memory;			// call function at search_free_memory
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
	call validate_fs_structure;			// call function at validate_fs_structure
	ld a, (iy + _flags);				// load A from IY+flags offset
	ret;								// return to caller

; // search for free memory block
search_free_memory:
	ld hl, $2000;						// load HL with address $2000
	ld b, 4;							// load B with counter value 4

; // memory search loop continuation
memory_search_loop:
	ld a, (hl);							// load A with value at address HL
	and a;								// test A (check if zero)
	ret z;								// return if zero
	inc h;								// increment H register 
	djnz memory_search_loop;			// decrement B and jump if not zero
	scf;								// set carry flag
	ret;								// return to caller

; // clear error and set carry flag
clear_error_set_carry:
	xor a;								// clear A register (set to 0)
	ld (iy + _err_nr), a;				// clear error number in IY
	scf;								// set carry flag
	ret;								// return to caller

; // validate file system structure and data
validate_fs_structure:
	ld hl, $2d00;						// load HL with address $2D00
	ld bc, 0;							// clear BC register pair
	ld de, 0;							// clear DE register pair
	push hl;							// save HL on stack
	call read_disk_sector;				// call function at read_disk_sector
	pop hl;								// restore HL from stack
	jr c, clear_error_set_carry;		// jump to error handler if carry
	inc h;								// increment H register
	ld l, $fe;							// load L with value $FE
	ld a, (hl);							// load A from address HL
	inc l;								// increment L register
	and (hl);							// AND A with value at HL
	jr nz, clear_error_set_carry;		// jump to error if not zero
	dec h;								// decrement H register
	ld l, $0b;							// load L with value $0B
	ld a, (hl);							// load A from address HL
	inc l;								// increment L register
	or (hl);							// OR A with value at HL
	cp 2;								// compare A with 2
	jr nz, clear_error_set_carry;		// jump to error if not equal
	ld l, $10;							// load L with value $10
	ld a, (hl);							// load A from address HL
	cp 2;								// compare A with 2
	jr nz, clear_error_set_carry;		// jump to error if not equal
	ld hl, $2d00;						// load HL with address $2D00
	ld l, $13;							// load L with value $13
	ld e, (hl);							// load E from address HL
	inc l;								// increment L register
	ld d, (hl);							// load D from address HL
	ld a, e;							// copy E to A
	or d;								// OR A with D
	jr nz, process_fs_data;				// jump if not zero
	ld l, $20;							// load L with value $20
	rst $30;							// restart at vector $30
	ld bc, $70fd;						// load BC with value $70FD
	dec de;								// decrement DE register pair
	ld (iy + 26), c;					// store C at IY+26

; // process filesystem data and parameters
process_fs_data:
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
	jr z, clear_error_set_carry;		// jump if character is '2'
	dec l;								// decrement L to previous memory location
	ld a, (hl);							// load value from new memory address
	ld l, $36;							// point to memory location $36
	cp '1';								// $49
	ld a, 0;							// load 0 into accumulator
	jr z, process_fs_mode;				// jump if character is '1'
	ld l, $52;							// point to memory location $52
	inc a;								// increment accumulator (set to 1)

; // process filesystem mode and parameters
process_fs_mode:
	ld (iy + 28), a;					// store accumulator at IY+28 (mode flag)
	push de;							// save DE register pair
	push iy;							// push IY onto stack
	pop de;								// pop into DE (copy IY to DE)
	ld e, 4;							// set E to offset 4
	ld bc, 5;							// set byte count to 5
	ldir;								// copy 5 bytes from HL to DE
	pop de;								// restore DE register pair
	cp 1;								// compare accumulator with 1
	jr z, process_fat_parameters;		// jump if equals 1
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
	call add_32bit;						// call subroutine at add_32bit
	jr calculate_cluster_params;		// jump to calculate_cluster_params

; // process FAT parameters for FAT16
process_fat_parameters:
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
	call call_cluster_processing;		// call subroutine at call_cluster_processing

; // calculate cluster parameters and free space
calculate_cluster_params:
	ld h, 0;							// clear H register
	ld l, (iy + 37);					// load value from IY+37 into L
	sla l;								// shift L left arithmetic
	rl h;								// rotate H left through carry
	call sub_32bit;						// call subroutine at sub_32bit
	ld (iy + 45), b;					// store B at IY+45
	ld (iy + 44), c;					// store C at IY+44
	ld (iy + 43), d;					// store D at IY+43
	ld (iy + 42), e;					// store E at IY+42
	call calculate_free_clusters;		// call subroutine at calculate_free_clusters
	call process_directory_entry;		// call subroutine at process_directory_entry
	call init_volume_path;				// call subroutine at init_volume_path
	call process_volume_label;			// call subroutine at process_volume_label
	or a;								// clear carry flag
	ret;								// return from subroutine

; // calculate free clusters from sectors
calculate_free_clusters:
	ld h, (iy + 25);					// load high byte from IY+25
	ld l, (iy + 24);					// load low byte from IY+24
	or a;								// clear carry flag
	sbc hl, de;							// subtract DE from HL with carry
	ex de, hl;							// exchange DE and HL registers
	ld h, (iy + 27);					// load high byte from IY+27
	ld l, (iy + 26);					// load low byte from IY+26
	sbc hl, bc;							// subtract BC from HL with carry
	ld a, (iy + 37);					// get sectors per cluster value (power of 2)

; // cluster calculation shift loop
cluster_shift_loop:
	srl a;								// shift sectors per cluster right (find shift count)
	jr c, store_cluster_results;		// jump if bit was 1 (found the shift count)
	srl h;								// shift result high word right
	rr l;								// rotate result through carry
	rr d;								// rotate result through carry
	rr e;								// rotate result low byte through carry
	jr cluster_shift_loop;				// loop back to check next bit

; // store cluster calculation results
store_cluster_results:
	ld (iy + 62), e;					// store E at IY+62 (result low byte)
	ld (iy + 63), d;					// store D at IY+63 (result mid byte)
	ld (iy + 64), l;					// store L at IY+64 (result high byte)
	ld (iy + 65), h;					// store H at IY+65 (result top byte)
	ret;								// return from subroutine

; // process directory entry information
process_directory_entry:
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
	call read_disk_sector;				// call subroutine at read_disk_sector
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
	call set_working_cluster;			// call subroutine at set_working_cluster
	rst $30;							// floating point system call
	ld bc, $b6c3;						// load BC with float operation code
	ld de, $ff01;						// load DE with value $FF01
	rst $38;							// system call (error or comparison)
	ld de, $ffff;						// load DE with value $FFFF
	call set_working_cluster;			// call subroutine at set_working_cluster
	ld bc, 0;							// clear BC register pair
	ld de, 2;							// set DE to 2
	jp set_directory_cluster;			// jump to set_directory_cluster

; // process volume label and disk information
process_volume_label:
	ld hl, $1416;						// load address $1416
	ld a, 8;							// set A to 8
	call process_filesystem_operation;	// call subroutine at process_filesystem_operation
	jr nc, setup_label_copy;			// jump if no carry (success)
	ld hl, $2d2b;						// load address $2D2B

; // setup label copy parameters
setup_label_copy:
	push iy;							// save IY register
	pop de;								// copy IY address to DE
	ld e, $0c;							// set E to offset $0C
	ld a, (hl);							// load value from memory
	and a;								// test if zero
	jr nz, copy_label_string;			// jump if not zero

; // use default no name label
use_default_label:
	ld hl, default_label_string;		// point to default "NO NAME" string

; // call string copy subroutine
copy_label_string:
	call copy_string_limited;			// call string copy subroutine
	ret;								// return from routine

; // copy string with length limit
copy_string_limited:
	ld b, $0b;							// set counter to 11 characters

; // character copy loop
char_copy_loop:
	ld a, (hl);							// load character from source
	cp ' ';								// $20
	jr z, handle_space_chars;			// jump if space character

; // store character and continue
store_char_continue:
	ld (de), a;							// store character at destination
	inc hl;								// increment source pointer
	inc de;								// increment destination pointer
	djnz char_copy_loop;				// decrement B and loop if not zero
	ret;								// return from routine

; // handle space characters in label
handle_space_chars:
	inc hl;								// move to next character
	ld a, (hl);							// load next character
	cp ' ';								// $20
	dec hl;								// move back to space
	ld a, (hl);							// reload space character
	jr nz, store_char_continue;			// continue copying if next char not space
	ld a, b;							// check remaining count
	cp $0b;								// compare with 11
	jr z, use_default_label;			// jump to default name if no chars copied
	ld a, 0;							// load zero
	ld (de), a;							// null terminate string
	ret;								// return from routine

; // default disk label string
default_label_string:
	defb "NO NAME  ";					// if disk has no label
; // initialize volume path string
init_volume_path:
	call process_cluster_pointer;		// call subroutine at process_cluster_pointer
	call store_fs_parameters;			// call subroutine at store_fs_parameters
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

; // store filesystem parameters
store_fs_parameters:
	ld a, (iy + 28);					// load mode flag from IY+28
	cp 1;								// compare with 1
	jr nz, store_param_values;			// jump if not equal to 1
	ld a, d;							// load D register
	or b;								// OR with B register
	or c;								// OR with C register

; // check if all registers zero
check_all_zero:
	or e;								// OR with E register (check if all zero)
	call z, process_cluster_pointer;	// call process_cluster_pointer if all registers are zero

; // store parameter values
store_param_values:
	ld (iy + 49), b;					// store B register at IY+49
	ld (iy + 48), c;					// store C register at IY+48
	ld (iy + 47), d;					// store D register at IY+47
	ld (iy + 46), e;					// store E register at IY+46
	ret;								// return from routine

; // read disk sector function
read_disk_sector:
	push bc;							// save BC register pair
	push de;							// save DE register pair
	ld a, (iy + _flags);				// load flags from IY+_flags
	rst $08;							// system call
	defb disk_read;						// disk read operation
	pop de;								// restore DE register pair
	pop bc;								// restore BC register pair
	ret;								// return from routine

; // write disk sector function
write_disk_sector:
	ld a, (iy + _flags);				// load flags from IY+_flags
	rst $08;							// system call
	defb disk_write;					// disk write operation
	ret;								// return from routine

; // write sector with current drive
write_current_drive:
	push bc;							// save BC register pair
	push de;							// save DE register pair
	ld a, ($3c25);						// get disk drive number
	rst $08;							// call system function
	defb disk_write;					// write sector to disk
	pop de;								// restore DE register pair
	pop bc;								// restore BC register pair
	ret;								// return to caller

; // write cluster data to disk
write_cluster_data:
	call calculate_cluster_address;		// load cluster start address
	jr write_current_drive;				// jump to disk write routine

; // read cluster data from disk
read_cluster_data:
	call calculate_cluster_address;		// load cluster start address
	jr read_disk_sector;				// jump to disk read routine

; // check drive and cluster cache
check_drive_cluster_cache:
	ld a, ($3c25);						// get current drive number
	cp (iy + _flags);					// compare with file system drive
	jr nz, validate_cluster_get_buffer;	// jump if different drive
	ld hl, $3c14;						// point to cluster number buffer
	call compare_32bit;					// compare 32-bit cluster values

; // validate cluster and get buffer
validate_cluster_get_buffer:
	ld hl, $2800;						// load default buffer address
	ccf;								// complement carry flag
	ret z;								// return if zero flag set
	call flush_dirty_buffer;			// call cluster validation routine
	ret c;								// return if error
	push de;							// save DE register
	push bc;							// save BC register
	push hl;							// save HL register
	call call_cluster_processing;		// calculate sector address
	push hl;							// save calculated address
	call read_disk_sector;				// read sector from disk
	pop hl;								// restore calculated address
	call c, read_cluster_data;			// if read failed, try write operation
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

; // flush dirty buffer to disk
flush_dirty_buffer:
	ld a, ($3c2b);						// get dirty buffer flag
	or a;								// test if buffer needs flushing
	ret z;								// return if buffer clean
	push bc;							// save BC register
	push de;							// save DE register
	push hl;							// save HL register
	ld de, ($3c11);						// get sector address low word
	ld bc, ($3c13);						// get sector address high word
	call flush_buffer_to_disk;			// flush buffer to disk
	pop hl;								// restore HL register
	pop de;								// restore DE register
	pop bc;								// restore BC register
	ret;								// return to caller

; // mark buffer as dirty
mark_buffer_dirty:
	ld a, $ff;							// set dirty flag value
	ld ($3c2b), a;						// mark buffer as dirty
	or a;								// set flags for return
	ret;								// return with non-zero

; // flush buffer to disk with error handling
flush_buffer_to_disk:
	xor a;								// clear accumulator
	ld ($3c2b), a;						// clear dirty buffer flag
	ld hl, $2800;						// point to disk buffer
	push de;							// save sector address low word
	push bc;							// save sector address high word  
	push hl;							// save buffer address
	call call_cluster_processing;		// calculate final sector address
	push hl;							// save calculated address
	call write_current_drive;			// write buffer to disk
	pop hl;								// restore calculated address
	jr c, handle_write_errors;			// jump if write error
	call write_cluster_data;			// perform additional write operation
	or a;								// check operation result

; // handle buffer write errors
handle_write_errors:
	call c, write_cluster_data;			// call cleanup if error occurred
	jr c, cleanup_buffer_ops;			// jump to exit if still error
	call load_directory_sector;			// call buffer flush function

; // cleanup buffer operations
cleanup_buffer_ops:
	pop hl;								// restore HL register
	pop bc;								// restore BC register
	pop de;								// restore DE register
	ret;								// return with final status
;;; 10_cluster_nav.asm


; // set file current sector address in descriptor
set_file_sector_address:
	ld (ix + 20), e;					// store sector address low byte
	ld (ix + 21), d;					// store sector address byte 1
	ld (ix + 22), c;					// store sector address byte 2  
	ld (ix + 23), b;					// store sector address high byte
	ret;								// return after storing addressreturn after storing address

; // get file current sector address from descriptor
get_file_sector_address:
	ld e, (ix + 20);					// load sector address low byte
	ld d, (ix + 21);					// load sector address byte 2
	ld c, (ix + 22);					// load sector address byte 3
	ld b, (ix + 23);					// load sector address high byte
	ret;								// return DEBC = current sector address

; // set file next cluster in descriptor
set_file_next_cluster:
	ld (ix + 24), e;					// store next cluster low byte
	ld (ix + 25), d;					// store next cluster byte 2
	ld (ix + 26), c;					// store next cluster byte 3
	ld (ix + 27), b;					// store next cluster high byte
	ret;								// return after storing DEBC cluster

; // get file next cluster from descriptor
get_file_next_cluster:
	ld e, (ix + 24);					// load next cluster low byte
	ld d, (ix + 25);					// load next cluster byte 2
	ld c, (ix + 26);					// load next cluster byte 3
	ld b, (ix + 27);					// load next cluster high byte
	ret;								// return DEBC = next cluster address

; // process cluster pointer and call 32-bit add
process_cluster_pointer:
	push hl;							// save HL register
	push iy;							// save IY register
	pop hl;								// load IY into HL
	ld l, $26;							// set low byte to offset $26
	rst $30;							// call ROM routine
	ld bc, $c9e1;						// load return instruction and pop hl

; // call cluster processing with arithmetic
call_cluster_processing:
	push hl;							// save HL register
	ld l, (iy + 29);					// load cluster pointer low byte
	ld h, (iy + 30);					// load cluster pointer high byte
	call add_32bit;						// call cluster processing function
	pop hl;								// restore HL register
	ret;								// return from function

; // calculate cluster address with offset
calculate_cluster_address:
	push hl;							// save HL register
	push bc;							// save BC register
	push de;							// save DE register
	call get_cluster_start_address;		// get cluster start address in BCDE
	pop hl;								// restore DE to HL
	add hl, de;							// add low 16-bits of cluster address
	ex de, hl;							// result low 16-bits to DE
	pop hl;								// restore BC to HL
	adc hl, bc;							// add high 16-bits with carry
	ld b, h;							// move result high byte to B
	ld c, l;							// move result low byte to C
	pop hl;								// restore HL register
	ret;								// return with 32-bit address in BCDE

; // get cluster start address from volume descriptor
get_cluster_start_address:
	ld e, (iy + 31);					// load cluster start address low byte
	ld d, (iy + 32);					// load cluster start address byte 1
	ld c, (iy + 33);					// load cluster start address byte 2
	ld b, (iy + 34);					// load cluster start address high byte
	ret;								// return DEBC = cluster start addressreturn DEBC = cluster start addressreturn DEBC = cluster start address

; // get filesystem parameters from volume descriptor
get_filesystem_parameters:
	ld b, (iy + 49);					// load filesystem parameter byte 3
	ld c, (iy + 48);					// load filesystem parameter byte 2
	ld d, (iy + 47);					// load filesystem parameter byte 1
	ld e, (iy + 46);					// load filesystem parameter low byte
	ret;								// return BCDE = filesystem parameters

; Function: Get directory cluster from volume descriptor
get_directory_cluster:
	ld e, (iy + 53);					// load directory cluster low byte
	ld d, (iy + 54);					// load directory cluster byte 2
	ld c, (iy + 55);					// load directory cluster byte 3
	ld b, (iy + 56);					// load directory cluster high byte
	ret;								// return DEBC = current directory cluster

; Function: Set directory cluster in volume descriptor
set_directory_cluster:
	ld (iy + 53), e;					// store directory cluster low byte
	ld (iy + 54), d;					// store directory cluster byte 2
	ld (iy + 55), c;					// store directory cluster byte 3
	ld (iy + 56), b;					// store directory cluster high byte
	ret;								// return after storing DEBC cluster

; Function: Get working cluster from volume descriptor
get_working_cluster:
	ld e, (iy + 57);					// load working cluster low byte
	ld d, (iy + 58);					// load working cluster byte 2
	ld c, (iy + 59);					// load working cluster byte 3
	ld b, (iy + 60);					// load working cluster high byte
	ret;								// return DEBC = working cluster

; Function: Set working cluster in volume descriptor
set_working_cluster:
	ld (iy + 57), e;					// store working cluster low byte
	ld (iy + 58), d;					// store working cluster byte 2
	ld (iy + 59), c;					// store working cluster byte 3
	ld (iy + 60), b;					// store working cluster high byte
	ret;								// return after storing DEBC cluster

; Function: Load directory sector if needed
load_directory_sector:
	ld a, (iy + 61);					// check if directory buffer valid
	or a;								// test validity flag
	ret z;								// return if buffer already valid
	ld hl, $3fe8;						// load buffer management address
	call get_working_cluster;			// get working cluster
	rst $30;							// call ROM routine
	nop;								// padding/alignment
	call get_directory_cluster;			// get directory cluster
	rst $30;							// call ROM routine
	nop;								// padding/alignment
	ld hl, $3e00;						// load directory buffer address
	ld bc, 0;							// clear cluster offset
	ld de, 1;							// set sector count to 1
	jp write_disk_sector;				// jump to sector read routine

; Function: Process file sector loading
process_file_sector:
	call get_file_next_cluster;			// call sector loading function
	call read_disk_sector;				// call directory processing
	ret;								// return from function

; Function: Check sector flags and load data
check_sector_flags:
	call get_file_next_cluster;			// call sector loading function
	ld a, ($3c26);						// load system flags
	cp (iy + _flags);					// compare with file flags
	jr nz, handle_sector_buffer;		// jump if flags differ
	ld hl, $3c2a;						// load buffer address
	call compare_32bit;					// call utility function

; Function: Handle sector buffer operations
handle_sector_buffer:
	ld hl, $2a00;						// load sector buffer address
	ccf;								// complement carry flag
	ret z;								// return if zero
	ld a, (iy + _flags);				// load file flags
	ld ($3c26), a;						// store flags in buffer
	ld ($3c27), de;						// store DE address in buffer
	ld ($3c29), bc;						// store BC value in buffer
	push hl;							// save HL register
	call process_file_sector;			// call sector/directory processing
	pop hl;								// restore HL register
	ret;								// return from function

; Function: Clear memory buffer
clear_memory_buffer:
	push hl;							// save HL register
	ld hl, $2a00;						// load buffer address
	call call_file_descriptor;			// call memory clear function
	pop hl;								// restore HL register
	ret;								// return from function

; Function: Process file flags and load sector
process_file_flags:
	call get_file_next_cluster;			// call sector loading function
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
process_sector_decrement:
	dec (ix + 19);						// decrement sector count
	jr z, complete_sector_processing;	// jump if all sectors processed
	call get_file_next_cluster;			// call sector loading function
	call inc_32bit;						// call disk function
	jp set_file_next_cluster;			// jump back to processing loop

; Function: Complete sector processing
complete_sector_processing:
	call process_file_sector_mapping;	// call completion function
	ret c;								// return if carry set
	jp advance_to_next_cluster;			// jump to finalization

; Function: Check file position and parameters
check_file_position:
	ld a, (iy + 28);					// load file position indicator
	cp 1;								// check if position is 1
	jr z, apply_sector_shift;			// jump if at position 1
	ld a, d;							// load D register
	or e;								// check if DE is zero
	jr nz, apply_sector_shift;			// jump if DE not zero
	ld bc, 0;							// clear BC register
	ld d, (iy + 36);					// load file size high byte
	ld e, (iy + 35);					// load file size low byte
	ld a, (iy + 66);					// load status flag
	ret;								// return with file parameters

; Function: Apply sector size shift to address calculation
apply_sector_shift:
	ld a, (iy + 37);					// load sectors per cluster shift count

; Function: Shift loop for address scaling
shift_address_loop:
	srl a;								// shift right shift count
	jr c, add_file_offset;				// exit when shift complete
	sla e;								// shift left E register
	rl d;								// rotate left D register
	rl c;								// rotate left C register
	rl b;								// rotate left B register
	jr shift_address_loop;				// continue shifting loop

; Function: Add file offset to base address (32-bit arithmetic)
add_file_offset:
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

; Function: Initialize file sector setup
setup_file_sector:
	call set_file_sector_address;		// call sector/cluster address setup

; Function: Check file position and advance to next cluster
advance_to_next_cluster:
	call check_file_position;			// call file position check
	ld (ix + 19), a;					// store sector count in file control block
	jp set_file_next_cluster;			// jump to main processing loop

; Function: Get file sector and process cluster mapping
process_file_sector_mapping:
	call get_file_sector_address;		// call cluster calculation function
	call map_sector_from_cluster;		// call sector mapping function
	jp nc, set_file_sector_address;		// jump to setup if no carry
	cp $80;								// check for empty block marker
	scf;								// set carry flag (error condition)
	ret nz;								// return with error if not empty block
	bit 2, (ix + 1);					// test file flag bit 2
	ret z;								// return if bit not set
	jp store_hl_memory_ptr;				// jump to extended processing

; Function: Map sector from cluster with position handling
map_sector_from_cluster:
	ld a, (iy + 28);					// load file position indicator
	cp 1;								// check if position is 1
	jr z, handle_position_one;			// jump to special handling if 1
	push de;							// save DE register
	ld e, d;							// shift registers for 32-bit calculation
	ld d, c;							// D = C (shift high)
	ld c, b;							// C = B (shift high)
	ld b, 0;							// clear B (most significant byte)
	call check_drive_cluster_cache;		// call cluster to sector conversion
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
check_chain_end_marker:
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
handle_position_one:
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
	call check_drive_cluster_cache;		// call cluster to sector conversion
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
	jr nz, check_chain_end_marker;		// jump if not equal
	ld a, $ff;							// load mask value
	and c;								// mask with C
	and d;								// mask with D
	jr check_chain_end_marker;			// jump to check end marker

; Function: Process disk operations with error handling
process_disk_operation:
	push de;							// save DE register
	call get_working_cluster;			// call buffer management function
	inc b;								// increment B register
	jr z, simple_return;				// jump if zero result
	dec b;								// decrement B back
	call c, inc_32bit;					// call disk function if carry set
	call nc, dec_32bit;					// call alternate function if no carry
	call set_working_cluster;			// call cleanup function

; Function: Simple operation return point
simple_return:
	pop de;								// restore DE register
	ret;								// return from cluster operation

; Function: Validate cluster operation
validate_cluster_operation:
	push bc;							// save BC register
	push de;							// save DE register
	call get_working_cluster;			// get working cluster
	rst $30;							// call ROM routine
	dec c;								// decrement cluster count
	pop de;								// restore DE register
	pop bc;								// restore BC register
	ret nz;								// return if non-zero (valid)
	ld a, 9;							// load error code 9 (invalid cluster)
	scf;								// set carry flag for error
	ret;								// return with error

; Function: Disk write operation with RAM page management
write_with_page_management:
	call get_file_next_cluster;			// call sector loading function
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
process_fat_cluster_operations:
	call get_directory_cluster;			// call FAT processing function
	call map_sector_from_cluster;		// call sector mapping function
	call check_system_flag_bit;			// call system function
	ret c;								// return if operation failed
	ld h, d;							// load D to H
	ld l, e;							// load E to L
	ld a, $ff;							// load end-of-chain marker
	call store_at_memory_hl;			// call cluster marking function
	push de;							// save DE register
	ld de, ($3c11);						// load system parameter address
	ld bc, ($3c13);						// load system parameter value
	push bc;							// save BC register
	push de;							// save DE register again
	call mark_buffer_dirty;				// call cluster calculation function
	pop de;								// restore DE register
	pop bc;								// restore BC register
	pop hl;								// restore HL register
	ret c;								// return if error occurred

; Function: Multi-precision right shifts for FAT address conversion
fat_address_right_shift:
	rr h;								// rotate right H register
	rr l;								// rotate right L register
	ld a, (iy + 28);					// load FAT type indicator
	cp 1;								// check if FAT12
	jr nz, register_shift_32bit;		// jump if not FAT12
	srl b;								// shift right B register
	rr c;								// rotate right C register
	rr d;								// rotate right D register
	rr e;								// rotate right E register
	rr l;								// rotate right L register

; Function: Register shift operations for 32-bit calculations
register_shift_32bit:
	ld b, c;							// shift register chain: B = C
	ld c, d;							// C = D
	ld d, e;							// D = E  
	ld e, l;							// E = L
	or a;								// clear carry flag
	ret;								// return with shifted registers

; Function: Process command with 8-byte limit
process_command_8byte:
	ld b, 8;							// set counter to 8 bytes
	call validate_filename_chars;		// call processing function
	call process_filename_chars;		// call validation function
	ld a, (hl);							// load character from buffer
	cp '.';								// check for period (external command marker)
	jr nz, extract_extension_3char;		// jump if not period
	inc hl;								// advance past period

; Function: Extract 3-character extension with validation
extract_extension_3char:
	ld b, 3;							// set counter for 3-character extension

; Function: Process filename characters with validation
process_filename_chars:
	ld a, (hl);							// load character from filename
	ld c, $20;							// set padding character (space)
	cp '.';								// check for period (extension separator)
	jr z, pad_with_spaces;				// jump to padding if period found
	and a;								// check for null terminator
	jr z, pad_with_spaces;				// jump to padding if null
	cp '/';								// check for path separator
	jr z, pad_with_spaces;				// jump to padding if path separator
	call validate_fat_char;				// validate character is acceptable for FAT filesystem
	jr nc, convert_to_uppercase;		// jump to case conversion if valid

; Function: Return error for invalid filename character
invalid_filename_char:
	scf;								// set carry flag (invalid character)
	ld a, 7;							// load error code 7 (bad filename)
	ret;								// return with error

; Function: Convert lowercase to uppercase for FAT compatibility
convert_to_uppercase:
	cp 'a';								// check if lowercase letter
	jr c, store_char_advance;			// jump if below 'a'
	cp '{';								// check if above 'z' ('{' is char after 'z')
	jr nc, store_char_advance;			// jump if above lowercase range
	and %11011111;						// clear bit 5 to convert lowercase to uppercase

; Function: Store character and advance pointers
store_char_advance:
	ld (de), a;							// store converted character
	inc de;								// advance destination pointer
	inc hl;								// advance source pointer
	djnz process_filename_chars;		// continue processing characters
	ld a, (hl);							// load next character
	and a;								// check for null terminator
	jr z, complete_filename_processing;	// jump to completion if null
	cp '/';								// check for path separator
	jr nz, invalid_filename_char;		// error if unexpected character

; Function: Complete filename processing
complete_filename_processing:
	or a;								// clear carry flag (success)
	ret;								// return successfully

; Function: Pad remaining filename space with specified character
pad_with_spaces:
	ld a, c;							// load padding character (typically space)

; Function: Character padding loop
padding_loop:
	ld (de), a;							// store padding character
	inc de;								// advance destination pointer
	djnz padding_loop;					// repeat for remaining character count
	or a;								// clear carry flag (success)
	ret;								// return after padding

; Function: Process file extension for FAT 8.3 format
validate_filename_chars:
	ld a, (hl);							// load character from extension
	cp '.';								// check for period (extension marker)
	ret nz;								// return if not extension
	ld bc, $0b00;						// B=11 chars total, C=0 for comparison
	ldi;								// copy period and increment pointers
	cp (hl);							// compare with next character
	jr nz, set_extension_padding;		// jump if different
	ldi;								// copy another character
	dec b;								// decrement remaining character count

; Function: Set padding for extension processing
set_extension_padding:
	ld c, $20;							// set space character for padding
	call pad_with_spaces;				// pad remaining extension space
	pop bc;								// restore BC register
	ret;								// return from extension processing

; Function: Validate character for FAT filesystem compatibility
validate_fat_char:
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

	; // data table or unused bytes
	ccf;								// data byte $3f
	ld ($3a2f), hl;						// data bytes $22 $2f $3a
	dec sp;								// data byte $3b
	inc l;								// data byte $2c
	inc a;								// data byte $3c
	ld a, $5c;							// data bytes $3e $5c
	ld a, h;							// data byte $7c
	ld l, $2a;							// data bytes $2e $2a
;;; 11_directory.asm


; Function: Compare directory entries
compare_directory_entries:
	push de;							// save DE register
	push hl;							// save HL register
	push bc;							// save BC register
	ld b, $0b;							// set comparison length (11 chars for 8.3 filename)

; Function: Character-by-character filename comparison loop
filename_compare_loop:
	ld a, (de);							// load character from search pattern
	cp '*';								// check for wildcard character
	jr z, restore_after_comparison;		// jump if wildcard (auto-match)
	cp (hl);							// compare with directory entry character
	jr nz, restore_after_comparison;	// jump if no match
	inc de;								// advance search pattern pointer
	inc hl;								// advance directory entry pointer
	djnz filename_compare_loop;			// continue for all 11 characters

; Function: Restore registers after comparison
restore_after_comparison:
	pop bc;								// restore BC register
	pop hl;								// restore HL register
	pop de;								// restore DE register
	ret;								// return with comparison result

; Function: Process file operation with error checking
; Function: Process file operation with error checking
process_file_operation:
	ld b, a;							// save operation code
	push bc;							// save BC register
	push hl;							// save HL register
	call get_file_sector_address;		// get file current sector address
	ld hl, $3c22;						// load buffer address
	call compare_32bit;					// call comparison function
	pop hl;								// restore HL register
	pop bc;								// restore BC register
	ld a, b;							// reload operation code
	jr z, return_device_error;			// jump if zero result
	or a;								// test operation code
	ret;								// return with result

; Function: Return specific error code
return_device_error:
	ld a, $13;							// load error code 19 (device error)
	ret;								// return with error

; Function: Check file attributes and extensions
check_file_attributes:
	ld b, a;							// save operation type
	push bc;							// save BC register
	push hl;							// save HL register
	call get_file_sector_address;		// get file current sector address
	push iy;							// save IY register
	pop hl;								// transfer IY to HL
	ld l, $29;							// set offset for file attribute
	call compare_32bit;					// call comparison function
	jr nz, cleanup_and_return;			// jump if not zero
	pop hl;								// restore HL register
	push hl;							// save HL again
	ld a, (hl);							// load first character
	cp '.';								// check for period
	jr nz, cleanup_and_return;			// jump if not extension
	inc l;								// advance pointer
	ld a, (hl);							// load next character
	cp ' ';								// check for space

; Function: Cleanup and return operation code
cleanup_and_return:
	pop hl;								// restore HL register
	pop bc;								// restore BC register
	ld a, b;							// load operation code
	ret;								// return with operation result

; Function: Initialize buffer and call system routines
init_buffer_system_call:
	ld de, $2f00;						// load buffer address
	push de;							// save buffer address
	exx;								// switch to alternate registers
	call process_cluster_pointer;		// call system function
	exx;								// switch back to main registers
	call directory_entry_setup;			// call ROM routine
	pop hl;								// restore buffer address to HL
	or a;								// test result flags
	ret;								// return with status

; Function: Process filesystem operation with parameter handling
process_filesystem_operation:
	push af;							// save accumulator
	call get_filesystem_parameters;		// get filesystem parameters
	call store_cluster_address;			// call processing function
	call setup_file_sector;				// call sector/cluster address setup
	pop af;								// restore accumulator

; Function: File operation validation and processing
validate_file_operation:
	call check_file_attributes;			// call file operation processing
	jr z, init_buffer_system_call;		// jump if zero result
	call process_file_operation;		// call error checking function
	ret c;								// return if error
	res 2, (ix + 1);					// clear file status bit
	ld (iy + 51), a;					// store accumulator in volume descriptor
	res 1, (iy + 52);					// clear volume status bit
	ld ($3c04), hl;						// store HL in system variable

; Function: Set error and prepare buffer operations
set_error_prepare_buffer:
	ld a, $11;							// load error code 17
	ld (ix + 6), a;						// store error code in file descriptor
	ld hl, disk_sector_buffer;			// load buffer address
	push hl;							// save buffer address
	call process_file_sector;			// call buffer read function
	pop hl;								// restore HL register
	ret c;								// return if error

; // directory entry processing loop
dir_entry_loop:
	dec (ix + 6);						// decrement entry counter
	jr nz, dir_process_entry;			// jump if more entries to process
	call process_sector_decrement;		// call sector advance function
	jr set_error_prepare_buffer;		// jump to reload buffer

; // process current directory entry
dir_process_entry:
	ld a, (hl);							// load first character of entry
	and a;								// check if entry is empty (end of directory)
	jr z, dir_end_reached;				// jump if end of directory
	cp 229;								// check for deleted entry marker ($e5)
	jr z, dir_deleted_entry;			// jump if deleted entry
	ld c, l;							// save current entry pointer in C
	ld a, l;							// load entry pointer
	add a, 11;							// add 11 to point to attributes byte
	ld l, a;							// update pointer to attributes
	ld a, (hl);							// load file attributes
	ld l, c;							// restore entry pointer
	cp 15;								// check for long filename entry ($0f)
	jr nz, dir_check_attributes;		// jump if not long filename entry

; // skip long filename entries
dir_skip_entry:
	ld bc, $20;							// load directory entry size (32 bytes)
	add hl, bc;							// advance to next directory entry
	jr dir_entry_loop;					// jump back to process next entry

; // handle deleted directory entry
dir_deleted_entry:
	call handle_deleted_entry;			// call deleted entry handler
	jr dir_skip_entry;					// jump to skip entry

; // process deleted entry for reuse tracking
handle_deleted_entry:
	bit 1, (iy + 52);					// check if already tracking deleted entry
	ret nz;								// return if already tracking
	set 1, (iy + 52);					// set deleted entry tracking flag
	ld a, (ix + 6);						// load current entry number
	ld (ix + 30), a;					// store as deleted entry number
	ld a, (ix + 19);					// load current sector high
	ld (ix + 31), a;					// store as deleted entry sector
	call get_file_next_cluster;			// call file descriptor function
	call store_file_size;				// call position storage function
	call get_file_sector_address;		// call sector calculation function
	call store_file_position;			// call position update function
	ret;								// return from function

; // check file attributes and compare filenames
dir_check_attributes:
	ld e, a;							// store file attributes in E
	ld a, (iy + 51);					// load file attribute filter
	and a;								// check if filter is set
	jr z, dir_compare_filename;			// jump if no filter
	and e;								// apply filter to file attributes
	jr z, dir_skip_entry;				// skip entry if doesn't match filter

; // compare entry with search filename
dir_compare_filename:
	ld de, ($3c04);						// load search filename pointer
	call compare_directory_entries;		// call filename comparison function
	jr nz, dir_skip_entry;				// skip if no match
	ld (ix + 28), l;					// store matched entry low address
	ld (ix + 29), h;					// store matched entry high address
	or a;								// clear carry flag (success)
	ret;								// return with match found

; // handle end of directory (file not found)
dir_end_reached:
	call handle_deleted_entry;			// call deleted entry handler
	ld a, (ix + 30);					// load saved deleted entry number
	ld (ix + 6), a;						// restore entry counter
	ld a, (ix + 31);					// load saved deleted entry sector
	ld (ix + 19), a;					// restore sector number
	call load_file_size;				// call position restore function
	call set_file_next_cluster;			// call sector setup function
	call load_file_position;			// call position load function
	call set_file_sector_address;		// call position store function
	ld a, 5;							// load error code 5 (file not found)
	scf;								// set carry flag (error)
	ret;								// return with error

; // initialize file lookup operation
init_file_lookup:
	ld bc, $ffff;						// initialize counters to -1 (not found)
	ld ($3c1f), bc;						// store in first counter variable
	ld ($3c20), bc;						// store in second counter variable

; // setup directory buffer and call system function
setup_dir_buffer:
	ld de, $2c00;						// load directory buffer address
	push de;							// save buffer address on stack
	rst $30;							// call system function (disk operation)
	dec b;								// decrement operation parameter
	pop hl;								// restore buffer address to HL
	ld (iy + 52), a;					// store operation flags
	rra;								// rotate right to check bit 0
	jr nc, path_init_filename;			// jump if directory operation
	push hl;							// save HL register
	push iy;							// save IY register
	pop hl;								// load IY value into HL
	ld l, $80;							// set L to $80 (buffer offset)
	ld de, $2c80;						// load destination buffer address
	push de;							// save destination address
	ld a, (iy + 127);					// load buffer size (FIXME: negative offset)
	push af;							// save buffer size
	sub $80;							// subtract $80 from buffer size
	ld b, 0;							// clear B register
	ld c, a;							// store adjusted size in BC
	ldir;								// copy buffer data
	pop af;								// restore original buffer size
	pop de;								// restore destination address
	ld e, a;							// store buffer size in E
	pop hl;								// restore HL register

; // initialize filename processing
path_init_filename:
	xor a;								// clear A register
	ld (ix + 29), a;					// clear high byte of entry pointer
	ld a, (hl);							// load first character of path
	and a;								// check if path is empty
	jp z, path_empty;					// jump if empty path
	cp '/';								// check for root directory marker
	jr nz, path_setup_processing;		// jump if not root directory
	bit 0, (iy + 52);					// check if absolute path flag set
	jr z, path_advance_root;			// jump if not absolute path
	cp a;								// clear zero flag
	ld e, $80;							// load buffer offset
	ld (de), a;							// store path separator
	inc de;								// advance buffer pointer

; // advance past root directory marker
path_advance_root:
	inc hl;								// advance path pointer past '/'

; // setup path processing
path_setup_processing:
	ld ($3dea), de;						// store current buffer pointer
	call z, process_cluster_pointer;	// call root directory setup if needed
	call nz, get_filesystem_parameters;	// call current directory setup if not root

; // main path component processing loop
path_component_loop:
	ld ($3dec), hl;						// store current path position
	ld a, (hl);							// load current character
	and a;								// check if end of path
	jp z, path_end_reached;				// jump if end of path reached
	call store_cluster_address;			// call path position storage
	call setup_file_sector;				// call directory setup
	ld de, $3c06;						// load filename buffer address
	push de;							// save buffer address
	call process_command_8byte;			// call filename extraction function
	pop de;								// restore buffer address
	ret c;								// return if error in filename extraction
	push hl;							// save path pointer
	ex de, hl;							// exchange DE/HL (filename buffer to HL)
	xor a;								// clear A register
	call validate_file_operation;		// call directory entry search function
	pop de;								// restore path pointer
	jp c, path_search_failed;			// jump if search failed
	ld c, l;							// save entry pointer low in C
	ld a, l;							// load entry pointer low
	add a, $0b;							// add 11 to point to attributes
	ld l, a;							// update pointer to attributes
	bit 4, (hl);						// check directory attribute bit
	ld l, c;							// restore entry pointer
	ex de, hl;							// exchange back to original order
	jr nz, path_directory_found;		// jump if directory entry
	ld a, (hl);							// load next path character
	and a;								// check if end of path
	jr z, path_file_found;				// jump if end of path (file found)
	ld a, $13;							// load error code 19 (not a directory)
	scf;								// set carry flag (error)
	ret;								// return with error

; // handle successful file found at end of path
path_file_found:
	ld a, (iy + 52);					// load operation flags
	rla;								// rotate left to check bit 7
	ld a, $11;							// load error code 17
	ret c;								// return error if wrong operation type
	jr path_success_handler;			// jump to success handler

; // handle directory entry found - traverse into subdirectory
path_directory_found:
	bit 0, (iy + 52);					// check if path building is enabled
	jr z, path_traverse_directory;		// jump if not building path
	push hl;							// save entry pointer
	ld hl, ($3dec);						// load current path position
	ld de, ($3dea);						// load path buffer pointer
	ld a, (hl);							// load next path character
	cp '.';								// check for '.' (current/parent directory)
	jr z, path_dot_directory;			// jump if dot directory

; // copy directory name to path buffer
path_copy_name:
	ld a, (hl);							// load character from path
	inc hl;								// advance path pointer
	and a;								// check if end of component
	jr z, path_add_separator;			// jump if end of component (add separator)
	cp '/';								// check for path separator ($2f)
	jr z, path_add_separator;			// jump if path separator found
	ld (de), a;							// store character in path buffer
	inc de;								// increment buffer pointer
	jr path_copy_name;					// continue copying characters

; // handle parent directory (..) navigation
path_dot_directory:
	inc hl;								// skip first dot
	ld a, (hl);							// load next character
	cp '.';								// check for second dot ($2e)
	jr nz, path_update_buffer;			// jump if not parent directory
	dec de;								// backtrack in path buffer
	dec de;								// backtrack further

; // backtrack to find parent directory
path_find_parent:
	ld a, (de);							// load character from path buffer
	cp '/';								// check for path separator ($2f)
	jr z, path_parent_found;			// jump if separator found
	dec de;								// continue backtracking
	jr path_find_parent;				// loop until separator found

; // position after parent directory separator
path_parent_found:
	inc de;								// move past separator
	jr path_update_buffer;				// jump to path update

; // add path separator after directory name
path_add_separator:
	ld a, $2f;							// load path separator character
	ld (de), a;							// store separator in buffer
	inc de;								// increment buffer pointer

; // update path buffer pointer and continue processing
path_update_buffer:
	ld ($3dea), de;						// store updated path buffer pointer
	pop hl;								// restore entry pointer
	ld a, e;							// check buffer position
	cp $81;								// compare with buffer limit
	ld a, $15;							// load error code 21 (path too long)
	ret c;								// return if path buffer overflow
	call z, process_cluster_pointer;	// call root directory setup if at root
	jr z, path_continue_processing;		// jump if root directory

; // setup directory for subdirectory traversal
path_traverse_directory:
	call setup_directory_cluster;		// call directory cluster setup function

; // continue path processing or handle completion
path_continue_processing:
	ld a, (hl);							// load next path character
	and a;								// check if end of path
	jr z, path_end_reached;				// jump if end of path reached
	cp '/';								// check for path separator ($2f)
	inc hl;								// advance path pointer
	jp z, path_component_loop;			// jump to continue processing if separator

; // error - invalid path format
path_empty:
	scf;								// set carry flag (error condition)
	ld a, $13;							// load error code 19 (invalid filename)
	ret;								// return with error

; // handle end of path - check operation type
path_end_reached:
	ld a, (iy + 52);					// load operation flags
	rla;								// rotate left to check bit 7
	ccf;								// complement carry flag
	ld a, $10;							// load error code 16 (wrong operation)
	ret c;								// return error if wrong operation type

; // successful path resolution - call finalization
path_success_handler:
	call path_finalize_function;		// call path finalization function
	or a;								// clear carry flag (success)
	ret;								// return successfully

; // path finalization function
path_finalize_function:
	bit 0, (iy + 52);					// check if path building enabled
	ret z;								// return if path building disabled
	ld hl, ($3dec);						// load current path position
	ld de, ($3dea);						// load path buffer pointer

; // copy remaining path string
path_copy_string:
	ld a, (hl);							// load character from source
	ld (de), a;							// store character in destination
	inc hl;								// increment source pointer
	inc de;								// increment destination pointer
	or a;								// check if null terminator
	ret z;								// return if end of string
	jr path_copy_string;				// continue copying

; // handle file not found error with path completion
path_search_failed:
	ex de, hl;							// exchange DE and HL
	ld a, (hl);							// load character from path
	and a;								// check if end of path
	jr z, path_not_found_finalize;		// jump if end reached
	scf;								// set carry flag (error)
	ld a, $13;							// load error code 19 (invalid filename)
	ret;								// return with error

; // finalize path and return file not found error
path_not_found_finalize:
	call path_finalize_function;		// call path finalization function
	scf;								// set carry flag (error)
	ld a, 5;							// load error code 5 (file not found)
	ret;								// return with error

; // setup directory cluster for operations
setup_directory_cluster:
	push hl;							// save HL register
	ld a, (ix + 29);					// load cluster high byte from descriptor
	and a;								// check if cluster is set
	jr nz, load_cluster_descriptor;		// jump if cluster exists
	call process_cluster_pointer;		// call root directory setup
	jr restore_registers_check;			// jump to completion

; // load cluster from descriptor and setup directory
load_cluster_descriptor:
	ld h, a;							// copy cluster high byte to H
	ld a, (ix + 28);					// load cluster low byte from descriptor
	add a, $14;							// add offset to directory entry
	ld l, a;							// set cluster low byte in L
	call process_cluster_chain;			// call cluster setup function

; // restore registers and check sector count
restore_registers_check:
	pop hl;								// restore HL register

; // check sector parameters and return
check_sector_params:
	ld a, (iy + 28);					// load sectors per cluster
	cp 1;								// check if single sector cluster
	ret z;								// return if single sector
	ld bc, 0;							// clear BC register
	ret;								// return with cleared registers

; // process cluster chain and validate
process_cluster_chain:
	call extract_cluster_data;			// call cluster data extraction function
	ld a, c;							// load cluster low byte
	or b;								// combine with high byte
	or e;								// combine with extended data
	or d;								// combine all cluster data
	call z, process_cluster_pointer;	// call root directory if cluster is zero
	jr check_sector_params;				// jump to parameter check

; // extract cluster data from directory entry
extract_cluster_data:
	ld c, (hl);							// load cluster low byte
	inc l;								// increment to next byte
	ld b, (hl);							// load cluster high byte
	ld a, l;							// get current L value
	add a, 5;							// skip 5 bytes to extended cluster
	ld l, a;							// update L pointer
	ld e, (hl);							// load extended cluster low byte
	inc l;								// increment to next byte
	ld d, (hl);							// load extended cluster high byte
	inc l;								// increment pointer for return
	ret;								// return with cluster data

	; // buffer management function with system call
	ex de, hl;							// exchange DE and HL
	push iy;							// save IY register
	pop hl;								// load IY value to HL
	ld l, $80;							// set buffer offset
	rst $30;							// call system function
	inc b;								// increment B register
	or a;								// clear carry flag
	ret;								// return from function
;;; 12_file_io.asm


; // file I/O operation with buffer management
file_io_buffer_operation:
	push hl;							// save HL register
	set 5, (ix + 1);					// set buffer flag in descriptor
	call buffer_io_function;			// call buffer I/O function
	res 5, (ix + 1);					// clear buffer flag
	pop hl;								// restore HL register
	ret;								// return from operation

; // file close operation
file_close_operation:
	call file_flush_update;				// call file close function
	ld (ix + 0), 0;						// clear file descriptor status
	ret;								// return from close operation

; // file flush and update operation
file_flush_update:
	or a;								// clear carry flag initially

file_flush_loop_start equ $1699

	bit 3, (ix + 1);					// check if directory operation flag set
	jp z, flush_dirty_buffer;			// jump to cleanup if not directory
	call directory_update_function;		// call directory update function
	ret c;								// return if update failed
	ld de, $14;							// load offset to directory entry data
	add hl, de;							// add offset to HL
	call load_cluster_address;			// call file position function
	ld (hl), c;							// store low byte of position
	inc hl;								// increment to next byte
	ld (hl), b;							// store high byte of position
	inc hl;								// skip to next field
	inc hl;								// skip reserved bytes
	inc hl;								// continue skipping
	inc hl;								// skip more reserved bytes
	inc hl;								// advance to size field
	ld (hl), e;							// store size low byte
	inc hl;								// increment to next byte
	ld (hl), d;							// store size high byte
	inc hl;								// increment pointer
	call load_file_size;				// call file size function
	rst $30;							// call system function
	nop;								// no operation
	call directory_sector_write;		// call directory write function

; // error handling and buffer management function
error_buffer_management:
	push af;							// save accumulator and flags
	ld hl, $3c1b;						// load buffer management address
	rst $30;							// call system function
	ld bc, $4fcd;						// load error recovery parameters
	ld de, $c3f1;						// load jump instruction pattern
	di;									// interrupts off

; // directory update processing function
directory_update_function equ $16cb

	djnz file_flush_loop_start;			// loop back to file flush if B register not zero
	ld e, h;							// copy H to E register
	ld de, $1b21;						// load directory operation code
	inc a;								// increment accumulator

; // continue directory processing after error recovery
	rst $30;							// call system function
	nop;								// no operation
	call load_directory_cluster;		// call file size get function
	call set_file_next_cluster;			// call cluster set function
	call directory_position_function;	// call directory position function
	ex de, hl;							// exchange DE and HL
	ret;								// return from function

; // file delete operation entry point
file_delete_operation:
	ld a, b;							// load operation flags from B
	ld ($3c01), a;						// store operation flags
	ld ($3c23), de;						// store file parameters
	ld a, 1;							// load file lookup mode
	call init_file_lookup;				// call file lookup function
	jr nc, handle_existing_file;		// jump if file found
	cp 5;								// check for file not found error
	scf;								// set carry flag (error)
	ret nz;								// return if other error
	ld a, ($3c01);						// load operation flags
	and %00001100;						// mask file operation bits
	scf;								// set carry flag (error)
	ld a, 5;							// load file not found error
	ret z;								// return if no operation specified
	jp file_creation_operation;			// jump to file creation

; // handle existing file operations
handle_existing_file:
	ld a, ($3c01);						// load operation flags
	and %00001100;						// mask file operation type bits
	cp 4;								// check for delete operation
	jr nz, determine_file_operation;	// jump if not delete
	scf;								// set carry flag (error)
	ld a, $12;							// load error code 18 (file exists)
	ret;								// return with error

; // determine file operation type
determine_file_operation:
	cp $0c;								// check for directory creation
	jp z, directory_creation_handler;	// jump to directory creation function
	jp file_access_handler;				// jump to file access function

; // file creation operation
file_creation_operation:
	call validate_cluster_operation;	// call cluster validation function
	ret c;								// return if validation failed
	call directory_position_function;	// call directory position function
	ret c;								// return if position failed
	ld a, (de);							// load directory entry status
	push af;							// save status
	call directory_entry_creation;		// call directory entry creation
	pop de;								// restore status to DE
	ret c;								// return if creation failed
	ld a, d;							// check entry status
	cp $e5;								// check for deleted entry marker
	jr z, init_file_descriptor;			// jump to initialization if deleted
	call clear_directory_entry;			// call directory entry clear function
	ret c;								// return if clear failed

; // initialize file descriptor and setup file attributes
init_file_descriptor:
	ld hl, $3c1b;						// load file buffer address
	rst $30;							// call system function
	ld bc, $07cd;						// load initialization parameters
	ld a, (de);							// load entry data
	call reset_file_position;			// call file position reset function
	call store_file_position;			// call file position store function
	ld a, ($3c01);						// load operation flags
	push af;							// save flags
	and %00000011;						// mask access mode bits
	or %00000010;						// set write access bit
	ld (ix + 1), a;						// store access mode in descriptor
	pop af;								// restore original flags
	or a;								// check flags
	bit 6, a;							// check directory creation bit
	jr z, finalize_file_creation;		// jump if not directory
	call directory_buffer_setup;		// call directory initialization function
	call save_hl_reg_again;				// call directory setup function
	ret c;								// return if setup failed
	ld hl, $2d00;						// load directory buffer address
	call call_file_descriptor;			// call directory write function
	ret c;								// return if write failed
	set 3, (ix + 1);					// set directory flag in descriptor
	ld a, $80;							// load directory buffer offset
	ld (ix + 11), a;					// store in file descriptor
	ld (ix + 15), a;					// store buffer position
	call file_flush_update;				// call file update function
	ret c;								// return if update failed

; // complete file creation and setup file buffer
finalize_file_creation:
	call transfer_error_number;			// call error number transfer function
	ld hl, $2c80;						// load file buffer address
	ld a, ($3df9);						// load file buffer size
	ld b, a;							// copy size to B register
	or b;								// check if size is valid
	ret;								// return with status

; // transfer system error number to file descriptor
transfer_error_number:
	ld a, (iy + _err_nr);				// load error number from system variables
	ld (ix + 0), a;						// store error in file descriptor
	ret;								// return from function

; // clear directory buffer based on address alignment
clear_directory_entry:
	ld a, h;							// load high byte of address
	and %00000001;						// check if address is odd (bit 0)
	add a, l;							// add to low byte for alignment check
	ld bc, next_char_rst20;				// load default clear size (31 bytes)
	jr nz, clear_buffer_operation;		// jump to clear if not aligned
	set 2, (ix + 1);					// set buffer operation flag
	call process_sector_decrement;		// call sector processing function
	res 2, (ix + 1);					// clear buffer operation flag
	ld hl, disk_sector_buffer;			// load sector buffer address
	ld bc, $01ff;						// load full sector size (511 bytes)

; // clear memory buffer with zeros
clear_buffer_operation:
	ld a, (hl);							// load byte from buffer (will be overwritten)
	ld d, h;							// copy source address high to destination
	ld e, l;							// copy source address low to destination
	inc de;								// increment destination pointer
	ld (hl), 0;							// store zero at source address
	ldir;								// copy zeros to clear entire buffer
	call directory_sector_write;		// call directory sector write function
	ret;								// return from clear operation

; // create new directory entry from filename
directory_entry_creation:
	ld hl, $3c06;						// load formatted filename buffer address
	ld bc, $0b;							// load filename length (11 characters FAT format)
	ldir;								// copy filename to directory entry
	xor a;								// clear accumulator
	ld (de), a;							// null-terminate filename
	ex de, hl;							// exchange DE and HL
	inc hl;								// move to attribute field

; // initialize directory entry fields
init_dir_entry:
	ld (hl), a;							// clear attribute field
	inc hl;								// move to next field
	ld (hl), a;							// clear reserved field
	inc hl;								// move to time field
	rst $08;							// call system function
	defb m_getdate;						// get current date/time
	rst $30;							// call system function
	nop;								// no operation
	xor a;								// clear accumulator
	ld (hl), a;							// clear file size byte 1
	inc l;								// increment to next byte
	ld (hl), a;							// clear file size byte 2
	inc l;								// increment to next byte
	ld (hl), a;							// clear file size byte 3
	inc l;								// increment to next byte
	ld (hl), a;							// clear file size byte 4
	inc l;								// increment to cluster field
	rst $30;							// call system function
	nop;								// no operation
	ld (hl), a;							// clear cluster low byte
	inc l;								// increment to next byte
	ld (hl), a;							// clear cluster high byte
	inc l;								// increment pointer
	ld b, a;							// clear B register
	ld c, b;							// clear C register
	ld d, c;							// clear D register
	ld e, d;							// clear E register (32-bit zero)
	rst $30;							// call ROM calculator routine
	nop;								// padding instruction
	push hl;							// save directory entry pointer
	call directory_sector_write;		// call directory sector write function
	pop hl;								// restore directory entry pointer
	ret c;								// return if write failed
	push hl;							// save entry pointer again
	call get_file_next_cluster;			// call file descriptor function
	ld hl, $3c1b;						// load file buffer address
	rst $30;							// call ROM calculator routine
	nop;								// padding instruction
	pop hl;								// restore entry pointer
	or a;								// clear carry flag (success)
	ret;								// return from function

; // file position reset function
reset_file_position:
	ld b, 0;							// clear 32-bit file position
	ld c, b;							// clear C register
	ld d, c;							// clear D register
	ld e, d;							// clear E register (position = 0)
	call set_file_sector_address;		// call file position validation
	call store_file_size;				// call file size store function
	ret;								// return from position reset

; // directory sector write function
directory_sector_write:
	ld hl, disk_sector_buffer;			// load sector buffer address
	call call_file_descriptor;			// call sector write routine
	push af;							// save write result flags
	xor a;								// clear accumulator
	ld ($3c26), a;						// clear sector modification flag
	pop af;								// restore write result
	ret;								// return with write status

; // directory position calculation function
directory_position_function:
	ld hl, disk_sector_buffer;			// load sector buffer address
	push hl;							// save buffer address
	call process_file_sector;			// call directory sector read function
	pop hl;								// restore buffer address
	ret c;								// return if read failed

; // directory entry sector calculation
directory_entry_sector_calc:
	ld a, $10;							// load entries per sector (16)
	sub (ix + 6);						// subtract drive number for offset
	sla a;								// shift left (multiply by 2)
	sla a;								// shift left (multiply by 4)
	sla a;								// shift left (multiply by 8)
	sla a;								// shift left (multiply by 16)
	sla a;								// shift left (multiply by 32 bytes per entry)
	ld e, a;							// store byte offset in E
	ld d, 0;							// clear high byte
	rl d;								// rotate carry into D for 16-bit offset
	add hl, de;							// add offset to base address
	ex de, hl;							// exchange DE and HL (result in DE)
	or a;								// clear carry flag (success)
	ret;								// return with calculated address

; // directory creation and initialization function
directory_creation_handler:
	call setup_directory_cluster;		// call directory setup function
	push bc;							// save BC register pair
	push de;							// save DE register pair
	ld l, (ix + 28);					// load directory entry pointer low
	ld h, (ix + 29);					// load directory entry pointer high
	ld de, $0c;							// load offset to file size field (12 bytes)
	add hl, de;							// add offset to pointer
	call init_dir_entry;				// call file size write function
	pop de;								// restore DE register pair
	pop bc;								// restore BC register pair
	ret c;								// return if size write failed
	call call_rom_calculator;			// call system function
	call nc, flush_dirty_buffer;		// call directory update if no error
	ret c;								// return if update failed
	call reset_file_position;			// call file position reset
	call store_file_position;			// call cluster chain update
	call transfer_error_number;			// call directory finalize function
	ld hl, $1a7c;						// load function vector address
	ld ($3dee), hl;						// store function vector
	call descriptor_cleanup_validation;	// call directory completion function
	ld (ix + 0), 0;						// clear file status byte
	jp init_file_descriptor;			// jump to completion routine

; // file access and initialization function
file_access_handler:
	ld a, ($3c01);						// load file access mode flags
	push af;							// save access flags
	and %00000011;						// mask to get access mode (read/write)
	ld (ix + 1), a;						// store access mode in file descriptor
	call get_file_next_cluster;			// call file descriptor setup
	call file_validation_function;		// call file validation function
	call setup_directory_cluster;		// call directory setup
	call file_position_init;			// call file position initialization
	ld l, (ix + 28);					// load directory entry pointer low
	ld h, (ix + 29);					// load directory entry pointer highload directory entry pointer high
	ld de, $1c;							// load offset to file data area (28 bytes)
	add hl, de;							// add offset to get data pointer
	call file_processing_validation;	// call file processing function
	pop af;								// restore access flags
	bit 6, a;							// test write access bit
	jr z, $1894;						// jump if read-only access
	ld hl, $2d00;						// load buffer address for write mode
	ld bc, $80;							// load buffer size (128 bytes)
	call file_io_buffer_operation;		// call buffer allocation function
	ret c;								// return if allocation failed
	call filename_validation_checksum;	// call filename validation
	ld l, $0f;							// load file attribute mask
	jr z, file_attribute_processing;	// jump if validation passed
	ld (ix + 15), 0;					// clear file handle
	push hl;							// save attribute mask
	call file_buffer_init;				// call file buffer initialization
	pop hl;								// restore attribute mask

file_attribute_processing:
	ld de, ($3c23);						// load file attribute data address
	ld bc, 8;							// load attribute data length
	rst $30;							// call ROM memory copy routine
	ld b, $c3;							// load file completion marker
	ld h, a;							// store completion status
	rla;								// rotate left for status check

; // file processing and validation function
file_processing_validation:
	rst $30;							// call ROM calculator routine
	ld bc, $d3cd;						// load function code for file processing
	add hl, de;							// add offset to file pointer
	or a;								// clear carry flag (success)
	ret;								// return from function

; // file buffer initialization function
file_buffer_init:
	push af;							// save accumulator flags
	ld a, $ff;							// load file marker value (empty)
	ld (hl), a;							// store marker in buffer
	inc l;								// increment buffer pointer
	call load_file_size;				// call cluster address calculation
	ld (hl), e;							// store cluster address low byte
	inc l;								// increment pointer
	ld (hl), d;							// store cluster address high byte
	inc l;								// increment pointer
	ld b, 5;							// load loop counter (5 bytes)
	xor a;								// clear accumulator

clear_buffer_loop:
	ld (hl), a;							// clear buffer byte
	inc l;								// increment pointer
	djnz clear_buffer_loop;				// decrement B and loop if not zero
	pop af;								// restore accumulator flags
	ret;								// return from initialization

; // filename validation and checksum function
filename_validation_checksum:
	push hl;							// save filename pointer
	ld de, $40;							// load comparison buffer address
	ld bc, 9;							// load filename length (8.3 format)

checksum_compare_loop:
	ld a, (de);							// load byte from comparison buffer
	cpi;								// compare with filename and increment
	jr nz, filename_compare_finished;	// jump if no match
	inc de;								// increment comparison pointer
	jp pe, checksum_compare_loop;		// jump if more bytes to compare

filename_compare_finished:
	pop hl;								// restore filename pointer
	ret nz;								// return if filename doesn't match
	ld c, $7f;							// load checksum mask value
	xor a;								// clear accumulator for checksum

checksum_calculation_loop:
	add a, (hl);						// add filename byte to checksum
	cpi;								// increment pointer and compare
	jp pe, checksum_calculation_loop;	// loop if more bytes to process
	cp (hl);							// compare calculated checksum
	ret;								// return with comparison result

; // file position initialization function
file_position_init:
	call store_cluster_address;			// call file size validation
	call setup_file_sector;				// call cluster chain setup
	ld b, 0;							// clear 32-bit file position
	ld c, b;							// clear C register
	ld d, c;							// clear D register
	ld e, d;							// clear E register (position = 0)
	jp store_file_position;				// jump to cluster update function
	bit 0, (ix + 1);					// test file access mode bit
	ld a, 8;							// load error code (invalid access)
	scf;								// set carry flag (error condition)
	ret z;								// return error if access mode is zero
	push hl;							// save buffer pointer
	call calculate_file_size;			// call file size calculation
	pop hl;								// restore buffer pointer
	ld a, c;							// load size low byte
	or b;								// combine with high byte
	ret z;								// return if size is zero

buffer_io_function:
	res 2, (ix + 1);					// clear file modification bit

; // file I/O byte count preservation
file_io_byte_count:
	push bc;							// save byte count for loop processing

; // file position load and validation loop
file_position_load_loop:
	ld e, (ix + 15);					// load file position low byte
	ld a, (ix + 16);					// load file position byte 1
	and %00000001;						// mask to get sector offset bit
	ld d, a;							// store masked offset in D
	call position_validation_function;	// call position validation function
	jr c, file_io_error_cleanup;		// jump to error cleanup if validation failed
	push bc;							// save byte count
	push hl;							// save buffer pointer
	ld hl, $0200;						// load sector size (512 bytes)
	sbc hl, de;							// calculate remaining space in sector
	ex de, hl;							// exchange HL and DE
	ld h, b;							// load byte count high byte
	ld l, c;							// load byte count low byte
	sbc hl, de;							// subtract available space
	jr c, restore_buffer_and_process;	// jump if all bytes fit in sector
	ld b, d;							// limit to available space
	ld c, e;							// store limited byte count

restore_buffer_and_process:
	pop hl;								// restore buffer pointer
	push bc;							// save processed byte count
	call sector_io_dispatch;			// call sector I/O operation
	pop de;								// restore processed count in DE
	pop bc;								// restore original byte count
	jr c, file_io_error_cleanup;		// jump to cleanup if I/O failed
	ld a, c;							// load original count low
	sub e;								// subtract processed count
	ld c, a;							// store remaining count
	ld a, b;							// load original count high
	sbc a, d;							// subtract processed count with borrow
	ld b, a;							// store remaining count
	or c;								// check if any bytes remain
	ex de, hl;							// exchange buffer pointers
	call update_file_position;			// call buffer position update
	ex de, hl;							// restore buffer pointers
	jr nz, file_position_load_loop;		// loop if more bytes to process
	or a;								// clear carry (success)

file_io_error_cleanup:
	pop de;								// restore stack balance
	push af;							// save error flags
	ex de, hl;							// exchange pointers
	or a;								// clear carry for subtraction
	sbc hl, bc;							// calculate bytes transferred
	ld b, h;							// store transferred count
	ld c, l;							// in BC register pair
	ex de, hl;							// restore pointers
	pop af;								// restore error flags
	ret;								// return with transfer status

position_validation_function:
	or e;								// check if E register is non-zero
	ret nz;								// return if E is not zero
	push de;							// save DE register pair
	push bc;							// save BC register pair
	push hl;							// save HL register pair
	call load_file_position;			// call file position load function
	rst $30;							// call ROM calculator routine
	dec c;								// decrement C register
	call nz, process_sector_decrement;	// call function if C not zero
	pop hl;								// restore HL register pair
	pop bc;								// restore BC register pair
	pop de;								// restore DE register pair
	ret;								// return from function

; // sector I/O dispatch function
sector_io_dispatch:
	ld a, b;							// load byte count high
	sub 2;								// subtract 2 (512 bytes = 2x256)
	or c;								// combine with low byte
	jr nz, partial_sector_io;			// jump if not exactly 512 bytes
	bit 2, (ix + 1);					// test write mode bit
	jp nz, write_with_page_management;	// jump to write function if set
	bit 5, (ix + 1);					// test read mode bit
	jp nz, process_file_sector;			// jump to read function if set
	jp process_file_flags;				// jump to default I/O function

; // partial sector I/O function
partial_sector_io:
	push bc;							// save byte count
	push hl;							// save buffer pointer
	call check_sector_flags;			// call sector buffer setup
	pop de;								// restore buffer as destination
	pop bc;								// restore byte count
	ret c;								// return if setup failed
	ld l, (ix + 15);					// load file position low
	ld a, (ix + 16);					// load file position byte 2
	and %00000001;						// mask to get sector offset bit
	add a, h;							// add to buffer high address
	ld h, a;							// store masked position in H register
	bit 2, (ix + 1);					// test write mode bit
	jr nz, write_mode_handler;			// jump to write handler if set
	bit 5, (ix + 1);					// test read mode bit
	jr z, spi_interface_handler;		// jump to SPI handler if not set
	ldir;								// copy BC bytes from HL to DE
	ex de, hl;							// exchange source and destination pointers
	or a;								// clear carry flag (success)
	ret;								// return from copy operation

; // SPI interface handler function
spi_interface_handler:
	rst $30;							// call ROM calculator routine
	ld b, mmcspi;						// load MMC SPI port address
	ret;								// return from SPI handler

; // write mode handler function
write_mode_handler:
	ex de, hl;							// exchange DE and HL registers
	rst $30;							// call ROM calculator routine
	rlca;								// rotate A left circular
	jp clear_memory_buffer;				// jump to write processing routine

; // file size calculation and validation function
calculate_file_size:
	push bc;							// save BC register pair
	call load_file_position;			// call file position load function
	ld h, (ix + 12);					// load file size high byte
	ld l, (ix + 11);					// load file size low byte
	or a;								// clear carry for subtraction
	sbc hl, de;							// subtract file position from size
	ex de, hl;							// exchange result to DE
	ld h, (ix + 14);					// load file size upper high byte
	ld l, (ix + 13);					// load file size upper low byte
	sbc hl, bc;							// subtract position high from size high
	pop bc;								// restore BC register pair
	ld a, l;							// load result low byte
	or h;								// combine with high byte
	ret nz;								// return if size calculation non-zero
	ld h, d;							// copy remaining size to HL
	ld l, e;							// for comparison with requested bytes
	sbc hl, bc;							// subtract requested from available
	ret nc;								// return if enough bytes available
	ld b, d;							// limit to available bytes
	ld c, e;							// store in BC
	ret;								// return with limited byte count

; // file position update and store function
update_file_position:
	push de;							// save DE register pair
	push bc;							// save BC register pair
	call load_file_position;			// call file position load function
	call add_32bit;						// call 32-bit addition function
	call store_file_position;			// call file position store function
	pop bc;								// restore BC register pair
	pop de;								// restore DE register pair
	ret;								// return from function

; // store 32-bit file position (DEBC -> file descriptor)
store_file_position:
	ld (ix + 15), e;					// store file position byte 0 (low)
	ld (ix + 16), d;					// store file position byte 1
	ld (ix + 17), c;					// store file position byte 2
	ld (ix + 18), b;					// store file position byte 3 (high)
	ret;								// return from position store

; // load 32-bit file position (file descriptor -> DEBC)
load_file_position:
	ld e, (ix + 15);					// load file position byte 0 (low)
	ld d, (ix + 16);					// load file position byte 1
	ld c, (ix + 17);					// load file position byte 2
	ld b, (ix + 18);					// load file position byte 3 (high)
	ret;								// return with position in DEBC

; // store 32-bit file size (DEBC -> file descriptor)
store_file_size:
	ld (ix + 11), e;					// store file size byte 0 (low)
	ld (ix + 12), d;					// store file size byte 1
	ld (ix + 13), c;					// store file size byte 2
	ld (ix + 14), b;					// store file size byte 3 (high)
	ret;								// return from size store

; // load 32-bit file size (file descriptor -> DEBC)
load_file_size:
	ld e, (ix + 11);					// load file size byte 0 (low)
	ld d, (ix + 12);					// load file size byte 1
	ld c, (ix + 13);					// load file size byte 2
	ld b, (ix + 14);					// load file size byte 3 (high)
	ret;								// return with size in DEBC

; // store 32-bit cluster address (DEBC -> file descriptor)
store_cluster_address:
	ld (ix + 7), e;						// store cluster address byte 0 (low)
	ld (ix + 8), d;						// store cluster address byte 1
	ld (ix + 9), c;						// store cluster address byte 2
	ld (ix + 10), b;					// store cluster address byte 3 (high)
	ret;								// return from cluster store

; // load 32-bit cluster address (file descriptor -> DEBC)
load_cluster_address:
	ld e, (ix + 7);						// load cluster address byte 0 (low)
	ld d, (ix + 8);						// load cluster address byte 1
	ld c, (ix + 9);						// load cluster address byte 2
	ld b, (ix + 10);					// load cluster address byte 3 (high)
	ret;								// return with cluster in DEBC

; // store 32-bit directory cluster (DEBC -> file descriptor)
file_validation_function:
	ld (ix + 2), e;						// store directory cluster byte 0 (low)
	ld (ix + 3), d;						// store directory cluster byte 1
	ld (ix + 4), c;						// store directory cluster byte 2
	ld (ix + 5), b;						// store directory cluster byte 3 (high)
	ret;								// return from directory store

; // load 32-bit directory cluster (file descriptor -> DEBC)
load_directory_cluster:
	ld e, (ix + 2);						// load directory cluster byte 0 (low)
	ld d, (ix + 3);						// load directory cluster byte 1
	ld c, (ix + 4);						// load directory cluster byte 2
	ld b, (ix + 5);						// load directory cluster byte 3 (high)
	ret;								// return with directory cluster in DEBC

; // file descriptor cleanup and validation function
descriptor_cleanup_validation:
	push bc;							// save BC register pair
	push de;							// save DE register pair
	ld hl, $2420;						// load file descriptor table address
	ld b, $0f;							// load loop counter (15 descriptors)

descriptor_table_scan:
	ld a, (hl);							// load descriptor status byte
	and a;								// test if descriptor is active
	jr z, descriptor_inactive;			// jump if descriptor is inactive
	ld a, ixh;							// load current descriptor high byte
	cp h;								// compare with table entry high
	jr nz, descriptor_next;				// jump if different descriptor
	ld a, ixl;							// load current descriptor low byte
	cp l;								// compare with table entry low
	jr z, descriptor_inactive;			// jump if same descriptor (skip cleanup)

descriptor_next:
	call descriptor_validation_comparison;	// call descriptor validation function

descriptor_inactive:
	ld de, $20;							// load descriptor size (32 bytes)
	add hl, de;							// advance to next descriptor
	djnz descriptor_table_scan;			// decrement counter and loop
	pop de;								// restore DE register pair
	pop bc;								// restore BC register pair
	or a;								// clear carry flag (success)
	ret;								// return from cleanup function

; // file descriptor validation and comparison function
descriptor_validation_comparison:
	ld a, (hl);							// load descriptor status byte
	cp (ix + 00);						// compare with current descriptor status
	ret nz;								// return if status doesn't match
	push hl;							// save descriptor pointer
	ld a, 6;							// load offset to drive number
	add a, l;							// add to pointer low byte
	ld l, a;							// store updated pointer
	ld a, (hl);							// load drive number from descriptor
	cp (ix + 6);						// compare with current drive number
	pop hl;								// restore descriptor pointer
	ret nz;								// return if drive doesn't match
	push bc;							// save BC register pair
	push hl;							// save descriptor pointer
	ld a, 5;							// load offset to comparison data
	add a, l;							// add to pointer
	ld l, a;							// store updated pointer
	call load_directory_cluster;		// call directory cluster load
	call compare_32bit;					// call cluster comparison function
	call z, restart_28;					// call restart if clusters match
	pop hl;								// restore descriptor pointer
	pop bc;								// restore BC register pair
	ret;								// return from validation

	pop hl;								// restore stack balance
	pop hl;								// restore stack balance
	pop hl;								// restore stack balance
	pop hl;								// restore stack balance
	pop de;								// restore DE register pair
	pop bc;								// restore BC register pair
	scf;								// set carry flag (error condition)
	ret;								// return with error

	dec l;								// decrement pointer to status field
	dec l;								// decrement pointer further
	dec l;								// position at file flags
	res 4, (hl);						// clear bit 4 (file closed flag)
	ld a, $0a;							// load offset to size field (10)
	add a, l;							// add to pointer
	ld l, a;							// store updated pointer
	call load_file_size;				// call file size load function
	jp store_32bit;						// jump to completion routine
	dec l;								// decrement pointer to status field
	dec l;								// decrement pointer further
	dec l;								// position at file flags
	set 4, (hl);						// set bit 4 (file active flag)
	res 3, (hl);						// clear bit 3 (directory flag)
	ld a, 6;							// load offset to drive field (6)
	add a, l;							// add to pointer
	ld l, a;							// store updated pointer
	ex de, hl;							// exchange DE and HL
	push ix;							// save IX register
	pop hl;								// load IX into HL
	ld a, 7;							// load offset to data area (7)
	add a, l;							// add to pointer
	ld l, a;							// store updated pointer
	ld bc, 21;							// load data length (21 bytes)
	ldir;								// copy data from source to destination
	ret;								// return from data copy

	dec d;								// decrement D register (address high byte)
	dec h;								// decrement H register (pointer high byte)
	ret;								// return from function

	ld a, (de);							// load byte from DE address
	and e;								// mask with E register
	ld a, (de);							// load byte from DE address again
	and c;								// mask with C register
	ld a, (de);							// load byte from DE address third time
	nop;								// no operation (padding)
	nop;								// no operation (padding)
	rrca;								// rotate A right circular
	dec h;								// decrement H register
	or a;								// set flags based on A register
	ret;								// return from function

	call block_size_calc_scaling;		// call block size calculation
	ld a, ixl;							// load RAM page number
	out (mmcram), a;					// Set divMMC RAM page...
	ld a, ($3df8);						// load saved page number
	ld ixh, a;							// store in IXH for later
	xor a;								// clear accumulator
	out (mmcram), a;					// divMMC RAM page 0
	call file_seek_preparation;			// call file seek function
	ret c;								// return if seek failed
	ld e, (iy + _newppc);				// load file handle
	ld a, ixl;							// load RAM page number
	out (mmcram), a;					// Set divMMC RAM page...
	ld a, e;							// load file handle
	push de;							// save DE register pair
	rst $08;							// call esxDOS API
	defb f_write;						// write to file
	pop de;								// restore DE register pair
	push af;							// save write result flags
	ld a, e;							// load file handle
	rst $08;							// call esxDOS API
	defb f_sync;						// synchronize file (flush buffers)
	pop af;								// restore write result flags
	jr file_io_result_handler;			// jump to result handling
	call block_size_calc_scaling;		// call block size calculation
	ld a, ixl;							// load RAM page number
	out (mmcram), a;					// Set divMMC RAM page...
	ld a, ($3df8);						// load saved page number
	ld ixh, a;							// store in IXH for later
	xor a;								// clear accumulator
	out (mmcram), a;					// divMMC RAM page 0
	call file_seek_preparation;			// call file seek function
	ret c;								// return if seek failed
	ld e, (iy + _newppc);				// load file handle
	ld a, ixl;							// load RAM page number
	out (mmcram), a;					// Set divMMC RAM page...
	ld a, e;							// load file handle
	rst $08;							// call esxDOS API
	defb f_read;						// read from file

; // file I/O result handling function
file_io_result_handler:
	ld iyl, a;							// store result code in IYL

; // restore divMMC page and return result
restore_divmmc_page_and_return:
	ld a, ixh;							// load saved page number
	ld ($3df8), a;						// restore saved page variable
	ld a, 0;							// clear accumulator
	out (mmcram), a;					// divMMC RAM page 0
	ld a, iyl;							// load result code
	ret;								// return with result

; // file seek preparation function
file_seek_preparation:
	ld a, (iy + _newppc);				// load file handle
	push hl;							// save HL register
	ld l, 0;							// clear L (seek mode = absolute)
	rst $08;							// call esxDOS API
	defb f_seek;						// seek to file position
	pop hl;								// restore HL register
	ret c;								// return if seek failed
	push hl;							// save HL register
	ld hl, $80;							// load base block size (128 bytes)
	ld a, (iy + _flags);				// load file flags
	and %00000111;						// mask to get block size bits
	dec a;								// decrement (0 = 128 bytes)
	jr z, store_block_size;				// jump if 128 byte blocks

block_size_calculation_loop:
	add hl, hl;							// double the block size (left shift)
	dec a;								// decrement size counter
	jr nz, block_size_calculation_loop;	// loop until correct block size

store_block_size:
	ld b, h;							// store block size high byte
	ld c, l;							// store block size low byte
	pop hl;								// restore HL register
	or a;								// clear carry flag (success)
	ret;								// return with block size in BC

; // block size calculation with sector scaling
block_size_calc_scaling:
	call sector_scaling_function;		// call sector-based scaling function
	ld a, (iy + _flags);				// load file flags
	and %00000111;						// mask to get block size bits
	dec a;								// decrement (0 = base size)
	ret z;								// return if base size (128 bytes)

scaling_shift_loop:
	sla e;								// shift E left (multiply by 2)
	rl d;								// rotate D left with carry
	rl c;								// rotate C left with carry
	rl b;								// rotate B left with carry (32-bit left shift)
	dec a;								// decrement scaling counter
	jr nz, scaling_shift_loop;			// loop until scaling complete
	ret;								// return with scaled value

; // sector-based scaling function (multiply by 128)
sector_scaling_function:
	ld a, 7;							// load shift count (2^7 = 128)

sector_shift_loop:
	sla e;								// shift E left (multiply by 2)
	rl d;								// rotate D left with carry
	rl c;								// rotate C left with carry
	rl b;								// rotate B left with carry (32-bit left shift)
	dec a;								// decrement shift counter
	jr nz, sector_shift_loop;			// loop until 7 shifts complete
	ret;								// return with value multiplied by 128

;;; 13_boot_data.asm

	org $1b37
copyright:
	defb "UnoDOS 3.141 (Ram)       ", $0d, $0d;
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
	ld hl, 22862;						// load ZX Spectrum attribute area start address ($5946)
	ld de, 28;							// load row offset for attribute area (32-4 = 28)
	ld b, 4;							// set outer loop counter (4 rows)

;		org $1b72
; // outer loop - process 4 rows of attributes
outer_loop:
	ld a, 4;							// set inner loop counter (4 columns)

;		org $1b74
; // inner loop - process 4 attribute cells per row
inner_loop:
	ld (hl), %01000111;					// bright white
	inc hl;								// advance to next attribute cell
	dec a;								// decrement column counter
	jr nz, inner_loop;					// do four cells
	add hl, de;							// move to start of next row (skip remaining cells)
	djnz outer_loop;					// do four rows
	ret;								// return from attribute setting function

;	org $1b7e
boot_icon:

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

;;; 14_spi.asm

spi_data_table_entry:
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
	call sd_card_command_setup;			// execute SD card command
	ret c;								// return if error
	call clear_bc_pair;					// process command result
	ld a, (iy + _err_nr);				// get error status
	ret;								// return to caller

check_card_type_flag:
	and %00001000;						// check bit 3 (card type flag)
	ld a, $f6;							// default SPI command value
	jr z, store_spi_command;			// if bit 3 clear, use default
	dec a;								// adjust for different card type

store_spi_command:
	ld ($3dfe), a;						// store SPI command value
	ret;								// return to caller

sd_card_command_setup:
	ld ($3df2), de;						// save DE parameter
	ld ($3dfa), a;						// save command
	call check_card_type_flag;			// prepare SPI interface
	call deselect_all_cards;			// send command to SD card
	ret c;								// return if error
	call send_interface_condition;		// process response
	ret c;								// return if error
	ld hl, $3e00;						// data buffer address
	ld a, $49;							// command code
	call send_sd_command;				// execute command
	ret c;								// return if error
	ld hl, $3e20;						// next buffer address
	ld a, $4a;							// next command code
	call send_sd_command;				// execute command
	ret c;								// return if error
	ld a, ($3dfa);						// get stored command
	call final_utility_call;			// execute SPI command
	ld a, $7a;							// set command code
	ld de, 0;							// clear DE register
	call send_command_get_response;		// call SPI routine
	ret c;								// return if error
	ld a, b;							// get B register value
	and %01000000;						// test bit 6 (card type flag)
	or %00000011;						// set lower 2 bits
	ld (iy + _flags), a;				// store in flags register
	and %01000000;						// check bit 6 (initialization flag?)
	call z, sd_card_init_command;		// if clear, initialize SD card
	ld hl, $3e05;						// point to SPI data
	call get_flags_again;				// send SPI command
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

sd_card_init_command:
	ld a, $50;							// SD card initialization command
	ld de, $0200;						// timeout values
	ld b, e;							// copy E to B
	ld c, e;							// copy E to C
	jr send_spi_command;				// jump to initialization routine

send_interface_condition:
	ld a, $48;							// CMD8 - send interface condition
	ld de, $01aa;						// voltage range and check pattern
	call send_command_get_response;		// send SD command
	ld hl, $1d65;						// address for SDHC cards
	jr c, set_retry_counter;			// if error, try SDHC
	ld hl, $1d20;						// address for standard SD cards

set_retry_counter:
	ld bc, $78;							// retry counter (120 attempts)

retry_loop_start:
	push bc;							// save retry counter
	call jump_card_specific_init;		// call initialization routine
	pop bc;								// restore retry counter
	ret nc;								// return if successful
	djnz retry_loop_start;				// decrement B and retry
	dec c;								// decrement C counter
	jr nz, retry_loop_start;			// retry if C not zero
	scf;								// set carry flag (error)
	ret;								// return with error

	ld a, $77;							// CMD55 - application specific command
	call clear_bc_argument;				// send SD command
	ld a, $69;							// ACMD41 - SD send operating condition
	ld bc, $4000;						// HCS bit set (supports SDHC)
	ld d, c;							// clear D
	ld e, c;							// clear E
	jr send_spi_command;				// send command

jump_card_specific_init:
	jp (hl);							// jump to card-specific initialization

send_sd_command:
	call clear_bc_argument;				// send command to SD card
	ret c;								// return if error occurred
	call set_retry_count_10;			// wait for FE response token
	ret c;								// return if timeout or error
	ld b, $12;							// set byte count to 18 bytes
	ld c, mmcspi;						// set port address for SPI
	inir;								// Read 12 bytes from divMMC SPI port into (HL)
	or a;								// clear carry flag (success)
	jr save_accumulator;				// deselect SD card and return

deselect_all_cards:
	call save_accumulator;				// deselect all SD cards
	ld b, $0a;							// set loop counter to 10

load_dummy_byte:
	ld a, $ff;							// load FF (dummy byte)
	out (mmcspi), a;					// Write FF to divMMC SPI port
	djnz load_dummy_byte;				// repeat 10 times
	call save_acc_select_card;			// select SD card
	ld b, 8;							// set retry counter to 8

cmd0_go_idle:
	ld a, $40;							// CMD0 - GO_IDLE_STATE command
	ld de, 0;							// clear argument (32-bit = 0)
	push bc;							// save retry counter
	call clear_bc_high_word;			// send command and get response
	pop bc;								// restore retry counter
	ret nc;								// return if command successful
	djnz cmd0_go_idle;					// retry if attempts remaining
	scf;								// set carry flag (error)

save_accumulator:
	push af;							// save accumulator
	ld a, $ff;							// deselect value (all bits high)
	out (mmcdev), a;					// Select all available SD cards
	pop af;								// restore accumulator
	ret;								// return to caller

	ld a, $41;							// CMD1 - SEND_OP_COND command

clear_bc_argument:
	ld bc, 0;							// clear BC (argument high word)
	ld d, b;							// clear D (argument byte 1)
	ld e, c;							// clear E (argument byte 0)

send_spi_command:
	call select_sd_card;				// send SPI command
	or a;								// test response (zero = success)
	ret z;								// return if successful

set_error_flag:
	scf;								// set carry flag (error)
	jr save_accumulator;				// deselect card and return

clear_bc_high_word:
	ld bc, 0;							// clear BC (argument high word)
	call select_sd_card;				// send SPI command
	ld b, a;							// save response in B
	and %11111110;						// mask out bit 0 (ignore busy bit)
	ld a, b;							// restore full response
	jr nz, set_error_flag;				// jump to error if bad response
	ret;								// return (carry clear = success)

send_command_get_response:
	call clear_bc_high_word;			// send command and get basic response
	ret c;								// return if command failed
	push af;							// save command response
	call set_poll_retries;				// poll the SPI port for a non FFh value
;										// to be returned. Result returned in A.
	ld h, a;							// store first data byte in H
	call set_poll_retries;				// poll the SPI port for a non FFh value
;										// to be returned. Result returned in A.
	ld l, a;							// store second data byte in L
	call set_poll_retries;				// poll the SPI port for a non FFh value
;										// to be returned. Result returned in A.
	ld d, a;							// store third data byte in D
	call set_poll_retries;				// poll the SPI port for a non FFh value
;										// to be returned. Result returned in A.
	ld e, a;							// store fourth data byte in E
	ld b, h;							// copy H to B (return data)
	ld c, l;							// copy L to C (return data)
	pop af;								// restore command response
	ret;								// return to caller

select_sd_card:
	call save_acc_select_card;			// select SD card
	out (mmcspi), a;					// write to divMMC SPI port
	push af;							// save command byte
	ld a, b;							// get argument byte 3
	nop;								// timing delay
	out (mmcspi), a;					// write to divMMC SPI port
	ld a, c;							// get argument byte 2
	nop;								// timing delay
	out (mmcspi), a;					// write to divMMC SPI port
	ld a, d;							// get argument byte 1
	nop;								// timing delay
	out (mmcspi), a;					// write to divMMC SPI port
	ld a, e;							// get argument byte 0
	nop;								// timing delay
	out (mmcspi), a;					// write to divMMC SPI port
	pop af;								// restore command byte
	cp '@';								// $40
	ld b, $95;							// CRC for CMD0
	jr z, get_crc_byte;					// jump if CMD0
	cp 'H';								// $48
	ld b, $87;							// CRC for CMD8
	jr z, get_crc_byte;					// jump if CMD8
	ld b, $ff;							// default CRC (dummy)

get_crc_byte:
	ld a, b;							// get CRC byte
	out (mmcspi), a;					// write to divMMC SPI port
	jr set_poll_retries;				// poll the SPI port for a non $FF value

set_retry_count_10:
	ld b, $0a;							// set retry counter to 10

save_retry_counter:
	push bc;							// save retry counter
	call set_poll_retries;				// poll the SPI port for a non FFh value
;										// to be returned. Result returned in A.
	pop bc;								// restore retry counter
	cp $fe;								// was the return code FE?
	ret z;								// return if so
	djnz save_retry_counter;			// retry if attempts remaining
	scf;								// set carry flag (timeout)
	ret;								// return with error

;	// Poll the SPI port up to 255*50 times, waiting for a non-FFh value to be returned
;	// Return results in A;
set_poll_retries:
	ld bc, $32;							// number of retries (C)=50*255 (12750)

read_spi_port:
	in a, (mmcspi);						// read divMMC SPI port
	cp $ff;								// did I read FFh?
	ret nz;								// RET if not FFh
	djnz read_spi_port;					// decrement B and loop back if B is not 0
	dec c;								// decrement C
	jr nz, read_spi_port;				// if C is not 0 , loop back
	ret;								// return after 50 lots of 255 attempts

save_acc_select_card:
	push af;							// save accumulator
	in a, (mmcspi);						// read divMMC SPI port
	ld a, ($3dfe);						// get SD card select value
	out (mmcdev), a;					// select SD card(s)
	pop af;								// restore accumulator
	ret;								// return to caller

	ld a, (iy + _flags);				// get system flags
	and %01000000;						// test bit 6 (some specific flag)
	call z, shift_register_setup;		// call routine if flag clear
	ld a, (iy + _err_nr);				// get error number
	ld ixh, a;							// save error in IXH
	ld a, ixl;							// get divMMC page from IXL
	out (mmcram), a;					// Set divMMC ram page...
	ld a, ixh;							// restore error number
	call check_card_type_flag;			// call error handling routine
	ld a, $58;							// CMD24 - WRITE_BLOCK command
	call send_spi_command;				// send command to SD card
	ld a, 6;							// error code 6 (write error)
	jr c, restore_cpu_interrupt;		// jump to error handler if failed
	ld a, $fe;							// start block token
	out (mmcspi), a;					// write FE to divMMC SPI port
	ld bc, $eb;							// set count for 512 bytes (2x235)
	otir;								// output 235 bytes from (HL) to SPI
	otir;								// output 235 bytes from (HL) to SPI  
	ld a, $ff;							// dummy CRC byte
	out (mmcspi), a;					// write FF to divMMC SPI port
	nop;								// timing delay
	out (mmcspi), a;					// write FF to divMMC SPI port
	call set_poll_retries;				// poll the SPI port for a non FFh value
;										// to be returned. Result returned in A.
	and $1f;							// mask response bits (keep lower 5 bits)
	cp 5;								// check if response is 5 (data accepted)
	ld a, 6;							// error code 6 (write error)
	scf;								// set carry flag (error)
	jr nz, restore_cpu_interrupt;		// jump to error if not accepted

	org $1E2A
poll_spi_non_ff:
	call set_poll_retries;				// poll the SPI port for a non FFh value
	;									// to be returned. Result returned in A.
	or a;								// test if zero
	jr z, poll_spi_non_ff;				// loop if zero

restore_cpu_interrupt:
	call save_accumulator;				// this routine probably sets normal CPU / interrupt
	ld b, a;							// save value of A
	xor a;								// LD A, 0
	out (mmcram), a;					// divMMC RAM page 0
	ld a, b;							// restore value of A
	ret;								// and exit

;	org $1e39
; // NOTE: this is AY PSG register data for the boot chime (belongs logically
; // with boot_chime in 13_boot_data but is fixed here by ROM address constraints)
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
get_system_flags:
	ld a, (iy + _flags);				// get system flags
	and %01000000;						// test bit 6 (some specific flag)
	call z, shift_register_setup;		// call routine if flag clear
	ld a, (iy + _err_nr);				// get error number
	ld ixh, a;							// save error in IXH
	ld a, ixl;							// get divMMC page from IXL
	out (mmcram), a;					// Set divMMC RAM page...
	ld a, ixh;							// restore error number
	call check_card_type_flag;			// call error handling routine
	ld a, $51;							// CMD17 - READ_SINGLE_BLOCK command
	call send_spi_command;				// send command to SD card
	jr nc, wait_for_fe_token;			// jump to read data if successful

	org $1e71
read_error_code_6:
	ld a, 6;							// error code 6 (read error)
	jr restore_cpu_interrupt;			// jump to error handler

wait_for_fe_token:
	call set_retry_count_10;			// wait for FE response token
	jr c, read_error_code_6;			// jump to error if timeout
	ld bc, $eb;							// set count for 512 bytes (2x235)
	inir;								// read ?255? bytes from divMMC SPI port to (HL)
	inir;								// read ?255? bytes from divMMC SPI port to (HL)
	nop;								// timing delay
	in a, (mmcspi);						// read divMMC SPI port
	nop;								// timing delay
	in a, (mmcspi);						// read divMMC SPI port
	or a;								// clear carry flag (success)
	jr restore_cpu_interrupt;			// jump to completion

final_utility_call:
	call check_handle_limit;							// call utility routine
	ld hl, spi_data_table_entry;		// load address of routine
	ld (iy + _tv_flag), l;				// store low byte in TV flag
	ld (iy + _err_sp), h;				// store high byte in error SP
	ret;								// return to caller

shift_register_setup:
	ld b, c;							// shift register arrangement
	ld c, d;							// move D to C
	ld d, e;							// move E to D  
	ld e, 0;							// clear E register

shift_d_left:
	sla d;								// shift D left (arithmetic)
	rl c;								// rotate C left through carry
	rl b;								// rotate B left through carry
	ret;								// return to caller

get_flags_again:
	ld a, (iy + _flags);				// get system flags
	and %01000000;						// test bit 6 (specific flag)
	jr z, load_byte_from_hl;			// jump if flag clear
	inc hl;								// increment HL pointer
	inc hl;								// increment HL pointer again
	ld a, (hl);							// load value from address HL
	and %00111111;						// mask upper 2 bits (keep lower 6)
	ld c, a;							// store masked value in C
	inc hl;								// advance pointer
	ld d, (hl);							// load next byte into D
	inc hl;								// advance pointer
	ld e, (hl);							// load next byte into E
	call inc_32bit;						// call utility function
	call shift_register_setup;			// call register shift routine
	jr shift_d_left;					// jump to shift left routine

load_byte_from_hl:
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
	call shift_e_left;					// call bit shifting routine
	ld e, d;							// move D to E
	ld d, c;							// move C to D
	ld c, b;							// move B to C
	ld b, 0;							// clear B register
	srl c;								// shift C right logical
	rr d;								// rotate D right through carry
	rr e;								// rotate E right through carry
	ret;								// return to caller

shift_e_left:
	sla e;								// shift E left arithmetic
	rl d;								// rotate D left through carry
	rl c;								// rotate C left through carry
	rl b;								// rotate B left through carry
	dec a;								// decrement counter
	jr nz, shift_e_left;				// loop if counter not zero
	ret;								// return to caller

clear_bc_pair:
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

load_byte_hl:
	ld a, (hl);							// load byte from address HL
	and %01111111;						// mask upper bit (clear bit 7)
	inc hl;								// increment HL pointer
	inc hl;								// increment HL pointer
	inc hl;								// increment HL pointer
	inc hl;								// increment HL pointer
	jr nz, copy_b_to_a;					// jump if not zero
	or (hl);							// OR A with value at HL
	jr z, copy_b_to_a;					// jump if zero
	inc (iy + _err_nr);					// increment error number

copy_b_to_a:
	ld a, b;							// copy B to A (preserve counter)
	ld bc, 4;							// set BC to 4 bytes to skip
	add hl, bc;							// add offset to HL
	ld c, 8;							// set byte count to 8
	ldir;								// copy 8 bytes from (HL) to (DE)
	ld b, a;							// restore counter
	djnz load_byte_hl;					// loop if counter not zero
	ret;								// return to caller

;;; 15_sebasic.asm

;	org $1f3f
file_test:
	ld hl, msg_ok;						// point to OK message
	jp nc, print_result_msg;			// jump if no error, display OK message
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
	call select_basic_rom;				// restore ROM 1 (48K BASIC)
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
	call select_basic_rom;				// restore ROM 1 (48K BASIC)
	ld hl, msg_failed;					// point to failure message
	jp pr_str;							// display error message and exit

;	org $1f87
get_rom_byte:
	ld a, ($3200);						// read byte at $3200 in current ROM
	ret;								// return with byte in A register

;;; 16_unmap.asm

;	// vector table for 'dot' commands
	org $1FCA
	jp error_code_4;					// V24F2 - vector to system function
	org $1FCD
	jp error_code_2;					// V24E6 - vector to system function
	org $1FD0
	jp pr_str;							// v_pr_str - print string routine (05_api.asm)
	org $1FD3
	jp format_decimal_10k;				// V0861 - numeric display routine (05_api.asm)
	org $1FD6
	jp format_file_size;				// V089A - file size display routine (05_api.asm)
	org $1FD9
	jp open_screen_channel;				// V0DEB - screen channel open (08_memory.asm)
	org $1FDC
	jp call_expression_eval;			// V2488 - vector to system function
	org $1FDF
	jp save_accumulator_flag;			// V24A6 - vector to system function
	org $1FE2
	jp call_rom_routine_c1;				// V24C1 - vector to system function
	org $1FE5
	jp error_handler_setup;				// V24CD - vector to system function
	org $1FE8
	jp load_file_state_flag;			// V24F5 - vector to system function
	org $1FEB
	jp load_file_state_again;			// V2502 - vector to system function
	org $1FEE
	jp pr_msg;							// v_pr_msg - message print routine (07_error.asm)
	org $1FF1
	jp delay_routine;					// V0297 - vector to system function

	org $1ff4
interrupt_cleanup_exit:
	ex (sp), hl;						// exchange HL with top of stack
	jr unmap_and_return;				// jump to unmap routine
	ei;									// enable interrupts

;	// A jump to 1FF8 - 1FFF unmaps divMMC ROM/RAM when M1 goes high
direct_unmap_return:
	ret;								// return (causes divMMC unmap on M1)

	ei;									// enable interrupts

;	// Jump from RST $18 handler to return to a system ROM routine whose address has 
;	// been placed in the stack
;	// Also called from taps.io
unmap_and_return:
	ret;								// return to ROM routine (unmaps divMMC)

jump_unmap_hl:
	jp (hl);							// jump to address in HL (with divMMC unmapped)
	rst $38;							// mask interrupt (filler)
	rst $38;							// mask interrupt (filler)
	rst $38;							// mask interrupt (filler)
	rst $38;							// mask interrupt (filler)

;;; 17_basic.asm

;	// UNODOS.SYS starts here
	org $2000
system_entry:
	call process_command_preserve;		// initialize UnoDOS system
	ret c;								// return if initialization failed
	jp $2800;							// jump to BASIC extension entry point

system_reinit:
	call process_command_preserve;		// re-initialize system
	ret c;								// return if failed
	jp $28be;							// jump to secondary entry point

basic_command_entry:
	jp $29af;							// jump to BASIC command processor

jump_basic_handler:
	jp $294b;							// jump to BASIC statement handler

cleanup_routine:
	jp store_char_processing;			// jump to cleanup routine
	nop;								// padding

cached_compare_addr equ $2019

	jr z, cached_compare_addr;			// jump if condition met
	rst $38;							// call RST $38 (error handler)

	org $201e
nmi_status_handler:
	jr save_stack_pointer;				// jump to main initialization
	ld hl, 0;							// clear HL register
	add hl, sp;							// get current stack pointer
	ld h, a;							// save A in H
	ld a, l;							// get low byte of stack
	cp $0A;								// check stack boundary
	jr z, restore_a_register;			// jump if at boundary
	pop bc;								// restore BC from stack

restore_a_register:
	ld a, h;							// restore A register
	jp unmap_and_return;				// unmap divMMC and return

save_stack_pointer:
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
	call printer_buffer_start;			// call system initialization
	pop bc;								// restore registers
	ld a, b;							// get B register
	ld ($2E7A), a;						// save system status
	ld a, $0f;							// set completion flag
	ld ($201F), a;						// store flag
	pop bc;								// restore registers
	pop de;								// restore DE register
	pop hl;								// restore HL register
	jr nz, set_system_stack;			// if not zero, continue
	ld sp, ($2E61);						// restore original stack pointer
	pop af;								// restore AF register
	ld ($2E61), sp;						// save original stack pointer again

set_system_stack:
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
	call load_page_offset;				// call ROM paging routine
	ld a, ($5800);						// get screen attribute
	rrca;								// rotate right
	rrca;								// rotate right to get next color bit
	rrca;								// extract color bits
	and 7;								// mask to get color value
	ld ($2e64), a;						// save border color
	call point_interrupt_table;			// call hardware initialization
	ld a, 1;							// set interrupt mode
	ei;									// enable interrupts
	halt;								// wait for interrupt
	ld ($2e63), a;						// save interrupt flag
	im 1;								// set interrupt mode 1
	call point_register_save;			// call system setup
	call ram_source_address;			// call additional setup
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
	jr nz, get_rom_status;				// jump if not mode 2
	inc hl;								// advance pointer
	inc hl;								// advance to next address
	ld ($2E61), hl;						// update stack pointer

get_rom_status:
	ld a, ($3DF8);						// get ROM status
	ld ($2E79), a;						// save ROM status
	ld hl, $2e4a;						// point to system data
	call $2f00;							// call BASIC handler
	ld a, ($2E79);						// restore ROM status
	ld ($3df8), a;						// update ROM status
	ld a, ($2e68);						// get system mode
	cp 2;								// check for mode 2
	jr nz, set_rom_page;				// jump if not mode 2
	ld hl, ($2e61);						// get stack pointer
	dec hl;								// adjust stack
	dec hl;								// adjust stack pointer
	ld ($2e61), hl;						// save adjusted stack

set_rom_page:
	ld a, $f5;							// set ROM page
	call load_page_offset;				// call ROM paging routine
	im 1;								// set interrupt mode 1
	ei;									// enable interrupts
	halt;								// wait for interrupt
	di;									// interrupts off
	ld a, ($2e67);						// get memory page
	ld bc, $7ffd;						// 128 paging register
	out (c), a;							// set memory page
	ld hl, $2e69;						// point to system variables
	call setup_10_registers;			// call system variable handler
	ld a, ($2e5d);						// get system flags
	bit 2, a;							// test bit 2
	ld hl, $86;							// set default value
	jr nz, save_hl_system;				// jump if bit set
	inc hl;								// increment value
	ld a, ($2e5e);						// get counter
	inc a;								// increment counter
	ld ($2e5e), a;						// save counter

save_hl_system:
	ld ($213e), hl;						// save HL at system location
	ld hl, $2e64;						// point to border color
	ld a, (hl);							// get border color value
	out (ula), a;						// set ULA border color
	dec hl;								// move to interrupt mode setting
	ld a, (hl);							// get interrupt mode
	im 0;								// set interrupt mode 0
	or a;								// test interrupt mode value
	jr z, point_interrupt_reg;			// jump if mode 0
	im 1;								// set interrupt mode 1
	dec a;								// decrement mode counter
	jr z, point_interrupt_reg;			// jump if mode 1
	im 2;								// set interrupt mode 2

point_interrupt_reg:
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
point_interrupt_table:
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
point_register_save:
	ld hl, $2e69;						// point to register save area
	ld de, restart_10;					// 10 registers to read

ay_register_port:
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
	jr nz, ay_register_port;			// loop until done
	ret;								// return

// AY sound chip register writing routine
setup_10_registers:
	ld de, restart_10;					// 10 registers to write

ay_port_setup:
	ld bc, $fffd;						// AY register port
	out (c), d;							// select register
	ld b, $bf;							// AY data port
	ld a, (hl);							// get value to write
	out (c), a;							// write to register
	inc hl;								// next value
	inc d;								// next register
	dec e;								// decrement counter
	jr nz, ay_port_setup;				// loop until done
	ret;								// return

// Memory copying and system initialization routine
ram_source_address:
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

save_current_page:
	push af;							// save current page number
	exx;								// switch to alternate registers
	ld bc, $7ffd;						// 128K memory paging port
	out (c), a;							// select memory page
	exx;								// switch back to main registers
	ld de, $c000;						// point to high memory area
	ld hl, $1c58;						// point to comparison data
	ld b, 6								// compare 6 bytes

get_byte_from_page:
	ld a, (de);							// get byte from current memory page
	cp (hl);							// compare with expected value
	jr nz, cleanup_stack;				// jump if no match found
	inc de;								// advance memory pointer
	inc hl;								// advance comparison pointer
	djnz get_byte_from_page;			// continue byte comparison
	inc c;								// increment valid page counter
	pop af;								// restore page number
	ld ($2e67), a;						// save current page number

next_page_increment:
	inc a;								// move to next page
	ld b, a;							// save incremented page number
	and 7;								// mask to keep only page bits (0-7)
	ld a, b;							// restore full page number
	jr nz, save_current_page;			// jump back if not at page boundary
	ld a, ($2e67);						// load saved page number
	exx;								// switch to alternate register set
	out (c), a;							// output page to memory control port
	exx;								// switch back to main register set
	ld a, c;							// load page count to accumulator
	pop bc;								// restore byte count
	pop de;								// restore destination address
	pop hl;								// restore source address
	ldir;								// block copy memory
	jr test_accumulator;				// jump to completion

cleanup_stack:
	pop af;								// clean up stack (page number)
	jr next_page_increment;				// retry next page
	jr test_accumulator;				// jump to completion

test_accumulator:
	and a;								// test accumulator flags
	ret z;								// return if zero (no valid pages found)
	inc a;								// increment page count
	and 7;								// mask to page boundary (0-7)
	ld ($2e68), a;						// store final page count
	ret;								// return with page count

load_page_offset:
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
printer_buffer_start:
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
	call jump_unmap_hl;					// call processing function
	ld sp, ($3e10);						// restore original stack pointer
	ld hl, $3e00;						// temporary storage location
	ld de, $5b00;						// ZX printer buffer destination
	ld bc, $0e;							// 14 bytes to restore
	ldir;								// restore original printer buffer
	cp $af;								// compare result with CODE token
	push af;							// save comparison result
	ld a, $10;							// load value 16
	jr z, store_result_flag;			// jump if CODE token matched
	ld a, 0;							// otherwise load zero

store_result_flag:
	ld ($2E67), a;						// store result flag
	pop af;								// restore comparison result
	ret;								// return

; Function: UnoDOS system call handler
load_syscall_number:
	ld a, ($0001);						// load system call number
	jp $3DFD;							// jump to UnoDOS handler

; Function: Initialize message printer 
clear_message_offset:
	ld de, 0;							// clear message offset
	ld hl, $2d4e;						// load message table address
	call load_char_from_msg;			// call message printer
	jp unmap_and_return;				// jump to completion handler

; Function: BASIC calculator operations
enter_calculator:
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
load_char_from_msg:
	ld a, (de);							// load character from message
	inc de;								// advance message pointer
	and a;								// test for null terminator
	jr nz, check_carriage_return;		// jump if not null
	ex de, hl;							// swap pointers
	jr load_char_from_msg;				// continue with new pointer

check_carriage_return:
	cp $0D;								// check for carriage return
	ret z;								// return if carriage return
	cp 1;								// check for special code 1
	call z, load_char_attribute;		// handle special code if found
	call save_hl_register;				// print character
	jr load_char_from_msg;				// continue printing

; Function: Handle special code 1 (attribute/graphics handling)
load_char_attribute:
	ld a, ($2e31);						// load character attribute
	cp '*';								// compare with asterisk ($2a)
	ret z;								// return if asterisk
	push af;							// save attribute value
	and $F8;							// mask upper 5 bits (ink/paper)
	srl a;								// shift right
	srl a;								// shift right  
	srl a;								// shift right (divide by 8)
	or $60;								// OR with base graphics code
	call save_hl_register;				// print graphics character
	ld a, $64;							// load separator character 'd'
	call save_hl_register;				// print separator
	pop af;								// restore character value
	and 7;								// extract lower 3 bits (0-7)
	add a, $30;							// convert to ASCII digit (0-7)
	or a;								// set flags
	ret;								// return

; Function: Print character preserving registers
save_hl_register:
	push hl;							// save HL register
	push de;							// save DE register
	rst $18;							// call ROM routine
	defw add_char;						// add character to display
	pop de;								// restore DE register
	pop hl;								// restore HL register
	ret;								// return

; Function: Error code handler and system boundary checks  
error_code_handler:
	cp $FF;								// check for error code $FF
	jp z, full_init;					// jump to error handler if found
	cp $FE;								// check for error code $FE
	jp z, exit_to_basic;				// jump to error handler if found
	cp $FC;								// check for boundary code $FC
	jr c, load_message_pointer;			// jump to normal handler if less
	ld de, $225c;						// load error message pointer
	jr z, load_system_status;			// jump if equal to $FC
	ld de, $2250;						// load alternate message pointer

load_system_status:
	ld a, ($3d00);						// load system status flag
	and a;								// test flag
	jr nz, set_border_white;			// jump if flag set
	ld a, $1c;							// load error code $1C
	scf;								// set carry flag (error)
	ret;								// return with error

set_border_white:
	ld a, 7;							// set border to white
	out (ula), a;						// output to ULA border register
	jr store_message_pointer;			// jump to completion

load_message_pointer:
	ld de, $2246;						// load standard message pointer
	ld ($2e31), a;						// store status code
	and a;								// test status
	jr z, store_message_pointer;		// jump to completion if zero
	ld de, $2d4e;						// load message table address
	rst $30;							// call ROM routine
	inc b;								// increment B register
	ld de, $224a;						// load alternate message pointer

; Function: Complete error handling and system cleanup
store_message_pointer:
	ld ($223b), de;						// store message pointer
	di;									// interrupts off
	call select_basic_rom;				// call system function
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
	jr z, call_rom_routine;				// jump if memory test passed
	res 7, h;							// clear bit 7 of H (address adjustment)

call_rom_routine:
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
load_stack_address:
	ld hl, $5e62;						// load stack address
	push hl;							// push stack address
	ld hl, $223a;						// load return address
	push hl;							// push return address
	ei;									// enable interrupts
	jp $3DFD;							// jump to UnoDOS system handler

; Function: File extension processor
store_char_processing:
	ld ($2e33), a;						// store character for processing
	cp '.';								// check for period character
	jp z, advance_past_period;			// jump to extension handler if period
	call save_char_in_c;				// call character validation
	ret nc;								// return if validation failed
	push hl;							// save HL register
	ex de, hl;							// swap DE and HL
	call memory_address_compare;		// call comparison function
	pop hl;								// restore HL register
	jr nc, load_processed_char;			// jump if comparison failed
	ld a, $1a;							// load error code $1A
	rst $20;							// call error handler

load_processed_char:
	ld a, ($2e33);						// load processed character
	jp $2800;							// jump to completion handler

; Function: Memory address comparison
memory_address_compare:
	ld a, (cached_compare_addr);		// load saved address low byte
	cp l;								// compare with current L
	jr nz, save_current_address;		// jump if different
	ld a, ($201a);						// load saved address high byte
	cp h;								// compare with current H
	ret z;								// return if addresses match

save_current_address:
	ld (cached_compare_addr), hl;		// save current address
	call build_alt_sys_path;			// call system function
	ld a, $24;							// load file handle $24
	ld b, 1;							// set mode to read
	rst $08;							// call DOS function
	defb f_open;						// open file operation
	jr c, save_error_code;				// jump if open failed
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

save_error_code:
	push af;							// save error code
	xor a;								// clear accumulator
	ld ($201a), a;						// clear address high byte
	pop af;								// restore error code
	ret;								// return with error

; Function: Character validation against token overloads
save_char_in_c:
	ld c, a;							// save character in C
	ld de, tk_overloads;				// load token overloads table
	ld a, (de);							// load first table entry

test_table_end:
	or a;								// test for table end
	ret z;								// return if end of table
	inc de;								// advance to next table entry
	cp c;								// compare with target character
	jr z, load_validation_result;		// jump if character found
	ld a, (de);							// load next entry

check_entry_end_marker:
	cp $80;								// check for entry end marker
	jr nc, test_table_end;				// continue if end marker found
	inc de;								// advance pointer
	or a;								// test for null
	ld a, (de);							// load next character
	jr z, test_table_end;				// continue if null found
	jr check_entry_end_marker;			// continue scanning entry

load_validation_result:
	ld a, (de);							// load validation result
	cp $80;								// check validation result
	ret c;								// return if validation passed
	inc de;								// advance to next data
	jr load_validation_result;			// continue validation loop
;;; 18_commands.asm


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
alt_load_message_pointer:
	ld hl, $23b8;						// load message table address
	jr memory_address_compare;			// jump to address comparison

; Function: Process command with register preservation
process_command_preserve:
	push hl;							// save HL register
	push de;							// save DE register
	push bc;							// save BC register
	call alt_load_message_pointer;		// call message processing
	pop bc;								// restore BC register
	pop de;								// restore DE register
	pop hl;								// restore HL register
	ld a, ixl;							// load IX low byte
	ld ($3df8), a;						// store result code
	ld a, $1a;							// load error code $1A
	ret;								// return with error

; Function: Process file extension
advance_past_period:
	inc hl;								// advance past period character
	push hl;							// save extension pointer
	ld hl, cmd_folder;					// load folder command string
	ld de, $2dce;						// load destination buffer
	ld bc, 5;							// copy 5 bytes
	ldir;								// copy folder command
	pop hl;								// restore extension pointer
	ld c, $20;							// set space character limit

; Function: Parse extension characters
load_extension_char:
	ld a, (hl);							// load character from extension
	cp ' ';								// compare with space character
	jr z, check_space_char;				// jump if space found
	rst $18;							// call ROM routine
	defw pr_st_end;						// check for string end
	jr z, check_space_char;				// jump if end of string

	ldi;								// copy character and increment
	jp po, check_space_char;			// jump if byte count expired
	jr load_extension_char;				// continue parsing characters

check_space_char:
	cp ' ';								// $20
	jr nz, set_char_pointer_alt;		// jump if not space character
	inc hl;								// advance past space
	ld ($2e46), hl;						// save command position

load_command_char:
	ld a, (hl);							// load character from command
	rst $18;							// call ROM routine
	defw pr_st_end;						// check for string end
	jr z, set_character_pointer;		// jump if end of string

	inc hl;								// advance to next character
	jr load_command_char;				// continue scanning

set_character_pointer:
	ld (ch_add), hl;					// set character pointer
	ld hl, ($2e46);						// load saved pointer
	jr store_pointer_later;				// jump to completion

set_char_pointer_alt:
	ld (ch_add), hl;					// set character pointer
	ld hl, 0;							// clear HL register

store_pointer_later:
	ld ($2e46), hl;						// store pointer for later use

external_command_entry equ $241b

; Function: Process command and handle errors
	call call_rom_routine_c1;			// call command processor
	call clear_null_terminator;			// call error handler
	jp nc, memory_init_routine;			// jump if no error
	cp 5;								// check for specific error code
	jp nz, restart_20;					// restart system if not error 5
	ld a, $16;							// load error code $16
	rst $20;							// call error handler

; Function: Initialize string terminator and open file
clear_null_terminator:
	xor a;								// clear accumulator (null terminator)
	ld (de), a;							// store null terminator at DE

; Function: Process file path and open
call_path_processing:
	call set_max_length_15;				// call path processing function
	ld a, $24;							// load file handle $24
	ld hl, $2dce;						// load filename buffer address
	ld b, 1;							// set mode to read
	rst $08;							// call DOS function
	defb f_open;						// open file operation
	ret;								// return with open result

cmd_folder_setup:
	ld a, ($3df8);						// load current drive state
	ld ($3df0), a;						// save drive state for operation
	push hl;							// save HL register
	ld hl, cmd_folder;					// load folder command string
	ld de, $2dce;						// load destination buffer
	ld bc, 5;							// copy 5 bytes
	ldir;								// copy folder command
	pop hl;								// restore HL register

; Function: Copy filename characters until space
load_filename_char:
	ld a, (hl);							// load character from filename
	inc hl;								// advance source pointer
	cp ' ';								// compare with space character
	jr z, save_current_position;		// jump if space found
	ld (de), a;							// store character in buffer
	inc de;								// advance destination pointer
	jr load_filename_char;				// continue copying characters

; Function: Complete filename processing
save_current_position:
	ld ($2e46), hl;						// save current position
	call clear_null_terminator;			// call file processing function
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
	jp memory_cleanup_with_hl;			// jump to completion handler

; Function: Process path string with length check
set_max_length_15:
	ld b, $0f;							// set maximum length to 15
	ld hl, $2e22;						// load path buffer address

; Function: Scan path characters
load_path_char:
	ld a, (hl);							// load character from path
	and a;								// test for null terminator
	jr z, advance_next_char;			// jump if null found
	push hl;							// save path pointer
	push bc;							// save BC register
	rst $08;							// call DOS function
	defb f_close;						// close file operation
	pop bc;								// restore BC register
	pop hl;								// restore HL register

; Function: Increment path pointer and check bounds
advance_next_char:
	inc hl;								// advance to next character
	djnz load_path_char;				// continue loop if counter not zero
	ret;								// return from function

dirs_io_entry equ $248a

;	// called from dirs.io
; Function: Process directory command (called from dirs.io)
call_expression_eval:
	call call_rom_rst18;				// call expression evaluation
	ret z;								// return if zero result
	ld a, c;							// load C register value
	or b;								// test if BC is zero
	jp z, error_code_19;				// jump to error handler if zero
	ex de, hl;							// exchange DE and HL
	ld de, $2d4e;						// load destination buffer address
	ldir;								// copy string to buffer
	xor a;								// clear accumulator
	ld (de), a;							// add null terminator
	ret;								// return from function

; Function: Evaluate BASIC expression
call_rom_rst18:
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
save_accumulator_flag:
	push af;							// save accumulator
	rst $30;							// call calculator
	ld (bc), a;							// store result at BC
	cp $64;								// compare with 'd' character
	jp nz, error_code_11;				// jump if not 'd'
	rst $30;							// call calculator
	ld (bc), a;							// store result at BC
	jp z, error_code_11;				// jump if zero
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
call_rom_routine_c1:
	rst $18;							// call ROM routine
	defw get_char;						// get current character

; Function: Check for string end
call_rom_routine_c4:
	rst $18;							// call ROM routine
	defw pr_st_end;						// check for program/string end
	jp nz, error_code_3;				// jump if not at end
	rst $30;							// call calculator
	inc bc;								// increment BC
	ret nz;								// return if not zero

; Function: Set up error handling (called from dirs.io)
error_handler_setup:
	ld sp, (err_sp);					// restore error stack pointer
	ld (iy + 0), $ff;					// set system flag to $FF
	ld hl, $1bf4;						// load error handler address
	rst $30;							// call calculator
	inc bc;								// increment BC
	jp z, jump_unmap_hl;				// jump to system function if zero
	ld hl, $1b7d;						// load alternate handler address
	jp jump_unmap_hl;					// jump to system function
	ld a, 1;							// load error code 1
	rst $20;							// call error handler

; Function: File error handler (called from files.io)
error_code_2:
	ld a, 2;							// load error code 2
	rst $20;							// call error handler

; Function: Command processing error
error_code_3:
	ld a, 3;							// load error code 3
	rst $20;							// call error handler

; Function: Parameter error
error_code_11:
	ld a, $0B;							// load error code 11 ($0B)
	rst $20;							// call error handler

; Function: Invalid argument error
error_code_19:
	ld a, $13;							// load error code 19 ($13)
	rst $20;							// call error handler

; Function: File operation error (called from files.io)
error_code_4:
	ld a, 4;							// load error code 4
	rst $20;							// call error handler

;	// called from dirs.io
; Function: File close with state management (called from dirs.io)
load_file_state_flag:
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
load_file_state_again:
	ld a, ($2e32);						// load file state flag
	and a;								// test if flag is set
	ret z;								// return if no file open
	push bc;							// save BC register
	push de;							// save DE register
	call load_file_state_flag;			// call file close function
	pop de;								// restore DE register
	pop bc;								// restore BC register
	ret;								// return from function

; Function: Close file using BASIC system variable
load_basic_newppc:
	ld a, (iy + _newppc);				// load BASIC system variable
	rst $08;							// call DOS function
	defb f_close;						// close file operation
	ret;								// return from function

; Function: Graphics character validation and processing
save_char_in_ixh:
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
	jr nc, save_file_handle;			// jump if successful
	pop bc;								// clean up stack
	pop bc;								// clean up stack
	ret;								// return with error

save_file_handle:
	ld ($2D4D), a;						// save file handle
	ld hl, $2df2;						// load file status buffer
	rst $08;							// call DOS function
	defb f_fstat;						// get file status
	pop af;								// restore accumulator
	call check_handle_limit;			// call system function
	ld hl, $1a95;						// load address value
	ld (iy + 2), l;						// store low byte in IY+2
	ld (iy + 3), h;						// store high byte in IY+3
	pop bc;								// restore BC register
	call load_page_address;				// call validation function
	jr nc, load_b_register_flags;		// jump if no error
	call load_screen0_address;			// call alternate validation
	jr nc, load_b_register_flags;		// jump if no error
	ld c, 3;							// load error code 3

; Function: Process file attributes and flags
load_b_register_flags:
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
	jr z, save_iy_register;				// jump if zero
	ld h, 0;							// clear overflow counter

; Function: Multi-precision right shift with overflow tracking
shift_right_b:
	srl b;								// shift right B register
	rr c;								// rotate right C register
	rr d;								// rotate right D register
	rr e;								// rotate right E register
	rl h;								// rotate left H (collect overflow)
	dec l;								// decrement shift counter
	jr nz, shift_right_b;				// repeat until done
	ld a, h;							// load overflow bits
	and a;								// test for overflow
	call nz, inc_32bit;					// handle overflow if present

save_iy_register:
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
	ld hl, final_virtual_disk_string;	// load routine address
	rst $30;							// call ROM routine
	inc b;								// increment B register
	ld a, (iy + 0);						// load flags from system area
	or a;								// test flags
	ret;								// return with status

; Function: Load and validate memory page
load_page_address:
	ld de, $0800;						// load page address
	call save_bc_register;				// call page loading function
	ret c;								// return if error
	ld a, ($3ee7);						// load system flag
	cp $10;								// compare with expected value
	ld c, 2;							// load result code
	ret z;								// return if match

; Function: Set error flag and return
set_error_carry:
	scf;								// set carry flag for error
	ret;								// return with error

; Function: Load screen memory and validate
load_screen0_address:
	ld de, $4000;						// load screen 0 address
	call save_bc_register;				// call memory loading function
	ret c;								// return if error
	ld a, ($3e00);						// load directory header byte
	cp $FF;								// check for valid directory marker
	ret nz;								// return if not directory
	ld hl, $3e09;						// load signature start address
	ld a, (hl);							// load first signature character
	cp $44;								// check for 'D'
	jr nz, set_error_carry;				// jump to error if not 'D'
	inc l;								// advance to next character
	ld a, (hl);							// load second signature character
	cp $49;								// check for 'I'  
	jr nz, set_error_carry;				// jump to error if not 'I'
	inc l;								// advance to next character
	ld a, (hl);							// load third signature character
	cp $52;								// check for 'R' (completing "DIR")
	jr nz, set_error_carry;				// jump to error if not 'R'
	ld c, 2;							// load success code
	ret;								// return successfully

; Function: Seek and read file operation
save_bc_register:
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
shift_right_b_reg:
	srl b;								// shift right B register
	rr c;								// rotate right C register
	rr d;								// rotate right D register
	rr e;								// rotate right E register

disk_sector_buffer equ $ - 1
	rl l;								// rotate left L (collect overflow)
	dec a;								// decrement shift counter
	jr nz, shift_right_b_reg;			// repeat until counter zero
	ld a, l;							// load accumulated overflow
	and a;								// test for overflow bits
	ld a, h;							// load high byte for overflow check
	call nz, inc_32bit;					// call overflow handler if bits set
	ret;								// return from shift function

final_virtual_disk_string:
	defb "Virtual Disk", 0;				// null-terminated string constant

lower_end:
;;; 19_fat_high.asm


;	// this part starts at $3000 in MMC RAM 1
	org $3000
; Function: Initialize memory management variables
store_hl_memory_ptr:
	ld ($3c19), hl;						// store HL in memory pointer
	ld de, ($3c11);						// load base address to DE
	ld bc, ($3c13);						// load size to BC
	ld ($3c15), de;						// store base address copy
	ld ($3c17), bc;						// store size copy
	call check_system_flag_bit;			// call initialization routine
	ret c;								// return if error
	call process_disk_operation;		// call memory setup function
	ld h, d;							// transfer D to H
	ld l, e;							// transfer E to L
	ld a, $ff;							// load marker value
	call store_at_memory_hl;			// call memory marking function
	push de;							// save DE register
	ld de, ($3c11);						// load memory base address
	ld bc, ($3c13);						// load memory size
	call mark_buffer_dirty;				// call memory initialization
	pop hl;								// restore HL register
	call fat_address_right_shift;		// call address conversion
	push bc;							// save BC register
	push de;							// save DE register
	ld bc, ($3c17);						// load saved size value
	ld de, ($3c15);						// load saved address value
	call check_drive_cluster_cache;		// call memory operation
	ld de, ($3c19);						// load memory pointer
	ld a, d;							// load high byte
	and 1;								// mask to lowest bit
	ld d, a;							// store masked value
	add hl, de;							// add address offset
	pop de;								// restore DE register
	pop bc;								// restore BC register
	call call_mem_addr_calc;			// call finalization routine
	push bc;							// save BC register again
	push de;							// save DE register again
	ld bc, ($3c17);						// reload saved size
	ld de, ($3c15);						// reload saved address
	call mark_buffer_dirty;				// call memory reinitialization
	pop de;								// restore DE register
	pop bc;								// restore BC register
	jp set_file_sector_address;			// jump to file descriptor function

; Function: Check system flags and process
check_system_flag_bit:
	bit 2, (iy + _oldppc);				// check system flag bit
	jr z, copy_h_to_d;					// jump if flag not set

save_hl_reg:
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
	jr z, shift_left_e_again;			// jump if zero
	sla e;								// shift left E register

; Function: Continue bit shifting and address calculation
shift_left_e_again:
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
	jr z, clear_system_flag;			// jump if zero result
	ld e, l;							// transfer L to E
	ld d, h;							// transfer H to D
	call load_next_line_high;			// call validation function
	jr nz, save_hl_reg;					// jump if not zero
	ret;								// return successfully

clear_system_flag:
	res 2, (iy + _oldppc);				// clear system processing flag
	ld a, 9;							// load error code 9 (system error)
	scf;								// set carry flag to indicate error
	ret;								// return with error

copy_h_to_d:
	ld d, h;							// copy H register to D
	ld e, l;							// copy L register to E
	call load_next_line_high;			// call memory validation function
	ret z;								// return if validation successful (Z flag set)
	ld a, h;							// load H register into accumulator
	cp '*';								// $2a
	jr nz, copy_h_to_d;					// loop back if not wildcard
	res 2, (iy + _oldppc);				// clear system processing flag
	ld de, ($3c11);						// load memory base address
	ld bc, ($3c13);						// load memory size
	call inc_32bit;						// call 32-bit increment function
	push bc;							// save BC register
	push de;							// save DE register
	call inc_32bit;						// call 32-bit increment again
	push iy;							// save IY register
	pop hl;								// transfer IY to HL
	ld l, $22;							// set offset to system area
	call compare_32bit;					// call memory comparison function
	pop de;								// restore DE register
	pop bc;								// restore BC register
	jr nz, call_mem_allocation;			// jump if comparison failed
	set 2, (iy + _oldppc);				// set system processing flag
	call check_drive_cluster_cache;		// call memory allocation function
	jr nc, save_hl_reg;					// jump if allocation successful
	ret;								// return to caller

call_mem_allocation:
	call check_drive_cluster_cache;		// call memory allocation function
	jr nc, copy_h_to_d;					// continue loop if allocation successful
	ret;								// return with error

load_next_line_high:
	ld a, (iy + _nxtlin_h);				// load next line high byte from system vars
	cp 1;								// compare with 1 (special mode flag)
	ld a, 0;							// clear accumulator
	call z, or_with_memory;				// call extended function if in special mode

or_with_memory:
	or (hl);							// OR accumulator with memory value at HL
	inc l;								// increment low byte of address
	or (hl);							// OR accumulator with next memory value
	inc hl;								// increment HL register
	ret;								// return with combined result

store_at_memory_hl:
	ld (hl), a;							// store accumulator at memory location HL
	inc l;								// increment low byte of address
	ld (hl), a;							// store accumulator at next location
	inc hl;								// increment HL register
	push bc;							// save BC register
	ld b, a;							// copy accumulator to B register
	ld a, (iy + _nxtlin_h);				// load next line high byte
	cp 1;								// check if in special mode
	ld a, b;							// restore original accumulator value
	pop bc;								// restore BC register
	ret nz;								// return if not in special mode
	ld (hl), a;							// store accumulator in extended area
	inc l;								// increment address
	and $0F;							// mask lower 4 bits
	ld (hl), a;							// store masked value
	inc hl;								// increment address
	ret;								// return to caller

call_mem_addr_calc:
	call set_directory_cluster;			// call memory address calculation function
	ld (hl), e;							// store E register at memory location
	inc l;								// increment address
	ld (hl), d;							// store D register at next location
	ld a, (iy + _nxtlin_h);				// load next line high byte
	cp 1;								// check if in special mode
	ret nz;								// return if not in special mode
	inc l;								// increment to extended storage area
	ld (hl), c;							// store C register
	inc l;								// increment address
	ld (hl), b;							// store B register
	ret;								// return to caller

call_rom_calculator:
	rst $30;							// call ROM calculator routine
	dec c;								// decrement counter
	ret z;								// return if counter reached zero
	call validate_cluster_operation;	// call processing function
	jr nz, call_file_operation;			// jump if result not zero
	call set_directory_cluster;			// call address calculation function

call_file_operation:
	call map_sector_from_cluster;		// call file operation function
	jr c, check_eof_marker;				// jump to error handler if carry set
	call clear_accumulator_zero;		// call memory clearing function
	jr nc, call_rom_calculator;			// loop back if no carry (continue)
	ret;								// return to caller

check_eof_marker:
	cp $80;								// check for end-of-file marker
	scf;								// set carry flag (error condition)
	ret nz;								// return if not end-of-file

clear_accumulator_zero:
	xor a;								// clear accumulator (A = 0)
	call store_at_memory_hl;			// call memory storage function with zero
	push bc;							// save BC register
	push de;							// save DE register
	ld de, ($3c11);						// load memory base address
	ld bc, ($3c13);						// load memory size
	call mark_buffer_dirty;				// call memory initialization function
	push af;							// save accumulator and flags
	scf;								// set carry flag
	call process_disk_operation;		// call memory setup function
	pop af;								// restore accumulator and flags
	pop de;								// restore DE register
	pop bc;								// restore BC register
	ret;								// return to caller

call_file_descriptor:
	call get_file_next_cluster;			// call file descriptor function
	jp write_disk_sector;				// jump to file operations handler
	bit 1, (ix + $01);					// check file operation flag bit 1
	ld a, 8;							// load error code 8 (file not open)
	scf;								// set carry flag for error
	ret z;								// return if flag not set (file not open)
	ld a, c;							// load C register
	or b;								// OR with B register (check if BC is zero)
	ret z;								// return if no bytes to process
	push bc;							// save byte count
	call load_file_size;				// call buffer preparation function
	rst $30;							// call ROM calculator routine
	dec c;								// decrement counter
	pop bc;								// restore byte count
	jr nz, set_file_proc_flag;			// jump if counter not zero
	push bc;							// save BC register
	call save_hl_reg_again;				// call file processing function
	pop bc;								// restore BC register
	ret c;								// return if error

set_file_proc_flag:
	set 2, (ix + $01);					// set file processing flag bit 2
	call file_io_byte_count;			// call file buffer management function
	push af;							// save accumulator and flags
	push bc;							// save BC register
	push hl;							// save HL register
	call load_file_position;			// call file position function
	push ix;							// save IX register
	pop hl;								// transfer IX to HL
	ld a, l;							// get low byte of IX
	add a, $0e;							// add offset to file descriptor area
	ld l, a;							// store adjusted address
	rst $30;							// call ROM calculator routine
	ex af, af';							// exchange AF with AF'
	call c, call_file_sync;				// call error handler if carry set
	set 3, (ix + $01);					// set file operation flag bit 3
	pop hl;								// restore HL register
	pop bc;								// restore BC register
	pop af;								// restore accumulator and flags
	ret nc;								// return if no carry (success)
	push af;							// save accumulator and flags
	call flush_dirty_buffer;			// call cleanup function
	pop af;								// restore accumulator and flags
	ret;								// return to caller

call_file_sync:
	call store_file_size;				// call file buffer synchronization function
	push hl;							// save HL register
	ld hl, $1a6d;						// load system call address
	ld ($3dee), hl;						// store system call pointer
	call descriptor_cleanup_validation;	// execute system call
	pop hl;								// restore HL register
	ret;								// return to caller

save_hl_reg_again:
	push hl;							// save HL register
	call process_fat_cluster_operations;// call file descriptor validation function
	pop hl;								// restore HL register
	call nc, flush_dirty_buffer;		// call cleanup if no carry (success)
	ret c;								// return if carry set (error)
	push bc;							// save BC register
	call process_disk_operation;		// call memory setup function
	pop bc;								// restore BC register
	call store_cluster_address;			// call buffer management function
	call setup_file_sector;				// call file position update function
	push hl;							// save HL register
	ld hl, $1a7c;						// load completion handler address
	ld ($3dee), hl;						// store completion handler pointer
	call descriptor_cleanup_validation;	// execute completion handler
	pop hl;								// restore HL register
	ret;								// return to caller

	call file_flush_update;				// call file initialization function
	ret c;								// return if error (carry set)
	push iy;							// save IY register
	pop hl;								// transfer IY to HL
	ld d, h;							// copy H to D
	ld e, l;							// copy L to E
	inc de;								// increment DE (destination pointer)
	ld bc, $ff;							// set clear count to 255 bytes
	ld (hl), l;							// store L value at HL (clear first byte)
	ldir;								// clear memory block (HL to HL+BC)
	or a;								// clear carry flag (success)
	ret;								// return to caller

	push de;							// save DE register
	ld a, $80;							// load file operation code $80
	call init_file_lookup;				// call file operation function
	pop de;								// restore DE register
	jr nc, load_first_filename_char;	// jump if no carry (operation successful)
	cp $11;								// check for error code $11 (file not found)
	scf;								// set carry flag (error condition)
	ret nz;								// return if not file not found error

load_first_filename_char:
	ld a, ($3c06);						// load first character of filename
	cp '.';								// $2e
	ld a, $13;							// load error code $13 (invalid filename)
	scf;								// set carry flag (error condition)
	jp z, file_operation_error_handler;	// jump to error handler if filename starts with '.'
	call transfer_error_number;			// call file lookup function
	ld hl, $1a65;						// load file operation handler address
	ld ($3dee), hl;						// store operation handler pointer
	call descriptor_cleanup_validation;	// execute file operation handler
	ld a, $17;							// load error code $17 (file operation failed)
	ret c;								// return if operation failed
	ld l, (ix + $1C);					// load low byte of directory entry pointer
	ld h, (ix + $1D);					// load high byte of directory entry pointer
	ld a, $0b;							// offset to file attributes byte
	add a, l;							// add offset to low byte
	ld l, a;							// store adjusted address
	bit 0, (hl);						// check read-only attribute flag
	ld a, $18;							// load error code $18 (file is read-only)
	scf;								// set carry flag (error condition)
	jp nz, file_operation_completion;	// jump to error handler if read-only
	push de;							// save DE register
	call load_cluster_address;			// call file buffer preparation function
	ld hl, $3c1b;						// load buffer address
	rst $30;							// call ROM calculator routine
	nop;								// padding/alignment
	call setup_directory_cluster;		// call directory sector read function
	ld hl, $3c1f;						// load sector buffer address
	rst $30;							// call ROM calculator routine
	nop;								// padding/alignment
	call get_file_next_cluster;			// call file descriptor function
	call file_validation_function;		// call file processing function
	ld a, (ix + $06);					// load drive number from file descriptor
	ld ($3c23), a;						// save drive number to temporary storage
	ld l, (ix + $1C);					// load directory entry address low byte
	ld h, (ix + $1D);					// load directory entry address high byte
	ld de, $2d00;						// load directory buffer address
	ld bc, $20;							// load directory entry size (32 bytes)
	ldir;								// copy directory entry to buffer
	pop hl;								// restore HL register from stack
	ld a, $80;							// load file lookup operation mode
	call setup_dir_buffer;				// call file existence check function
	jr c, check_error_code_5;			// jump to create file if not found
	ld a, $12;							// load error code 18 (file already exists)
	scf;								// set carry flag (error condition)
	jr file_operation_completion;		// jump to error return

check_error_code_5:
	cp 5								// check for error code 5 (access denied)
	scf;								// set carry flag (error condition)
	jr nz, file_operation_error_handler;	// jump to error handler if not access denied
	ld a, ($3c06);						// load first character of filename
	cp '.';								// $2e
	ld a, $13;							// load error code $13 (invalid filename)
	scf;								// set carry flag (error condition)
	jr z, file_operation_error_handler;	// jump to error handler if filename starts with '.'
	call load_cluster_address;			// call file buffer preparation function
	ld hl, $3c1E;						// load buffer address for comparison
	call compare_32bit;					// call memory comparison function
	jr nz, call_dir_entry_create;		// jump if comparison failed (file exists)
	ld a, ($3c23);						// load saved drive number
	ld (ix + $06), a;					// restore drive number to file descriptor
	call directory_update_function;		// call directory update function
	jr c, file_operation_error_handler;	// jump to error handler if update failed
	ex de, hl;							// exchange DE and HL registers
	ld hl, $3c06;						// load filename buffer address
	ld bc, $0b;							// copy 11 bytes (filename length)
	ldir;								// copy filename to directory entry
	jr call_dir_sector_write_alt;		// jump to completion handler

call_dir_entry_create:
	call directory_position_function;	// call directory entry creation function
	jr c, file_operation_error_handler;	// jump to error handler if creation failed
	ld a, (de);							// load first byte of existing entry
	push af;							// save first byte on stack
	ld hl, $3c06;						// load source filename buffer
	ld bc, $0b;							// copy 11 bytes (filename length)
	ldir;								// copy filename to directory entry
	ld hl, $2d0b;						// load source attributes buffer
	ld bc, $15;							// copy 21 bytes (file attributes)
	ldir;								// copy attributes to directory entry
	push de;							// save DE register
	call directory_sector_write;		// call directory sector write function
	pop hl;								// restore HL register from stack
	pop de;								// restore DE register from stack (original entry byte)
	jr c, file_operation_error_handler;	// jump to error handler if write failed
	ld a, d;							// load original entry byte
	cp $E5;								// RESTORE
	jr z, call_dir_sector_write;		// jump if entry was marked as deleted
	call clear_directory_entry;			// call file deletion function

call_dir_sector_write:
	call directory_sector_write;		// call directory sector write function
	ld a, ($3c23);						// load saved drive number
	ld (ix + $06), a;					// restore drive number to file descriptor
	call directory_update_function;		// call directory update function
	jr c, file_operation_error_handler;	// jump to error handler if update failed
	ld (hl), $e5;						// mark directory entry as deleted

call_dir_sector_write_alt:
	call directory_sector_write;		// call directory sector write function

; // file operation error handler
file_operation_error_handler:
	push af;							// save accumulator and flags
	call flush_dirty_buffer;			// call cleanup function
	pop af;								// restore accumulator and flags

; // file operation completion handler
file_operation_completion:
	ld (ix + 0), 0;						// clear file descriptor status
	ret;								// return to caller

	push bc;							// save BC register (attribute flags)
	ld a, $80;							// load file operation code $80
	call init_file_lookup;				// call file lookup function
	pop bc;								// restore BC register (attribute flags)
	jr nc, call_filename_validation;	// jump if file not found
	cp $11;								// check for error code $11 (file not found)
	scf;								// set carry flag (error condition)
	jr z, save_bc_attribute_flags;		// jump if file not found (handle as valid case)
	ret;								// return with other errors

call_filename_validation:
	call validate_filename_special_chars;	// call filename validation function
	ret c;								// return if filename invalid

save_bc_attribute_flags:
	push bc;							// save BC register (attribute flags)
	call get_file_next_cluster;			// call file descriptor function
	call file_validation_function;		// call file processing function
	call setup_directory_cluster;		// call directory sector read function
	ld l, (ix + $1C);					// load low byte of directory entry pointer
	ld h, (ix + $1D);					// load high byte of directory entry pointer
	ld a, $0b;							// offset to file attributes byte
	add a, l;							// add offset to entry pointer
	ld l, a;							// update pointer to attributes
	pop bc;								// restore BC register (attribute flags)
	ld a, b;							// load attribute mask from B
	rra;								// rotate right to position bits
	ccf;								// complement carry flag
	rla;								// rotate left to restore position
	and c;								// mask with attribute values
	ld b, a;							// store masked attributes
	ld a, c;							// load attribute values
	and $27;							// mask valid attribute bits
	cpl;								// complement to create clear mask
	and (hl);							// clear specified attributes
	or b;								// set new attributes
	and $37;							// mask to valid attribute range
	ld (hl), a;							// store modified attributes
	call directory_sector_write;		// call directory sector write function
	ret c;								// return if error writing directory
	jp flush_dirty_buffer;				// jump to file descriptor cleanup

; // validate filename against special characters
validate_filename_special_chars:
	ld hl, $2c00;						// load filename buffer address
	ld a, (hl);							// load first character
	cp '/';								// check for root directory marker ($2f)
	jr nz, check_invalid_filename_patterns;	// jump if not root path
	inc hl;								// skip root marker

; // check for invalid filename patterns
check_invalid_filename_patterns:
	ld a, (hl);							// load filename character
	cp '.';								// check for dot character
	jr z, handle_invalid_filename_error;	// jump if dot (invalid pattern)
	or a;								// check if end of filename
	ret nz;								// return if valid filename

; // handle invalid filename error
handle_invalid_filename_error:
	ld a, 8;							// load error code 8 (invalid filename)
	scf;								// set carry flag (error condition)
	ret;								// return with error

	; // create directory function
	ld a, $80;							// load directory operation code
	call init_file_lookup;				// call file lookup function
	jr c, handle_file_lookup_errors;	// jump if file lookup failed

; // directory already exists error
directory_exists_error:
	ld a, $12;							// load error code 18 (directory exists)
	scf;								// set carry flag (error condition)
	ret;								// return with error

; // handle file lookup error codes
handle_file_lookup_errors:
	cp $11;								// check for error code 17 (file not found)
	jr z, directory_exists_error;		// jump to error if found (should not exist)
	cp 5;								// check for error code 5 (access denied)
	scf;								// set carry flag (error condition)
	ret nz;								// return if other error
	call load_cluster_address;			// call file buffer preparation function
	push bc;							// save BC register
	push de;							// save DE register
	call directory_creation_helper;		// call directory creation function
	pop de;								// restore DE register
	pop bc;								// restore BC register
	ret c;								// return if creation failed
	push bc;							// save BC register again
	push de;							// save DE register again
	ld de, $2d00;						// load directory buffer address
	ld hl, $33a2;						// load template address
	exx;								// exchange register sets
	call load_cluster_address;			// call buffer function with alt registers
	exx;								// restore register sets
	call directory_entry_setup;			// call directory entry setup function
	ex de, hl;							// exchange DE and HL
	exx;								// exchange register sets
	pop de;								// restore DE register
	pop bc;								// restore BC register
	exx;								// exchange register sets
	ld hl, $33a1;						// load parent directory template
	call directory_entry_setup;			// call directory entry setup for parent
	ld d, h;							// copy H to D
	ld e, l;							// copy L to E
	inc de;								// increment destination pointer
	xor a;								// clear accumulator
	ld (hl), a;							// clear first byte
	ld bc, $01BF;						// load buffer size (447 bytes for directory clear)
	ldir;								// copy zeros to clear directory buffer
	ld hl, $2d00;						// load directory buffer address
	call call_file_descriptor;			// call directory sector write function
	ret c;								// return if write operation failed
	jp file_flush_update;				// jump to file update function

; // directory creation helper function
directory_creation_helper:
	xor a;								// clear accumulator
	ld ($3c01), a;						// clear operation flags
	call file_creation_operation;		// call file creation function
	ld (ix + 0), 0;						// clear file descriptor error status
	ret c;								// return if creation failed
	ld hl, disk_sector_buffer;			// load sector buffer address
	call directory_entry_sector_calc;	// call directory sector calculation
	ret c;								// return if calculation failed
	ld a, $0b;							// load offset to attributes field
	add a, e;							// add to directory entry pointer
	ld e, a;							// store updated pointer
	ld a, $10;							// load directory attribute flag
	ld (de), a;							// set directory attribute
	call directory_sector_write;		// call directory sector write function
	ret c;								// return if write failed
	set 3, (ix + $01);					// set directory flag in descriptor
	jp save_hl_reg_again;				// jump to completion routine

; // directory entry setup function
directory_entry_setup:
	ld bc, $0b;							// load filename length (11 characters)
	ldir;								// copy filename to directory entry
	ld a, $10;							// load directory attribute
	ld (de), a;							// set directory attribute flag
	ex de, hl;							// exchange DE and HL
	inc hl;								// skip to date field
	ld (hl), a;							// set date attribute
	inc hl;								// move to next date field
	ld (hl), a;							// set date attribute
	inc hl;								// move to time field
	rst $08;							// call system function
	defb m_getdate;						// get current date/time
	rst $30;							// call system function
	nop;								// no operation
	xor a;								// clear accumulator
	ld (hl), a;							// clear file size high byte
	inc l;								// increment low byte of HL
	ld (hl), a;							// clear file size low byte
	inc l;								// increment low byte of HL
	push hl;							// save HL register
	exx;								// exchange register sets
	pop hl;								// restore HL in alt set
	ld (hl), c;							// store C value
	inc l;								// move to next directory field
	ld (hl), b;							// store cluster high byte
	inc l;								// move to next directory field
	push hl;							// save directory entry pointer
	exx;								// switch to alternate register set
	pop hl;								// restore pointer in alt registers
	rst $30;							// call ROM calculator routine
	nop;								// padding instruction
	push hl;							// save HL register
	exx;								// exchange register sets
	pop hl;								// restore HL in alt set
	ld (hl), e;							// store E value (cluster low)
	inc l;								// increment low byte of HL
	ld (hl), d;							// store D value (cluster high)
	inc l;								// increment low byte of HL
	push hl;							// save HL register
	exx;								// exchange register sets
	pop hl;								// restore HL in main set
	ld b, a;							// copy A to B
	ld c, b;							// copy B to C
	ld d, c;							// copy C to D
	ld e, d;							// copy D to E
	rst $30;							// call system function
	nop;								// no operation
	ret;								// return from function

	; // file access function - load filename character  
load_filename_character:
	ld l, $2e;							// load filename character '.' ($2e)
	jr nz, setup_file_access_mode;		// jump if not zero
	jr nz, adjust_file_access_params;	// jump if not zero  
	jr nz, clear_b_byte_count;			// jump if not zero
	jr nz, store_byte_count_c;			// jump if not zero
	jr nz, ldir_copy_block;				// jump if not zero
	ld a, $81;							// load file access mode
	call init_file_lookup;				// call file lookup function
	ret c;								// return if lookup failed
	call setup_directory_cluster;		// call file access setup function
	call store_fs_parameters;			// call file descriptor initialization
	ld hl, $2c80;						// load file buffer address
	ld a, ($3dea);						// load system variable
	ld (iy + $7f), a;					// store in descriptor offset
	push iy;							// save IY register
	pop de;								// load descriptor address to DE

; // setup file access mode
setup_file_access_mode:
	ld e, $80;							// load file mode flag

; // adjust file access parameters
adjust_file_access_params:
	sub $80;							// subtract base value

clear_b_byte_count:
	ld b, 0;							// clear B register for byte count

store_byte_count_c:
	ld c, a;							// store byte count in C register

ldir_copy_block equ $33cd

	ldir;								// copy BC bytes from HL to DE
	ld a, b;							// load remaining byte count
	ld (de), a;							// store final byte count
	or a;								// clear carry flag (success)
	ret;								// return from file access function

; // file creation and initialization function
file_creation_init:
	ld a, 1;							// load file flag value
	or b;								// combine with B register
	and $41;							// mask file attribute bits
	ld (ix + $01), a;					// store in file descriptor flags
	ld a, $80;							// load file operation mode
	call init_file_lookup;				// call file lookup function
	ret c;								// return if lookup failed
	call get_file_next_cluster;			// call file preparation function
	call file_validation_function;		// call file allocation function
	call setup_directory_cluster;		// call access setup function
	call store_cluster_address;			// call buffer initialization
	call setup_file_sector;				// call sector management function
	ld b, 0;							// clear B register
	ld c, b;							// clear C register
	ld d, c;							// clear D register
	ld e, d;							// clear E register
	call store_file_position;			// call file size setup function
	call dec_32bit;						// call 32-bit arithmetic function
	call store_file_size;				// call buffer management function
	call transfer_error_number;			// call file completion function
	or a;								// clear carry flag
	ret	;								// return from function

; // exchange DE and HL registers
exchange_registers:
	ex de, hl;							// exchange DE and HL

; // directory buffer read function
directory_buffer_read:
	ld hl, $2d00;						// load directory buffer address
	ld bc, $20;							// load directory entry size (32 bytes)
	push de;							// save DE register
	call file_io_buffer_operation;		// call buffer read function
	pop de;								// restore DE register
	ret c;								// return if read failed
	ld a, (hl);							// load first byte of entry
	and a;								// check if entry is empty (first byte = 0)
	ret z;								// return if empty entry found
	cp $e5;								// check for deleted entry marker
	jr z, directory_buffer_read;		// jump to continue if deleted entry
	ld l, $0b;							// load offset to attributes field
	bit 3, (hl);						// check volume label bit (bit 3)
	ld l, 0;							// reset L to start of entry
	jr nz, directory_buffer_read;		// jump to continue if volume label
	push de;							// save directory entry position
	ld de, $2d20;						// load filename output buffer address
	push de;							// save output buffer pointer
	inc de;								// increment destination pointer
	ld b, 8;							// set filename length (8 characters)
	call filename_char_copy;			// call filename copy function
	ld a, (hl);							// load character from source
	cp ' ';								// check for space character ($20)
	jr z, process_file_extension;		// jump if space (no extension)
	ld a, $2e;							// load dot character for extension
	ld (de), a;							// store dot separator
	inc de;								// increment destination pointer

; // process file extension
process_file_extension:
	ld b, 3;							// set extension length (3 characters)
	call filename_char_copy;			// call extension copy function
	xor a;								// clear accumulator
	ld (de), a;							// null-terminate filename
	inc de;								// increment destination pointer
	ld a, (hl);							// load file attributes
	and $3F;							// mask attribute bits
	ld ($2d20), a;						// store attributes in buffer
	ld bc, 9;							// skip to cluster field (9 bytes)
	add hl, bc;							// add offset to HL
	ld c, (hl);							// load cluster low byte
	inc hl;								// increment to cluster high byte
	ld b, (hl);							// load cluster high byte
	ld ($3c21), bc;						// store cluster number
	inc hl;								// move to file size field
	ldi;								// copy file size byte 1
	ldi;								// copy file size byte 2
	ldi;								// copy file size byte 3
	ldi;								// copy file size byte 4
	ld c, (hl);							// load date/time low byte
	inc hl;								// increment to date/time high byte
	ld b, (hl);							// load date/time high byte
	ld ($3c1f), bc;						// store date/time information
	inc hl;								// move to next directory entry field
	ldi;								// copy date/time byte 1 and increment pointers
	ldi;								// copy date/time byte 2 and increment pointers
	ldi;								// copy date/time byte 3 and increment pointers
	ldi;								// copy date/time byte 4 and increment pointers
	bit 6, (ix + $01);					// check enhanced directory flag (bit 6)
	call nz, enhanced_directory_processing;	// call enhanced processing if flag set
	ld b, 0;							// clear B register for return value
	ld a, e;							// load destination pointer offset
	sub $20;							// subtract base buffer address
	ld c, a;							// store buffer size in C
	pop hl;								// restore filename buffer pointer
	pop de;								// restore directory entry pointer
	ret c;								// return if error occurred
	rst $30;							// call ROM calculator routine
	ld b, $eb;							// load completion code
	ld a, 1;							// set success flag
	or a;								// clear carry flag (success)
	ret;								// return from directory processing

; // enhanced directory processing function
enhanced_directory_processing:
	ld a, ($2D20);						// load file attributes from buffer
	bit 4, a;							// check directory attribute flag (bit 4)
	jr nz, directory_invalid_date_handler;	// jump to directory handler if set
	ld hl, $3C1F;						// load date/time buffer address
	push de;							// save output buffer pointer
	rst $30;							// call ROM calculator routine
	ld bc, $0df7;						// load date validation code
	jr z, date_processing_completion;	// jump if date validation passed
	call check_file_position;			// call date conversion function
	ld hl, disk_sector_buffer;			// load date output buffer
	push hl;							// save buffer pointer
	call read_disk_sector;				// call date formatting function
	pop hl;								// restore buffer pointer

; // date processing completion handler
date_processing_completion:
	pop de;								// restore output buffer pointer
	ret c;								// return if date processing failed
	push de;							// save output buffer pointer
	call filename_validation_checksum;	// call date validation function
	pop de;								// restore output buffer pointer
	jr nz, directory_invalid_date_handler;	// jump to error handler if validation failed
	ld hl, $2d20;						// load file attributes buffer
	ld a, $40;							// load valid file flag (bit 6)
	or (hl);							// combine with existing attributes
	ld (hl), a;							// store updated attributes
	ld hl, $260f;						// load formatted date buffer
	ld bc, 8;							// load date field size (8 bytes)

; // date field copy and completion
date_field_copy_complete:
	ldir;								// copy date field to output buffer
	xor a;								// clear accumulator (success code)
	ret;								// return from date processing

; // directory or invalid date handler
directory_invalid_date_handler:
	ld a, $ff;							// load invalid date marker (255)
	ld (de), a;							// store invalid marker in output
	inc de;								// increment output pointer
	inc a;								// increment to 0 (next invalid marker)
	ld (de), a;							// store second invalid marker
	push de;							// save output pointer
	pop hl;								// transfer to HL for copying
	inc de;								// increment destination pointer
	ld bc, 5;							// load remaining field size (5 bytes)
	jr date_field_copy_complete;		// jump to field copy completion

; // character copy function for filename processing
filename_char_copy:
	ld a, (hl);							// load character from source filename
	inc hl;								// move to next filename character
	cp ' ';								// $20
	jr z, final_char_loop;				// skip if space character (padding)
	ld (de), a;							// store valid character in output
	inc de;								// increment output pointer

final_char_loop:
	djnz filename_char_copy;			// decrement B and loop for all characters
	ret;								// return from filename copy function

; // directory buffer setup and validation function
directory_buffer_setup:
	ld de, $2d00;						// load directory buffer address
	ld hl, $40;							// load source filename template
	ld bc, $0b;							// load filename length (11 characters)
	ldir;								// copy filename template to buffer
	ld hl, ($3c23);						// load cluster/directory information
	ld e, $0f;							// set directory attributes offset
	ld bc, 8;							// set attribute field size
	rst $30;							// call ROM calculator routine
	rlca;								// rotate accumulator left
	xor a;								// clear accumulator
	ld (de), a;							// clear directory field
	ld h, d;							// copy D to H
	ld l, e;							// copy E to L 
	inc e;								// increment directory pointer
	ld bc, $67;							// load clear size (103 bytes)
	ldir;								// clear remaining directory fields
	push de;							// save directory entry pointer
	ld l, $10;							// offset to cluster field
	ld e, (hl);							// load cluster low byte
	inc l;								// increment to cluster high byte
	ld d, (hl);							// load cluster high byte
	ld b, a;							// copy accumulator to B
	ld c, a;							// copy accumulator to C
	push hl;							// save cluster pointer
	ld hl, $80;							// load sector size constant
	call add_32bit;						// call arithmetic function
	pop hl;								// restore cluster pointer
	ld l, $0b;							// offset to attributes field
	rst $30;							// call ROM calculator routine
	nop;								// padding instruction
	pop hl;								// restore entry pointer
	ld l, 0;							// reset to entry start
	ld c, $7f;							// load checksum counter (127 bytes)
	xor a;								// clear accumulator for checksum

add_dir_byte_checksum:
	add a, (hl);						// add directory byte to checksum
	cpi;								// compare and increment, decrement BC
	jp pe, add_dir_byte_checksum;		// loop while parity even (BC not zero)
	ld (hl), a;							// store calculated checksum
	ret;								// return from checksum calculation

; // memory validation and arithmetic function
memory_validation_arithmetic:
	call get_working_cluster;			// call memory bounds checking function
	ld a, b;							// load B register value
	inc a;								// increment for boundary test
	jr nz, call_memory_setup;			// jump if not at memory boundary
	call clear_memory_flag;				// call memory allocation function
	cp 9;								// check for error code 9 (out of memory)
	scf;								// set carry flag (error condition)
	ret nz;								// return if error occurred

call_memory_setup:
	call set_working_cluster;			// call memory setup function
	ld a, (iy + _x_ptr);				// load X pointer from system variables

shift_right_a_reg:
	srl a;								// shift right A register
	ccf;								// complement carry flag
	ret nc;								// return if no carry (shift complete)
	sla e;								// shift left E register
	rl d;								// rotate left D register with carry
	rl c;								// rotate left C register with carry
	rl b;								// rotate left B register with carry
	jr shift_right_a_reg;				// loop for multi-precision left shift

clear_memory_flag:
	res 3, (iy + _oldppc);				// clear memory management flag bit 3
	exx;								// switch to alternate register set
	ld bc, 0;							// clear BC register pair
	ld de, 2;							// load minimum allocation size
	call check_drive_cluster_cache;		// call memory allocation function
	ret c;								// return if allocation failed

call_memory_mgmt:
	call check_system_flag_bit;			// call memory management function
	exx;								// switch to alternate register set
	call inc_32bit;						// call 32-bit increment function
	ret c;								// return if arithmetic overflow
	exx;								// switch back to main register set
	jr call_memory_mgmt;				// loop for memory block processing
; // return point from memory allocation loop
memory_allocation_return:
	call load_file_position;			// call file position function
	or a;								// clear carry flag (success)
	ret;								// return from memory allocation

; // directory entry removal with state management
directory_entry_removal:
	push hl;							// save filename pointer
	ld b, 0;							// clear operation mode flag
	call file_creation_init;			// call file creation function
	pop hl;								// restore filename pointer
	ret c;								// return if operation failed
	ld a, ($3df8);						// load original state flag
	ld c, a;							// save in C register
	ld a, ($3df9);						// load new state flag
	ld ($3df8), a;						// update state flag
	push hl;							// save registers
	push bc;							// save state information
	call init_dir_entry_counter;		// call directory validation
	pop bc;								// restore state information
	pop hl;								// restore registers
	push af;							// save operation result
	ld a, c;							// load original state
	ld ($3df8), a;						// restore original state
	pop af;								// restore operation result
	ret c;								// return if validation failed
	ld a, $80;							// load file operation code
	jr call_file_lookup;				// jump to file deletion

init_dir_entry_counter:
	ld b, 0;							// initialize directory entry counter

; // directory entry validation loop
directory_entry_validation_loop:
	ld hl, $2d40;						// load directory entry buffer
	push bc;							// save entry counter
	push hl;							// save buffer pointer
	call exchange_registers;			// call directory read function
	pop hl;								// restore buffer pointer
	pop bc;								// restore entry counter
	ret c;								// return if read failed
	and a;								// test if entry found
	jr z, validate_directory_count;		// jump if no entry found
	inc b;								// increment entry count
	inc hl;								// move to next entry
	ld a, (hl);							// load entry character
	cp '.';								// $2e
	jr z, directory_entry_validation_loop;	// loop if dot entry (current/parent dir)

; // directory entry count validation error
directory_count_validation_error:
	ld a, $1b;							// load error code 27 (directory not empty)
	scf;								// set carry flag (error condition)
	ret;								// return with error

; // validate directory entry count
validate_directory_count:
	ld a, b;							// load entry count
	cp 2;								// compare with 2 (only . and .. should remain)
	jr nz, directory_count_validation_error;	// jump to error if more entries exist
	ld a, ($3c06);						// load first character of filename
	cp '.';								// $2e
	jr nz, clear_carry_success;			// jump if not dot directory
	ld a, 8;							// load error code 8 (invalid operation)
	scf;								// set carry flag (error condition)
	ret;								// return with error

clear_carry_success:
	or a;								// clear carry flag (success)
	ret;								// return from validation

; // file deletion handler continuation
file_deletion_continuation:
	ld a, 0;							// clear operation mode

call_file_lookup:
	call init_file_lookup;				// call file lookup function
	ret c;								// return if lookup failed
	call transfer_error_number;			// call file validation function
	call get_file_next_cluster;			// call file descriptor setup
	call file_validation_function;		// call file allocation function
	call setup_directory_cluster;		// call directory access setup
	ld hl, $1a65;						// load completion handler address
	ld ($3dee), hl;						// store completion handler pointer
	call descriptor_cleanup_validation;	// execute completion handler
	ld a, $17;							// load error code 23 (file operation failed)
	jr c, file_deletion_error_handler;	// jump to error handler if operation failed
	ld l, (ix + $1C);					// load directory entry pointer low byte
	ld h, (ix + $1D);					// load directory entry pointer high byte
	push hl;							// save directory entry pointer
	ld a, $0b;							// offset to file attributes
	add a, l;							// add offset to entry pointer
	ld l, a;							// update pointer to attributes
	bit 0, (hl);						// check read-only attribute
	pop hl;								// restore directory entry pointer
	ld a, $18;							// load error code 24 (file is read-only)
	scf;								// set carry flag (error condition)
	jr nz, file_deletion_error_handler;	// jump to error handler if read-only
	ld (hl), $e5;						// mark directory entry as deleted
	push bc;							// save BC register
	push de;							// save DE register
	call directory_sector_write;		// call directory sector write
	pop de;								// restore DE register
	pop bc;								// restore BC register
	call nc, call_rom_calculator;		// call cluster deallocation if write succeeded
	call nc, flush_dirty_buffer;		// call file descriptor cleanup if successful

; // file deletion error handler
file_deletion_error_handler:
	ld (ix + 0), 0;						// clear file descriptor status
	ret;								// return with error condition

; // directory management with file creation
directory_mgmt_file_creation:
	ld b, 1;							// set directory creation flag
	push hl;							// save directory name pointer
	push de;							// save registers
	call file_delete_operation;			// call directory creation function
	pop de;								// restore registers
	pop hl;								// restore directory name pointer
	jr nc, exchange_de_hl;				// jump if creation successful
	cp $10;								// check for error code 16 (directory exists)
	scf;								// set carry flag (error condition)
	ret nz;								// return if other error
	push de;							// save registers for file creation
	ld b, 0;							// clear creation mode (file not directory)
	call file_creation_init;			// call file creation function
	pop de;								// restore registers
	ret c;								// return if file creation failed

exchange_de_hl:
	ex de, hl;							// exchange DE and HL registers
	call directory_entry_attribute_mgmt;	// call directory processing function
	ret;								// return from directory management

; // directory entry setup and attribute management  
directory_entry_attribute_mgmt:
	push hl;							// save directory entry pointer
	ld hl, $2d00;						// load directory buffer address
	ld a, (iy + 0);						// load system variable byte 0
	ld (hl), a;							// store in directory buffer
	inc hl;								// increment buffer pointer
	ld a, (iy + 1);						// load system variable byte 1
	ld (hl), a;							// store in directory buffer
	call directory_update_function;		// call directory sector access
	pop de;								// restore directory entry pointer
	ret c;								// return if sector access failed
	push de;							// save directory entry pointer again
	ex de, hl;							// exchange DE and HL
	ld hl, $2d02;						// load directory data buffer
	ld a, $0b;							// load attributes offset
	ld c, a;							// save offset in C
	add a, e;							// add offset to entry pointer
	ld e, a;							// update entry pointer
	ld a, (de);							// load file attributes
	ld (hl), a;							// store attributes in buffer
	inc hl;								// increment buffer pointer
	ld a, c;							// restore attributes offset
	add a, e;							// add to entry pointer
	ld e, a;							// update entry pointer
	ex de, hl;							// exchange DE and HL
	ld bc, 4;							// load copy count (4 bytes)
	ldir;								// copy directory entry data
	ex de, hl;							// exchange DE and HL back
	call load_file_size;				// call buffer management function
	rst $30;							// call ROM calculator
	nop;								// padding instruction
	pop de;								// restore directory entry pointer
	ld hl, $2d00;						// load directory buffer address
	ld bc, $0b;							// load filename length
	rst $30;							// call ROM calculator
	ld b, $b7;							// load operation code
	jp error_buffer_management;			// jump to directory completion handler
; // file truncation function
file_truncation_function:
	ld a, 0;							// clear operation mode (truncate)
	call init_file_lookup;				// call file lookup function
	ret c;								// return if lookup failed
	call transfer_error_number;			// call file validation
	call get_file_next_cluster;			// call file descriptor setup
	call file_validation_function;		// call file allocation
	ld l, (ix + $1C);					// load directory entry pointer low
	ld h, (ix + $1D);					// load directory entry pointer high
	ld a, $0b;							// offset to attributes field
	add a, l;							// add offset to pointer
	ld l, a;							// update pointer to attributes
	bit 0, (hl);						// check read-only attribute
	ld a, $18;							// load error code 24 (read-only)
	scf;								// set carry flag (error)
	jr nz, write_error_handler;			// jump to error if read-only
	ld b, 0;							// clear 32-bit value
	ld c, b;							// clear C register
	ld d, c;							// clear D register  
	ld e, d;							// clear E register
	call call_file_sync;				// call file buffer sync
	call setup_directory_cluster;		// call directory access
	call system_processing_call;		// call truncation completion

; // file operation error handler
write_error_handler:
	push af;							// save error code and flags
	call file_close_operation;			// call file descriptor cleanup
	pop af;								// restore error code and flags
	ret;								// return with original error condition

; // file write operation with validation
file_write_validation:
	bit 1, (ix + $01);					// check file write flag (bit 1)
	ld a, 8;							// load error code 8 (file not open for write)
	scf;								// set carry flag (error condition)
	ret z;								// return if file not open for writing
	call load_file_position;			// call file position function
	call call_file_sync;				// call buffer synchronization
	call get_file_sector_address;		// call write operation handler

system_processing_call:
	call call_rom_calculator;			// system processing call
	call nc, flush_dirty_buffer;		// call if no carry
	ld hl, $1a7c;						// set system address
	ld ($3dee), hl;						// store system address
	call descriptor_cleanup_validation;	// call processing routine
	or a;								// test accumulator
	ret;								// return to caller
;;; 20_low_utils.asm


clear_l_register:
	ld l, 0;							// clear L register
	jr save_bc_registers;				// jump to initialization
	ld l, 0;							// clear L register
	ld b, l;							// clear B register
	ld c, l;							// clear C register
	ld d, l;							// clear D register
	ld e, l;							// clear E register

save_bc_registers:
	push bc;							// save BC registers
	push de;							// save DE registers
	ld a, (iy + _nxtlin_h);				// get next line high byte
	cp 0;								// test if zero
	jr nz, get_x_pointer;				// jump if not zero
	call load_cluster_address;			// call processing routine
	rst $30;							// restart 30 (calculator)
	dec c;								// decrement C register
	ld b, 0;							// clear B register
	jr nz, get_x_pointer;				// jump if not zero
	inc b;								// increment B register
	ld a, (iy + _udg_h);				// get UDG high byte
	jr set_y_coordinate;				// jump to coordinate setting

get_x_pointer:
	ld a, (iy + _x_ptr);				// get X pointer

set_y_coordinate:
	ld (iy + _coord_y), a;				// set Y coordinate
	ld (iy + _coord_x), b;				// set X coordinate
	pop de;								// restore DE registers
	pop bc;								// restore BC registers
	ld a, l;							// get L register value
	cp 0;								// test if zero
	jr z, syscall_code_14;				// jump if zero
	push bc;							// save BC registers
	push de;							// save DE registers
	call load_file_position;			// call processing routine
	ex de, hl;							// exchange DE and HL
	pop de;								// restore DE registers
	cp 1;								// compare with 1
	jr z, add_de_to_hl;					// jump if equal to 1
	cp 2;								// compare with 2
	jr z, final_subtract_with_carry;	// jump if equal to 2
	ld a, 2;							// load error code 2
	pop bc;								// restore BC registers
	scf;								// set carry flag
	ret;								// return with error

final_subtract_with_carry:
	sbc hl, de;							// subtract DE from HL with carry
	ex de, hl;							// exchange DE and HL
	ld l, c;							// load C into L
	ld h, b;							// load B into H
	pop bc;								// restore BC registers
	sbc hl, bc;							// subtract BC from HL with carry
	jr store_l_to_c;					// jump to result handling

add_de_to_hl:
	add hl, de;							// add DE to HL
	ex de, hl;							// exchange DE and HL
	ld l, c;							// load C into L
	ld h, b;							// load B into H
	pop bc;								// restore BC registers
	adc hl, bc;							// add BC to HL with carry

store_l_to_c:
	ld c, l;							// store L back to C
	ld b, h;							// store H back to B
	jr nc, syscall_code_14;				// jump if no carry (no overflow)
	ld de, 0;							// clear DE (overflow handling)
	ld b, d; 							// clear B register (overflow handling)
	ld c, e;							// clear BC (overflow handling)

syscall_code_14:
	ld a, $0e;							// load system call code
	call save_ix_register;							// call system routine
	rst $30;							// restart 30 (calculator)
	ex af, af';							// exchange AF registers
	jr nc, syscall_code_18;				// jump if no carry
	call load_file_size;				// call error routine

syscall_code_18:
	ld a, $12;							// load system call code 12
	call save_ix_register;							// call system routine
	rst $30;							// restart 30 (calculator)
	ex af, af';							// exchange AF registers
	jp z, test_accumulator_flags;		// jump if zero to handler
	jr c, save_bc_regs;					// jump if carry to processing
	push de;							// save DE registers
	push bc;							// save BC registers
	call load_cluster_address;			// call processing routine
	call file_position_init;			// call display routine
	pop bc;								// restore BC registers
	pop de;								// restore DE registers
	jr syscall_code_18;					// loop back for more processing

save_bc_regs:
	push bc;							// save BC registers
	push de;							// save DE registers
	rst $30;							// restart 30 (calculator)
	dec c;								// decrement counter
	jr nz, save_de_regs;				// jump if not zero
	call print_inverse_control;			// call completion routine
	jr save_de_registers_alt;			// jump to continuation

save_de_regs:
	push de;							// save DE registers
	push bc;							// save BC registers
	xor a;								// clear accumulator
	call test_accumulator_alt;			// call display routine
	call print_inverse_control;			// call completion routine
	ld a, 1;							// load value 1
	pop bc;								// restore BC registers
	pop de;								// restore DE registers
	call test_accumulator_alt;			// call display routine

save_de_registers_alt:
	push de;							// save DE registers
	call load_file_position;			// call graphics routine
	rst $30;							// restart 30 (calculator)
	dec c;								// decrement counter
	jr z, print_position_control;		// jump if zero
	ld a, (iy + _coord_x);				// get X coordinate
	or a;								// test if zero
	jr nz, call_coordinate_routine;		// jump if not zero
	call load_file_position;			// call graphics routine
	call test_accumulator_alt;			// call display routine

print_position_control:
	ld a, $1f;							// load control code 31 (print position)
	call save_ix_register;							// call system routine
	rst $30;							// restart 30 (calculator)
	ex af, af';							// exchange AF registers
	jr z, call_coordinate_routine;		// jump if zero
	push bc;							// save BC registers
	push de;							// save DE registers
	call complete_sector_processing;	// call processing routine
	pop de;								// restore DE registers
	pop bc;								// restore BC registers
	jr nc, call_error_handling;			// jump if no carry
	pop hl;								// restore HL registers
	pop de;								// restore DE registers
	pop bc;								// restore BC registers
	ret;								// return to caller

call_error_handling:
	call inc_32bit;						// call error handling routine
	jr print_position_control;			// loop back for retry

call_coordinate_routine:
	call get_file_next_cluster;			// call coordinate routine
	ld a, (iy + _coord_y);				// get Y coordinate
	sub (ix + $13);						// subtract offset value
	ld h, 0;							// clear H register
	ld l, a;							// load result into L
	call sub_32bit;						// call graphics calculation routine
	ld a, (iy + _coord_y);				// get Y coordinate
	pop hl;								// restore HL registers
	dec a;								// decrement Y coordinate
	and l;								// mask with L register
	ld h, 0;							// clear H register
	ld l, a;							// load masked value into L
	call add_32bit;						// call coordinate routine
	call set_file_next_cluster;			// call display routine
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

test_accumulator_flags:
	or a;								// test accumulator
	jp store_file_position;				// jump to handler routine

test_accumulator_alt:
	or a;								// test accumulator
	ld hl, $0200;						// load value 512
	jr nz, decrement_hl_reg;						// jump if not zero
	ld a, (iy + _coord_y);				// get Y coordinate
	push af;							// save Y coordinate

rotate_right_carry:
	rrca;								// rotate right with carry
	jr c, restore_accumulator_final;	// jump if carry set
	add hl, hl;							// shift HL left
	jr rotate_right_carry;				// loop back

restore_accumulator_final:
	pop af;								// restore accumulator

decrement_hl_reg:
	dec hl;								// decrement HL
	call add_32bit;						// call coordinate routine
	ld e, d;							// move D to E
	ld d, c;							// move C to D
	ld c, b;							// move B to C
	ld b, 0;							// clear B register

shift_c_right_logical:
	srl c;								// shift C right logical
	rr d;								// rotate D right through carry
	rr e;								// rotate E right through carry
	rrca;								// rotate accumulator right with carry
	jr nc, shift_c_right_logical;		// loop while no carry
	jp dec_32bit;						// jump to processing routine

print_inverse_control:
	ld a, $1c;							// load control code 28 (print inverse)
	call save_ix_register;				// call offset calculation
	rst $30;							// restart 30 (calculator)
	nop;								// no operation
	ret;								// return to caller

save_ix_register:
	push ix;							// save IX register
	pop hl;								// get IX value into HL
	add a, l;							// add A to L
	ld l, a;							// store result in L
	ret;								// return with offset address

upper_end:
// End of UnoDOS 3 BASIC integration module
// This module provides complete BASIC interpreter integration
// including system calls, file I/O, and ROM interfacing
