  The SD card initialization lives entirely in 14_spi.asm (lines 5272–5785). Here's the specific breakdown:

  ---
  The current flow (lines 5311–5404):

  sd_card_command_setup (line 5311) is the main orchestrator. It calls:
  1. deselect_all_cards → cmd0_go_idle (lines 5417–5436): sends CMD0 with 8 retries
  2. send_interface_condition (line 5373): sends CMD8 with check pattern $01AA, then selects an init path
  3. A command-specific path via jump_card_specific_init: jp (hl) (line 5403)

  The path selection in send_interface_condition (lines 5377–5380):
  ld hl, $1d65;   // address for SDHC cards      <-- comment is WRONG
  jr c, set_retry_counter;                        // CMD8 failed → keep $1d65
  ld hl, $1d20;   // address for standard SD cards <-- comment is WRONG

  The comments are inverted. Tracing the source order:
  - $1d20 is the unlabeled ACMD41+HCS path at line 5395 (CMD55 → ACMD41 with bc=$4000) — this is the modern SDv2 path
  - $1d65 is the unlabeled CMD1 path at line 5445 (ld a, $41) — this is the old MMC path

  So the logic is actually correct: if CMD8 fails (old card), use CMD1; if CMD8 succeeds (SDv2+), use ACMD41+HCS. Only the ; comments mislead.

  ---
  The framework for modern cards is present:
  - CMD8 sent (line 5374)
  - ACMD41 with HCS=1 (line 5398: ld bc, $4000)
  - CMD58 READ_OCR (line 5329: ld a, $7a)
  - CCS bit stored to iy+_flags bit 6 (lines 5333–5336)
  - Byte vs block addressing via shift_register_setup at line 5660, gated on the CCS flag in read/write (line 5558 pre-CMD24, and the equivalent pre-CMD17 at line 5623)

  ---
  What likely causes modern cards to fail — areas to fix:

  1. ACMD41 argument is missing voltage window (line 5398). The code sends bc=$4000, de=0 → argument $40000000 (HCS only). Strict modern cards expect the VDD voltage window too — typically $40300000 (HCS + bits 20–21 for 3.2–3.4
  V). To fix: change ld bc, $4000 to ld bc, $4030 (and leave DE=0).
  2. No CMD8 response verification (line 5376). The code checks only R1 (idle-state-only), never verifies bytes 3–4 of the R7 response hold back $01 (voltage accepted) and $AA (check pattern echo). A card that accepts the command
  but echoes wrong values is currently indistinguishable from a good one, and some edge-case modern cards will fall through the old-card path silently.
  3. CMD0 retry count (line 5426: ld b, 8). Eight attempts of CMD0 may not be enough for cards with slower internal power-up. Modern initialization guidelines suggest 10+ with explicit 1 ms delays between. Tripling this (e.g. ld b,
   24) would cover most.
  4. CMD1 path is retained (line 5445). If the goal is FAT‑32 on modern cards only (SDv2+), the CMD1 entry and the jr c, set_retry_counter at line 5378 can be removed — have send_interface_condition return error if CMD8 fails, and
  the jp (hl) dispatch / two-address select can be dropped entirely. This simplifies the init.
  5. The inverted comments at lines 5377–5379 and the two unlabeled entry points at 5395 and 5445 should get meaningful labels. Something like sd_v2_init_acmd41: at 5395 and mmc_init_cmd1: at 5445 (or drop the latter per #4), with
  the ld hl in send_interface_condition pointing to the labels instead of hard-coded $1d20/$1d65.

  ---
  Summary of "where to change": all in 14_spi.asm — the send_interface_condition routine and the two init-path entry points it dispatches to (lines 5373–5445). The read/write paths and OCR handling already support SDHC/SDXC block
  addressing correctly and don't need changes.