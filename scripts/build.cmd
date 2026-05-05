cd src
rasm -pasmo kernel.asm -ob ..\bin\kernel.bin -sz -os ..\bin\symbols.txt
cd ..\bin
copy /b unodos0.sys+unodos1.sys unodos.sys
erase unodos0.sys
erase unodos1.sys
