## Warning
This software may cause data loss.

## Legal
UnoDOS III is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

UnoDOS III is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty o;
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with UnoDOS 3. If not, see <http://www.gnu.org/licenses/>.

## Install (Chloe 280SE)
Updates to the UnoDOS III kernel are included in the firmware update binary.
Place the binary on the root of your SD card and power cycle your computer.

## Clean install (divMMC)
1. Set write enable on the EEPROM.
2. Install the firmware on your divMMC using the `unodos.tap` file.
3. Set write protect on the EEPROM.
4. Copy the DOS folder to the root folder of your SD card.

## Test install (divMMC)
If you have an existing esxDOS system installed you can perform a test install.
1. Copy the `DOS` folder to the root folder of your SD card.
2. Copy `unodos.tap` to your SD card.
3. Set write protect on the EEPROM.
4. From esxDOS, mount the `unodos.tap` file and load the flash utility.
5. Press <kbd>Enter</kbd>, then after installation hold <kbd>Space</kbd> and press RESET.

## Upgrade (divMMC)
If you have an existing esxDOS system installed you can convet it to UnoDOS.
1. Copy the `DOS` folder to the root folder of your SD card.
2. Copy `unodos.tap` to your SD card.
3. Set write enable on the EEPROM.
4. From esxDOS, mount the `unodos.tap` file and load the flash utility.
5. Set write protect on the EEPROM.

## Upgrade (ZX-Uno)
1. Copy the `DOS` folder to the root folder of your SD card.
2. Rename `UNODOS.ROM` to `ESXDOS.ZX1` and copy it to the root of your SD card.
3. From the BIOS, select "Upgrade ESXDOS for ZX".
4. Restart your machine.

## Upgrade (ZEsarUX)
1. Copy the DOS folder to the root folder of your SD image.
2. Rename `unodos.rom` to `esxmmc085.rom` and copy it to the ZEsarUX folder.

## Boot mode
By default, UnoDOS III performs a silent boot. To display information, hold
down <kbd>Shift</kbd> during boot.

## Commands
UnoDOS III includes only the `RUN` command. This is used to launch apps.
You can use any commands that are compatible with the esxDOS 0.8.5 API.
Place them in the DOS folder. You can find some useful commands here:
<https://github.com/nagydani/dot-commands>

## BetaDisk emulation by Pheonix
The following external files that are not part of UnoDOS III are included in this
distribution:
* `BETADISK.SYS`: emulator
* `TRDOS-5.04T`: firmware
* `CONFIG/TRDOS.CFG`: config file
* `VDISK`: mount command

Copyright © 2017-2020 Source Solutions, Inc.
