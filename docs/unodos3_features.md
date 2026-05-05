# UnoDOS 3: Features and Capabilities

UnoDOS 3 is a modern, modular operating system for the ZX Spectrum and compatible systems, designed to leverage the divMMC SD card interface. It provides advanced file, device, and memory management, along with a robust API for developers and users.

---

## Key Features

### 1. Advanced File System Support
- FAT-compatible file system for SD cards
- Support for files, folders, and subdirectories
- File operations: open, read, write, seek, close, delete, rename
- Directory operations: create, remove, list, change directory
- File attributes and status retrieval
- Large file support (32-bit addressing)

### 2. Modular Kernel Architecture
- Clean separation of core OS, device drivers, and extensions
- Easily extendable via kernel extensions and external commands
- Well-documented kernel source with modular sections for restarts, I/O, file system, math, formatting, and error handling

### 3. Device & Memory Management
- Dynamic memory allocation and management routines
- Support for divMMC RAM paging and device selection
- Temporary variable workspace ($3C00 range) for efficient system operations
- Stack management for system/user separation

### 4. Robust API & System Calls
- RST vector-based API for system calls and user programs
- Hook codes for disk, file, and device operations
- Centralized error handling with standardized error codes
- Support for external commands and user extensions

### 5. User & Developer Tools
- Build scripts for automated assembly and binary generation
- Label management scripts for code clarity and maintainability
- Comprehensive documentation for system variables, memory map, and kernel structure
- Example code and usage patterns for common operations

### 6. Compatibility & Integration
- Designed for ZX Spectrum + divMMC hardware
- Integrates with BASIC ROM routines and system variables
- Compatible with existing ZX Spectrum software conventions

### 7. Performance & Reliability
- Efficient buffer and cache management for file I/O
- Optimized routines for 32-bit arithmetic and formatting
- Error recovery and fallback mechanisms for device operations

---

## Summary Table

| Area                | Capabilities                                                      |
|---------------------|------------------------------------------------------------------|
| File System         | FAT, files/folders, 32-bit, attributes, seek, delete, rename      |
| Device Management   | divMMC RAM, device selection, paging                             |
| Memory Management   | Dynamic allocation, workspace variables, stack separation         |
| API/System Calls    | RST vectors, hook codes, error codes, external commands           |
| Extensibility       | Kernel extensions, user commands, modular source                 |
| Build/Automation    | Scripts for build, label replacement, cleanup                    |
| Documentation       | Memory map, variables, kernel structure, usage examples          |
| Compatibility       | ZX Spectrum, BASIC ROM, divMMC                                   |
| Performance         | Optimized I/O, 32-bit math, buffer management                    |

---

*For more details, see the Programmer's Guide and source documentation in the UnoDOS 3 repository.*
