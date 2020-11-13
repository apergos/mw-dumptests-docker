#!/bin/bash

if [ ! -f scripts/test-settings.sh ]; then
    echo "Create a file with your directory settings in"
    echo "scripts/test-settings.sh. See scripts/test-settings.sh.sample"
    echo "for an example. Then run this script again. Quitting."
    exit 1
fi

source scripts/test-settings.sh

echo "Copying scripts and settings"
cp scripts/*sh "${REPODIR}/"

echo "Converting and copying config files"
mkdir -p "${REPODIR}/confs"
conffiles="confs/*"
for path in $conffiles; do
    if [ -d "$path" ]; then
	continue
    elif [[ "$path" == *.yaml ]]; then
	cp "$path" "${REPODIR}/confs/"
    elif [[ "$path" != *.templ ]]; then
       continue
    else
	newname=$( echo "$path" | sed -e 's/.templ//g;' )
	cat "$path" | sed -e "s|{REPODIR}|$REPODIR|g; s|{BASEROOT}|$BASEROOT|g; s|{BASEMW}|$BASEMW|g;" > "${newname}"
	cp "${newname}" "${REPODIR}/confs/"
    fi
done

echo "Copying dblists"
mkdir -p "${REPODIR}/dblists"
cp dblists/* "${REPODIR}/dblists/"

echo "Done!"
exit 0

