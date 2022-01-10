#!/bin/bash
# set up my bash mods

# use this script like so:
# curl -O https://mvgfr.com/bash-mods-setup.sh && chmod u+x bash-mods-setup.sh && ./bash-mods-setup.sh


# Dependencies:
# curl
# https://mvgfr.com/bash-mods.tgz

# History:
# 20210514 mvr: need to popd, before archive self
#               which means needs to pushd, vs depend on cd being aliased to that
# 20210330 mvr: if file from the tar is same as existing, simply skip (don't replace needlessly)
# 20210330 mvr: no longer need risky rm of ._ files,
#               since using COPYFILE_DISABLE to not tar them in the first place
# 20210330 mvr: clean up comments (some were dated/wrong)
# 20210330 mvr: diff the files replaced


# TBD:
# safer to create our own tmp dir, than work out of ~/tmp (may conflict w/ files already there)
# handle fail, at curl
# preserve file extension (if any) in archiveme()


# who am I?
myName=$(basename "$0")

# fn to save the files we're replacing, in a local archive, dated:
archiveme ()
{ 
    myFn=$(basename "$1");
    mv -v "$1" ~/z-old/"$myFn"-saved-$(date "+%Y%m%d-%H%M%S")
}

# create dirs if needed:
for i in tmp z-old .screen-logs .Trash ; do
    if [ ! -d ~/$i ]; then mkdir ~/$i; chmod go-rwx ~/$i; fi
done

# work out of my tmp dir:
pushd ~/tmp

# get the tar of mods, and unpack:
curl -O https://mvgfr.com/bash-mods.tgz
tar xzpf bash-mods.tgz

# diff, and move current files (if any) aside, and move new ones into place:
# (don't delete, to leave an "undo" path)
for j in $(tar tzf bash-mods.tgz)
do
    # check to see if there's an existing copy:
    if [ -f ../$j ] ; then
	# see if file from the tar is diff:
	diffOut=$(diff -s "$j" ../"$j" 2>&1)
	diffResult=$?
	# if there is a difference, show it:
	if [ $diffResult -ne 0 ] ; then
	    echo; echo "replacing $j; diff to follow:";
	    ls -ld "$j"; ls -ld ../"$j"
	    echo "$diffOut"
	    archiveme ../$j
	    mv $j ../
	else
	    # no diff, so get rid of this extraneous copy from the tar:
	    rm "$j"
	fi
    else
	# file wasn't yet deployed; do so now:
	mv $j ../
    fi
done

# save the tar:
archiveme bash-mods.tgz

# last, archive myself:
popd # pop back out, to dir started in
archiveme "$myName"
