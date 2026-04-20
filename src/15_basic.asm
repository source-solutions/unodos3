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
