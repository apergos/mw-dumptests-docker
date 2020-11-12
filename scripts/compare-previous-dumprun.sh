#!/bin/bash

usage() {
	cat<<EOF
Usage: $0 --wiki <dbname> [--revinfo|--batches|--private]
  --wiki         dbname of wiki
  --revinfo      do the revinfo version of the test
  --batches      do the primary and secondary batch worker version of the test
  --private      do the output into private directory version of the test
  --compareonly  just compare existing output w/o producing new files
EOF
	exit 1
}

set_defaults() {
    vars="COMPAREONLY DOREVINFO DOBATCHES DOPRIVATE WIKI"
    for varname in $vars; do
        declare $varname="";
    done
}

process_opts () {
    while [ $# -gt 0 ]; do
	if [ $1 == "--revinfo" ]; then
	    DOREVINFO="revinfo"
	    shift
	elif [ $1 == "--batches" ]; then
	    DOBATCHES="batches"
	    shift
	elif [ $1 == "--private" ]; then
	    DOPRIVATE="private"
	    shift
	elif [ $1 == "--compare" ]; then
	    COMPAREONLY="true"
	    shift
	elif [ $1 == "--wiki" ]; then
	    WIKI="$2"
	    shift; shift
	else
	    echo "$0: Unknown option $1"
	    usage && exit 1
	fi
    done
}

check_opts() {
    if [ -z "$WIKI" ]; then
        echo "$0: Mandatory option 'wiki' must be specified"
        usage && exit 1
    fi
    if [ -n "$DOPRIVATE" -a -n "$DOBATCHES" ]; then
	echo "$0: "Only one of --private, --batches, --revinfo may be specified"
        usage && exit 1
    fi
    if [ -n "$DOPRIVATE" -a -n "$DOREVINFO" ]; then
	echo "$0: "Only one of --private, --batches, --revinfo may be specified"
        usage && exit 1
    fi
    if [ -n "$DOBATCHES" -a -n "$DOREVINFO" ]; then
	echo "$0: "Only one of --private, --batches, --revinfo may be specified"
        usage && exit 1
    fi
    if [ -n "$DOPRIVACY" -a "$WIKI" != "elwikivoyage" ]; then
	echo "$0: "Only elwikivoyage is set up to run the privacy version of this test."
        usage && exit 1
    fi
}

globals() {
    if [ -z "$DOPRIVATE" ]; then
	BASEPATH="${BASEROOT}/public"
    else
	BASEPATH="${BASEROOT}/private"
    fi
    PRIVATEPATH="${BASEROOT}/private"
    if [ -z "$DOREVINFO" ]; then
	OLDDIR="${BASEPATH}/${WIKI}/${DATE}.prefetch"
    else
	OLDDIR="${BASEPATH}/${WIKI}/${DATE}.revinfo"
    fi
    NEWDIR="${BASEPATH}/${WIKI}/${DATE}"
    TEMPBASE="${BASEROOT}/temp"
    TEMPDIR="${TEMPBASE}/${WIKI:0:1}/${WIKI}"
    LOCKFILE="${PRIVATEPATH}/${WIKI}/lock_${DATE}"
    BATCHINFOFILE="${PRIVATEPATH}/${WIKI}/${DATE}/batches-metahistorybz2dump.json"
    mkdir -p testoutput
    TEST_OUTPUT_BASE="testoutput/COMPARE.${WIKI}"
    PRIVATEDBLIST="dblists/private.dblist"
}

setup() {
    # set up a clean copy for today
    rm -rf "$NEWDIR"

    # remove any lock file
    rm -f "$LOCKFILE"

    # remove batchinfo file
    rm -f "$BATCHINFOFILE"

    # clear out any temp files incl revinfo
    rm -rf "$TEMPDIR"
}

check_files() {
    uncompressor="$1"
    if [ "$2" == "timestuff" ]; then
	timefilter="1"
    elif [ "$2" == "updatestuff" ]; then
	updatefilter="1"
    elif [ "$2" == "sizestuff" ]; then
	sizefilter="1"
    fi
    for newpath in $FILES; do
	canonical=$( basename $newpath )
	oldpath=${OLDDIR}/${canonical}
	if [ ! -e $oldpath ]; then
	    echo "new file $newpath not in old directory" >> "$TEST_OUTPUT"
	    continue
	fi
	# skip over version of mw and schema in the header, these can vary
	# old version has no newline at end of file, new one does
	# sql dumps have dump timestamp at end of file
	if [ -n "$timefilter" ]; then
	    oldmd5=$( $uncompressor $oldpath | sed -e 's/"time":"[^Z]*Z"/"time":"YYYY-MM-DDTHH:MM:SSZ"/g;' | /usr/bin/md5sum )
	elif [ -n "$updatefilter" ]; then
	    oldmd5=$( $uncompressor $oldpath | sed -e 's/updated:.*$/updated:YYYY-MM-DD HH:MM:SS/g;' | /usr/bin/md5sum )
	elif [ -n "$sizefilter" ]; then
	    oldmd5=$( $uncompressor $oldpath | sed -e 's/"size": [^,]*,/"size": 100,/g;' | /usr/bin/md5sum )
	else
	    oldmd5=$( $uncompressor $oldpath | tail -n +7 | head -n -1 | /usr/bin/md5sum )
	fi
	# echo "$uncompressor $oldpath | tail -n +7 | head -n -1 | /usr/bin/md5sum" >> "$TEST_OUTPUT"
	# new schema has '<origin>' tags
	# newmd5=$( $uncompressor $newpath | tail -n +7 | grep -v '<origin>' | head -n -1 | /usr/bin/md5sum )
	if [ -n "$timefilter" ]; then
	    newmd5=$( $uncompressor $oldpath | sed -e 's/"time":"[^Z]*Z"/"time":"YYYY-MM-DDTHH:MM:SSZ"/g;' | /usr/bin/md5sum )
	elif [ -n "$updatefilter" ]; then
	    newmd5=$( $uncompressor $oldpath | sed -e 's/updated:.*$/updated:YYYY-MM-DD HH:MM:SS/g;' | /usr/bin/md5sum )
	elif [ -n "$sizefilter" ]; then
	    newmd5=$( $uncompressor $oldpath | sed -e 's/"size": [^,]*,/"size": 100,/g;' | /usr/bin/md5sum )
	else
	    newmd5=$( $uncompressor $newpath | tail -n +7 | head -n -1 | /usr/bin/md5sum )
	fi
        # echo "$uncompressor $newpath | tail -n +7 | grep -v '<origin>' | head -n -1 | /usr/bin/md5sum" >> "$TEST_OUTPUT"
	if [ "$oldmd5" == "$newmd5" ]; then
	    echo "$canonical OK" >>  "$TEST_OUTPUT"
	else
	    echo "different content in new $canonical" >>  "$TEST_OUTPUT"
	fi
    done
}

check_missing_files() {
    for oldpath in $FILES; do
	canonical=$( basename $oldpath )
	newpath=${NEWDIR}/${canonical}
	if [ ! -e $newpath ]; then
	    echo "old file $oldpath not in new directory" >> "$TEST_OUTPUT"
	    continue
	fi
    done
}

do_test() {
    if [ -n "$DOPRIVATE" ]; then
	echo "$WIKI" > "$PRIVATEDBLIST"
	echo "badwiki" >> "$PRIVATEDBLIST"
    else
	echo "badwiki" > "$PRIVATEDBLIST"
    fi
    if [ -z "$DOBATCHES" ]; then
	if [ -z "$DOREVINFO" ]; then
		python ./worker.py --configfile confs/wikidump.conf.current:bigwikis --date "$DATE" "$WIKI"
	else
	    python ./worker.py --configfile confs/wikidump.conf.current-revinfo:bigwikis --date "$DATE" "$WIKI"
	fi
    else
	# run everything that doesn't involve the bz2 pages-meta-history
	python ./worker.py --configfile confs/wikidump.conf.current:bigwikis --date "$DATE" --skipjobs metahistorybz2dump,metahistorybz2dumprecombine,metahistory7zdump,metahistory7zdumprecombine "$WIKI"

	echo ">>>>>>>>>>>>>>>>>>>>>>>>>  STARTING PRIMARY"
	wait_pids=()
	# run the pmh bz2 as primary 
	( python ./worker.py --configfile confs/wikidump.conf.current:bigwikis --date "$DATE" --job metahistorybz2dump --exclusive "$WIKI" ) &
	wait_pids+=($!)

	# wait a little before starting the secondary batch worker, so the batch file shows up;
	# if there's none after 60 seconds, assume that this wiki is not configured for batches
	# and move on
	count=1
	while [ ! -f "$BATCHINFOFILE" ]; do
    	    sleep 1
	    count=$(( $count + 1 ))
	    if [ $count -gt 60 ]; then
		break
	    fi
	done

	echo ">>>>>>>>>>>>>>>>>>>>>>>>>  BATCHFILE EXISTS, RUNNING SECONDARY WORKER"
	# run the pmh bz2 also as secondary with no locks
	( python ./worker.py --configfile confs/wikidump.conf.current:bigwikis --date "$DATE" --job metahistorybz2dump --batches "$WIKI" ) &
	ps axuww | grep worker.py
	wait_pids+=($!)

	echo ">>>>>>>>>>>>>>>>>>>>>>>>>  WAITING FOR COMPLETION"
	# wait for them all to complete
	for pid in ${wait_pids[*]}; do
	    wait $pid
	    if [ $? -ne 0 ]; then
		echo "metahistorybz2dump FAILED somehow"
            fi
	done

	# run the rest (7z, recombines)
	python ./worker.py --configfile confs/wikidump.conf.current:bigwikis --date "$DATE" --skipdone "$WIKI"
    fi
}

do_compare() {
    # check that the regenerated file(s) have the same name and content as the old ones
    FILES=$( ls ${NEWDIR}/${WIKI}*gz )
    check_files zcat
    FILES=$( ls ${NEWDIR}/${WIKI}*json.gz )
    check_files zcat timestuff
    FILES=$( ls ${NEWDIR}/${WIKI}*bz2 )
    check_files bzcat
    FILES=$( ls ${NEWDIR}/dumpruninfo.txt )
    check_files cat
    FILES=$( ls ${NEWDIR}/report.json )
    check_files cat sizestuff
    FILES=$( ls ${OLDDIR}/${WIKI}*gz )
    check_missing_files
    FILES=$( ls ${OLDDIR}/${WIKI}*bz2 )
    check_missing_files
    FILES=$( ls ${OLDDIR}/${WIKI}*7z )
    check_missing_files
    # FIXME we don't check for files that weren't created in the new run

    if [ ! -z "$DOBATCHES" ]; then
	# display the batches info file so humans can check that it looks reasonable
	echo "Batchinfo file ${BATCHINFOFILE} (check for multiple pids and all batches done):"
	cat "$BATCHINFOFILE" | sed -e 's/}}},/}}},\n/g;'
    fi
}

compare_wiki() {
    WIKI="$1"
    globals

    # this file collecting test output is set up per test and wiki
    TEST_OUTPUT="${TEST_OUTPUT_BASE}-${DOREVINFO}${DOBATCHES}${DOPRIVATE}out.txt"
    # clean up the old contents
    rm -f "${TEST_OUTPUT}"

    if [ -z "$COMPAREONLY" ]; then
	setup
	do_test
    fi

    do_compare
}

#################
# MAIN MAIN MAIN

source test-settings.sh

set_defaults || exit 1
process_opts "$@" || exit 1
check_opts || exit 1

echo "running tests with options $@"

compare_wiki "$WIKI"
echo "Check ${TEST_OUTPUT} for results"
