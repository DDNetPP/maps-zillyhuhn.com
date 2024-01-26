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
if [ ! -d maps-themes/BlmapChill ]
then
	echo "[!] Warning: no BlmapChill/ found in maps-themes"
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
	update_repo maps-themes

	popd || exit 1
}

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
	local theme
	local theme_outfile
	for theme in "$SCRIPT_PATH/maps-scripts/$mapname"/themes/*.py
	do
		theme="$(basename "$theme" .py)"
		echo "[*]   generating python $theme theme ..."
		"$SCRIPT_PATH/maps-scripts/$mapname/themes/$theme.py" "$map" "${mapname}_${theme}.map"
		checksum="$(sha256sum "${mapname}_${theme}.map" | cut -d' ' -f1)"
		theme_outfile="${mapname}_${theme}_$checksum.map"
		echo "[*]   $theme_outfile"
		mv "${mapname}_${theme}.map" "$theme_outfile"
	done
	for theme in "$SCRIPT_PATH/maps-themes/$mapname"/*.map
	do
		local theme_fullpath="$theme"
		theme="$(basename "$theme" .map)"
		echo "[*]   generating $theme.map theme sha1sums ..."
		checksum="$(sha256sum "$theme_fullpath" | cut -d' ' -f1)"
		theme_outfile="${mapname}_${theme}_$checksum.map"
		echo "[*]   $theme_outfile"
		cp "$theme_fullpath" "$theme_outfile"
	done
	echo "[*]   $outfile"
	mv "$map" "$outfile"
}

all_maps=(BlmapChill)

mkdir -p public
cd public || exit 1

for map in "${all_maps[@]}"
do
	[[ -f "$map".map ]] && rm "$map".map
	wget -q "https://github.com/DDNetPP/maps/raw/master/$map.map"
	hash_map "$map".map
done

