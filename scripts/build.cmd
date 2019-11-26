copy zeus\zcl.exe src\zcl.exe
cd src
zcl kernel.asm
erase zcl.exe
cd ..
cd bin
copy /b unodos0.sys+unodos1.sys unodos.sys
erase unodos0.sys
erase unodos1.sys
