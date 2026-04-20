#!/bin/bash

# Script to replace L0000 label references with meaningful names
# This preserves both labels initially for safety

cd "$(dirname "$0")/../src"

echo "Replacing L0000 label references with meaningful names..."

# Create backup
cp kernel.asm kernel.asm.backup

# Replace each label reference individually (safer approach)
echo "Replacing next_char_basic references..."
sed -i.tmp '/^L000B:/!s/\bL000B\b/next_char_basic/g' kernel.asm && rm -f kernel.asm.tmp

echo "Replacing next_char_rst20 references..."
sed -i.tmp '/^L001F:/!s/\bL001F\b/next_char_rst20/g' kernel.asm && rm -f kernel.asm.tmp

echo "Replacing system_info references..."
sed -i.tmp '/^L0040:/!s/\bL0040\b/system_info/g' kernel.asm && rm -f kernel.asm.tmp

echo "Replacing load_byte_de references..."
sed -i.tmp '/^L0048:/!s/\bL0048\b/load_byte_de/g' kernel.asm && rm -f kernel.asm.tmp

echo "Replacing keyboard_test_pattern references..."
sed -i.tmp '/^L0049:/!s/\bL0049\b/keyboard_test_pattern/g' kernel.asm && rm -f kernel.asm.tmp

echo "Replacing char_process_continue references..."
sed -i.tmp '/^L004D:/!s/\bL004D\b/char_process_continue/g' kernel.asm && rm -f kernel.asm.tmp

echo "Replacing cr_string references..."
sed -i.tmp '/^L0050:/!s/\bL0050\b/cr_string/g' kernel.asm && rm -f kernel.asm.tmp

echo "Replacing nmi_handler references..."
sed -i.tmp '/^L0068:/!s/\bL0068\b/nmi_handler/g' kernel.asm && rm -f kernel.asm.tmp

echo "Replacing select_basic_rom references..."
sed -i.tmp '/^L00EF:/!s/\bL00EF\b/select_basic_rom/g' kernel.asm && rm -f kernel.asm.tmp

echo "Replacing reset_init references..."
sed -i.tmp '/^L0101:/!s/\bL0101\b/reset_init/g' kernel.asm && rm -f kernel.asm.tmp

echo "Replacing delay_loop references..."
sed -i.tmp '/^L0107:/!s/\bL0107\b/delay_loop/g' kernel.asm && rm -f kernel.asm.tmp

echo "Replacing full_init references..."
sed -i.tmp '/^L0124:/!s/\bL0124\b/full_init/g' kernel.asm && rm -f kernel.asm.tmp

echo "Replacing memory_test_loop references..."
sed -i.tmp '/^L013D:/!s/\bL013D\b/memory_test_loop/g' kernel.asm && rm -f kernel.asm.tmp

echo "Replacing memory_init_complete references..."
sed -i.tmp '/^L016B:/!s/\bL016B\b/memory_init_complete/g' kernel.asm && rm -f kernel.asm.tmp

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