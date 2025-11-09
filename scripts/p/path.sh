#!/bin/bash

p="/usr/local/bin"
zDir="$p/zeP"
zigDir="$zDir/zig"
zigExe="$zigDir/zig.exe"

if [ $EUID != 0 ]; then
	sudo "$0" "$@"
	currentPath=$PATH
	if ! [[ $currentPath == *"$zigDir"* ]]; then 
			echo "Setting PATH" 
			export PATH="$zigDir:$PATH"
			echo $PATH
	fi
	exit $?
fi

if ! [ -e $zDir ]; then
	mkdir $zDir
			exit
fi

if ! [ -e $zigDir ]; then
	mkdir $zigDir
			exit
fi

if [ $# -eq 0 ]; then
	echo "No arguments supplied"
			exit
fi
target=$1

if ! [ -e $target ]; then
	echo "Target does not exist!"
			exit       
fi

if [ -e $zigExe ]; then
	rm $zigExe
fi

ln -s $target $zigExe
