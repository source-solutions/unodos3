#!/bin/bash

# Script to remove old L0000: label definitions after replacement is verified

cd "$(dirname "$0")/../src"

# List of old labels to remove (only the definitions, not references)
# Only remove labels that have been successfully replaced
OLD_LABELS=(
    "L0985"  # syscall_dispatcher
    "L098C"  # syscall_reg_save
    "L0845"  # char_print_routine
    "L0CD4"  # char_processing_routine
    "L0091"  # vector_dispatcher
    "L009F"  # vector_lookup
    "L081C"  # inc_32bit
    "L0824"  # dec_32bit
    "L0831"  # add_32bit
    "L0836"  # sub_32bit
    "L0694"  # compare_32bit
    "L06A5"  # syntax_check
    "L06A9"  # store_32bit
    "L06E1"  # disk_mount_init
    "L06E8"  # mount_filesystems_loop
    "L17AC"  # init_dir_entry
    "L17DB"  # reset_file_position
    "L1989"  # calculate_file_size
    "L19AB"  # update_file_position
    "L19B9"  # store_file_position
    "L19C6"  # load_file_position
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