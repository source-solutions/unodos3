# UnoDOS 3 Programmer's Guide

## Introduction
UnoDOS 3 is a Z80-based operating system designed for the divMMC SD card interface, providing advanced file, memory, and device management for ZX Spectrum-compatible systems. This guide covers the architecture, memory map, system variables, kernel structure, and programming conventions for UnoDOS 3.

---

## System Architecture
- **Target Platform:** ZX Spectrum + divMMC
- **Core Language:** Z80 Assembly
- **Main Components:**
  - Kernel (src/kernel.asm)
  - I/O and OS includes (src/io.inc, src/os.inc)
  - Scripts for build/label management (scripts/)
  - Documentation (docs/)

---

## Memory Map and Temporary Variables
UnoDOS 3 uses the $3C00-$3C2B range for temporary variables critical to system operations. These are documented in detail in `docs/temporary_variables_3c00.md`.

### $3C00-$3C2B: Temporary/System Variables
| Address | Size | Purpose | Description |
|---------|------|---------|-------------|
| $3C00   | 2    | Font/Messages Pointer | Points to font or message data in verbose mode |
| $3C01   | 1    | Operation Flags | File access mode flags and operation status |
| $3C04   | 2    | System Variable | Search filename pointer, general HL storage |
| $3C06   | Multi| Filename Buffer | Formatted filename buffer for file operations |
| $3C11   | 2    | Sector Address Low | Low word of 32-bit sector address |
| $3C13   | 2    | Sector Address High | High word of 32-bit sector address |
| $3C14   | Multi| Cluster Number Buffer | Cluster number storage for file system operations |
| $3C15   | 2    | Base Address Copy | Backup copy of memory base address |
| $3C17   | 2    | Size Copy | Backup copy of memory size value |
| $3C19   | 2    | Memory Pointer | Current memory allocation pointer |
| $3C1B   | Multi| File Buffer Address | File buffer management and directory operations |
| $3C1E   | Multi| Comparison Buffer | Buffer address for filename comparisons |
| $3C1F   | 2    | Counter/DateTime | First counter variable or date/time information |
| $3C20   | 2    | Counter Variable | Second counter variable for loops |
| $3C21   | 2    | Cluster Number | Current cluster number for file operations |
| $3C22   | 2    | Buffer Address | General purpose buffer address |
| $3C23   | Multi| File Parameters | Drive number, file attributes, cluster/directory info |
| $3C25   | 1    | Disk Drive Number | Current disk drive identifier |
| $3C26   | 1    | System Flags | Sector modification flag and system status |
| $3C27   | 2    | DE Buffer Storage | Temporary storage for DE register pair |
| $3C29   | 2    | BC Buffer Storage | Temporary storage for BC register pair |
| $3C2A   | 2    | Buffer Address | General buffer address pointer |
| $3C2B   | 1    | Dirty Buffer Flag | Indicates if buffer needs flushing to disk |

**See `docs/temporary_variables_3c00.md` for detailed descriptions and usage examples.**

---

## Kernel Structure (`src/kernel.asm`)
The kernel is modular, with each section handling a specific aspect of the OS. Key regions include:
- **Restart Vectors:** RST $00, $08, $10, $18, $20, $28, $30, $38, $66
- **Initialization:** System, memory, and device setup
- **Screen and I/O:** Display, keyboard, and device routines
- **File System:** File open, read, write, directory, and buffer management
- **Math/Formatting:** 32-bit arithmetic, number formatting, and display
- **Error Handling:** Centralized error codes and handlers

### Section Highlights
- **Entry Points:**
  - `start` ($0000): System reset entry
  - `restart_08` ($0008): Main API entry
  - `restart_10` ($0010): Print character
  - `restart_18` ($0018): Call BASIC ROM routine
  - `restart_20` ($0020): Next char handler
  - `maskint` ($0038): Maskable interrupt
  - `NMI` ($0066): Non-maskable interrupt
- **Auxiliary Routines:**
  - `keyboard_test_pattern`: Keyboard scan test
  - `char_process_continue`: Character processing continuation
  - `vector_dispatcher`, `vector_lookup`: Internal call dispatch
- **File Operations:**
  - `save_command_trap`, `load_command_trap`: Automapped entry points
  - `open_file_read`, `close_file_page0`, `read_file_data`, etc.
- **Math/Formatting:**
  - `load_32bit_value`, `compare_32bit`, `inc_32bit`, `format_file_size`, etc.

---

## System Variables and Equates
System variables are defined in `src/os.inc` and `src/io.inc`.

### Examples from `os.inc`:
- `mmcram`, `mmcdev`, `mmcspi`: divMMC I/O ports
- `mmc_1`, `mmc_2`, `mmc_3`, `mmc_sp`: divMMC RAM page variables
- `cur_drive`: Current SD card
- `ext_cmd`: Current external command
- `hook_base`, `misc_base`, `fsys_base`: Hook code bases
- `disk_read`, `disk_write`, `disk_ioctl`, etc.: Disk operation codes
- `f_open`, `f_close`, `f_read`, `f_write`, etc.: File system operation codes
- `EOK`, `EIO`, `ENOENT`, etc.: Error codes

### Examples from `io.inc`:
- `ula`: ULA I/O port
- `print_a`, `get_char`, `next_char`, etc.: BASIC ROM routines
- `last_k`, `defadd`, `strms_0`, `chars`, `err_nr`, `err_sp`, etc.: BASIC system variables
- IY-relative system variables: `_err_nr`, `_flags`, `_tv_flag`, etc.

---

## Programming Conventions
- **Tabs:** 4 spaces per tab; comments (`//`) aligned at column 41
- **Labels:** Use meaningful names; avoid generic labels (e.g., L0000)
- **Section Headers:** Use clear, consistent headers for each module/section
- **Temporary Variables:** Use $3C00 range for workspace/temporary data
- **Register Usage:** HL, DE, BC, IX, IY used for parameter passing and temporary storage
- **Stack Management:** System and user stacks are separated (e.g., SP set to $5e00 or $3de8)
- **Error Handling:** Use centralized error codes and handlers

---

## Build and Automation
- **Build Scripts:** Use `scripts/build.sh` (Unix) or `scripts/build.cmd` (Windows) to assemble the kernel and generate binaries.
- **Label Management:**
  - `scripts/replace_labels.sh`: Replace generic labels with meaningful names
  - `scripts/cleanup_old_labels.sh`: Remove obsolete label references
- **Output:**
  - `bin/unodos.rom`: Main ROM image
  - `bin/unodos.sys`, `bin/dos/`: System files and drivers

---

## Extending UnoDOS 3
- **Add new commands:** Place in `src/commands/` or `src/commands/contrib/`
- **Kernel Extensions:** Place in `src/kexts/`
- **Document new variables:** Update `docs/temporary_variables_3c00.md` and relevant includes
- **Follow formatting and naming conventions**

---

## References
- `src/kernel.asm`: Main kernel source
- `src/os.inc`, `src/io.inc`: System and I/O variable definitions
- `docs/temporary_variables_3c00.md`: Temporary/system variable documentation
- `README.md`: Project overview

---

*For further details, review the source files and documentation in the UnoDOS 3 repository.*
