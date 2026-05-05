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

;	// RASM directives
	save "../bin/unodos.rom", 0, $2000
	save "../bin/unodos0.sys", $2000, lower_end-$2000
	save "../bin/unodos1.sys", $3000, upper_end-$3000

	include "os.inc"
	include "io.inc"

    include "01_restarts.asm"			// restart vectors and interrupt handlers
    include "02_init.asm"				// system initialization and startup routines
    include "03_system_loader.asm"		// system loading and ROM management functions
	include "04_tape.asm"				// tape loading and saving traps
	include "05_arithmetic.asm"			// 32-bit arithmetic functions
	include "06_formatting.asm"			// file system formatting routines
	include "07_dispatcher.asm"			// system call dispatcher and file handle management
	include "08_error.asm"				// error handling and reporting routines
	include "09_filesystem.asm"			// file system operations
	include "10_cluster_nav.asm"		// cluster navigation functions
	include "11_folders.asm"			// folder management functions
	include "12_file_io.asm"			// file input/output operations
	include "13_boot_data.asm"			// data structures and system tables
    include "14_spi.asm"				// SPI communication for SD card interface
    include "15_romtest.asm"			// ROM testing and validation functions
    include "16_vector.asm"				// vector table management
    include "17_basic.asm"				// BASIC ROM integration and extensions
	include "18_commands.asm"			// command processing and execution routines
	include "19_fat_high.asm"			// FAT file system high-level functions
	include "20_low_utils.asm"			// low-level utility functions
