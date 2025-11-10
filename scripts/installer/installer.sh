#!/bin/bash
set -e

usrLocalBin="/usr/local/bin"

lib="/lib"

zepExe="$usrLocalBin/zeP.exe"
zepDir="$lib/zeP"
zepZigDir="$zepDir/zig"
zepZigExe="$zepZigDir/zig.exe"

mkdir -p "$zepDir"
mkdir -p "$zepZigDir"

if [ $EUID != 0 ]; then
	sudo "$0" "$@"
	exit $?
fi


tempZepZipDir="/tmp/zeP";
mkdir -p "$tempZepZipDir"

tempZepZipVersion="$tempZepZipDir/0.1";
mkdir -p "$tempZepZipVersion"

tempZepZipFile="/tmp/zeP/0.1.zip";


echo "Downloading release..."
curl -L "https://github.com/XerWoho/zeP/releases/download/pre/0.1.zip" -o "$tempZepZipFile"

echo "Extracting..."
unzip -o "$tempZepZipFile" -d "$tempZepZipDir"

# clear the current data
if [ -e "$zepDir/*" ]; then
	rm -r "$zepDir/*"
fi

# Move folders
tempZepPackagesFolder="$tempZepZipDir/packages"
destZepPackagesFolder="$zepDir/ava"
mkdir -p "$(dirname "$destZepPackagesFolder")"
mv -f "$tempZepPackagesFolder" "$destZepPackagesFolder"

tempZepScriptsFolder="$tempZepZipDir/scripts"
destZepScriptsFolder="$zepDir/scripts"
mkdir -p "$(dirname "$destZepScriptsFolder")"
mv -f "$tempZepScriptsFolder" "$destZepScriptsFolder"

# remove the current zepExe
if [ -e $zepExe ]; then
	rm $zepExe
fi


tempZepExe="$tempZepZipDir/zeP.exe"
mv -f "$tempZepExe" "$zepExe"
rm -r $tempZepZipDir

chmod ugo-wrx "$zepExe"
chmod +rx "$zepExe"
chmod u+w "$zepExe"

echo "Installation complete."