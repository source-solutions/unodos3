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
