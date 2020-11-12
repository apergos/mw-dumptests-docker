#!/bin/bash

globals() {
    BASEPATH="${BASEROOT}/public"
    DIR="${BASEPATH}/${WIKI}/${DATE}"
    TEMPBASE="${BASEROOT}/temp"
    TEMPDIR="${TEMPBASE}/${WIKI:0:1}/${WIKI}"
    LOCKFILE="${BASEROOT}/private/${WIKI}/lock_${DATE}"
    TEST_OUTPUT="TESTS.${WIKI}-OUT.txt"
}

setup() {
    # set up a clean copy
    rm -rf "$DIR"
    cp -a "${DIR}.prefetch" "$DIR"

    # fix up the dumpruninfo file
    cat ${DIR}/dumpruninfo.txt | sed -e 's/name:articlesdump; status:done/name:articlesdump; status:failed/g;' > ${DIR}/dumpruninfo.txt.new
    mv ${DIR}/dumpruninfo.txt.new ${DIR}/dumpruninfo.txt

    # remove any lock file
    rm -f "$LOCKFILE"

    # clear out any temp files
    rm -rf $TEMPDIR
}

check_generated_file() {
    tocheck="$1"
    for removed in $FILES; do
	if [ "$tocheck" == "$removed" ]; then
	    return
	fi
    done
    echo "${TESTNUM} extra file ${tocheck} generated" >> "$TEST_OUTPUT"
}

do_test() {
    TESTNUM=$1

    # remove file(s) to be regenerated
    for filename in $FILES; do
	rm -f ${DIR}/${filename}
    done

    python ./worker.py --configfile confs/wikidump.conf.current:bigwikis  --job articlesdump --date "$DATE" "$WIKI"

    # check that the regenerated file(s) have the same name and content as the old ones
    for filename in $FILES; do
	if [ ! -e "${DIR}/${filename}" ]; then
	    echo "${TESTNUM} missing $filename" >> "$TEST_OUTPUT"
	else
	    newmd5=$( bzcat "${DIR}/${filename}" | md5sum )
	    oldmd5=$( bzcat "${DIR}.prefetch/${filename}" | md5sum )
	    if [ "$newmd5" != "$oldmd5" ]; then
		echo "${TESTNUM} changed content for ${filename}" >> "$TEST_OUTPUT"
	    else
		echo "${TESTNUM} ${filename} OK" >> "$TEST_OUTPUT"
	    fi
	fi
	# ls -lt "$DIR"/${WIKI}*articles*bz2 | head -5 >> "$TEST_OUTPUT"
    done
    # check that no other bz2 files were generated just now
    generated=$( find "$DIR" -name ${WIKI}-${DATE}-pages-articles\*bz2 -mmin -15 )
    for filename in $generated; do
	canonical=$( basename $filename )
	check_generated_file $canonical
    done
}


cleanup() {
    toremove="$1"
    rm -f "${DIR}/${toremove}"
}


replace() {
    toreplace="$1"
    cp -a "${DIR}.prefetch/${toreplace}" "${DIR}/${toreplace}"
}    

do_test_batch() {
    setup

    name="$1"
    do_test $name
    cleanup pagerangeinfo.json
    do_test "${name}_A"
    replace pagerangeinfo.json
}

do_wikidata() {
    WIKI=wikidatawiki

    globals
    # clean up the old tests output file
    rm -f "$TEST_OUTPUT"

    # one file not at start or end
    FILES="wikidatawiki-20200214-pages-articles4.xml-p2601p3600.bz2"
    do_test_batch ONE

    # two files in two parts, first file is all of the part
    FILES="wikidatawiki-20200214-pages-articles2.xml-p101p300.bz2 wikidatawiki-20200214-pages-articles4.xml-p2601p3600.bz2"
    do_test_batch TWO

    # two consecutive files in one part
    FILES="wikidatawiki-20200214-pages-articles4.xml-p2601p3600.bz2 wikidatawiki-20200214-pages-articles4.xml-p3601p4450.bz2"
    do_test_batch THREE

    # two nonconsecutive files in one part
    FILES="wikidatawiki-20200214-pages-articles4.xml-p601p1600.bz2 wikidatawiki-20200214-pages-articles4.xml-p2601p3600.bz2"
    do_test_batch FOUR

    # one file in one part, two nonconsecutive files in another part, first file is all of the part
    FILES="wikidatawiki-20200214-pages-articles2.xml-p101p300.bz2 wikidatawiki-20200214-pages-articles4.xml-p601p1600.bz2 wikidatawiki-20200214-pages-articles4.xml-p2601p3600.bz2"
    do_test_batch FIVE

    # one file at start of a part
    FILES="wikidatawiki-20200214-pages-articles4.xml-p601p1600.bz2"
    do_test_batch SIX

    # two consecutive files at start of a part
    FILES="wikidatawiki-20200214-pages-articles4.xml-p601p1600.bz2 wikidatawiki-20200214-pages-articles4.xml-p1601p2600.bz2"
    do_test_batch SEVEN

    # several consecutive files for all of a part
    FILES="wikidatawiki-20200214-pages-articles4.xml-p601p1600.bz2 wikidatawiki-20200214-pages-articles4.xml-p1601p2600.bz2 wikidatawiki-20200214-pages-articles4.xml-p2601p3600.bz2 wikidatawiki-20200214-pages-articles4.xml-p3601p4450.bz2"
    do_test_batch EIGHT
}

do_elwikt() {
    WIKI=elwikt

    globals
    # clean up the old tests output file
    rm -f "$TEST_OUTPUT"

    # one file
    FILES="elwikt-20200214-pages-articles2.xml.bz2"
    setup
    do_test ONE

    # two nonconsecutive parts
    FILES="elwikt-20200214-pages-articles1.xml.bz2 elwikt-20200214-pages-articles4.xml.bz2"
    setup
    do_test TWO

    # two consecutive parts
    FILES="elwikt-20200214-pages-articles2.xml.bz2 elwikt-20200214-pages-articles3.xml.bz2"
    setup
    do_test THREE

    # first and third parts: nonconsecutive, first
    FILES="elwikt-20200214-pages-articles1.xml.bz2 elwikt-20200214-pages-articles3.xml.bz2"
    setup
    do_test FOUR

    # second and fourth parts: nonconsecutive, last
    FILES="elwikt-20200214-pages-articles2.xml.bz2 elwikt-20200214-pages-articles4.xml.bz2"
    setup
    do_test FIVE

    # all parts!
    FILES="elwikt-20200214-pages-articles1.xml.bz2 elwikt-20200214-pages-articles2.xml.bz2 elwikt-20200214-pages-articles3.xml.bz2 elwikt-20200214-pages-articles4.xml.bz2"
    setup
    do_test SIX
}

do_tenwiki() {
    WIKI=tenwiki

    globals
    # clean up the old tests output file
    rm -f "$TEST_OUTPUT"

    # one file
    FILES="tenwiki-20200214-pages-articles.xml.bz2"
    setup
    do_test ONE
}

#################
# MAIN MAIN MAIN

source test-settings.sh
#do_wikidata
do_elwikt
#do_tenwiki

