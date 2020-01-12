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

org $2800
L2800:
	defb $80
	defb "O", 'k' + $80
	defb "Syntax erro", 'r' + $80
	defb "Statement los", 't' + $80
	defb "Wrong file typ", 'e' + $80
	defb "Missing file or folde", 'r' + $80
	defb "I/O erro", 'r' + $80
	defb "Bad filenam", 'e' + $80
	defb "Access denie", 'd' + $80
	defb "Disk ful", 'l' + $80
	defb "Bad I/O reques", 't' + $80
	defb "No such driv", 'e' + $80
	defb "Too many open file", 's' + $80
	defb "Bad file descripto", 'r' + $80
	defb "No such devic", 'e' + $80
	defb "File pointer overflo", 'w' + $80
	defb "Is a folde", 'r' + $80
	defb "Not a folde", 'r' + $80
	defb "File exist", 's' + $80
	defb "Bad pat", 'h' + $80
	defb "Missing SY", 'S' + $80
	defb "Path too lon", 'g' + $80
	defb "No such comman", 'd' + $80
	defb "File in us", 'e' + $80
	defb "File is read onl", 'y' + $80
	defb "Verify faile", 'd' + $80
	defb "Loading .IO faile", 'd' + $80
	defb "Folder not empt", 'y' + $80
	defb "MAPRAM activ", 'e' + $80
	defb "Drive bus", 'y' + $80
	defb "Unknown file syste", 'm' + $80
	defb "Device bus", 'y' + $80
