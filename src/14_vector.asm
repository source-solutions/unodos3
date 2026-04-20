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
