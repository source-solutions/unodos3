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

;	// Function: Process data with printer buffer preservation
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

;	// Function: UnoDOS system call handler
load_syscall_number:
	ld a, ($0001);						// load system call number
	jp $3DFD;							// jump to UnoDOS handler

;	// Function: Initialize message printer 
clear_message_offset:
	ld de, 0;							// clear message offset
	ld hl, $2d4e;						// load message table address
	call load_char_from_msg;			// call message printer
	jp unmap_and_return;				// jump to completion handler

;	// Function: BASIC calculator operations
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

;	// Function: Message/string printer
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

;	// Function: Handle special code 1 (attribute/graphics handling)
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

;	// Function: Print character preserving registers
save_hl_register:
	push hl;							// save HL register
	push de;							// save DE register
	rst $18;							// call ROM routine
	defw add_char;						// add character to display
	pop de;								// restore DE register
	pop hl;								// restore HL register
	ret;								// return

;	// Function: Error code handler and system boundary checks  
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

;	// Function: Complete error handling and system cleanup
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

;	// Function: System call handler with stack setup
load_stack_address:
	ld hl, $5e62;						// load stack address
	push hl;							// push stack address
	ld hl, $223a;						// load return address
	push hl;							// push return address
	ei;									// enable interrupts
	jp $3DFD;							// jump to UnoDOS system handler

;	// Function: File extension processor
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

;	// Function: Memory address comparison
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

;	// Function: Character validation against token overloads
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
