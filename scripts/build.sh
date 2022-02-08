cp rasm/rasm-deb-arm64 src/rasm
cd src
./rasm -pasmo kernel.asm -ob ../bin/kernel.bin -sz -os ../bin/symbols.txt
cd ../bin
mv unodos0.sys unodos.sys
cat unodos1.sys >> unodos.sys
rm unodos1.sys
