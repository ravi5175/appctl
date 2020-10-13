#!/bin/bash

ERR_CODE_NOT_EXIST=1500
ERR_CODE_PERMISSION=1501
ERR_CODE_EXECUTION=1502
ERR_CODE_TYPE=1503
ERR_CODE_NOT_DEFINED=1504

ERR_MESG() {
    echo "[Error]: $@"
}

INFO_MESG() {
    echo "[Info]: $@"
}

ERR_EXIT() {
    local err_code=$1
    shift
    cleanup
    ERR_MESG "$@"
    exit $err_code
}

function cleanup {
    [[ -z $NO_CLEAN ]] && [[ ! -z "$name" ]] && [[ -d "$WRK_DIR/$name" ]] && rm -rf "$WRK_DIR/$name"
    return 0
}

function checkDir {
    for i in "$@" ; do
        if [[ ! -d $i ]] ; then
            ERR_MESG "'$i' not exist"
            exit $ERR_CODE_NOT_EXIST
        elif [[ ! -w $i ]] ; then
            ERR_MESG "'$i' is not writable"
            exit $ERR_CODE_PERMISSION
        elif [[ ! -x $i ]] || [[ ! -r $i ]] ; then
            ERR_MESG "'$i' is not readable"
            exit $ERR_CODE_PERMISSION
        fi
    done
}

function verify {
    INFO_MESG "verifying recipe"
    [[ -z "$name"    ]] && ERR_EXIT $ERR_CODE_NOT_DEFINED "'name' is not defined"
    [[ -z "$version" ]] && ERR_EXIT $ERR_CODE_NOT_DEFINED "'version' is not defined"
    [[ -z "$release" ]] && ERR_EXIT $ERR_CODE_NOT_DEFINED "'release' is not defined"

    for i in $EXEC_LIST ; do
        [[ $(type -t $i) != "function" ]] && ERR_EXIT $ERR_CODE_TYPE "'$i' is not a 'function' type"
    done

    return 0
}

function download {
    
    for s in $SOURCES ; do
        if echo $s | grep -Eq '::(http|https|ftp)://' ; then
            filename=$(echo $s | awk -F '::' '{print $1}')
            url=$(echo $s | awk -F '::' '{print $2}')
        else
            filename=$(basename $s)
            url=$s
        fi
        WGET_ARGS=${WGET_ARGS:-"-c --passive-ftp --no-directories --tries=3 --waitretry=3 --no-check-certificate"}

        if [[ "$filename" != "$s" ]] ; then
            if [[ ! -f "$SRC_DIR/$filename" ]] || [[ $REDOWNLOAD ]] ; then
                [[ $REDOWNLOAD ]] && rm -f "$SRC_DIR/$filename.part"
                
                INFO_MESG "Downloading $filename"
                wget $WGET_ARGS --output-document="$SRC_DIR/$filename.part" $url
                if [[ "$?" = 0 ]] ; then
                    mv "$SRC_DIR/$filename".part "$SRC_DIR/$filename"
                else
                    ERR_EXIT $ERR_CODE_EXECUTION "Failed to download $filename"
                fi
            fi
        else
            [[ ! -f $filename ]] && ERR_EXIT $ERR_CODE_NOT_EXIST "source file $SRC_DIR/$filename is missing"
        fi         
    done
    return 0
}

