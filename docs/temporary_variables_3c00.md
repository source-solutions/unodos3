# UnoDOS 3 Temporary Variables ($3C00 Range)

This document lists all temporary variables stored in the $3C00 memory range used by the UnoDOS 3 kernel for various system operations.

## Memory Map ($3C00-$3C2B)

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

## Detailed Descriptions

### Sector Address Management ($3C11, $3C13)
These form a 32-bit sector address used throughout the file system operations:
- $3C11-$3C12: Low 16 bits of sector address
- $3C13-$3C14: High 16 bits of sector address

### Memory Management ($3C15, $3C17, $3C19)
Used for dynamic memory allocation and management:
- $3C15: Base address backup for memory operations
- $3C17: Size backup for memory operations  
- $3C19: Current memory pointer during allocation

### File System Operations ($3C06, $3C1B, $3C21, $3C23)
Critical variables for file and directory operations:
- $3C06: Formatted filename buffer (variable length)
- $3C1B: File buffer for directory entries and file data
- $3C21: Current cluster number being processed
- $3C23: Multi-purpose storage for file attributes and parameters

### Buffer Management ($3C26, $3C27, $3C29, $3C2B)
Used for disk buffer cache management:
- $3C26: Flags indicating buffer modification status
- $3C27: Temporary DE register storage during buffer operations
- $3C29: Temporary BC register storage during buffer operations
- $3C2B: Dirty flag indicating buffer needs disk write

### Counters and Temporary Storage ($3C1F, $3C20, $3C25)
General purpose variables for loops and temporary data:
- $3C1F: Counter variable or date/time storage
- $3C20: Second counter for nested operations
- $3C25: Current disk drive number (0-based)

## Additional Temporary/System Variables in UnoDOS 3 Kernel

### Memory Locations and Variables

- **$3C00**  
  - Used as a pointer for font/messages and to enable verbose mode.  
  - Example: `ld hl, $3c00 ; enable verbose mode (point to font/messages)`

- **mmc_1, mmc_2, mmc_3, mmc_sp**  
  - Temporary storage for memory page configuration and stack pointer during MMC/divMMC operations.  
  - Example:  
    - `ld (mmc_2), hl ; save HL to MMC temporary storage`  
    - `ld hl, (mmc_sp) ; load MMC stack pointer`

- **x_ptr**  
  - Pointer to a marker in BASIC, used for temporary storage of HL.  
  - Example: `ld (x_ptr), hl ; save HL to ? marker pointer in BASIC`

- **ch_add**  
  - Pointer to the next character in a BASIC program.

- **err_nr**  
  - System variable for error number/status.

- **keyboard_test_pattern**  
  - Used for keyboard scanning routines.

- **cmd_folder**  
  - Holds the string "/dos/" to avoid keyword clashes.

- **next_char_rst20, restart_20**  
  - Used for interrupt/restart handling.

- **sp, af, hl, bc, de, ix, iy**  
  - Z80 register pairs, often used for temporary storage and parameter passing.

- **mmcram, mmcdev**  
  - I/O ports for divMMC RAM page and device selection.

- **_flags, _err_nr, _newppc, _tv_flag, _err_sp**  
  - System variables (often in IY-relative addressing) for flags, error numbers, file handles, etc.

### General Patterns

- **Stack Usage**  
  - The stack pointer (`sp`) is frequently set to specific addresses (e.g., `$5e00`, `$3de8`) for system and user stack separation.
- **Temporary Buffers**  
  - HL, DE, and BC are often used as temporary buffers for data transfer, especially in block and file I/O routines.
- **Page and Memory Management**  
  - Variables like `mmc_1`, `mmc_2`, `mmc_3` are used to save/restore memory page states during bank switching.

### Example Usage

```assembly
ld hl, $3c00        ; HL points to font/messages area (temporary)
ld (mmc_2), hl      ; Save HL to MMC temporary storage
ld hl, (mmc_sp)     ; Load MMC stack pointer
ld (x_ptr), hl      ; Save HL to marker pointer in BASIC
ld hl, (ch_add)     ; Get pointer to next character in BASIC program
ld a, (err_nr)      ; Load error number
```

**Note:**
This list is not exhaustive but covers the most prominent temporary and system variables used in the kernel source, especially those related to $3C00 and other workspace/system areas. For a complete list, review the `os.inc` and `io.inc` includes, as they may define additional system variables and workspace locations.

## Usage Notes

- Variables marked as "Multi" may extend beyond their listed address
- Some addresses serve dual purposes depending on the operation context
- Critical to preserve these variables across function calls in the kernel
- The $3C range appears to be dedicated temporary storage, not persistent data

## Related Files

- `kernel.asm`: Main kernel file using these variables
- `08_memory.asm`: Memory management functions
- File system modules using sector and cluster variables

---
*Generated from UnoDOS 3 kernel analysis - addresses based on actual usage patterns in kernel.asm*