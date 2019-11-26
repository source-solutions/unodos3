cd src
wine ../zeus/zcl kernel.asm
cd ../bin
mv unodos0.sys unodos.sys
cat unodos1.sys >> unodos.sys
rm unodos1.sys
