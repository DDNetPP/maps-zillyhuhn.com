#!/bin/bash

SCRIPT_PATH="$( cd -- "$(dirname "$0")" || exit 1 >/dev/null 2>&1 ; pwd -P )"

if [ "$SCRIPT_PATH" == "" ]
then
	echo "[-] Error: could not get script path"
	exit 1
fi

NEW_MAPS_SCRIPTS=0
NEW_MAPS_THEMES=0

python3 -c "import twmap" || exit 1

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
	# if update_repo maps-scripts
	# then
	# 	echo "got new commits"
	# fi
	local folder="$1"
	local branch="${2:-master}"
	local commit_pre_pull=''
	local commit_post_pull=''
	pushd "$SCRIPT_PATH" || exit 1
	if [ ! -d "$folder/.git" ]
	then
		pushd "$folder" || exit 1
		echo "[*] updating $folder ..."
		git checkout "$branch"
		commit_pre_pull="$(git rev-parse HEAD)"
		git pull
		commit_post_pull="$(git rev-parse HEAD)"
		popd || exit 1
		git add "$folder" && git commit -m "Auto update submodule $folder" && git push
	fi
	popd || exit 1 # SCRIPT_PATH

	if [ "$commit_pre_pull" != "$commit_post_pull" ]
	then
		return 0
	fi
	return 1
}

update_all_git() {
	pushd "$SCRIPT_PATH" || exit 1

	git pull
	update_repo maps-scripts && NEW_MAPS_SCRIPTS=1
	update_repo maps-themes && NEW_MAPS_THEMES=1

	popd || exit 1
}

update_maps_scripts() {
	local map="$1"
	# skip generate if there are no new commits
	[[ "$NEW_MAPS_SCRIPTS" == "1" ]] || return

	local theme
	local theme_outfile
	for theme in "$SCRIPT_PATH/maps-scripts/$mapname"/themes/*.py
	do
		[ -f "$theme" ] || continue

		theme="$(basename "$theme" .py)"
		echo "[*]   generating python $theme theme ..."
		"$SCRIPT_PATH/maps-scripts/$mapname/themes/$theme.py" "$map" "${mapname}_${theme}.map"
		checksum="$(sha256sum "${mapname}_${theme}.map" | cut -d' ' -f1)"
		theme_outfile="${mapname}_${theme}_$checksum.map"
		echo "[*]   $theme_outfile"
		mv "${mapname}_${theme}.map" "$theme_outfile"
	done
}

update_maps_themes() {
	local map="$1"
	# skip generate if there are no new commits
	[[ "$NEW_MAPS_THEMES" == "1" ]] || return

	echo "[*]   generate themes based on .map themes ..."
	pushd "$SCRIPT_PATH/maps-themes" || exit 1
	git pull
	./update.sh || exit 1
	git add .
	git commit -m "generate themes"
	git push
	popd || exit 1

	echo "[*]   generate .map file themes sha sums ..."
	local theme
	local theme_outfile
	for theme in "$SCRIPT_PATH/maps-themes/$mapname"/*.map
	do
		[ -f "$theme" ] || continue

		local theme_fullpath="$theme"
		theme="$(basename "$theme" .map)"
		echo "[*]   generating $theme.map theme sha256sums ..."
		checksum="$(sha256sum "$theme_fullpath" | cut -d' ' -f1)"
		theme_outfile="${mapname}_${theme}_$checksum.map"
		echo "[*]   $theme_outfile"
		cp "$theme_fullpath" "$theme_outfile"
	done
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
	update_all_git
	echo "[*] adding '$map'"
	update_maps_scripts "$map"
	update_maps_themes "$map"
	if [ -f "$outfile" ]
	then
		echo "[*]   already got '$outfile'"
	else
		echo "[*]   adding new '$outfile'"
	fi
	mv "$map" "$outfile"
}

all_maps=(
	BlmapChill
	blmapV3multistarbox
)

if [ ! -d public ]
then
	# force refresh all on first run
	NEW_MAPS_SCRIPTS=1
	NEW_MAPS_THEMES=1
fi

mkdir -p public
cd public || exit 1

for map in "${all_maps[@]}"
do
	[[ -f "$map".map ]] && rm "$map".map
	wget -q "https://github.com/DDNetPP/maps/raw/master/$map.map"
	hash_map "$map".map
done

