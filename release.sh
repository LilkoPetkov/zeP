#!/bin/bash
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-windows-msvc -p tempR/w
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux-gnu -p tempR/l
mkdir -p release
mkdir -p release/w
mkdir -p release/l


versionName=$1
if [ $# -eq 0 ]
  then
	date=$(date '+%Y-%m-%d')
	versionName="$date"
fi


zip -j release/w/windows_$versionName.zip tempR/w/bin/zeP.exe
zip -r release/w/windows_$versionName.zip packages/ scripts/p/

tar -C tempR/l/bin -cvf release/l/linux_$versionName.tar zeP
tar -rf release/l/linux_$versionName.tar packages/ scripts/p/

rm -r tempR/