function prepare {
    umask 022


    [[ -d $WRK_DIR/$name ]] && rm -r $WRK_DIR/$name

    mkdir -p $src $pkg

    for s in $SOURCES ; do
        if echo $s | grep -Eq '::(http|https|ftp)://'; then
				filename=$SRC_DIR/$(echo $s | awk -F '::' '{print $1}')
        elif echo $s | grep -Eq '^(http|https|ftp)://'; then
            filename=$SRC_DIR/$(basename $s)
        else
            filename=$PWD/$(basename $s)
        fi
        for NOEXT in $noextract; do
            if [ "$NOEXT" = "$(basename $filename)" ]; then
                nxt=1
                break
            fi
        done
        
        [[ ! -f "$filename" ]] && ERR_EXIT $ERR_CODE_NOT_EXIST "source file '$SRC_DIR/$filename' is missing"

        if [[ "$filename" != "$file" ]] && [[ "$nxt" != 1 ]] ; then
            case $filename in
                *.tar|*.tar.*|*.tgz|*.tbz2|*.txz|*.zip|*.rpm)
                    case $filename in
                    	*bz2|*bzip2)   CMS=j ;;
                    	*gz)    CMS=z ;;
                    	*xz)    CMS=J ;;
                    	
                    esac
                    INFO_MESG "Extracting $(basename $filename)"
                    tar -C $src -${CMS} -xf $filename
                    ;;
                *)
                    INFO_MESG "Preparing $(basename $filename)"
                    cp "$filename" "$src"
                    ;;
            esac
            if [[ "$?" != 0 ]] ; then
                ERR_EXIT $ERR_CODE_EXECUTION "failed"
            fi
        else
            INFO_MESG "copying $(basename $filename)"
            cp "$filename" "$src"
            if [[ "$?" != 0 ]] ; then
                ERR_EXIT $ERR_CODE_EXECUTION "failed"
            fi
        fi
        unset nxt
    done

}

function builder {
    [[ "$(id -u)" == 0 ]] || ERR_EXIT $ERR_CODE_PERMISSION "need superuser permission"

    INFO_MESG "compiling $name-$version"

    cd $src >/dev/null

    (set -e -x; build 2>&1)
    [[ "$?" == "0" ]] && INFO_MESG "Successfully compiled $name" || ERR_EXIT $ERR_CODE_EXECUTION "failed to compile $name"

    cd - >/dev/null

}

function strip__ {
    INFO_MESG "cleaning $name"
    cd $pkg >/dev/null
    [[ $nostrip_empty   ]] || find . -type d -empty -delete
    [[ $nostrip_libtool ]] || find . ! -type d -name "*.la" -delete
    
    if [[ -z "$nostrip" ]] ; then
	FILTER="cat"
    else
        for i in $nostrip ; do
            xstrip="$xstrip -e $i"
        done
        FILTER="grep -v $xstrip"
    fi
    
    INFO_MESG "stripping $name"
    find . -type f -printf "%P\n" 2>/dev/null | $FILTER | while read -r binary ; do
		case "$(file -bi "$binary")" in
			*application/x-sharedlib*)  # Libraries (.so)
				echo "stripping shared library"
				${CROSS_COMPILE}strip --strip-unneeded "$binary" 2>/dev/null ;;
			*application/x-pie-executable*)  # Libraries (.so)
				echo "stripping pie executable"
				${CROSS_COMPILE}strip --strip-unneeded "$binary" 2>/dev/null ;;
			*application/x-archive*)    # Libraries (.a)
				echo "stripping library archive"
				${CROSS_COMPILE}strip --strip-debug "$binary" 2>/dev/null ;;
			*application/x-object*)
				echo "stripping object"
				case "$binary" in
					*.ko)                   # Kernel module
						${CROSS_COMPILE}strip --strip-unneeded "$binary" 2>/dev/null ;;
					*)
						continue;;
				esac;;
			*application/x-executable*) # Binaries
				echo "stripping executable"
				strip --strip-all "$binary" 2>/dev/null 
				;;
			*)
				echo "continue"
				continue ;;
		esac
	done
    cd - >/dev/null
}

function gen_appinfo {
    INFO_MESG "generating info"
    cd $(dirname $RCP_FILE) >/dev/null

    mkdir -p $pkg/.data/
    
    for i in install update remove usrgrp data ; do
        [[ -f $i ]] && cp $i $pkg/.data/
    done

    echo "name: $name
version: $version
release: $release
description: $desc
depends on: $deps
" > $pkg/.data/info

    cd - >/dev/null
}

