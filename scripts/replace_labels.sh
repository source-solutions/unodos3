#!/bin/bash

# Script to replace L0000 label references with meaningful names
# This preserves both labels initially for safety

cd "$(dirname "$0")/../src"

echo "Replacing L0000 label references with meaningful names..."

# Create backup
cp kernel.asm kernel.asm.backup

# Replace each label reference individually (safer approach)
echo "Replacing syscall_dispatcher references..."
sed -i.tmp '/^L0985:/!s/\bL0985\b/syscall_dispatcher/g' kernel.asm && rm -f kernel.asm.tmp

echo "Replacing syscall_reg_save references..."
sed -i.tmp '/^L098C:/!s/\bL098C\b/syscall_reg_save/g' kernel.asm && rm -f kernel.asm.tmp

echo "Replacing char_print_routine references..."
sed -i.tmp '/^L0845:/!s/\bL0845\b/char_print_routine/g' kernel.asm && rm -f kernel.asm.tmp

echo "Replacing char_processing_routine references..."
sed -i.tmp '/^L0CD4:/!s/\bL0CD4\b/char_processing_routine/g' kernel.asm && rm -f kernel.asm.tmp

echo "Replacing vector_dispatcher references..."
sed -i.tmp '/^L0091:/!s/\bL0091\b/vector_dispatcher/g' kernel.asm && rm -f kernel.asm.tmp

echo "Replacing vector_lookup references..."
sed -i.tmp '/^L009F:/!s/\bL009F\b/vector_lookup/g' kernel.asm && rm -f kernel.asm.tmp

echo "Replacing 32-bit arithmetic functions..."
sed -i.tmp '/^L081C:/!s/\bL081C\b/inc_32bit/g' kernel.asm && rm -f kernel.asm.tmp
sed -i.tmp '/^L0824:/!s/\bL0824\b/dec_32bit/g' kernel.asm && rm -f kernel.asm.tmp
sed -i.tmp '/^L0831:/!s/\bL0831\b/add_32bit/g' kernel.asm && rm -f kernel.asm.tmp
sed -i.tmp '/^L0836:/!s/\bL0836\b/sub_32bit/g' kernel.asm && rm -f kernel.asm.tmp

echo "Replacing utility functions..."
sed -i.tmp '/^L0694:/!s/\bL0694\b/compare_32bit/g' kernel.asm && rm -f kernel.asm.tmp
sed -i.tmp '/^L06A5:/!s/\bL06A5\b/syntax_check/g' kernel.asm && rm -f kernel.asm.tmp
sed -i.tmp '/^L06A9:/!s/\bL06A9\b/store_32bit/g' kernel.asm && rm -f kernel.asm.tmp

echo "Replacing disk and filesystem functions..."
sed -i.tmp '/^L06E1:/!s/\bL06E1\b/disk_mount_init/g' kernel.asm && rm -f kernel.asm.tmp
sed -i.tmp '/^L06E8:/!s/\bL06E8\b/mount_filesystems_loop/g' kernel.asm && rm -f kernel.asm.tmp
sed -i.tmp '/^L17AC:/!s/\bL17AC\b/init_dir_entry/g' kernel.asm && rm -f kernel.asm.tmp
sed -i.tmp '/^L17DB:/!s/\bL17DB\b/reset_file_position/g' kernel.asm && rm -f kernel.asm.tmp

echo "Replacing file management functions..."
sed -i.tmp '/^L1989:/!s/\bL1989\b/calculate_file_size/g' kernel.asm && rm -f kernel.asm.tmp
sed -i.tmp '/^L19AB:/!s/\bL19AB\b/update_file_position/g' kernel.asm && rm -f kernel.asm.tmp
sed -i.tmp '/^L19B9:/!s/\bL19B9\b/store_file_position/g' kernel.asm && rm -f kernel.asm.tmp
sed -i.tmp '/^L19C6:/!s/\bL19C6\b/load_file_position/g' kernel.asm && rm -f kernel.asm.tmp

echo "Replacement complete!"
echo "Testing build..."

# Test the build
cd ..
if ./scripts/build.sh > /dev/null 2>&1; then
    echo "✓ Build successful with new label references!"
    echo ""
    echo "You can now manually remove the old L0000: label definitions"
    echo "or run: ./scripts/cleanup_old_labels.sh"
else
    echo "✗ Build failed! Restoring backup..."
    cd src
    mv kernel.asm.backup kernel.asm
    echo "Backup restored."
fi
sed -i.tmp '/^L19AB:/!s/\bL19AB\b/update_file_position/g' kernel.asm && rm -f kernel.asm.tmp
sed -i.tmp '/^L19B9:/!s/\bL19B9\b/store_file_position/g' kernel.asm && rm -f kernel.asm.tmp
sed -i.tmp '/^L19C6:/!s/\bL19C6\b/load_file_position/g' kernel.asm && rm -f kernel.asm.tmp

echo "Replacement complete!"
echo "Testing build..."

# Test the build
cd ..
if ./scripts/build.sh > /dev/null 2>&1; then
    echo "✓ Build successful with new label references!"
    echo ""
    echo "You can now manually remove the old L0000: label definitions"
    echo "or run: ./scripts/cleanup_old_labels.sh"
else
    echo "✗ Build failed! Restoring backup..."
    mv src/kernel.asm.backup src/kernel.asm
    echo "Backup restored. Please check for errors."
    exit 1
fi