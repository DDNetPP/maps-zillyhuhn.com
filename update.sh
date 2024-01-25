#!/bin/bash

SCRIPT_PATH="$( cd -- "$(dirname "$0")" || exit 1 >/dev/null 2>&1 ; pwd -P )"

if [ "$SCRIPT_PATH" == "" ]
then
	echo "[-] Error: could not get script path"
	exit 1
fi


if [ ! -d maps-scripts/BlmapChill ]
then
	echo "[!] Warning: no BlmapChill/ found in maps-scripts"
	echo "[!]          trying to load submodule"
	git submodule update --init --recursive
fi

update_repo() {
	local folder="$1"
	local branch="${2:-master}"
	if [ ! -d "$folder/.git" ]
	then
		pushd "$folder" || exit 1
		echo "[*] updating $folder ..."
		git checkout "$branch"
		git pull
		popd || exit 1
		git add "$folder" && git commit -m "Auto update submodule $folder" && git push
	fi
}

update_all_git() {
	pushd "$SCRIPT_PATH" || exit 1

	git pull
	update_repo maps-scripts

	popd || exit 1
}

mkdir -p public
cd public || exit 1

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
	update_all_git
	echo "[*] adding '$map'"
	echo "[*]   generating dark theme ..."
	"$SCRIPT_PATH/maps-scripts/$mapname/dark.py" "$map" "${mapname}_dark.map"
	echo "[*]   $outfile"
	mv "$map" "$outfile"
	checksum="$(sha256sum "${mapname}_dark.map" | cut -d' ' -f1)"
	outfile="${mapname}_dark_$checksum.map"
	echo "[*]   $outfile"
	mv "${mapname}_dark.map" "$outfile"
}

wget -q https://github.com/DDNetPP/maps/raw/master/BlmapChill.map 
hash_map BlmapChill.map


