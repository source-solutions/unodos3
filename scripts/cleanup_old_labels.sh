#!/bin/bash

# Script to remove old L0000: label definitions after replacement is verified

cd "$(dirname "$0")/../src"

# List of old labels to remove (only the definitions, not references)
# Only remove labels that have been successfully replaced
OLD_LABELS=(
    "L000B"  # next_char_basic
    "L001F"  # next_char_rst20
    "L0040"  # system_info
    "L0048"  # load_byte_de
    "L0049"  # keyboard_test_pattern
    "L004D"  # char_process_continue
    "L0050"  # cr_string
    "L0068"  # nmi_handler
    "L00EF"  # select_basic_rom
    "L0101"  # reset_init
    "L0107"  # delay_loop
    "L0124"  # full_init
    "L013D"  # memory_test_loop
    "L016B"  # memory_init_complete
)

echo "Removing old L0000: label definitions..."

# Create backup before cleanup
cp kernel.asm kernel.asm.pre-cleanup

# Remove each old label definition line
for label in "${OLD_LABELS[@]}"; do
    echo "Removing label definition: ${label}:"
    # Remove lines that are exactly just the label definition
    sed -i.tmp "/^${label}:$/d" kernel.asm
    rm -f kernel.asm.tmp
done

echo "Cleanup complete!"
echo "Testing build..."

# Test the build
cd ..
if ./scripts/build.sh > /dev/null 2>&1; then
    echo "✓ Build successful after cleanup!"
    echo "Old L0000 labels successfully removed."
    rm src/kernel.asm.pre-cleanup
else
    echo "✗ Build failed after cleanup! Showing errors:"
    echo ""
    ./scripts/build.sh
    echo ""
    echo "Restoring backup..."
    mv src/kernel.asm.pre-cleanup src/kernel.asm
    echo "Backup restored. Manual review may be needed."
    exit 1
fi