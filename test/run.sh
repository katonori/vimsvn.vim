#!/bin/sh

rm -fv repos/res*.txt
cp *.vim repos
pushd repos
vim -c ":source SvnGetLog.vim"
popd
mv repos/res*.txt .

rm -fv res.txt
for file in res*-*.txt
do
    diff ${file} ref/${file} 2>&1 | tee -a res.txt
done
LINE=`cat res.txt`
if [ "" = "${LINE}" ]; then
    echo "OK"
    exit 0
else
    echo "NG"
    exit 1
fi
