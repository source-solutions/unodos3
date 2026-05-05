# UnoDOS 3.141 Ram

This project maintains the sources of the UnoDOS 3 kernel.

It is used as the disk operating system in the firmware of the [Chloe 280SE](https://www.patreon.com/c/chloe280se)

## Kernel

The kernel provides a set of system calls, accessed by the `RST 8` instruction, followed by the system code.

## Binary snapshots

UnoDOS 3 is distributed in two parts (`unodos.rom` and `unodos.sys`). The ROM file should be flashed to the divMMC. The system file can be loaded to divMMC RAM from the SD card, but on the Chloe 280SE it is loaded from the boot ROM.

## Build instructions

The preferred IDE is [Visual Studio Code](https://code.visualstudio.com/).

The preferred assembler is [RASM](https://github.com/EdouardBERGE/rasm).

## Version numbering

UnoDOS 3 follows the TeX versioning convention.

## License

Copyright &copy; 2017-2026 Source Solutions, Inc. All rights reserved.

Licensed under the [GNU General Public License](LICENSE).
