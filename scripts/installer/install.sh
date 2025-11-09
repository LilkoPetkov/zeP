#!/bin/bash

p="/usr/local/bin"
zDir="$p/zeP/bin"

currentPath=$PATH
if ! [[ $currentPath == *"$zDir"* ]]; then 
		echo "Setting PATH" 
		export PATH="$zDir:$PATH"
		echo $PATH
fi
exit $?