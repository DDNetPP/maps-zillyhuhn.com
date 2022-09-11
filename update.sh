#!/bin/bash

cd /var/www/html/maps || exit 1

if [ -f BlmapChill.map ]
then
	rm BlmapChill.map
fi

function hash_map() {
	local map="$1"
	local checksum
	if [ ! -f "$map" ]
	then
		echo "Error: map not found '$map'"
		exit 1
	fi
	checksum="$(sha256sum "$map" | cut -d' ' -f1)"
	mv "$map" "$(basename "$map" .map)_$checksum.map"
}

wget https://github.com/DDNetPP/maps/raw/master/BlmapChill.map 
hash_map BlmapChill.map


