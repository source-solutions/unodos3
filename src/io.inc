;	// UnoDOS 3 - An operating system for the divMMC SD card interface.
;	// Copyright (c) 2017-2019 Source Solutions, Inc.

;	// UnoDOS 3 is free software: you can redistribute it and/or modify
;	// it under the terms of the GNU General Public License as published by
;	// the Free Software Foundation, either version 3 of the License, or
;	// (at your option) any later version.
;	// 
;	// UnoDOS 3 is distributed in the hope that it will be useful,
;	// but WITHOUT ANY WARRANTY; without even the implied warranty o;
;	// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;	// GNU General Public License for more details.
;	// 
;	// You should have received a copy of the GNU General Public License
;	// along with UnoDOS 3. If not, see <http://www.gnu.org/licenses/>.

; 	// This source is compatible with Zeus
;	// (http://www.desdes.com/products/oldfiles)


;	// I/O
ula equ $fe;


;	// BASIC ROM ROUTINES
print_a		equ $0010;		// rst $10
get_char	equ $0018;		// rst $18
next_char	equ $0020;		// rst $20
bc_spaces	equ $0030;		// rst $30
reentry		equ $007b;		// IF1 reentry point
k_test		equ $031e;
print_out	equ $09f4;		// screen channel
key_scan	equ $028e;
beeper		equ $03b5;
me_new_lp	equ $08d2;
cls_lower	equ $0d6e;
add_char	equ $0f81;
remove_fp	equ $11a7;
chan_open	equ $1601;
make_room	equ $1655;
set_min		equ $16b0;
set_work	equ $16bf;
line_addr	equ $196e;
each_stmt	equ $198b;
next_one	equ $19b8;
reclaim_1	equ $19e5;
e_line_no	equ $19fb;
check_end	equ 0x1bee
expt_2num	equ $1c7a;
expt_1num	equ $1c82;
expt_exp	equ $1c8c;
use_zero	equ $1ce6;
find_int2	equ $1e99;
test_room	equ $1f05;
pr_st_end	equ $2048;
syntax_z	equ $2530;
stk_fetch	equ $2bf1;
stack_bc	equ $2d2b;
fp_to_bc	equ $2da2;


;	// BASIC SYSTEM VARIABLES
last_k		equ $5c08;		// stores newly pressed key.
defadd		equ $5c0b;		// address of arguments of user defined function
;							// if one is being evaluated; otherwise 0. 
strms_0		equ $5c16;		// keyboard stream.
chars		equ $5c36;		// 256 less than address of character set (which
;							// starts with space and carries on to the
;							// copyright symbol). Normally in ROM, but you
;							// can set up your own in RAM and make CHARS
;							// point to it. 
err_nr		equ $5c3a;		// 1 less than the report code. Starts off at 255
;							// (for 1) so PEEK 23610 gives 255. 
err_sp		equ $5c3d;		// address of item on machine stack to be used as
;							// error return.
newppc		equ $5c42;		// line to be jumped to.
ppc			equ $5c45;		// line number of statement currently being
;							// executed. 
bordcr		equ $5c48;		// border color * 8; also contains the attributes
;							// normally used for the lower half of the screen.
vars		equ $5c4b;		// address of variables.
chans		equ $5c4f;		// address of channel data.
prog		equ $5c53;		// address of BASIC program.
curchl		equ $5c51;		// address of information currently being used
;							// for input and output.
datadd		equ $5c57;		// address of terminator of last DATA item.
e_line		equ $5c59;		// address of command being typed in.
ch_add		equ $5c5d;		// address of the next character to be
;							// interpreted: the character after the argument.
;							// of PEEK, or the NEWLINE at the end of a POKE
;							// statement. 
x_ptr		equ $5c5f;		// address of the character after the ? marker. 
worksp		equ $5c61;		// address of workspace.
stkbot		equ $5c63;		// address of end of spare space.
stkend		equ $5c65;		// address of start of spare space.
frames		equ $5c78;		// 3 byte (least significant first), frame counter.
attr_p		equ $5c8d;		// permanent colors, etc. (as set up by color
;							// statements).
attr_t		equ $5c8f;		// temporary current colors, etc. (as set up by
;							// color items). 
df_cc		equ $5c84;		// address in display file of PRINT position. 
s_posn		equ $5c88;		// 33 column number for PRINT position.
nmiadd		equ $5cb0;		// the address of a user supplied NMI address
;							// which is read by the standard ROM when a
;							// peripheral activates the NMI. Probably
;							// intentionally disabled so that the effect is
;							// to perform a reset if both locations hold
;							// zero, but do nothing if the locations hold a
;							// non-zero value.


;	// IY OFFSETS TO BASIC SYSTEM VARIABLES;
_err_nr		equ $00;
_flags		equ $01;
_tv_flag	equ $02;
_err_sp		equ $03;
_newppc		equ $08;
_subppc		equ $0d;
_nxtlin_h	equ $1c;
_x_ptr		equ $25;
_x_ptr_h	equ $26;
_oldppc		equ $34;
_flag_x		equ $37;
_udg_h		equ $42;
_coord_x	equ $43;
_coord_y	equ $44;