#!/bin/bash

SCRIPT_PATH="$( cd -- "$(dirname "$0")" || exit 1 >/dev/null 2>&1 ; pwd -P )"

if [ "$SCRIPT_PATH" == "" ]
then
	echo "[-] Error: could not get script path"
	exit 1
fi

cd /var/www/html/maps || exit 1

if [ -f BlmapChill.map ]
then
	rm BlmapChill.map
fi

function hash_map() {
	local map="$1"
	local mapname
	local checksum
	local outfile
	if [ ! -f "$map" ]
	then
		echo "Error: map not found '$map'"
		exit 1
	fi
	mapname="$(basename "$map" .map)"
	checksum="$(sha256sum "$map" | cut -d' ' -f1)"
	outfile="${mapname}_$checksum.map"
	if [ -f "$outfile" ]
	then
		echo "[*] already got '$outfile'"
		rm "$map"
		return
	fi
	echo "[*] adding '$map'"
	echo "[*]   generating dark theme ..."
	"$SCRIPT_PATH/maps-scripts/BlmapChill/dark.py" "$map" "${mapname}_dark.map"
	echo "[*]   $outfile"
	mv "$map" "$outfile"
	checksum="$(sha256sum "${mapname}_dark.map" | cut -d' ' -f1)"
	outfile="${mapname}_dark_$checksum.map"
	echo "[*]   $outfile"
	mv "${mapname}_dark.map" "$outfile"
}

wget -q https://github.com/DDNetPP/maps/raw/master/BlmapChill.map 
hash_map BlmapChill.map