function package {
    INFO_MESG "compressing $name"
    cd $pkg >/dev/null

    rm -f usr/share/info/dir usr/info/dir
    rm -f usr/lib/charset.alias
    find . \( -name perllocal.pod -o -name .packlist \) -delete
	[ -d usr/share/fonts ] && {
		find usr/share/fonts \( -name fonts.dir -o -name fonts.scale \) -delete
	}

    for f in ${backup[@]} ; do
        INFO_MESG "backing up $f"
        mv $f $f.update
    done

    echo "size: $(du -hs .)" >> $pkg/.data/info
    echo "build: $(date +'%I:%M:%S %P %d-%m-%y')" >> $pkg/.data/info
    tar -cJf $PKG_DIR/$pkgname * .data || {
        #rm -f $PKG_DIR/$pkgname
        ERR_EXIT $ERR_CODE_EXECUTION "failed to compress $name"
    }

    #tar -tvf $PKG_DIR/$pkgname | sort -k 6

    cd ->/dev/null
}

function PrintHelp {

cat << EOF
$(basename $0) - part of rlxOS appctl tool to build package using recipe file

Usage:
    $(basename $0) [ <options> ]

Options:
    --specs                     Set Specification file
    --src-dir                   Set Source directory
    --pkg-dir                   Set Packages directory
    --wrd-dir                   Set Work directory
    --help                      Print help
    --recipe                    Set recipe file to use [default \$PWD/recipe]
    --exec                      Set function list and call order
    --redownload                Set REDOWNLOAD flags to perform re-download of source
    --repack                    Set REPACK flag to repack

EOF
}

function Main {
    for i in $@ ; do
        case "$i" in
            --repack)
                REPACK=1
                ;;

            --specs=*)
                SPEC_FILE=${i#*=}
                ;;

            --src-dir=*)
                SRC_DIR=${i#*=}
                ;;
            
            --pkg-dir=*)
                PKG_DIR=${i#*=}
                ;;
            
            --wrk-dir=*)
                WRK_DIR=${i#*=}
                ;;

            --help)
                PrintHelp
                exit 0
                ;;

            --recipe=*)
                RCP_FILE=${i#*=}
                ;;

            --exec=*)
                EXEC_LIST=${i#*=}
                ;;

            --redownload)
                REDOWNLOAD=1
                ;;
        esac
    done


    . $SPEC_FILE &>/dev/null || true

    checkDir "$SRC_DIR" "$PKG_DIR" "$WRK_DIR"
    
    if [[ ! -f "$RCP_FILE" ]] ; then
        ERR_MESG "$RCP_FILE not exist"
        exit $ERR_CODE_NOT_EXIST
    fi

    . $RCP_FILE

    desc=$(cat $RCP_FILE | grep '# Description:' | sed 's|# Description: ||g')
    deps=$(cat $RCP_FILE | grep '# Depends on:' | sed 's|# Depends on: ||g')

    if [[ ! -z $DEBUG ]] ; then
        echo "Name:    $name"
        echo "Version: $version"
        echo "Release: $release"
    fi
    src=$WRK_DIR/$name/src
    pkg=$WRK_DIR/$name/pkg

    pkgname=$name-$version-$release-$(uname -m).rlx

    for fnc in $EXEC_LIST ; do
        if [[ $(type -t $fnc) == "function" ]] ; then
            $fnc || {
                ERR_MESG "failed to execute $fnc"
                exit $ERR_CODE_EXECUTION
            }
        else
            ERR_MESG "$fnc is not a function type"
            exit $ERR_CODE_TYPE
        fi
    done

}

# _start
trap "interrupted" 1 2 3 15
export LC_ALL=C
SPEC_FILE='/rlx/conf/app/buildtool.in'

SRC_DIR='/rlx/cache/app/sources'
PKG_DIR='/rlx/cache/app/packages'
WRK_DIR='/rlx/cache/app/work'
EXEC_LIST='verify download prepare builder strip__ gen_appinfo package cleanup'
RCP_FILE=$PWD/recipe

Main $@
