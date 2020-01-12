;	// UnoDOS 3 - An operating system for the divMMC SD card interface.
;	// Copyright (c) 2017-2020 Source Solutions, Inc.

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

include "../io.inc"
include "../os.inc"

org $2800;
L2800:
	ld a, b;
	and a;					// CP 0
	jp z, L2899;
	cp 1;
	jp z, L2908;
	cp 2;
	jp z, L2879;
	cp 3;
	jr z, L281C;
	cp 4;
	jr z, L286A;
	cp 5;
	jr z, L286F;
	ret;

L281C:
	ld a, ($2D4B);
	and a;
	ret z;
	push de;
	call L285A;
	pop de;
	ld a, e;
	or d;
	ret z;

L2829:;
	ld bc, 3;
	ld hl, $2E7C;
	push de;
	call L2AAF;
	pop de;
	ret c;
	ld a, c;
	cp 3;
	jr z, L283E;
	ld a, 255;
	scf;
	ret;

L283E:
	push de;
	ld hl, ($2E7C);
	dec hl;
	ex de, hl;
	ld l, 1;
	ld bc, 0;
	call L2AA9;
	pop de;
	ret c;
	call L2AB5;
	ld a, d;
	cp h;
	jr nz, L2829;
	ld a, e;
	cp l;
	ret z;
	jr L2829;

L285A:
	ld de, 0;
	ld l, e;
	ld bc, 0;
	push bc;
	call L2AA9;
	pop hl;
	ld ($2E86), hl;
	ret;

L286A:
	ld hl, ($2E86);
	or a;
	ret;

L286F:
	ld a, ($2E88);
	xor 1;
	ld ($2E88), a;
	or a;
	ret;

L2879:
	ld a, ($2D4B);
	and a;
	ret z;
	ex de, hl;
	ld hl, $261A;
	rst $30;
	inc b;
	ld a, ($2E85);
	or a;
	ret;

L2889:
	ld a, ($2D4C);
	and a;
	ret z;
	ex de, hl;
	ld hl, $269A;
	rst $30;
	inc b;
	ld a, ($2E84);
	or a;
	ret;

L2899:
	call L2908;
	call L28B5;
	ld ($2E85), a;
	ld b, 1;
	ld de, $261A;
	call L2915;
	ret c;
	ld ($2D4B), a;
	ld hl, 0;
	ld ($2E86), hl;
	ret;

L28B5:
	ld a, ixh;
	cp $2A;
	ret nz;
	ld a, ($2D46);
	ret;
	ld a, b;
	and a;
	ld b, 10;
	jr z, L28D4;
	cp 1;
	jp z, L28FB;
	cp 2;
	jr z, L2889;
	cp 3;
	ld b, 14;
	jr z, L28D4;
	ret;

L28D4:
	push bc;
	call L28FB;
	call L28B5;
	ld ($2E84), a;
	ld de, $269A;
	pop bc;
	call L2915;
	ret c;
	ld hl, $2DCE;
	ld ($2D4C), a;
	rst $08;
	defb f_fstat;
	ld hl, $2DD5;
	ld a, ($2D4C);
	rst $30;
	ld bc, $002E;
	rst $08;
	defb f_seek;
	ret;

L28FB:
	ld a, ($2D4C);
	and a;
	ret z;
	call L2938;
	xor a;
	ld ($2D4C), a;
	ret;

L2908:
	ld a, ($2D4B);
	and a;
	ret z;
	call L2938;
	xor a;
	ld ($2D4B), a;
	ret;

L2915:
	push de;
	push af;
	push bc;
	ld de, $2D4E;
	push de;
	rst $30;
	dec b;
	pop hl;
	pop bc;
	pop af;
	rst $08;
	defb f_open;
	pop de;
	ret c;
	push af;
	ld a, ($3DF8);
	ld c, a;
	ld a, b;
	ld ($3DF8), a;
	push bc;
	rst $30;
	dec b;
	pop bc;
	ld a, c;
	ld ($3DF8), a;
	pop af;
	ret;

L2938:
	push hl;
	ld hl, ($3DF8);
	push hl;
	rst $08;
	defb f_close;
	pop hl;
	ld ($3DF8), hl;
	pop hl;
	ret;

L2945:
	ld a, ($2D4C);
	rst $08;
	defb f_write;
	ret;
	ld ($2AD7), sp;
	ld sp, $3DEA;
	di;
	inc de;
	inc de;
	ld hl, $2E7F;
	ld bc, 3;
	ld ($2E81), a;
	ld ($2E7F), de;
	call L2945;
	jp c, L29F3;
	ld bc, ($2E7F);
	dec bc;
	dec bc;
	ld a, b;
	or c;
	jr z, L298B;
	push ix;
	push bc;
	push ix;
	pop hl;
	call L2945;
	pop bc;
	pop hl;
	jr c, L29A8;
	ld a, ($2E81);

