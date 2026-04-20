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
