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