L2982:
	xor (hl);
	cpi;
	jp pe, L2982;
	ld ($2E81), a;

L298B:
	ld bc, 1;
	ld hl, $2E81;
	call L2945;
	jr c, L29A8;
	ld bc, ($2E7F);
	ld a, c;
	or b;
	cp 20;
	jr c, L29A5;
	ld a, ($2D4C);
	rst $08;
	defb f_sync;

L29A5:
	jp L2A8D;

L29A8:
	ld a, ($2D4C);
	rst $08;
	defb f_sync;
	jr L29F3;
	ld ($2AD7), sp;
	ld a, (bordcr);
	ld sp, $3DEA;
	rra;
	rra;
	rra;
	and 7;
	out ($FE), a;
	ex af, af';
	jr c, L29C8;
	add ix, de;
	jp L2A8D;

L29C8:
	ld bc, 3;
	ld hl, $2E7C;
	ld ($2E7F), de;
	ld ($2E81), a;
	call L2AAF;
	jr c, L29F3;
	ld a, c;
	cp 3;
	jr z, L29F8;
	ld l, 0;
	ld b, l;
	ld c, l;
	ld d, l;
	ld e, l;
	call L2AA9;
	jr c, L29F3;
	ld hl, 0;
	ld ($2E86), hl;
	jp L2AA6;

L29F3:
	scf;
	ccf;
	jp L2AD6;

L29F8:
	ld a, ($2E81);
	ld hl, $2E7E;
	cp (hl);
	jp nz, L2A93;
	ld hl, ($2E7C);
	dec hl;
	dec hl;
	ld de, ($2E7F);
	or a;
	sbc hl, de;
	jr z, L2A1c;
	jr c, L2A1a;
	dec hl;
	ld ($2E8A), hl;
	ld a, 1;
	jr L2A31;

L2A1a:
	add hl, de;
	ex de, hl;

L2A1c:
	push ix;
	pop hl;
	ld a, h;
	cp '@';
	jr c, L2A4E;
	xor a;
	dec hl;
	add hl, de;
	jr nc, L2A31;
	ld ($2E8A), hl;
	ex de, hl;
	sbc hl, de;
	ex de, hl;
	inc a;

L2A31:
	ld c, e;
	ld b, d;
	ld ($2E89), a;
	push ix;
	pop hl;
	push hl;
	call L2AAF;
	pop de;
	jr c, L29F3;
	call L2ABd;
	ld a, ($2E89);
	and a;
	jr z, L2A62;
	ld de, ($2E8A);
	inc de;

L2A4E:
	add hl, de;
	push hl;
	pop ix;
	inc de;
	ld l, 1;
	ld bc, 0;
	call L2AA9;
	jr c, L29F3;
	call L2AB5;
	jr L2A8D;

L2A62:
	push ix;
	push hl;
	pop ix;
	ld bc, 1;
	ld hl, $2A85;
	call L2AAF;
	call L2AB5;
	pop hl;
	jp c, L29F3;
	ld bc, ($2E7F);
	ld a, ($2E7E);

L2A7e:
	xor (hl);
	cpi;
	jp pe, L2A7e;
	cp 0;					// could probably use AND A
	jr z, L2A8D;
	xor a;
	scf;
	ccf;
	jr L2AD6;

L2A8D:
	scf;
	ld de, 0;
	jr L2AD6;

L2A93:
	ld hl, ($2E7C);
	dec hl;
	ex de, hl;
	ld l, 1;
	ld bc, 0;
	call L2AA9;
	jp c, L29F3;
	call L2AB5;

L2AA6:
	cp a;
	jr L2AD6;

L2AA9:
	ld a, ($2D4B);
	rst $08;
	defb f_seek;
	ret;

L2AAF:
	ld a, ($2D4B);
	rst $08;
	defb f_read;
	ret;

L2AB5:
	ld hl, ($2E86);
	inc hl;
	ld ($2E86), hl;
	ret;

L2ABd:
	ld a, ($2E88);
	and a;
	ret z;
	ld a, e;
	add a, d;
	cp '@';
	ret nz;
	ld de, ($2E7F);
	ld a, e;
	add a, d;
	cp $1B;
	ret nz;
	ld de, $07D0;
	jp V0297;				// UnoDOS call

L2AD6:
	ld sp, 0;
	jp V1FFA;				// UnoDOS call
