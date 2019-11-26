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

	output_bin "run", $2000, $0200
	include "hookcodes.inc"

	org $2000

start:
	ld a, l;							// test for
	or h;								// args
	jr nz, run_app;						// jump if found

error:
	scf;								// use UnoDOS error
	ld a, 2;							// syntax error
	ret;								// print it

get_dest:
	ld de, progname;					// destination
	ld bc, $0bff;						// LD B, 11; LD C, 255;

first_11:
	ld a, (hl);							// get character
	and a;								// test for zero
	ret z;								// return if so
	cp ':';								// new statement?
	ret z;								// return if so
	cp $0d;								// end of statement?
	ret z;								// return if so
	ldi;								// copy byte
	djnz first_11;						// loop until done 
	ex de, hl;							// end to HL
	ld (hl), 0;							// set end marker
	ret;								// done

run_app:
	call get_dest;						// app name to second buffer
	ld hl, basepath;					// base path
	ld de, buffer;						// point to first buffer
	ld bc, 10;							// byte count
	ldir;								// copy basepath

	ld hl, progname;					// source
	ld bc, 11;							// maximum name length

copy11:
	ld a, (hl);							// get character
	cp ' ';								// is it a space?
	jr nz, not_space;					// jump if not
	ld a, '_';							// substitute underline
	ld (hl), a;							// write it back

not_space:
	ldi;								// write contents of HL to DE, decrement BC
	ld a, (hl);							// next character
	and a;								// test for zero
	jr z, endcp11;						// jump if end of filename reached
	ld a, c;							// test count
	or b;								// for zero
	jr nz, copy11;						// loop until done

endcp11:
	ld hl, prgpath;						// complete path
	ld bc, 6;							// byte count
	ldir;								// copy it

	ld a, '*';							// use current drive
	ld hl, buffer;						// pointer to path
	rst divmmc;							// issue a hookcode
	defb f_chdir;						// change folder
	jr c, error;						// return with error

	ld (oldsp), sp;						// save old SP
	ld sp, $6000;						// lower stack

; get shortname
	ld hl, progname - 1;				// start of filename - 1
	ld b, 9;							// maximum name length + 1

skip8:
	inc hl;								// next character
	ld a, (hl);							// get character
	and a;								// test for zero
	jr z, endskp8;						// jump if end of filename reached
	djnz skip8;							// loop until done

endskp8:
	ex de, hl;							// destination to DE
	ld hl, appname;						// tail end of short name
	ld bc, 5;							// five bytes to copy
	ldir;								// copy it
; end of get shortname

	ld hl, progname;					// program name
	ld a, '*';							// use current drive
	ld b, fa_read | fa_open_ex;			// open for reading if file exists
	rst divmmc;							// issue a hookcode
	defb f_open;						// open file
	jr c, error;						// jump if error
	ld (handle), a;						// store handle

	ld hl, f_stats;						// buffer for file stats
	rst divmmc;							// issue a hookcode
	defb f_fstat;						// get file stats
	jp c, error;						// jump if error

	ld a, (handle);						// restore handle
	ld bc, (f_size);					// get length
	ld hl, $6000;						// get address

	rst divmmc;							// issue a hookcode
	defb f_read;						// 
	jp c, error;						// jump if error
	ld a, (handle);						// 
	rst divmmc;							// issue a hookcode
	defb f_close;						// 
	jr c, app_not_found;				// jump if error

	ld a, '*';							// use current drive
	ld hl, resources;					// path to resource fork
	rst divmmc;							// issue a hookcode
	defb f_chdir;						// change folder

	ld hl, $6000;						// start of app
	push hl;							// stack it
	jp $1ffa;							// jump to page out MMC and ret

app_not_found:
	ld sp, (oldsp);						// restore stack pointer
	jp c, error;						// jump if error

basepath:
	defb "/programs";					// "/programs/" (continues into progpath)

prgpath:
	defb "/prg";						// "/prg/", 0 (continues into rootpath)
	
rootpath:
	defb '/', 0;						// root	

appname:
	defb ".prg", 0;						// application extension

resources:
	defb "../rsc", 0;					// resource folder

oldsp:
	defw 0;								// old stack pointer

handle:
	defb 0;								// file handle

f_stats:

drive:
	defb 0;

device:
	defb 0;

f_attr:
	defb 0;

f_time:
	defw 0;

f_date:
	defw 0;

f_size:
	defw 0, 0;

f_addr:
	defw 0;

progname:
	defs 32, 0;							// program name

buffer:
	defw 0;								// buffer
